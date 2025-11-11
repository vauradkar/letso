use std::collections::BTreeMap;
use std::fs;
use std::fs::create_dir_all;
use std::path::Path;
use std::path::PathBuf;

use async_walkdir::WalkDir;
use futures_lite::StreamExt;

use crate::Directory;
use crate::Error;
use crate::FileStat;
use crate::SyncItem;

// File paths and optional contents to create in the temporary test
pub(crate) static TEMP_FILES: &[(&str, &str, bool)] = &[
    ("file1.txt", "", false),
    ("file2.txt", "", false),
    ("dir1", "", true),
    ("dir1/file3.txt", "", false),
    ("dir1/dir2", "", true),
    ("dir1/dir2/file4.txt", "", false),
    ("dir1/dir2/dir_empty1", "", true),
    ("dir3", "", true),
    ("dir3/file6.txt", "", false),
];

/// Utility structure for managing a temporary test directory and its files.
#[derive(Debug)]
pub struct TestRoot {
    /// Root of the temporary test directory.
    pub root: tempdir::TempDir,
    /// Set of file paths created in the test root.
    pub files: BTreeMap<PathBuf, FileStat>,

    save_path: Option<PathBuf>,
}

impl TestRoot {
    /// Creates a new `TestRoot` instance with a temporary directory.
    pub async fn new(save_path: Option<&str>) -> Result<Self, Error> {
        let root = tempdir::TempDir::new("").map_err(|e| Error::CreateFailed {
            what: "temporary directory".into(),
            how: e.to_string(),
        })?;
        let mut ret = Self {
            root,
            files: BTreeMap::new(),
            save_path: save_path.map(|p| Path::new("/tmp/").join(p)),
        };
        for (relative_path, contents, is_dir) in TEMP_FILES {
            let dir = if *is_dir {
                Path::new(relative_path)
            } else {
                Path::new(relative_path).parent().unwrap()
            };
            println!("Creating dir: {}", dir.display());
            create_dir_all(ret.root.path().join(dir)).map_err(|e| Error::CreateFailed {
                what: format!("directory {}", dir.display()),
                how: e.to_string(),
            })?;
            if !*is_dir {
                ret.create_file(relative_path, Some(contents))
                    .await
                    .unwrap();
            }
        }
        ret.reload_files().await?;
        Ok(ret)
    }

    /// Creates a new file with the specified relative path and content in the
    /// temporary test directory.
    pub async fn create_file(
        &mut self,
        relative_path: &str,
        content: Option<&str>,
    ) -> Result<(), std::io::Error> {
        let full_path = self.root.path().join(relative_path);
        if let Some(parent) = full_path.parent() {
            create_dir_all(parent)?;
        }
        if let Some(content) = content {
            std::fs::write(&full_path, content)?;
        }
        let stat = FileStat::from_path(&full_path).await.unwrap();
        self.files.insert(relative_path.into(), stat);

        let mut parent = Path::new(relative_path);
        while let Some(p) = parent.parent() {
            let dir_path = self.root.path().join(p);
            let dir_stat = FileStat::from_path(&dir_path).await.unwrap();
            println!("Updating dir stat for {}: {:?}", p.display(), dir_stat);
            self.files.insert(p.to_path_buf(), dir_stat);
            parent = p;
        }

        Ok(())
    }

    async fn get_insertable(&self, path: &Path) -> Result<(PathBuf, FileStat), Error> {
        let stats = FileStat::from_path(path).await?;
        let relative_path = path
            .strip_prefix(self.root.path())
            .map_err(|e| Error::ReadError {
                what: "strip_prefix".into(),
                how: e.to_string(),
            })?;

        Ok((relative_path.to_owned(), stats))
    }

    async fn reload_files(&mut self) -> Result<(), Error> {
        let mut new_files: BTreeMap<PathBuf, FileStat> = BTreeMap::new();
        let mut entries = WalkDir::new(self.root.path());
        loop {
            match entries.next().await {
                Some(Ok(entry)) => {
                    let (p, s) = self.get_insertable(&entry.path()).await?;
                    new_files.insert(p, s);
                }
                Some(Err(e)) => {
                    return Err(Error::ReadError {
                        what: "reading directory entry".into(),
                        how: e.to_string(),
                    });
                }
                None => break,
            }
        }
        self.files = new_files;
        Ok(())
    }

    /// Returns error if they are this directory and items are not synced.
    pub fn are_synced(&self, items: &[SyncItem]) -> Result<(), Error> {
        let mut files: BTreeMap<PathBuf, FileStat> = BTreeMap::new();
        for item in items {
            let item_path = PathBuf::from(&item.path);
            files.insert(item_path, item.stats.clone().unwrap());
        }

        println!("on_disk files: {:#?}", self.files);
        println!("incoming files: {files:#?}");
        if files != self.files {
            let (more, _more_name, less, less_name) = if self.files.len() > files.len() {
                (&self.files, "on_disk", &files, "incoming")
            } else {
                (&files, "incoming", &self.files, "on_disk")
            };

            for (path, stat) in more {
                match less.get(path) {
                    Some(other_stat) => {
                        if stat != other_stat && !stat.is_directory {
                            return Err(Error::SyncFailed {
                                what: format!("File stats do not match for {}", path.display()),
                                how: format!("expected: {stat:?}, found: {other_stat:?}"),
                            });
                        }
                    }
                    None => {
                        return Err(Error::SyncFailed {
                            what: format!("File missing: {} in {}", path.display(), less_name),
                            how: "File not found in synced items".to_string(),
                        });
                    }
                }
            }
        }

        Ok(())
    }

    /// Verify that all entries in `dir` match the files recorded in this
    /// TestRoot; panics if any entry's stats differ or are missing.
    pub fn match_entries(&self, dir: &Directory) {
        let dir_path = PathBuf::from(&dir.current_path);
        for item in &dir.items {
            let path = dir_path.join(&item.name);
            println!("Matching entry: {}", path.display());
            let stat = self.files.get(&path).unwrap();
            assert_eq!(&item.stats, stat);
        }
    }

    fn copy_dir_all(src: impl AsRef<Path>, dst: impl AsRef<Path>) -> Result<(), Error> {
        create_dir_all(&dst).unwrap();
        for entry in fs::read_dir(src).unwrap() {
            let entry = entry.unwrap();
            let ty = entry.file_type().unwrap();
            if ty.is_dir() {
                Self::copy_dir_all(entry.path(), dst.as_ref().join(entry.file_name())).unwrap();
            } else {
                fs::copy(entry.path(), dst.as_ref().join(entry.file_name())).unwrap();
            }
        }
        Ok(())
    }
}

impl Drop for TestRoot {
    fn drop(&mut self) {
        if let Some(save_path) = &self.save_path {
            let _ = Self::copy_dir_all(self.root.path(), save_path);
            println!("TestRoot preserved at {}", save_path.to_string_lossy());
        }
    }
}

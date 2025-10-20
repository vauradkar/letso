use std::fmt::Display;
use std::path::PathBuf;

use poem_openapi::Object;
use serde::Deserialize;
use serde::Deserializer;
use serde::Serialize;
use serde::de;

use crate::Error;
use crate::FileStat;
use crate::SyncItem;

/// A custom deserializer function for a Vec<String> that checks for ".."
/// components.
fn deserialize_components<'de, D>(deserializer: D) -> Result<Vec<String>, D::Error>
where
    D: Deserializer<'de>,
{
    let components = Vec::<String>::deserialize(deserializer)?;

    if components.iter().any(|c| c == ".." || c == ".") {
        // If an invalid component is found, return a custom error
        Err(de::Error::custom("Path component cannot contain '..'"))
    } else {
        // If all components are valid, return the result
        Ok(components)
    }
}

/// Represents a filesystem path as a vector of its portable components.
#[derive(Debug, Clone, Serialize, Deserialize, Object, PartialEq)]
pub struct PortablePath {
    /// The components of the portable path as a vector of strings.
    #[serde(deserialize_with = "deserialize_components")]
    components: Vec<String>,
}

impl PortablePath {
    /// Returns the last component of the portable path, typically the file or
    /// directory name.
    pub fn basename(&self) -> Option<&str> {
        self.components.last().map(|s| s.as_str())
    }
}

impl Display for PortablePath {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let path: PathBuf = self.into();
        write!(f, "{}", path.display())
    }
}

impl PortablePath {
    fn get_file_stat(&self) -> Result<Option<FileStat>, Error> {
        let path: PathBuf = self.into();
        if path.exists() {
            let metadata = path.metadata().map_err(|e| Error::ReadError {
                what: "metadata".into(),
                how: e.to_string(),
            })?;
            Ok(Some(FileStat::from(&metadata)))
        } else {
            Ok(None)
        }
    }
    /// Looks up the metadata for the current portable path.
    ///
    /// # Returns
    /// * `Result<Lookup, Error>` - The lookup result containing the path and
    ///   its metadata, or an error message.
    pub fn lookup(&self) -> Result<SyncItem, Error> {
        Ok(SyncItem {
            path: self.clone(),
            stats: self.get_file_stat()?,
        })
    }

    /// Returns the parent path of the current `PortablePath`, or `None` if
    /// there is no parent.
    pub fn parent(&self) -> Option<PortablePath> {
        if self.components.is_empty() {
            None
        } else {
            let mut parent_components = self.components.clone();
            parent_components.pop();
            Some(PortablePath {
                components: parent_components,
            })
        }
    }

    /// Appends a new component to the end of the portable path.
    ///
    /// # Arguments
    ///
    /// * `component` - The path component to add.
    pub fn push(&mut self, component: &str) {
        self.components.push(component.to_owned());
    }
}

impl<T> TryFrom<&[T]> for PortablePath
where
    T: AsRef<str>,
{
    type Error = Error;

    fn try_from(components: &[T]) -> std::result::Result<Self, Self::Error> {
        let mut c = Vec::new();
        for comp in components {
            let s = comp.as_ref();
            if s.contains('/') || s.contains('\\') {
                return Err(Error::InvalidArgument(format!(
                    "Invalid path component: {s}"
                )));
            }
            if s == "." || s == ".." || s.is_empty() {
                return Err(Error::InvalidArgument(format!(
                    "Invalid path component: {s}"
                )));
            }
            c.push(s.to_string());
        }
        Ok(PortablePath { components: c })
    }
}

impl TryFrom<&PathBuf> for PortablePath {
    type Error = Error;

    fn try_from(path: &PathBuf) -> Result<Self, Self::Error> {
        let str = path.to_string_lossy();
        if str == "." || str == ".." {
            return Err(Error::InvalidArgument(
                "Path cannot contain '.' or '..' components".to_string(),
            ));
        }
        let components = path
            .components()
            .filter_map(|comp| {
                let s = comp.as_os_str().to_str()?;
                if s == std::path::Component::RootDir.as_os_str().to_str().unwrap() {
                    None
                } else {
                    Some(s.to_string())
                }
            })
            .collect();
        Ok(PortablePath { components })
    }
}

impl From<&PortablePath> for PathBuf {
    fn from(portable: &PortablePath) -> Self {
        let mut path = PathBuf::new();
        for comp in &portable.components {
            if comp != "." && comp != ".." && comp != "/" {
                path.push(comp);
            }
        }
        path
    }
}

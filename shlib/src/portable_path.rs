use std::fmt::Display;
use std::path::PathBuf;

use poem_openapi::Object;
use serde::Deserialize;
use serde::Serialize;

use crate::Error;
use crate::FileStat;
use crate::LookupResult;

/// Represents a filesystem path as a vector of its portable components.
#[derive(Debug, Clone, Serialize, Deserialize, Object, PartialEq)]
pub struct PortablePath {
    /// The components of the portable path as a vector of strings.
    pub components: Vec<String>,
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
    pub fn lookup(&self) -> Result<LookupResult, Error> {
        Ok(LookupResult {
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

impl From<&PathBuf> for PortablePath {
    fn from(path: &PathBuf) -> Self {
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
        PortablePath { components }
    }
}

impl From<&PortablePath> for PathBuf {
    fn from(portable: &PortablePath) -> Self {
        let mut path = PathBuf::new();
        for comp in &portable.components {
            path.push(comp);
        }
        path
    }
}

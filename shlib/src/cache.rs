use std::num::NonZeroUsize;

use lru::LruCache;
use poem_openapi::Object;
use serde::Deserialize;
use serde::Serialize;

use crate::FileStat;
use crate::PortablePath;

#[derive(Default, Debug, Clone, Serialize, Deserialize, PartialEq, Object)]
pub struct CacheStats {
    pub hits: u64,
    pub misses: u64,
}

pub(crate) struct Cache {
    lru: LruCache<PortablePath, FileStat>,
    stats: CacheStats,
}

impl Cache {
    pub fn new(capacity: NonZeroUsize) -> Self {
        Cache {
            lru: LruCache::new(capacity),
            stats: CacheStats::default(),
        }
    }

    pub fn get(&mut self, key: &PortablePath) -> Option<&FileStat> {
        let ret = self.lru.get(key);
        if ret.is_some() {
            self.stats.hits += 1;
        } else {
            self.stats.misses += 1;
        }
        ret
    }

    pub fn put(&mut self, key: PortablePath, value: FileStat) {
        self.lru.put(key, value);
    }

    #[cfg(test)]
    pub(crate) fn stats(&self) -> &CacheStats {
        &self.stats
    }

    #[cfg(test)]
    pub fn len(&self) -> u64 {
        self.lru.len() as u64
    }

    pub fn pop(&mut self, key: &PortablePath) -> Option<FileStat> {
        self.lru.pop(key)
    }

    #[cfg(test)]
    pub fn dump_keys(&self) -> String {
        self.lru.iter().for_each(|(k, _v)| println!("\"{}\"", k));
        "".to_owned()
    }
}

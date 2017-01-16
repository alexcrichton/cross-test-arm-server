#[macro_use]
extern crate serde_derive;
extern crate flate2;

use std::fmt;
use std::fs::File;
use std::io::Read;
use std::io;
use std::path::Path;

#[derive(Deserialize, Serialize)]
pub struct Executable {
    contents: Vec<u8>,
    name: String,
}

impl fmt::Debug for Executable {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.debug_struct("File")
            .field("name", &self.name)
            .field("size", &self.contents.len())
            .finish()
    }
}

impl Executable {
    pub fn open<P>(path: P) -> Self
        where P: AsRef<Path>
    {
        Self::open_(path.as_ref())
    }

    fn open_(path: &Path) -> Self {
        let mut contents = Vec::new();
        {
            let mut output = flate2::write::ZlibEncoder::new(&mut contents,
                    flate2::Compression::Best);
            let mut input = File::open(path).unwrap();
            io::copy(&mut input, &mut output).unwrap();
        }

        Executable {
            contents: contents,
            name: path.file_name().unwrap().to_string_lossy().into_owned(),
        }
    }

    pub fn contents(&self) -> Vec<u8> {
        let mut ret = Vec::new();
        flate2::read::ZlibDecoder::new(&self.contents[..])
            .read_to_end(&mut ret)
            .unwrap();
        return ret
    }

    pub fn name(&self) -> &str {
        &self.name
    }
}

#[derive(Deserialize, Serialize)]
pub struct Output {
    pub status: ExitStatus,
    pub stderr: Vec<u8>,
    pub stdout: Vec<u8>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct ExitStatus {
    pub code: Option<i32>,
    pub success: bool,
}

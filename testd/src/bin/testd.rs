extern crate bincode;
extern crate byteorder;
extern crate tempdir;
extern crate testd;

use std::fs::{File, Permissions};
use std::fs;
use std::io::{Read, Write};
use std::net::TcpListener;
use std::os::unix::fs::PermissionsExt;
use std::process::Command;

use bincode::SizeLimit;
use bincode::serde;
use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt};
use tempdir::TempDir;
use testd::{Executable, ExitStatus, Output};

const PORT: u16 = 12345;

pub fn main() {
    let listener = TcpListener::bind(("10.0.2.15", PORT)).unwrap();

    println!("Listening on {:?}", listener.local_addr());

    for stream in listener.incoming() {
        println!("got a peer");
        let mut stream = stream.unwrap();
        println!("{:?}", stream.peer_addr());
        println!("{:?}", stream.local_addr());

        let size = stream.read_u64::<LittleEndian>().unwrap();
        println!("got blob: {}", size);
        let mut blob = vec![0; size as usize];
        println!("allocated blob");
        stream.read_exact(&mut blob[..]).unwrap();
        println!("finished reading blob");

        let exec: Executable = serde::deserialize(&blob).unwrap();
        println!("got executable {:?}", exec);

        println!("creating tempdir");
        let td = TempDir::new("testd").unwrap();
        println!("creating a path");
        let tfile = td.path().join("test");
        println!("creating a file");
        File::create(&tfile).unwrap().write_all(&exec.contents()).unwrap();
        println!("set permissions");
        fs::set_permissions(&tfile, Permissions::from_mode(0o755)).unwrap();
        println!("worte the file");
        let coutput = Command::new(&tfile).output().unwrap();

        let output = Output {
            stdout: coutput.stdout,
            stderr: coutput.stderr,
            status: ExitStatus {
                success: coutput.status.success(),
                code: coutput.status.code(),
            },
        };
        println!("{:?}", output.status);

        let blob = serde::serialize(&output, SizeLimit::Infinite).unwrap();
        println!("done serializing");
        stream.write_u64::<LittleEndian>(blob.len() as u64).unwrap();
        println!("done writing length");
        stream.write_all(&blob).unwrap();
        println!("done writing blob");
    }
}

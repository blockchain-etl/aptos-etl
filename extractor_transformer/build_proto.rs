#[cfg(feature = "APTOS")]
include!("src/aptos_config/build_proto.rs");

include!("src/features.rs");

fn main() -> std::io::Result<()> {
    match build_protos() {
        Ok(_) => Ok(()),
        Err(_) => panic!("Failed to build protos"),
    }
}

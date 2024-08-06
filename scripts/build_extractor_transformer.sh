sudo apt install git cargo g++ protobuf-compiler
git clone --recurse-submodules --remote-submodules https://github.com/BCWResearch/aptos-etl.git
cd aptos-etl/extractor_transformer/
cargo build --release

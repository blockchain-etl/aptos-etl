# this will compile the pubsub_range protobuf for the python scripts in `aptos-etl/indexing_coordinator/` to use.
# NOTE: currently, the compiled protobuf is uploaded to this repo as  `aptos-etl/indexing_coordinator/pubsub_range_pb2.py`
#   so this script only needs to be re-run if you are making changes to the protobuf.
sudo apt install g++ protobuf-compiler
git clone --recurse-submodules --remote-submodules https://github.com/BCWResearch/aptos-etl.git
cd aptos-etl/indexing_coordinator/
protoc pubsub_range.proto --python_out=.

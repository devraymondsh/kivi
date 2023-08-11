set -e
cd core
zig build
zig build test
cd ..
cd drivers/js/nodejs
./build.sh
cd ../../..

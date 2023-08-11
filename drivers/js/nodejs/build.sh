set -e
# mkdir -p src/include
# npm i
# npm run install-headers
zig build
mv zig-out/lib/libnode.so zig-out/lib/addon.node
node src/index.js

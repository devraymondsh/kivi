import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const machine = os.machine();
let platform = os.platform();
let libNamePrefix = "lib";
if (platform == "win32") {
  platform = "windows";
  libNamePrefix = "";
}
let suffix;
switch (platform) {
  case "windows":
    suffix = "dll";
    break;
  case "dylib":
    suffix = "dll";
    break;
  default:
    suffix = "so";
    break;
}

export const coreDllPath = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  `../../../../zig-out/lib/${libNamePrefix}kivi-${machine}-${platform}.${suffix}`
);
export const addonDllPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  `../../../../zig-out/lib/kivi-addon-${machine}-${platform}.node`
);

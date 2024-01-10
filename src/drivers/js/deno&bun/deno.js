import path from "node:path";
import { fileURLToPath } from "node:url";

let suffix = "";
switch (Deno.build.os) {
  case "windows":
    suffix = "dll";
    break;
  case "darwin":
    suffix = "dylib";
    break;
  default:
    suffix = "so";
    break;
}

export const machine = Deno.build.arch;
export let platform = Deno.build.os;
let libNamePrefix = "lib";
if (platform == "win32") {
  platform = "windows";
}
if (platform == "windows") {
  libNamePrefix = "";
}
const dllPath = new URL(
  await import.meta.resolve(
    `../../../../zig-out/lib/${libNamePrefix}kivi-${machine}-${platform}.${suffix}`
  )
);
export const dlopenLib = Deno.dlopen(dllPath, {
  kivi_init: { parameters: ["pointer", "pointer"], result: "u32" },
  kivi_deinit: { parameters: ["pointer"], result: "void" },
  kivi_get: {
    parameters: ["pointer", "pointer", "usize", "pointer", "usize"],
    result: "u32",
  },
  kivi_set: {
    parameters: ["pointer", "pointer", "usize", "pointer", "usize"],
    result: "u32",
  },
  kivi_del: {
    parameters: ["pointer", "pointer", "usize", "pointer", "usize"],
    result: "u32",
  },
  kivi_rm: {
    parameters: ["pointer", "pointer", "usize"],
    result: "void",
  },
});

export const denoUtils = {
  makeBufferPtr: function (value) {
    return Deno.UnsafePointer.of(value);
  },
  symbols: dlopenLib.symbols,
};

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

export const dlopenLib = Deno.dlopen(
  `../../core/zig-out/lib/libkivi.${suffix}`,
  {
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
  }
);

export const denoUtils = {
  makeBufferPtr: function (value) {
    return Deno.UnsafePointer.of(value);
  },
  symbols: dlopenLib.symbols,
  cstringToJs: function (value_scratch, len) {
    const ptr = Deno.UnsafePointer.create(addr);
    if (ptr == null) return null;

    const sub = value_scratch.subarray(0, len);
    new Deno.UnsafePointerView(ptr).copyInto(sub, 0);

    return new TextDecoder().decode(sub);
  },
};

export const dlopenLib = Deno.dlopen("../../core/zig-out/lib/libkivi.so", {
  CollectionInit: { parameters: ["pointer"], result: "u32" },
  CollectionDeinit: { parameters: ["pointer"], result: "void" },
  CollectionGet: {
    parameters: ["pointer", "pointer", "pointer", "usize"],
    result: "void",
  },
  CollectionSet: {
    parameters: ["pointer", "pointer", "usize", "pointer", "usize"],
    result: "bool",
  },
  CollectionRmOut: {
    parameters: ["pointer", "pointer", "usize"],
    result: "void",
  },
});

export const denoUtils = {
  makeBufferPtr: function (value) {
    return Deno.UnsafePointer.of(value);
  },
  symbols: dlopenLib.symbols,
  cstringToJs: function (addr, len, value_scratch) {
    const ptr = Deno.UnsafePointer.create(addr);
    if (ptr == null) return null;

    const sub = value_scratch.subarray(0, len);
    new Deno.UnsafePointerView(ptr).copyInto(sub, 0);

    return new TextDecoder().decode(sub);
  },
};

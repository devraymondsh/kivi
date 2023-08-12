function isBun() {
  return "Bun" in globalThis;
}
function isDeno() {
  return "Deno" in globalThis;
}
function isNodeJS() {
  return typeof global !== "undefined" && globalThis === global;
}

var utils = undefined;
if (isBun()) {
  const { dlopen, FFIType, suffix, ptr, CString } = await import("bun:ffi");

  const lib = dlopen(`libkivi.${suffix}`, {
    CollectionInit: {
      args: [FFIType.ptr],
      returns: FFIType.u32,
    },
    CollectionGet: {
      args: [FFIType.ptr, FFIType.ptr, FFIType.cstring, FFIType.usize],
    },
    CollectionSet: {
      args: [
        FFIType.ptr,
        FFIType.cstring,
        FFIType.usize,
        FFIType.cstring,
        FFIType.usize,
      ],
      returns: FFIType.u32,
    },
    CollectionRm: {
      args: [FFIType.ptr, FFIType.cstring, FFIType.usize],
    },
    CollectionDeinit: {
      args: [FFIType.ptr],
    },
  });

  utils = {
    makeBufferPtr: function (value) {
      return ptr(value);
    },
    symbols: lib.symbols,
    cstringToJs: function (addr, len) {
      return new CString(Number(addr), 0, Number(len));
    },
  };
} else if (isDeno()) {
  const lib = Deno.dlopen("./libkivi.so", {
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
    CollectionRm: {
      parameters: ["pointer", "pointer", "usize"],
      result: "void",
    },
  });

  utils = {
    makeBufferPtr: function (value) {
      return Deno.UnsafePointer.of(value);
    },
    symbols: lib.symbols,
    cstringToJs: function (addr, len, value_scratch) {
      const ptr = Deno.UnsafePointer.create(addr);
      if (ptr == null) return null;

      const sub = value_scratch.subarray(0, len);
      new Deno.UnsafePointerView(ptr).copyInto(sub, 0);

      return new TextDecoder().decode(sub);
    },
  };
} else if (isNodeJS()) {
  const { createRequire } = await import("node:module");
  const require = createRequire(import.meta.url);
  const addon = require("./nodejs/zig-out/lib/addon.node");

  utils = {
    makeBufferPtr: function (value) {
      return value;
    },
    symbols: addon,
    cstringToJs: function (addr, len, value_scratch) {
      return "";
    },
  };
} else {
  throw new Error(
    "Unsupported runtime! Kivi only supports Bun, Deno, and Nodejs."
  );
}

export class Collection {
  #buf = new Uint8Array(120);
  #ptr = utils.makeBufferPtr(this.#buf);

  #str_buf = new Uint8Array(16);
  #str_ptr = utils.makeBufferPtr(this.#str_buf);
  #str_dv = new DataView(
    this.#str_buf.buffer,
    this.#str_buf.byteOffset,
    this.#str_buf.byteLength
  );

  #key_scratch = new Uint8Array(4096);
  #key_scratch_ptr = utils.makeBufferPtr(this.#key_scratch);
  value_scratch = new Uint8Array(4096);
  #value_scratch_ptr = utils.makeBufferPtr(this.value_scratch);

  constructor() {
    if (utils.symbols.CollectionInit(this.#ptr) !== 0) {
      throw new Error("Failed to initialize a collection!");
    }
  }
  destroy() {
    utils.symbols.CollectionDeinit(this.#ptr);
  }

  get(/** @type {string} */ key) {
    const res = new TextEncoder().encodeInto(key, this.#key_scratch);
    utils.symbols.CollectionGet(
      this.#ptr,
      this.#str_ptr,
      this.#key_scratch_ptr,
      res.written
    );

    const addr = this.#str_dv.getBigUint64(0, true);
    const len = Number(this.#str_dv.getBigUint64(8, true));

    if (len > 4096) {
      throw new Error("value too long");
    }

    return utils.cstringToJs(addr, len, this.value_scratch);
  }
  set(/** @type {string} */ key, /** @type {string} */ value) {
    const key_len = new TextEncoder().encodeInto(
      key,
      this.#key_scratch
    ).written;
    const value_len = new TextEncoder().encodeInto(
      value,
      this.value_scratch
    ).written;

    if (
      utils.symbols.CollectionSet(
        this.#ptr,
        this.#key_scratch_ptr,
        key_len,
        this.#value_scratch_ptr,
        value_len
      )
    ) {
      throw new Error("Failed to insert key!");
    }
  }
  rm(/** @type {string} */ key) {
    const key_len = new TextEncoder().encodeInto(
      key,
      this.#key_scratch
    ).written;

    // TODO: Replace the line below with CollectionRm.
    utils.symbols.CollectionRmOut(this.#ptr, this.#key_scratch_ptr, key_len);
  }
}

// while (true) {
//   {
//     // Plain JS object
//     const o = {};
//     const start = performance.now();
//     for (let i = 0; i < 1_000_000; i++) {
//       const key = `foo_${i}`;
//       o[key];
//       o[key] = "bar";
//       o[key];
//     }
//     const end = performance.now();
//     console.log("Plain JS object\t", end - start, "ms");
//   }

//   {
//     // JS Map
//     const m = new Map();
//     const start = performance.now();
//     for (let i = 0; i < 1_000_000; i++) {
//       const key = `foo_${i}`;
//       m.get(key);
//       m.set(key, "bar");
//       m.get(key);
//     }
//     const end = performance.now();
//     console.log("JS Map\t\t", end - start, "ms");
//   }

//   {
//     // kivi
//     const c = new Collection();
//     const start = performance.now();
//     for (let i = 0; i < 1_000_000; i++) {
//       const key = `foo_${i}`;
//       c.get(key);
//       c.set(key, "bar");
//       c.get(key);
//     }
//     const end = performance.now();
//     c.destroy();
//     console.log("kivi\t\t", end - start, "ms");
//   }
// }

const c = new Collection();
c.destroy();

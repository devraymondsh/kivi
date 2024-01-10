import { Buffer } from "node:buffer";

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
export let libNamePrefix = "lib";
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

const lib = Deno.dlopen(dllPath, {
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

export class DenoKivi {
  #selfbuf = new ArrayBuffer(72);
  #self = Deno.UnsafePointer.of(this.#selfbuf);

  value_scratch_buf = new Buffer.alloc(4096);
  value_scratch = Deno.UnsafePointer.of(this.value_scratch_buf);

  temp_buf;

  init() {
    return lib.symbols.kivi_init(this.#self, null);
  }
  destroy() {
    return lib.symbols.kivi_deinit(this.#self);
  }

  get(key) {
    const written_len = lib.symbols.kivi_get(
      this.#self,
      Deno.UnsafePointer.of(key),
      key.length,
      this.value_scratch,
      this.value_scratch_buf.length
    );
    if (written_len) {
      return this.value_scratch_buf;
    } else {
      if (written_len > this.value_scratch_buf.length) {
        this.temp_buf = Buffer.alloc(written_len);
        lib.symbols.kivi_get(
          this.#self,
          Deno.UnsafePointer.of(key),
          key.length,
          Deno.UnsafePointer.of(this.temp_buf),
          this.temp_buf.length
        );
        return this.temp_buf;
      }
    }
    return null;
  }
  set(key, value) {
    if (
      !lib.symbols.kivi_set(
        this.#self,
        Deno.UnsafePointer.of(key),
        key.length,
        Deno.UnsafePointer.of(value),
        value.length
      )
    ) {
      throw new Error("Out of memory!");
    }
  }
  del(key) {
    const written_len = lib.symbols.kivi_del(
      this.#self,
      Deno.UnsafePointer.of(key),
      key.length,
      this.value_scratch,
      this.value_scratch_buf.length
    );
    if (written_len) {
      return this.value_scratch_buf;
    } else {
      if (written_len > this.value_scratch_buf.length) {
        this.temp_buf = Buffer.alloc(written_len);
        lib.symbols.kivi_get(
          this.#self,
          Deno.UnsafePointer.of(key),
          key.length,
          Deno.UnsafePointer.of(this.temp_buf),
          this.temp_buf.length
        );
        return this.temp_buf;
      }
    }
    return null;
  }
  rm(key) {
    lib.symbols.kivi_rm(this.#self, Deno.UnsafePointer.of(key), key.length);
  }
}

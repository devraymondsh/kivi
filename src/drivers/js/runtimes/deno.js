import { Buffer } from "node:buffer";
import { KiviRuntime } from "./runtime.js";
import { coreDllPath } from "./dll.js";
import { kiviInstanceSize } from "../codegen-generated.js";

let lib = undefined;
export class DenoKivi extends KiviRuntime {
  #selfbuf = new ArrayBuffer(kiviInstanceSize);
  #self = Deno.UnsafePointer.of(this.#selfbuf);

  value_scratch_buf = new Buffer.alloc(4096);
  value_scratch = Deno.UnsafePointer.of(this.value_scratch_buf);

  temp_buf;

  constructor(config) {
    super(config);

    if (!lib) {
      lib = Deno.dlopen(coreDllPath, {
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
    }

    lib.symbols.kivi_init(this.#self, null);
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

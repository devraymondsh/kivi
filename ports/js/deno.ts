// cd core/zig-out/lib
// deno run --unstable ../../../ports/js/deno.ts

const lib = Deno.dlopen("./libcore.so", {
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
  CollectionRm: { parameters: ["pointer", "pointer", "usize"], result: "void" },
});

class Collection {
  #buf = new Uint8Array(128);
  #ptr = Deno.UnsafePointer.of(this.#buf);
  #str_buf = new Uint8Array(16);
  #str_ptr = Deno.UnsafePointer.of(this.#str_buf);
  #str_dv = new DataView(
    this.#str_buf.buffer,
    this.#str_buf.byteOffset,
    this.#str_buf.byteLength,
  );
  #key_scratch = new Uint8Array(4096);
  #key_scratch_ptr = Deno.UnsafePointer.of(this.#key_scratch);
  #value_scratch = new Uint8Array(4096);
  #value_scratch_ptr = Deno.UnsafePointer.of(this.#value_scratch);
  constructor() {
    if (lib.symbols.CollectionInit(this.#ptr) !== 0) {
      throw new Error("Failed to initialize a collection!");
    }
  }
  destroy() {
    lib.symbols.CollectionDeinit(this.#ptr);
  }

  get(key: string) {
    const res = new TextEncoder().encodeInto(key, this.#key_scratch);
    lib.symbols.CollectionGet(
      this.#ptr,
      this.#str_ptr,
      this.#key_scratch_ptr,
      res.written,
    );

    const addr = this.#str_dv.getBigUint64(0, true);
    const len = Number(this.#str_dv.getBigUint64(8, true));
    if (len > 4096) {
      throw new Error("value too long");
    }
    const ptr = Deno.UnsafePointer.create(addr);
    if (ptr == null) return null;
    const sub = this.#value_scratch.subarray(0, len);
    new Deno.UnsafePointerView(ptr).copyInto(sub, 0);
    return new TextDecoder().decode(sub);
  }
  set(key: string, value: string) {
    const key_len =
      new TextEncoder().encodeInto(key, this.#key_scratch).written;
    const value_len =
      new TextEncoder().encodeInto(value, this.#value_scratch).written;
    if (
      lib.symbols.CollectionSet(
        this.#ptr,
        this.#key_scratch_ptr,
        key_len,
        this.#value_scratch_ptr,
        value_len,
      )
    ) {
      throw new Error("Failed to insert key!");
    }
  }
  rm(key: string) {
    const key_len =
      new TextEncoder().encodeInto(key, this.#key_scratch).written;
    lib.symbols.CollectionRm(this.#ptr, this.#key_scratch_ptr, key_len);
  }
}

const coll = new Collection();

console.log(coll.get("foo"));

coll.set("foo", "bar");

console.log(coll.get("foo"));

coll.rm("foo");

console.log(coll.get("foo"));

coll.destroy();

console.time("runtime");
const c = new Collection();
for (let i = 0; i < 100_000; i++) {
  c.get("foo");
  c.set("foo", "bar");
  c.get("foo");
  c.rm("foo");
  c.get("foo");
}
c.destroy();
console.timeEnd("runtime");

import { dlopen, FFIType, suffix, ptr, CString } from "bun:ffi";

const lib = dlopen(`libcore.${suffix}`, {
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

export class Collection {
  collectionPtr;

  constructor() {
    const collectionPtr = ptr(new Uint8Array(128));
    const CollectionInitRes = lib.symbols.CollectionInit(collectionPtr);

    if (CollectionInitRes != 0) {
      throw new Error("Failed to initialize a collection!");
    }

    this.collectionPtr = collectionPtr;
  }

  set(key, value) {
    if (typeof key !== "string" || typeof value !== "string") {
      throw new Error("Key and Value should both be strings!");
    }

    const collectionSetRes = lib.symbols.CollectionSet(
      this.collectionPtr,
      ptr(Buffer.from(key, "utf8")),
      key.length,
      ptr(Buffer.from(value, "utf8")),
      value.length
    );

    if (collectionSetRes != 0) {
      throw new Error("Failed to set a value! Maximum memory usage!");
    }
  }

  get(key) {
    if (typeof key !== "string") {
      throw new Error("Key should be a string!");
    }

    let strArr = new Uint8Array(16);
    lib.symbols.CollectionGet(
      this.collectionPtr,
      ptr(strArr),
      ptr(Buffer.from(key, "utf8")),
      key.length
    );

    const dv = new DataView(
      strArr.buffer,
      strArr.byteOffset,
      strArr.byteLength
    );
    const addr = dv.getBigUint64(0, true);
    const len = dv.getBigUint64(8, true);

    if (addr === 0n) {
      return null;
    }

    return new CString(Number(addr), 0, Number(len));
  }

  rm(key) {
    if (typeof key !== "string") {
      throw new Error("Key should be a string!");
    }

    lib.symbols.CollectionRm(
      this.collectionPtr,
      ptr(Buffer.from(key, "utf8")),
      key.length
    );
  }

  destroy() {
    lib.symbols.CollectionDeinit(this.collectionPtr);
  }
}

const collection = new Collection();
collection.set("foo", "bar");
console.log(collection.get("foo"));

collection.rm("foo");
console.log(collection.get("foo"));

collection.destroy();

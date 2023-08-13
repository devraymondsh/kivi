import { dlopen, FFIType, suffix, ptr, CString } from "bun:ffi";

export const dlopenLib = dlopen(`../../core/zig-out/lib/libkivi.${suffix}`, {
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
  CollectionRmOut: {
    args: [FFIType.ptr, FFIType.cstring, FFIType.usize],
  },
  CollectionDeinit: {
    args: [FFIType.ptr],
  },
});

export const bunUtils = {
  makeBufferPtr: function (value) {
    return ptr(value);
  },
  symbols: dlopenLib.symbols,
  cstringToJs: function (addr, len) {
    if (len != 0) {
      return new CString(Number(addr), 0, len);
    } else {
      return null;
    }
  },
};

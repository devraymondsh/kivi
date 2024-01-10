What is Kivi?
--------------
Kivi is a high-performance in-memory key-value database written in the Zig programming language. Kivi is designed to be embeddable, concurrent, and fast.

> :warning: **Kivi is currently in development mode and not production-ready.**

## Latest benchmark
comparing Kivi to Javascript's builtin Map:
| Runtime | FFI  | Lookup       | Insertion    | Deletion     |
|---------|------|--------------|--------------|--------------|
| NodeJs  | Napi | 2x slower    | 1.2x faster  | 1.9x slower  |
| Deno    | Napi | 1.47x slower | 2.48x slower | 1.44x slower |
| Deno    | FFI  | 6.89x slower | 4.07x slower | 7.73x slower |
| Bun     | Napi | 1.06x faster | 1.23 faster  | 1.08x slower |
| Bun     | FFI  | 1.64x slower | 1.3x slower  | 1.97x slower |

## Code of conduct
You can check our [code of conduct guidelines](CODE_OF_CONDUCT.md).

## License
Kivi is licensed under MIT. Head over to [LICENSE](LICENSE) for full description.

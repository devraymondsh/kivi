What is Kivi?
--------------
Kivi is a high-performance in-memory key-value database written in the Zig programming language. Kivi is designed to be embeddable, concurrent, and fast.

> :warning: **Kivi is currently in development mode and not production-ready.**

## Latest benchmark:
```
JsMap:
┌─────────┬─────────────────┬────────────────────┬───────────────────┐
│ (index) │ totalLookupTime │ totalInsertionTime │ totalDeletionTime │
├─────────┼─────────────────┼────────────────────┼───────────────────┤
│    0    │  '1112.18 ms'   │    '1258.46 ms'    │   '1272.44 ms'    │
│    1    │  '1103.26 ms'   │    '1199.46 ms'    │   '1281.72 ms'    │
│ average │  '1107.72 ms'   │    '1228.96 ms'    │   '1277.08 ms'    │
└─────────┴─────────────────┴────────────────────┴───────────────────┘

Kivi:
┌─────────┬─────────────────┬────────────────────┬───────────────────┐
│ (index) │ totalLookupTime │ totalInsertionTime │ totalDeletionTime │
├─────────┼─────────────────┼────────────────────┼───────────────────┤
│    0    │  '1350.07 ms'   │    '559.04 ms'     │   '1355.66 ms'    │
│    1    │  '1349.39 ms'   │    '557.93 ms'     │    '1346.2 ms'    │
│ average │  '1349.73 ms'   │    '558.49 ms'     │   '1350.93 ms'    │
└─────────┴─────────────────┴────────────────────┴───────────────────┘

 This table shows how much JsMap is faster than Kivi:
┌───────────┬─────────┐
│  (index)  │ Values  │
├───────────┼─────────┤
│  lookup   │ '1.22x' │
│ insertion │ '0.45x' │
│ deletion  │ '1.06x' │
└───────────┴─────────┘
```

## Code of conduct:
You can check our [code of conduct guidelines](CODE_OF_CONDUCT.md).

## License:
Kivi is licensed under MIT. Head over to [LICENSE](LICENSE) for full description.

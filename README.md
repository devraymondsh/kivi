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
│    0    │   '134.71 ms'   │     '362.9 ms'     │    '212.05 ms'    │
│    1    │   '140.82 ms'   │    '149.01 ms'     │    '217.53 ms'    │
│ average │   '137.77 ms'   │    '255.95 ms'     │    '214.79 ms'    │
└─────────┴─────────────────┴────────────────────┴───────────────────┘

Kivi:
┌─────────┬─────────────────┬────────────────────┬───────────────────┐
│ (index) │ totalLookupTime │ totalInsertionTime │ totalDeletionTime │
├─────────┼─────────────────┼────────────────────┼───────────────────┤
│    0    │   '916.68 ms'   │     '225.9 ms'     │    '976.8 ms'     │
│    1    │   '907.01 ms'   │    '217.65 ms'     │   '1017.35 ms'    │
│ average │   '911.84 ms'   │    '221.78 ms'     │    '997.08 ms'    │
└─────────┴─────────────────┴────────────────────┴───────────────────┘

 This table shows how much JsMap is faster than Kivi:
┌───────────┬─────────┐
│  (index)  │ Values  │
├───────────┼─────────┤
│  lookup   │ '6.62x' │
│ insertion │ '0.85x' │
│ deletion  │ '4.64x' │
└───────────┴─────────┘
```

## Code of conduct:
You can check our [code of conduct guidelines](CODE_OF_CONDUCT.md).

## License:
Kivi is licensed under MIT. Head over to [LICENSE](LICENSE) for full description.

What is Kivi?
--------------
Kivi is a high-performance in-memory key-value database written in the Zig programming language. Kivi is designed to be embeddable, concurrent, and fast.

> :warning: **Kivi is currently in development mode and not production-ready.**

## Latest benchmark:
```
JsMap:
┌─────────┬─────────────────┬─────────────────────┬────────────────────┬────────────────────────┬───────────────────┬───────────────────────┐
│ (index) │ totalLookupTime │ totalBulkLookupTime │ totalInsertionTime │ totalBulkInsertionTime │ totalDeletionTime │ totalBulkDeletionTime │
├─────────┼─────────────────┼─────────────────────┼────────────────────┼────────────────────────┼───────────────────┼───────────────────────┤
│    0    │   '134.17 ms'   │     '138.9 ms'      │    '155.65 ms'     │       '301.3 ms'       │    '197.46 ms'    │      '215.23 ms'      │
│    1    │   '137.91 ms'   │     '135.72 ms'     │    '151.54 ms'     │      '167.48 ms'       │    '242.4 ms'     │      '217.72 ms'      │
│ average │   '136.04 ms'   │     '137.31 ms'     │    '153.59 ms'     │      '234.39 ms'       │    '219.93 ms'    │      '216.48 ms'      │
└─────────┴─────────────────┴─────────────────────┴────────────────────┴────────────────────────┴───────────────────┴───────────────────────┘

Kivi:
┌─────────┬─────────────────┬─────────────────────┬────────────────────┬────────────────────────┬───────────────────┬───────────────────────┐
│ (index) │ totalLookupTime │ totalBulkLookupTime │ totalInsertionTime │ totalBulkInsertionTime │ totalDeletionTime │ totalBulkDeletionTime │
├─────────┼─────────────────┼─────────────────────┼────────────────────┼────────────────────────┼───────────────────┼───────────────────────┤
│    0    │   '352.02 ms'   │     '774.82 ms'     │    '341.96 ms'     │      '555.72 ms'       │    '346.08 ms'    │      '793.16 ms'      │
│    1    │   '353.9 ms'    │     '791.95 ms'     │    '341.23 ms'     │      '543.91 ms'       │    '367.19 ms'    │      '805.19 ms'      │
│ average │   '352.96 ms'   │     '783.38 ms'     │    '341.59 ms'     │      '549.81 ms'       │    '356.64 ms'    │      '799.18 ms'      │
└─────────┴─────────────────┴─────────────────────┴────────────────────┴────────────────────────┴───────────────────┴───────────────────────┘

 This table shows how much JsMap is faster than Kivi:
┌───────────────┬─────────┐
│    (index)    │ Values  │
├───────────────┼─────────┤
│    lookup     │ '2.59x' │
│   insertion   │ '2.22x' │
│   deletion    │ '1.62x' │
│  bulkLookup   │ '5.71x' │
│ bulkInsertion │ '2.35x' │
│ bulkDeletion  │ '3.69x' │
└───────────────┴─────────┘
```

## Code of conduct:
You can check our [code of conduct guidelines](CODE_OF_CONDUCT.md).

## License:
Kivi is licensed under MIT. Head over to [LICENSE](LICENSE) for full description.

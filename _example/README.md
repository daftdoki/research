# Python dict vs list vs set Membership Lookup Performance

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

*This is an example project showing the expected format for research reports in this repository.*

## Question

How does membership testing (`x in collection`) scale for Python `dict`, `set`, and `list` across collection sizes from 10 to 100,000 elements? ([original prompt](#original-prompt))

## Answer

**dict and set are constant-time (O(1)); list is linear (O(n)).** At 100,000 elements, a list lookup for a missing element takes ~1.35ms — roughly 50,000x slower than a dict or set lookup (~27ns). Dict and set performance is essentially identical and does not degrade with size. For additional and more detailed information see the [research notes](notes.md).

## Methodology

Benchmarked using Python's [`timeit`](https://docs.python.org/3/library/timeit.html) module at collection sizes of 10, 100, 1K, 10K, and 100K. Two cases tested per structure:

- **Found**: target is the middle element (`size // 2`)
- **Missing**: target does not exist in the collection (`size + 1`)

Each measurement averaged over 1,000–100,000 iterations depending on size.

## Results

Nanoseconds per lookup:

| Size | list (found) | list (miss) | dict (found) | dict (miss) | set (found) | set (miss) |
|-----:|-------------:|------------:|-------------:|------------:|------------:|-----------:|
| 10 | 82 | 136 | 28 | 25 | 26 | 23 |
| 100 | 695 | 1,313 | 28 | 25 | 26 | 23 |
| 1,000 | 6,843 | 13,503 | 29 | 25 | 26 | 24 |
| 10,000 | 68,242 | 134,897 | 30 | 26 | 27 | 24 |
| 100,000 | 681,054 | 1,350,422 | 34 | 29 | 32 | 26 |

## Analysis

- **List** scales linearly. The "found" case averages half a full scan; the "missing" case requires a full scan. At 100K elements, a miss takes 1.35ms — unacceptable in any hot path.
- **Dict and set** stay flat at ~25–34ns regardless of size, as expected from hash table O(1) amortized lookups. The slight increase at 100K likely reflects cache effects.
- **Set is marginally faster than dict** (~10%) since it stores only keys, not key-value pairs, producing a smaller memory footprint and better cache behavior.
- For membership testing, **`set` is the idiomatic choice**. Use `dict` when you also need associated values.

## Files

- `benchmark.py` — Benchmark script using `timeit`; prints a table and saves JSON
- `results.json` — Raw benchmark results in nanoseconds per lookup
- `notes.md` — Research notes and work log

## Original Prompt

> How does membership testing (`x in collection`) scale for Python `dict`, `set`, and `list` across collection sizes from 10 to 100,000 elements?

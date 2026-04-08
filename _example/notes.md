# Python dict vs list lookup performance — Notes

## Goal

Investigate how Python `dict` (`in` operator) compares to `list` (`in` operator) for membership testing at various collection sizes.

## Approach

Write a benchmark script using `timeit` that tests both data structures at sizes 10, 100, 1,000, 10,000, and 100,000. Search for an element that exists (best/average case) and one that doesn't (worst case for list).

## Work log

- Started by writing `benchmark.py` with `timeit` module
- Used `number=10000` iterations for small sizes, `number=1000` for larger ones to keep runtime reasonable
- Initially forgot to test the "not found" case — added that after the first run
- Realized I should also test `set` since that's the idiomatic choice for membership testing
- Added set to the benchmark for completeness
- Results were dramatic — dict/set are O(1) as expected, list is clearly O(n)
- At size 100,000 the list lookup was ~1000x slower than dict for the "not found" case
- Wrote up findings in README.md

"""Benchmark dict vs list vs set membership testing in Python."""

import timeit
import json

SIZES = [10, 100, 1_000, 10_000, 100_000]
ITERATIONS = {10: 100_000, 100: 100_000, 1_000: 10_000, 10_000: 1_000, 100_000: 1_000}


def benchmark_lookup(size):
    data_list = list(range(size))
    data_dict = {i: True for i in range(size)}
    data_set = set(range(size))

    # Element in the middle (found case)
    target_found = size // 2
    # Element that doesn't exist (not-found case)
    target_missing = size + 1

    n = ITERATIONS[size]
    results = {}

    for label, structure, target in [
        ("list_found", data_list, target_found),
        ("list_missing", data_list, target_missing),
        ("dict_found", data_dict, target_found),
        ("dict_missing", data_dict, target_missing),
        ("set_found", data_set, target_found),
        ("set_missing", data_set, target_missing),
    ]:
        t = timeit.timeit(lambda: target in structure, number=n)
        per_op_ns = (t / n) * 1e9
        results[label] = round(per_op_ns, 1)

    return results


def main():
    all_results = {}
    for size in SIZES:
        print(f"Benchmarking size={size:,}...")
        all_results[size] = benchmark_lookup(size)

    print("\nResults (nanoseconds per lookup):\n")
    header = f"{'Size':>10} | {'list found':>12} | {'list miss':>12} | {'dict found':>12} | {'dict miss':>12} | {'set found':>12} | {'set miss':>12}"
    print(header)
    print("-" * len(header))
    for size in SIZES:
        r = all_results[size]
        print(
            f"{size:>10,} | {r['list_found']:>12.1f} | {r['list_missing']:>12.1f} | "
            f"{r['dict_found']:>12.1f} | {r['dict_missing']:>12.1f} | "
            f"{r['set_found']:>12.1f} | {r['set_missing']:>12.1f}"
        )

    with open("results.json", "w") as f:
        json.dump(all_results, f, indent=2)
    print("\nSaved to results.json")


if __name__ == "__main__":
    main()

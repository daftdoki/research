# Research Notes: Python tsnet Equivalent

## What I set out to find
Whether there's a Python analog of Tailscale's `tsnet` Go library for embedding a Tailscale node directly into an application.

## Key findings

### 1. libtailscale — Official Tailscale C library with Python bindings
- Repo: https://github.com/tailscale/libtailscale
- Has a `python/` directory with bindings wrapping the C library
- The C library is built from Go via `cgo` with `-buildmode=c-archive`
- Python bindings expose a `TSNet` class with `up()`, `listen()`, `close()` methods
- Also has a `TSNetListener` with `accept()` and `close()`
- Example echo server exists at `python/examples/echo.py`
- **Not on PyPI** — must be built from source
- Requires: Python 3.9+, Go compiler, CMake, C compiler, Git
- Build is reportedly broken as of mid-2025 (gvisor dependency issues, see tailscale/tailscale#14178)
- FR to publish on PyPI: tailscale/tailscale#7920 — still open

### 2. Python API surface of libtailscale
From the echo.py example:
```python
from tailscale import TSNet

ts = TSNet(ephemeral=True)
ts.up()
ln = ts.listen("tcp", ":1999")
conn = ln.accept()
# conn is a file descriptor, use os.read/os.write
```
- Uses raw file descriptors, not Python socket objects
- Uses os.fork() for concurrency in the example (not asyncio)
- Very low-level compared to Go's tsnet

### 3. Other Python packages (NOT tsnet equivalents)
- `tailscale` on PyPI (by frenck) — async client for the Tailscale **control plane API**, not embedded networking
- `tailscale_agent` on PyPI — also just a Tailscale API client wrapper
- `tslocal` on PyPI — client for the Tailscale Local API (talks to the local daemon via Unix socket)
- None of these embed a Tailscale node in-process

### 4. Architecture of libtailscale
- Go tsnet code → compiled as C archive (libtailscale.a) → C header (tailscale.h)
- Python uses a C extension module (`_tailscale`) that links against the archive
- Same approach works for Ruby, Swift, etc.

### 5. Current status (April 2026)
- libtailscale repo has ~48 commits, 296 stars, no releases
- Build has been broken due to gvisor dependency issues
- Workaround exists (updating deps with `go get -u tailscale.com && go mod tidy`)
- Not actively maintained at a high pace
- Swift bindings seem to get the most attention (47.5% of codebase)

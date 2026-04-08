# Python Equivalent of Tailscale's tsnet Go Library

## Question

Is there a Python analog of Tailscale's [tsnet](https://tailscale.com/docs/features/tsnet) Go library that allows embedding a Tailscale node directly into an application, without running a separate Tailscale daemon?

## Answer

**Yes, but it's immature and currently broken.** Tailscale maintains [`libtailscale`](https://github.com/tailscale/libtailscale), a C library with [Python bindings](https://github.com/tailscale/libtailscale/tree/main/python) that provides the same embed-a-Tailscale-node capability as tsnet. However, it is not published to PyPI, must be compiled from source (requiring a Go toolchain, CMake, and a C compiler), and its build has been [broken due to dependency issues](https://github.com/tailscale/tailscale/issues/14178) since at least mid-2025. There is no production-ready, pip-installable equivalent of tsnet for Python today.

## How libtailscale Works

The architecture is:

```
Go tsnet code
    ↓  (cgo, -buildmode=c-archive)
libtailscale.a + tailscale.h  (C library)
    ↓  (C extension module)
Python `tailscale` package
```

Tailscale compiles the Go tsnet implementation into a static C archive, then wraps it with language-specific bindings. The same approach supports Swift, Ruby, and other languages.

### Python API

The Python bindings expose a `TSNet` class:

```python
from tailscale import TSNet

ts = TSNet(ephemeral=True)
ts.up()

ln = ts.listen("tcp", ":1999")
conn = ln.accept()      # returns a raw file descriptor
data = os.read(conn, 2048)

ln.close()
ts.close()
```

Key characteristics:
- **Raw file descriptors** — connections are `int` FDs, not Python `socket` objects
- **No asyncio integration** — the example uses `os.fork()` and `select.select()`
- **Minimal API** — `TSNet` has `up()`, `listen()`, `set_authkey()`, `close()`; `TSNetListener` has `accept()` and `close()`
- **Authentication** via `$TS_AUTHKEY` env var, `ts.set_authkey()`, or interactive authorization URL

### Building from Source

Requirements: Python 3.9+, Go compiler, CMake, C compiler, Git.

```bash
git clone https://github.com/tailscale/libtailscale.git
cd libtailscale/python
python3 -m venv .venv && source .venv/bin/activate
make build
```

This produces a wheel like `tailscale-0.0.1-cp310-cp310-linux_x86_64.whl`.

**Current blocker:** The build fails due to an outdated gvisor dependency. A [workaround](https://github.com/tailscale/tailscale/issues/14178) involves running `go get -u tailscale.com && go mod tidy` before building.

## Other Python Tailscale Packages (Not tsnet Equivalents)

These exist on PyPI but serve different purposes:

| Package | What it does | tsnet equivalent? |
|---|---|---|
| [`tailscale`](https://pypi.org/project/tailscale/) (frenck) | Async client for the Tailscale control plane API | No — API client only |
| [`tailscale_agent`](https://pypi.org/project/tailscale_agent/) | Another Tailscale API wrapper | No — API client only |
| [`tslocal`](https://pypi.org/project/tslocal/) | Client for the Tailscale Local API (Unix socket to local daemon) | No — talks to existing daemon |

None of these embed a Tailscale node in-process.

## Practical Alternatives for Python Developers

If you need a Python application accessible on your tailnet today, the realistic options are:

1. **`tailscale serve` / `tailscale funnel`** — Proxy your Python app through the local Tailscale daemon. No code changes needed. You mentioned you're already familiar with this.

2. **Write a Go sidecar with tsnet** — Build a small Go binary using tsnet that proxies traffic to your Python app over localhost. Gives you the tsnet identity/cert benefits with a stable, well-supported library.

3. **Build libtailscale from source** — Use the Python bindings directly if you can tolerate the build complexity and the current dependency breakage. Suitable for experimentation, not production.

4. **Use the Tailscale Local API** — If the Tailscale daemon is already running, use [`tslocal`](https://pypi.org/project/tslocal/) to interact with it programmatically (manage serve config, get node status, etc.).

## Status Summary

| Aspect | Status |
|---|---|
| Official Python bindings exist? | Yes, in [libtailscale](https://github.com/tailscale/libtailscale/tree/main/python) |
| On PyPI? | No ([open FR since 2023](https://github.com/tailscale/tailscale/issues/7920)) |
| Currently builds? | No — [broken deps](https://github.com/tailscale/tailscale/issues/14178), workaround available |
| Production ready? | No |
| API completeness vs Go tsnet | Minimal (listen/accept only, no `Dial`, no HTTPS cert helpers) |
| Active development? | Low — ~48 commits total, Swift bindings get most attention |

## Files

| File | Description |
|---|---|
| `README.md` | This report |
| `notes.md` | Raw research notes and findings |

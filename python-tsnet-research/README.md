# Python Equivalent of Tailscale's tsnet

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

Tailscale's `tsnet` is a Go library that lets you embed a Tailscale node directly into a Go application -- no separate Tailscale daemon needed. Does an equivalent exist for Python? This investigation searches for official offerings, third-party libraries, FFI approaches, and alternative integration patterns.

## Answer / Summary

**There is no production-ready Python equivalent of tsnet.** However, Tailscale does maintain experimental Python bindings inside their [`libtailscale`](https://github.com/tailscale/libtailscale/tree/main/python) C library repository. These bindings provide the same embed-a-Tailscale-node capability as Go's tsnet, but they are **not on PyPI**, must be built from source (requiring Go, CMake, and a C compiler), are at version 0.0.1, and have reported build failures. No third-party Python library provides equivalent functionality.

For Python developers who need Tailscale integration today, the most practical approaches are: (1) running `tailscaled` as a sidecar/subprocess and communicating via its local API socket, or (2) using the Tailscale cloud/local API client libraries.

## Detailed Findings

### 1. Official: libtailscale Python Bindings (Experimental)

**Repository:** [github.com/tailscale/libtailscale](https://github.com/tailscale/libtailscale) (296 stars, BSD-3-Clause)

Tailscale maintains a C library called `libtailscale` that compiles Tailscale into a process entirely from userspace. It includes bindings for multiple languages, including Python.

**Architecture:**
```
Go (Tailscale core) --> C archive (go build -buildmode=c-archive) --> C++ pybind11 wrapper --> Python module
```

**Python API (from `python/tailscale/tsnet.py`):**
```python
from tailscale import TSNet

ts = TSNet(ephemeral=True)   # Create embedded Tailscale node
ts.up()                       # Bring the node online
ln = ts.listen("tcp", ":1999") # Listen on a port
conn = ln.accept()            # Accept connections (returns raw fd)
ln.close()
ts.close()
```

**Full C++ binding surface (from `python/src/main.cpp`):**
- `new`, `start`, `up`, `close` -- server lifecycle
- `listen`, `accept`, `dial` -- networking
- `set_dir`, `set_hostname`, `set_authkey`, `set_control_url`, `set_ephemeral`, `set_log_fd` -- configuration
- `loopback` -- loopback interface

**Build requirements:** Python 3.9+, Go compiler, CMake, C compiler, Git

**Build process:**
```bash
python3 -m venv venv && source venv/bin/activate
make build    # Compiles C archive from Go, then builds pybind11 extension
make wheel    # Produces a wheel for distribution
```

**Current status: Experimental / Broken**
- Version 0.0.1
- Not published to PyPI
- [Issue #7920](https://github.com/tailscale/tailscale/issues/7920) (open) requests PyPI publication; a June 2025 comment reports the build is broken
- [Issue #14178](https://github.com/tailscale/tailscale/issues/14178) documents build failures due to undefined gvisor functions
- The PyPI package name `tailscale` is already taken by a different project (API client)

### 2. No Official Python-Native tsnet

Tailscale does **not** offer a standalone Python tsnet package. Their GitHub organization has no Python-language repositories. The only Python code they maintain is the ~4.6% of the libtailscale repo described above.

### 3. No Third-Party Python tsnet Libraries

Extensive GitHub and web searches found **no community projects** that provide tsnet-equivalent embedding for Python. The `HanKruiger/tsNET` repository that appears in searches is unrelated (it's a graph visualization tool).

### 4. libtailscale C Library (FFI Foundation)

The core `libtailscale` produces either a static archive (`libtailscale.a`) or shared library via:
```bash
go build -buildmode=c-archive  # or make archive
go build -buildmode=c-shared   # or make shared
```

This C library **could** be used from Python via `ctypes` or `cffi` directly, bypassing the pybind11 wrapper. However, no one has published such bindings. The existing pybind11 approach is the only implemented path.

Community FFI bindings for libtailscale exist in other languages:
| Language | Repository | Stars |
|----------|-----------|-------|
| Rust | [messense/libtailscale-rs](https://github.com/messense/libtailscale-rs) | 29 |
| Kotlin | [gay-pizza/libtailscale](https://github.com/gay-pizza/libtailscale) | 3 |
| Java | [thetbw/libtailscale_java](https://github.com/thetbw/libtailscale_java) | 0 |
| Zig | [outskirtslabs/libtailscale-zig](https://github.com/outskirtslabs/libtailscale-zig) | 0 |
| Lua | [rosskukulinski/kong-tailscale-plugin](https://github.com/rosskukulinski/kong-tailscale-plugin) | 0 |

### 5. Python Packages in the Tailscale Ecosystem

These are all **API clients** -- they talk to a running Tailscale daemon or cloud API. None embed a Tailscale node.

| Package | PyPI Name | What It Does | Version | Maturity |
|---------|-----------|-------------|---------|----------|
| [frenck/python-tailscale](https://github.com/frenck/python-tailscale) | `tailscale` | Async client for Tailscale cloud API | 0.6.2 | Production/Stable |
| [kevinbringard/tailscale-python-client](https://github.com/kevinbringard/tailscale-python-client) | `tailscale_agent` | Tailscale API bindings | 0.5.0 | WIP |
| [apognu/tailscale_localapi](https://pypi.org/project/tailscale_localapi/) | `tailscale_localapi` | Local daemon socket API client | 0.5.0 | Active |
| [bouk/tslocal](https://github.com/bouk/tslocal) | `tslocal` | Local API client (port of Go client) | 0.3.1 | Active |
| Pulumi | `pulumi-tailscale` | Infrastructure-as-code provider | -- | Stable |

### 6. Alternative Approaches for Python Developers

#### Option A: libtailscale Python Bindings (embed, experimental)
Build from source and embed Tailscale directly. Highest integration but fragile build, no PyPI, experimental API.

#### Option B: Tailscaled Sidecar + Local API (recommended for production)
Run `tailscaled` in userspace mode as a sidecar or subprocess. Use `tailscale_localapi` or `tslocal` to control it programmatically via the Unix socket at `/var/run/tailscale/tailscaled.sock`. This gives you:
- Stable, supported daemon
- Programmatic control (set exit nodes, query peers, manage certs)
- No complex build dependencies

```python
# Example with tslocal
from tslocal import Client
with Client() as client:
    status = client.status()
    print(f"Tailscale version: {status.version}")
```

#### Option C: Tailscale Serve / Funnel (simplest)
Use `tailscale serve` to reverse-proxy your Python application onto your tailnet. No code changes needed, but limited to HTTP/HTTPS proxying.

#### Option D: SOCKS5 / HTTP Proxy (userspace networking)
Run `tailscaled` in userspace networking mode. It acts as a SOCKS5/HTTP proxy. Route your Python application's traffic through it using standard proxy configuration (e.g., `requests` library proxy settings).

#### Option E: DIY ctypes/cffi Wrapper
Build `libtailscale` as a shared library and write your own `ctypes` or `cffi` bindings against `tailscale.h`. This avoids the pybind11/CMake complexity but requires maintaining your own binding layer.

## Methodology

- Searched the [Tailscale GitHub organization](https://github.com/tailscale) for Python projects
- Examined the [libtailscale](https://github.com/tailscale/libtailscale) repository in detail (README, Python bindings source code, CMakeLists.txt, setup.py, main.cpp)
- Reviewed GitHub issues [#7920](https://github.com/tailscale/tailscale/issues/7920) and [#14178](https://github.com/tailscale/tailscale/issues/14178)
- Searched GitHub for community projects: `tsnet python`, `tailscale python wrapper binding`, `tailscale python embed`, `tailscale python integration`
- Searched GitHub code: `org:tailscale language:python tsnet`, `org:tailscale path:python _tailscale`
- Searched PyPI for all Tailscale-related packages
- Searched the web for blog posts, discussions, and alternative approaches

## Files

| File | Description |
|------|-------------|
| `README.md` | This report |
| `notes.md` | Raw research notes and search queries used |

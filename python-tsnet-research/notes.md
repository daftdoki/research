# Research Notes: Python Equivalent of Tailscale tsnet

## What I investigated
Whether there is a Python equivalent or analog of Tailscale's `tsnet` Go library, which lets you embed a Tailscale node directly into a Go application.

## Key findings

### 1. libtailscale has official Python bindings
- Found at https://github.com/tailscale/libtailscale/tree/main/python
- This is the closest thing to a Python tsnet equivalent
- It uses pybind11 to wrap the C library (which itself wraps the Go implementation)
- Build chain: Go -> C archive (via `go build -buildmode=c-archive`) -> C++ pybind11 wrapper -> Python module
- Requires Go compiler, CMake, C compiler, and Python 3.9+ to build
- NOT on PyPI - must be built from source
- Version: 0.0.1 - very early stage
- Build is reported broken as of June 2025 (referenced in issue #7920)
- Also a build failure issue #14178 with gvisor undefined functions

### 2. The API surface is minimal but functional
- TSNet class with: __init__(ephemeral), up(), listen(proto, addr), close()
- TSNetListener class with: accept(), close()
- C++ bindings expose: new, start, up, close, listen, accept, dial, set_dir, set_hostname, set_authkey, set_control_url, set_ephemeral, set_log_fd, loopback
- Python wrapper only exposes a subset of the C++ bindings
- Auth via $TS_AUTHKEY env var, TSNet.set_authkey(), or interactive URL
- Echo server example uses os.fork() for concurrency - very basic

### 3. Issue #7920 requesting PyPI package
- Feature request to add libtailscale to PyPI
- Tailscale contributor (Denton Gentry) pointed to existing libtailscale Python bindings
- User responded that it should be properly packaged on PyPI
- The "tailscale" name on PyPI is taken by frenck/python-tailscale (API client)
- Suggested alternatives: "libtailscale" or "pytailscale"
- Issue is still OPEN/reopened
- Recent commenter noted the build is broken

### 4. No third-party Python libraries provide tsnet-like embedding
- Searched GitHub extensively - no community projects wrapping tsnet for Python
- The only embedding approach is via libtailscale's Python bindings

### 5. Python packages in the Tailscale ecosystem (all API clients, NOT embedding)
- `tailscale` (PyPI) - frenck/python-tailscale - async client for Tailscale cloud API, v0.6.2
- `tailscale_agent` (PyPI) - kevinbringard/tailscale-python-client - Tailscale API bindings, v0.5.0
- `tailscale_localapi` (PyPI) - apognu - local daemon socket API, v0.5.0
- `tslocal` (PyPI) - bouk/tslocal - local API client (port of Go client), v0.3.1
- `pulumi-tailscale` (PyPI) - Pulumi provider for Tailscale resources

### 6. No Python projects in Tailscale's GitHub org
- Searched `org:tailscale language:python` - zero results
- The only Python code is inside the libtailscale repo under /python

### 7. libtailscale supports multiple languages
- Swift (47.5%), Go (15.2%), Ruby (13.5%), C (8.1%), Python (4.6%)
- Community bindings: Rust (29 stars), Kotlin, Java, Zig, Lua
- 296 stars, 50 forks, BSD-3-Clause license

### 8. Alternative approaches for Python developers
1. libtailscale Python bindings - embed directly, but build is fragile
2. tailscaled sidecar - run daemon in userspace, communicate via local API socket
3. tailscale serve/funnel - reverse proxy approach, CLI-based
4. Local API via Unix socket - use tailscale_localapi or tslocal packages
5. SOCKS5/HTTP proxy - tailscaled userspace networking mode
6. DIY ctypes/cffi wrapper against libtailscale shared library

## Search queries used
- GitHub repos: `tsnet python`, `org:tailscale language:python`, `tailscale python embed node`, `libtailscale`, `tailscale python wrapper binding`, `tailscale python integration`, `tailscale local api python`
- GitHub code: `org:tailscale language:python tsnet`, `org:tailscale path:python _tailscale`
- Web: various combinations of tailscale, tsnet, python, libtailscale, bindings, ctypes, cffi, PyPI

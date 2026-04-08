No production-quality Python equivalent to Tailscale's tsnet currently exists; the only near option is experimental Python bindings provided in Tailscale’s [`libtailscale`](https://github.com/tailscale/libtailscale/tree/main/python) C library repository. These bindings allow embedding a Tailscale node directly in Python, but they require manual build steps, are not published to PyPI, and are reportedly broken as of mid-2024. Third-party Python libraries for direct embedding do not exist, nor are there Python-native implementations. Most practical Python integrations rely on running the `tailscaled` daemon as a subprocess and communicating via its local UNIX socket API, using libraries like [`tslocal`](https://github.com/bouk/tslocal) or `tailscale_localapi`.

Key findings:
- Experimental libtailscale Python bindings exist but are hard to build and not production-ready.
- All Python Tailscale ecosystem packages are API clients, not node embedders.
- Running `tailscaled` as a subprocess and controlling it via the local API is the recommended, supported pattern for Python integration.

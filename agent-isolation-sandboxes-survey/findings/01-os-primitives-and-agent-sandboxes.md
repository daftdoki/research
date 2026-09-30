# Track 1: OS-level primitives and sandboxes built into coding agents

Research date: 2026-09-29. Every claim has an inline source. Where I read a raw file (README, script, man source), the URL is the upstream file. Some items are my own analysis of source code; those are labelled **[analysis]**.

---

## 0. Headline findings (TL;DR)

1. **All the built-in coding-agent sandboxes share the host kernel.** They are process sandboxes, not VMs: Claude Code/srt (bubblewrap or Seatbelt), Codex CLI (bubblewrap+seccomp or Seatbelt), Cursor (Landlock+seccomp or Seatbelt), and Gemini CLI's Seatbelt mode. A kernel bug is a sandbox escape. Anthropic's own docs name a VM as the tier for untrusted repos ([Claude Code sandbox-environments](https://code.claude.com/docs/en/sandbox-environments)).
2. **The Codex Linux sandbox is no longer Landlock-first.** The Codex Linux sandbox now uses **bubblewrap + seccomp by default**. The "legacy Landlock option is rejected" for filesystem-restricted policies "because it cannot isolate app-server Unix sockets" ([codex-rs/linux-sandbox/README.md](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md); [Codex Agent approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md): "Linux uses `bwrap` plus `seccomp` by default"). WSL1 lost support in Codex 0.115 because of this change (same source).
3. **Network filtering by domain works the same way in every tool: an out-of-sandbox proxy plus a netns/Seatbelt rule that forces traffic through it.** No tool terminates TLS by default. That leaves domain fronting and exfiltration through allowed broad domains open, and the vendors say so themselves ([Claude Code sandboxing: Security limitations](https://code.claude.com/docs/en/sandboxing); [srt README](https://github.com/anthropic-experimental/sandbox-runtime)).
4. **Proxy parser bugs have happened.** Real advisories: srt CVE-2025-66479 (the network sandbox was not enforced when no allowed domains were configured) ([GHSA-9gqj-5w7c-vx47](https://github.com/anthropic-experimental/sandbox-runtime/security/advisories/GHSA-9gqj-5w7c-vx47)), a SOCKS5 null-byte hostname allowlist bypass in Claude Code ([The Register, 2026-05-20](https://www.theregister.com/a/5243662)), a Claude Code git-worktree Seatbelt escape CVE-2026-55607 ([GHSA-7835-87q9-rgvv](https://github.com/anthropics/claude-code/security/advisories/GHSA-7835-87q9-rgvv)), and a Codex writable-root bypass CVE-2025-59532 ([GitLab advisory DB](https://advisories.gitlab.com/pkg/npm/@openai/codex/CVE-2025-59532/)).
5. **Observability is weak on Linux and better on macOS.** Bubblewrap has "no built-in violation reporting" (srt recommends `strace`) ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)). macOS Seatbelt denials show up in the unified log (`log stream`), and Codex exposes `codex sandbox macos --log-denials` ([Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md)). Since Linux 6.15 (Landlock ABI 7), Landlock emits native **audit records** (`AUDIT_LANDLOCK_ACCESS`, `AUDIT_LANDLOCK_DOMAIN`) ([kernel admin-guide Landlock](https://docs.kernel.org/admin-guide/LSM/landlock.html)).

---

## 1. Linux primitives

### 1.1 Namespaces (user / mount / net / pid / ipc / uts / cgroup / time)
- **Boundary:** each namespace gives a private view of one resource. The kernel is shared ([namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)). The user namespace lets unprivileged users create the other namespaces, which is what bubblewrap, srt, Codex and Cursor rely on ([bubblewrap README](https://github.com/containers/bubblewrap)).
- **Network namespace (`--unshare-net`)** leaves only loopback. It is the basis for "no network" in bwrap-based agent sandboxes ([bubblewrap README](https://github.com/containers/bubblewrap); [Codex linux-sandbox README](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md)).
- **Weakness, attack surface:** unprivileged user namespaces expose kernel interfaces normally reserved for root. Ubuntu cites Google data that "44% of the exploits they saw required unprivileged user namespaces" ([Ubuntu blog: restricted unprivileged user namespaces](https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces)). Ubuntu 23.10 added `kernel.apparmor_restrict_unprivileged_userns` (the same source). On Ubuntu 24.04+ it is on by default and breaks bwrap unless an AppArmor profile with `userns,` is loaded ([srt README Ubuntu 24.04 note](https://github.com/anthropic-experimental/sandbox-runtime); [Codex sandboxing docs](https://learn.chatgpt.com/docs/sandboxing), which recommend loading `/etc/apparmor.d/bwrap-userns-restrict`).
- The Landlock authors caution that namespaces "are not designed for access-control ... their complexity can lead to security issues, especially when untrusted processes can manipulate them" ([kernel Landlock userspace-api doc, Q&A](https://docs.kernel.org/userspace-api/landlock.html)).
- **Observability:** none native. Namespaces produce no denial log. Operations fail with ENOENT/EPERM.

### 1.2 seccomp-bpf
- **What it is:** a per-thread syscall filter written in classic BPF. The kernel doc says: "System call filtering isn't a sandbox. It provides a clearly defined mechanism for minimizing the exposed kernel surface" ([kernel seccomp_filter doc](https://docs.kernel.org/userspace-api/seccomp_filter.html)).
- **Actions:** KILL_PROCESS, KILL_THREAD, TRAP, ERRNO, USER_NOTIF, TRACE, LOG, ALLOW (the same source).
- **Pitfalls:** filters must check the architecture, because syscall numbers differ across ABIs. USER_NOTIF supervisors are exposed to TOCTOU on pointer arguments (the same source). seccomp cannot inspect pointed-to data such as paths, so it cannot filter Unix sockets by path. srt notes that `allowUnixSockets` path lists are "Ignored (seccomp can't filter by path)" on Linux ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)).
- **Agent use:** srt blocks `socket(AF_UNIX, ...)` via seccomp in a nested user+PID namespace (x64/arm64 only). If the filter is unavailable, sockets are **unrestricted with only a warning** ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)). In Claude Code the seccomp filter is "optional and adds Unix domain socket blocking" ([Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing)). Codex applies "`PR_SET_NO_NEW_PRIVS` and a seccomp network filter in-process", and in proxy mode "seccomp blocks new AF_UNIX/socketpair creation" ([Codex linux-sandbox README](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md)).
- **Observability:** `SECCOMP_RET_LOG` and `SECCOMP_FILTER_FLAG_LOG` exist since Linux 4.14. Logging is controlled by `/proc/sys/kernel/seccomp/actions_logged`, and ALLOW can never be logged ([seccomp(2)](https://man7.org/linux/man-pages/man2/seccomp.2.html)). Records go to the audit subsystem (type=SECCOMP) when audit is enabled. ERRNO returns are not logged unless the filter sets the LOG flag, so a typical EPERM-returning agent filter is silent by default. **[analysis based on seccomp(2)]**

### 1.3 Landlock LSM
- **What it is:** an unprivileged, stackable LSM. A process restricts itself and its future children via `landlock_create_ruleset`/`add_rule`/`restrict_self` ([landlock(7)](https://man7.org/linux/man-pages/man7/landlock.7.html)). It needs `CONFIG_SECURITY_LANDLOCK=y` and `landlock` in `lsm=` ([kernel Landlock doc](https://docs.kernel.org/userspace-api/landlock.html)).
- **ABI to kernel mapping:**

| ABI | Kernel | Adds | Source |
|---|---|---|---|
| 1 | 5.13 | FS: execute, read/write file, read dir, remove, make_* | [landlock(7)](https://man7.org/linux/man-pages/man7/landlock.7.html) |
| 2 | 5.19 | `FS_REFER` (cross-dir rename/link) | same |
| 3 | 6.2 | `FS_TRUNCATE` | same |
| 4 | 6.7 | **`NET_BIND_TCP`, `NET_CONNECT_TCP`** (port-based) | same |
| 5 | 6.10 | `FS_IOCTL_DEV` | same |
| 6 | 6.12 | `SCOPE_ABSTRACT_UNIX_SOCKET`, `SCOPE_SIGNAL` | same; [kernel doc](https://docs.kernel.org/userspace-api/landlock.html) |
| 7 | 6.15 | **audit logging flags** (`LOG_SAME_EXEC_OFF`, `LOG_NEW_EXEC_ON`, `LOG_SUBDOMAINS_OFF`) | [kernel doc](https://docs.kernel.org/userspace-api/landlock.html); kernel version per search/[LKML ABI 8 thread](https://kernsec.org/pipermail/linux-security-module-archive/2026-March/056508.html) |
| 8 | 7.0 (per search summary) | `RESTRICT_SELF_TSYNC` (all threads) | [kernel doc](https://docs.kernel.org/userspace-api/landlock.html) |
| 9 | ? | `FS_RESOLVE_UNIX` (pathname Unix sockets) | [kernel doc](https://docs.kernel.org/userspace-api/landlock.html) |
| 10 | ? | **UDP** `NET_BIND_UDP`, `NET_CONNECT_SEND_UDP`; `ADD_RULE_QUIET` | same |
| 11 | ? | `RESTRICT_SELF_NO_NEW_PRIVS` flag | same |

- **Network restriction is port-based only.** There are no IP or domain rules: a rule's object "is a TCP port" ([landlock(7)](https://man7.org/linux/man-pages/man7/landlock.7.html)). Domain allowlisting therefore still needs a proxy. landrun notes that TCP rules do not cover Multipath TCP and that UDP cannot be filtered on older ABIs ([landrun README](https://github.com/Zouuup/landrun)).
- **Limitations:** files opened before sandboxing are not restricted ([landlock(7)](https://man7.org/linux/man-pages/man7/landlock.7.html)). There is a limit of 16 stacked layers. Pipes, sockets and nsfs reached via `/proc/<pid>/fd` cannot be explicitly restricted. `FS_IOCTL_DEV` applies only to newly opened devices, so the TTY `TIOCSTI` caveat remains. `chroot` is not denied ([kernel doc, Current limitations](https://docs.kernel.org/userspace-api/landlock.html)).
- **Observability:** **the audit support is new (ABI 7 / Linux 6.15).** It adds the record types `AUDIT_LANDLOCK_ACCESS` (denials, with `blockers=fs.*|net.*|scope.*`) and `AUDIT_LANDLOCK_DOMAIN` (domain allocated/deallocated with creator PID/UID/exe). Example: `type=LANDLOCK_ACCESS msg=audit(...): domain=1a6fdc66f blockers=scope.signal opid=1 ocomm="systemd"`. Filtering uses auditctl, the restrict_self flags, or per-rule `LANDLOCK_ADD_RULE_QUIET` (ABI 10) ([kernel admin-guide Landlock](https://docs.kernel.org/admin-guide/LSM/landlock.html)). Landlock tracepoints "always fire when enabled" regardless of the log flags ([kernel userspace-api doc](https://docs.kernel.org/userspace-api/landlock.html)).
- **Agent users:** Cursor (Linux, needs kernel ≥ 6.2 / Landlock v3) ([Cursor run modes](https://cursor.com/docs/agent/security/run-modes.md)); landrun; minijail (has landlock code) ([minijail repo](https://github.com/google/minijail)); legacy Codex.

### 1.4 cgroups v2
- **Boundary:** resource limits only, not access control. Controllers are cpu, memory, io and pids. `memory.max` is a hard limit (OOM on breach), `memory.high` throttles, `pids.max` makes fork return EAGAIN (fork-bomb protection), and `cpu.max` sets "$MAX in each $PERIOD" ([kernel cgroup-v2 doc](https://docs.kernel.org/admin-guide/cgroup-v2.html)). Delegation to unprivileged users is supported with containment rules (same source).
- **Relevance:** none of the built-in agent sandboxes (srt, Codex, Cursor) documents CPU or memory limits **[analysis: not mentioned in any of their docs I read]**. For resource limits you need a container runtime, `systemd-run --user -p MemoryMax=...`, or nsjail (cgroup v1/v2 support) ([nsjail README](https://github.com/google/nsjail)). Rootless Podman cannot set resource limits on cgroups v1 ([Podman rootless.md](https://github.com/containers/podman/blob/main/rootless.md)).
- **Observability:** `memory.events`, `pids.events` counters (kernel cgroup-v2 doc).

### 1.5 AppArmor / SELinux (MAC LSMs)
- **Boundary:** a system-wide mandatory access control policy written by root. It is not self-applied like Landlock.
- **AppArmor:** complain mode logs violations without enforcing, and enforce mode enforces and logs. Tools: `aa-status`, `aa-complain`, `aa-enforce`, `aa-logprof` (scans the audit logs for denials), `aa-genprof` ([Ubuntu Server AppArmor docs](https://ubuntu.com/server/docs/how-to/security/apparmor/)). AppArmor also gates unprivileged userns on Ubuntu (see 1.1).
- **SELinux:** denials (AVC) go to `/var/log/audit/audit.log`. Query with `ausearch -m AVC,USER_AVC,...`, explain with `sealert`. `dontaudit` rules hide denials (`semodule -DB` exposes them) ([RHEL 9 SELinux troubleshooting](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_selinux/troubleshooting-problems-related-to-selinux_using-selinux)).
- **Relevance to agents:** these are the **best-observed** Linux controls because of the audit trail. They are rarely used directly for agent sandboxing and are more useful as a host-level guard around a container runtime, where Docker/Podman default profiles apply. **[analysis]**

---

## 2. Wrappers / sandbox launchers (Linux)

### 2.1 bubblewrap (`bwrap`)
- **What:** an unprivileged sandbox constructor built on user namespaces. "Historically ... supported a setuid mode ... However, this has been removed." It uses `PR_SET_NO_NEW_PRIVS` ([bubblewrap README](https://github.com/containers/bubblewrap)).
- **Key caveat:** "bubblewrap is not a complete, ready-made sandbox with a specific security policy ... the level of protection ... is entirely determined by the arguments passed" (same source).
- **Known pitfalls** (same source):
  - Without seccomp filtering of `TIOCSTI`, you need `--new-session` to prevent out-of-sandbox command injection (CVE-2017-5226).
  - "Everything mounted into the sandbox can potentially be used to escalate privileges", for example a bound D-Bus socket can run commands via systemd.
- Namespaces: PID (with a trivial pid1), IPC, net (loopback only), UTS; accepts a seccomp filter via fd (same source).
- **Observability:** none built in ([srt README](https://github.com/anthropic-experimental/sandbox-runtime): "Bubblewrap doesn't provide built-in violation reporting. Use `strace`").
- **Setup:** a distro package. On Ubuntu 24.04+ it needs the AppArmor userns profile (see 1.1). It fails in unprivileged containers because it cannot mount a fresh `/proc`, which is why Claude Code offers `enableWeakerNestedSandbox` and Codex falls back to the inherited `/proc` ([Claude Code sandboxing troubleshooting](https://code.claude.com/docs/en/sandboxing); [Codex linux-sandbox README](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md)).

### 2.2 firejail
- **What:** a **SUID-root** sandbox with namespaces, seccomp-bpf, capabilities, AppArmor/SELinux integration, 900+ app profiles, `--net=none`, `--private*` ([firejail README](https://github.com/netblue30/firejail)).
- **Weakness:** the SUID binary is itself attack surface. CVE-2022-31214: `--join` let a local user craft a fake container and gain **root** (0.9.68; fixed 0.9.70) ([Debian DSA-5167](https://www.debian.org/security/2022/dsa-5167); [Gentoo GLSA 202305-19](https://security.gentoo.org/glsa/202305-19.xml)). The bubblewrap README contrasts itself with firejail on exactly this point ([bubblewrap README](https://github.com/containers/bubblewrap)).
- **Relevance:** desktop app sandboxing. Not used by any major coding agent that I found.

### 2.3 nsjail (Google)
- Namespaces (UTS/MOUNT/PID/IPC/NET/USER/CGROUPS/TIME), cgroups v1/v2 (memory/pids/cpu/net_cls), rlimits, seccomp-bpf via the Kafel policy language. Modes are LISTEN/ONCE/EXECVE/RERUN. Networking via MACVLAN, a cloned interface, or pasta. Config is protobuf. "This is not an official Google product." ([nsjail README](https://github.com/google/nsjail)).
- **Good fit** for homelab "run this untrusted code with limits" (CTF hosting is an upstream example). Unlike bwrap it bundles resource limits.

### 2.4 minijail (Google)
- The "sandboxing and containment tool used in ChromeOS and Android". It works as an executable or as a library for self-sandboxing: change root/user, drop capabilities, seccomp policy files, and Landlock code present in the repo ([minijail docs](https://google.github.io/minijail/); [repo](https://github.com/google/minijail)).
- Seccomp failure-logging flags were not confirmed (see dead ends).

### 2.5 systemd service sandboxing / `systemd-run`
- Relevant directives ([systemd.exec(5) source](https://github.com/systemd/systemd/blob/main/man/systemd.exec.xml); [systemd.resource-control(5) source](https://github.com/systemd/systemd/blob/main/man/systemd.resource-control.xml)):
  - `ProtectSystem=strict` makes the whole FS read-only except /dev, /proc and /sys.
  - `PrivateNetwork=` gives a new netns with loopback only. It also cuts **abstract** AF_UNIX sockets, while filesystem sockets "will continue to be accessible".
  - `RestrictAddressFamilies=`, `RestrictNamespaces=`, `SystemCallFilter=`.
  - `SystemCallLog=` logs listed syscalls via seccomp, "useful for auditing".
  - `IPAddressAllow=`/`IPAddressDeny=` filter ingress and egress by IP prefix (eBPF).
  - `DynamicUser=` implies `ProtectSystem=strict` and `ProtectHome=read-only`.
- `systemd-run` can apply these ad hoc (`-p` properties). User managers (`systemd-run --user`) cannot switch user, and many namespace options there depend on `PrivateUsers=` being set up first (same source).
- `systemd-analyze security <unit>` scores the exposure of a unit **[well-known; not re-fetched, see dead ends]**.
- **Strengths for homelab:** combines FS, network, syscall and cgroup limits in one place, with journald logs. **Weakness:** IP-level only, with no domain allowlist.

### 2.6 landrun
- A Landlock CLI: "Think firejail, but lightweight ... baked into the kernel." FS needs 5.13+, TCP needs 6.7+ (ABI 4). Flags: `--ro`, `--rox`, `--rw`, `--bind-tcp`, `--connect-tcp`, `--unrestricted-network`, `--best-effort`, `--env`; `--log-level` / `LANDRUN_LOG_LEVEL`. Limits: classic TCP only (no MPTCP), no UDP filtering, and pre-opened fds are not restricted ([landrun README](https://github.com/Zouuup/landrun)).
- **No root, no namespaces**, so it works where userns is restricted. It cannot hide the process table or give a private /tmp. **[analysis]**

---

## 3. macOS

### 3.1 `sandbox-exec` / Seatbelt
- The man page marks `sandbox-exec` **DEPRECATED** and tells developers to adopt App Sandbox ([sandbox-exec(1) mirror](https://leancrew.com/all-this/man/man1/sandbox-exec.html)). It still works and is the macOS backend for Claude Code/srt, Codex, Cursor and Gemini CLI ([srt README](https://github.com/anthropic-experimental/sandbox-runtime); [Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md); [Cursor run modes](https://cursor.com/docs/agent/security/run-modes.md); [Gemini CLI sandbox doc](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/sandbox.md)). Profiles use SBPL (a Scheme-like language); the public reference is the unofficial [Apple Sandbox Guide](https://reverse.put.as/wp-content/uploads/2011/09/Apple-Sandbox-Guide-v1.0.pdf) linked from the srt README.
- **Boundary:** kernel-enforced MAC (Sandbox.kext) with a shared kernel. It can filter file read/write by path or regex, network by local/remote address, mach-lookup, and more.
- **Known gaps from vendor docs:**
  - Network can only be restricted to "a specific localhost port", which is why srt runs a proxy ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)).
  - Allowing `com.apple.trustd.agent` (needed by Go TLS) "opens a potential data exfiltration vector" (same).
  - Allowing Apple Events "removes code-execution isolation", because `open`/`osascript` launch apps unsandboxed ([Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing)).
  - DNS through the system resolver is not fenced on macOS (srt Windows limitations section: "This mirrors the macOS behaviour") ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)). That is a DNS-exfil channel. **[analysis]**
- **Observability:** the **best of the lot**. Violations land in the unified log. srt taps "the system's sandbox violation log store" and suggests `log stream --predicate 'process == "sandbox-exec"' --style syslog` ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)). Codex offers `codex sandbox macos --log-denials` ([Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md)).

### 3.2 App Sandbox
- An entitlement-based sandbox for **signed apps**: "limiting your app's access to resources requested through entitlements", and required for the Mac App Store ([Apple App Sandbox docs](https://developer.apple.com/documentation/security/app-sandbox)). CLI tools can only get it as helper tools embedded in a sandboxed app ([Apple: Embedding a helper tool in a sandboxed app](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app)). It is not a practical ad-hoc wrapper for agent shells, which is why every agent uses the deprecated `sandbox-exec`. **[analysis]**

---

## 4. Coding-agent built-in sandboxes

### 4.1 Claude Code sandboxed Bash + `@anthropic-ai/sandbox-runtime` (srt)
- **Mechanism:** macOS uses Seatbelt. Linux and WSL2 use bubblewrap + socat, plus an optional seccomp filter for Unix sockets. WSL1 and native Windows are unsupported ([Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing)). srt now also has an **alpha Windows backend**: a dedicated `srt-sandbox` account, a restricted token, and a WFP egress filter ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)). srt is labelled a "Beta Research Preview" (same).
- **Filesystem:** writes are allowed only in the CWD, the per-user temp dir and added dirs. Reads are allowed broadly by default, and credential dirs must be denied explicitly ("the default read policy still allows them") ([Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing)). Mandatory write denies cover shell rc files, `.git/hooks`, `.git/config`, `.mcp.json`, `.claude/commands|agents` ([sandbox-environments](https://code.claude.com/docs/en/sandbox-environments)). **On Linux the deny list is built once at launch** and does not cover repos created later (`git init`/`clone`). On macOS denies are checked at write time (same). Linux expands globs at wrap time, so files that appear later are not covered ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)).
- **Network:**
  - The netns is removed on Linux, and traffic goes through HTTP and SOCKS5 proxies on the host reached via bind-mounted Unix sockets. On macOS Seatbelt allows only the proxy's localhost port ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)).
  - The policy is allow-only by domain. A resolved-address check blocks loopback, link-local, metadata IPs and host interfaces, which gives DNS-rebinding protection (same).
  - Claude Code pre-allows no domains and prompts on first use ([Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing)).
  - Optional `tlsTerminate` (experimental) plus credential **masking**: sentinel values are swapped in by the proxy, and AWS SigV4 requests are re-signed (same).
- **Escape hatches:**
  - `dangerouslyDisableSandbox` retry. Disable it with `allowUnsandboxedCommands:false`.
  - `excludedCommands` (e.g. `docker *`, which is incompatible).
  - `enableWeakerNestedSandbox` for running inside Docker; it "considerably weakens security".
  - `failIfUnavailable` makes a missing dependency fatal instead of a silent unsandboxed fallback (all from [Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing)).
- **Scope gap:** the Bash sandbox covers only Bash, PowerShell and Monitor. Read/Edit/Write use the permission system, and **MCP servers and hooks "run unconstrained on the host"**. Wrapping the whole `claude` process in srt fixes that ([sandbox-environments](https://code.claude.com/docs/en/sandbox-environments)).
- **Vendor-stated weaknesses** ([Claude Code sandboxing: Security limitations](https://code.claude.com/docs/en/sandboxing)):
  - No TLS inspection by default, so domain fronting is possible and broad domains like `github.com` are exfil paths.
  - `allowUnixSockets` for `/var/run/docker.sock` = host access.
  - Weaker nested mode.
  - Apple Events.
  - "Sandboxing reduces risk but is not a complete isolation boundary."
- **Advisories:**
  - srt CVE-2025-66479 (<0.0.16): no enforcement when the allowlist was empty ([GHSA-9gqj-5w7c-vx47](https://github.com/anthropic-experimental/sandbox-runtime/security/advisories/GHSA-9gqj-5w7c-vx47)).
  - Claude Code CVE-2026-55607: git worktree `.git` naming + symlink + fsmonitor, leading to unsandboxed exec outside Seatbelt (2.1.38 to <2.1.163) ([GHSA-7835-87q9-rgvv](https://github.com/anthropics/claude-code/security/advisories/GHSA-7835-87q9-rgvv)).
  - SOCKS5 null-byte hostname bypass: JS `endsWith` vs libc `getaddrinfo` parser differential, fixed around 2.1.88–2.1.90 with no CVE ([The Register](https://www.theregister.com/a/5243662); details from secondary [pasqualepillitteri.it](https://pasqualepillitteri.it/en/news/3035/claude-code-sandbox-bypass-socks5-credentials)).
- **Observability:**
  - Violations are returned in the command result ("naming the path or host the sandbox denied") ([Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing)).
  - srt has a `SandboxViolationStore` with per-command attribution (`commandId`), `annotateStderrWithSandboxFailures()`, and `ignoreViolations`. Proxy denies return 403 with `X-Proxy-Error: blocked-by-sandbox-runtime` ([srt README](https://github.com/anthropic-experimental/sandbox-runtime)).
  - On Linux, FS denials are only visible as EPERM and need strace (same).
  - A custom proxy (`httpProxyPort`/`socksProxyPort`) enables full request logging ([Claude Code sandboxing](https://code.claude.com/docs/en/sandboxing)).
- **Setup effort:** minimal on macOS. On Linux, `apt install bubblewrap socat` plus the AppArmor fix on Ubuntu 24.04+.

### 4.2 OpenAI Codex CLI
- **Modes:**
  - `read-only`.
  - `workspace-write`, the default low-friction mode; network is **off** unless `sandbox_workspace_write.network_access=true`.
  - `danger-full-access`.
  - Approval policies `on-request` / `never` / `granular`; `untrusted` is retired. `--yolo` = no sandbox and no approvals ([Codex sandboxing](https://learn.chatgpt.com/docs/sandboxing); [Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md)).
- **Mechanism:**
  - macOS: `sandbox-exec -p <profile>` with a curated platform policy.
  - Linux/WSL2: **bwrap + seccomp by default**. It uses a system `bwrap` from PATH or falls back to the bundled one.
  - WSL1 is unsupported since 0.115.
  - Native Windows has its own sandbox (`[windows] sandbox="unelevated"|"elevated"`) ([Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md)).
  - Linux details: `--ro-bind / /`, writable roots via `--bind`, `.git` (including resolved `gitdir:`), `.codex` and `.agents` re-bound read-only, `--unshare-user`, `--unshare-pid`, `--unshare-net` when network is off. Symlink and missing-path tricks inside writable roots are blocked by mounting `/dev/null` ([Codex linux-sandbox README](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md)).
- **Network proxy** (`features.network_proxy`, off by default):
  - Domain allowlist with `*.`/`**.` semantics, deny wins.
  - Blocks local/private destinations by default and does best-effort DNS classification. The docs admit it "does not eliminate" rebinding: "If hostile DNS is in scope, enforce egress controls at a lower layer too".
  - SOCKS5 including UDP.
  - `dangerously_allow_all_unix_sockets` exists.
  - It does **not** cover web search, MCP, browser/Computer Use, or model traffic ([Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md)).
  - On Linux, proxy mode uses `--unshare-net` + a TCP→UDS→TCP bridge ([linux-sandbox README](https://github.com/openai/codex/blob/main/codex-rs/linux-sandbox/README.md)).
- **In containers:** the sandbox "may not work if the host or container configuration blocks the namespace, setuid `bwrap`, or `seccomp` operations". The advice is to rely on the container and run `danger-full-access` inside it. The reference `.devcontainer/devcontainer.secure.json` + `init-firewall.sh` includes bubblewrap ([Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md)).
- **Advisory:** CVE-2025-59532 (0.2.0–0.38.0): the model-generated cwd was treated as the writable root, allowing writes outside the workspace. The network restriction was not affected. Fixed in 0.39.0 ([GitLab advisory DB](https://advisories.gitlab.com/pkg/npm/@openai/codex/CVE-2025-59532/)).
- **Observability:**
  - `codex sandbox macos|linux|windows [--log-denials]` for testing (log-denials is macOS only).
  - Opt-in **OpenTelemetry** export (`[otel]`) with events `codex.tool_decision` (approved/denied + source), `codex.tool_result`, `codex.conversation_starts` (records the sandbox/approval policy). Prompts are redacted by default.
  - Caveat: with network off, OTel cannot reach the collector ([Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md)).

### 4.3 Gemini CLI
- **Off unless enabled:** `-s`, `GEMINI_SANDBOX=true|docker|podman|sandbox-exec|runsc|lxc`, or settings ([Gemini CLI sandbox.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/sandbox.md)).
- **Backends** (same source):
  - macOS Seatbelt profiles `{permissive,restrictive,strict}-{open,proxied}`, default `permissive-open`.
  - Docker/Podman (image `ghcr.io/google/gemini-cli`, CWD mounted at the same path).
  - **gVisor/runsc** (the "Strongest isolation available", user-space kernel; must be set explicitly).
  - LXC/LXD (experimental).
  - Windows native: `icacls` Low integrity, whose changes **persist** on files.
- **Weakness of the default:** `permissive-open` is `(deny default)` + `(allow file-read*)` from anywhere + broad network ([sandbox-macos-permissive-open.sb](https://raw.githubusercontent.com/google-gemini/gemini-cli/main/packages/cli/src/utils/sandbox-macos-permissive-open.sb)). A compromised command can therefore read `~/.ssh` and exfiltrate it. **[analysis from profile source]**
- **Features:** "Sandbox expansion" prompts for extra permissions on denial. "Tool sandboxing" isolates per tool call, and can be turned off via `security.toolSandboxing:false`. `SANDBOX_MOUNTS` defaults to ro (doc above).
- **Observability:** only `DEBUG=1` and manual inspection. "Sandboxing reduces but doesn't eliminate all risks" (doc above). There is no documented violation log beyond the OS (the macOS unified log applies).

### 4.4 Cursor
- **Mechanism** ([Cursor run modes](https://cursor.com/docs/agent/security/run-modes.md)):
  - macOS: Seatbelt via `sandbox-exec`.
  - Linux: **Landlock + seccomp**, requiring kernel ≥ 6.2 (Landlock v3) and unprivileged userns. There is a bubblewrap fallback (`CURSOR_SANDBOX_LANDLOCK_STATUS=fully_enforced|bubblewrap`). If requirements are not met, it falls back to approval prompts.
  - Ships an AppArmor profile .deb/.rpm for the CLI and remote hosts.
  - Windows runs the Linux sandbox in WSL2 ([Cursor blog, 2026-02-18](https://cursor.com/blog/agent-sandboxing)).
- **Policy:** workspace RW. Protected paths are `.git/config`, `.git/hooks`, `.vscode` and Cursor config. Network is blocked by default and opened via `sandbox.json` with a default allowlist of package registries; "Allow All" is an option. Team-admin policy overrides local files ([Cursor run modes](https://cursor.com/docs/agent/security/run-modes.md)).
- **Observed:** "Sandboxed agents stop 40% less often" ([Cursor blog](https://cursor.com/blog/agent-sandboxing)).
- **Observability:** the shell tool output names the responsible sandbox constraint (same blog). No violation log is documented.

### 4.5 Permission / approval systems (a policy layer, not isolation)
- **Claude Code:**
  - Rules are evaluated deny → ask → allow ([Claude Code permissions](https://code.claude.com/docs/en/permissions.md)).
  - The vendor says Bash rules are "not a security boundary around the program". They match command text only and miss `sh -c`, absolute paths and scripts, and "Bash permission patterns that try to constrain command arguments are fragile" (same).
  - Read/Edit deny rules don't cover "a Python or Node script that opens files itself" (same).
  - PreToolUse hooks can block; hooks cannot override deny/ask rules (same).
  - Auto mode's classifier "is a per-action control, not an isolation boundary" ([sandbox-environments](https://code.claude.com/docs/en/sandbox-environments)).
- **Codex:** rules allow/prompt/forbid command prefixes outside the sandbox. `approvals_reviewer=auto_review` routes approvals to a reviewer agent that fails closed, and the reviewer policy is open source ([Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md)).
- **Cursor:** Auto-review / Allowlist modes, classifier ([Cursor run modes](https://cursor.com/docs/agent/security/run-modes.md)).
- **Observability:** these layers produce the richest *semantic* logs, such as Codex `codex.tool_decision` OTel and Claude Code OTel ([Claude Code devcontainer doc links to monitoring-usage](https://code.claude.com/docs/en/devcontainer)). They log intent, not kernel-enforced outcomes.

---

## 5. Containers: rootless Docker / Podman, devcontainers, `--network none`, userns-remap

### 5.1 Docker rootless
- The "Docker daemon and containers inside a user namespace". Unlike userns-remap, the daemon is not root. It needs `newuidmap`/`newgidmap` (setuid) and `/etc/subuid`/`subgid` ([Docker rootless docs](https://docs.docker.com/engine/security/rootless/)).
- It is still a shared kernel. It mitigates daemon and runtime bugs such as runc CVE-2024-21626, where a leaked `/sys/fs/cgroup` fd plus a `WORKDIR` trick gave host FS access in runc 1.0.0-rc93–1.1.11, fixed in 1.1.12 ([runc GHSA-xr7r-f8xq-vfvv](https://github.com/opencontainers/runc/security/advisories/GHSA-xr7r-f8xq-vfvv)). With rootless, such an escape lands as an unprivileged user. **[analysis]**

### 5.2 Docker userns-remap
- Container root is mapped to a high unprivileged host UID range. It is incompatible with `--pid=host` and `--network=host`, with `--privileged` unless `--userns=host`, and with some volume drivers; `mknod` is unavailable ([Docker userns-remap docs](https://docs.docker.com/engine/security/userns-remap/)).

### 5.3 Rootless Podman
- Limits: no ports <1024; no resource limits on cgroups v1; pasta networking quirks; subuid setup; fuse-overlayfs on kernels <5.12; no device node creation ([Podman rootless.md](https://github.com/containers/podman/blob/main/rootless.md)). It is daemonless and rootless by default, which suits homelab use. **[analysis]**

### 5.4 Docker `--network none` and default seccomp
- `--network none` means "only the loopback device is created" ([Docker none driver](https://docs.docker.com/engine/network/drivers/none/)). It is the simplest hard network cut, but offers no allowlist.
- Docker's default seccomp profile "disables around 44 system calls out of 300+", and `seccomp=unconfined` disables it ([Docker seccomp docs](https://docs.docker.com/engine/security/seccomp/)).

### 5.5 Devcontainers (Anthropic reference)
- The reference `devcontainer.json` adds `--cap-add=NET_ADMIN,NET_RAW`, runs as `node`, and runs `sudo /usr/local/bin/init-firewall.sh` postStart. Sudo is limited to that script via `/etc/sudoers.d/node-firewall` ([devcontainer.json](https://github.com/anthropics/claude-code/blob/main/.devcontainer/devcontainer.json); [Dockerfile](https://github.com/anthropics/claude-code/blob/main/.devcontainer/Dockerfile)).
- `init-firewall.sh` ([source](https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh)):
  - Builds an ipset from GitHub `/meta` CIDRs plus `dig` A records of npm, api.anthropic.com, sentry.io, statsig.com and the VS Code marketplace.
  - Sets the default policy to DROP and ends with REJECT (icmp-admin-prohibited).
  - Self-tests: it fails if `example.com` is reachable and requires that `api.github.com` is reachable.
- **Weaknesses [analysis of the script]:**
  - IPs are resolved once at start, so CDN IP churn breaks it and shared CDN IPs over-allow.
  - UDP/53 is allowed to any destination (DNS tunnelling exfil).
  - TCP/22 outbound is allowed to **any** host.
  - The whole host /24 is allowed.
  - IPv4 only (ip6tables is untouched).
  - Allowing all of GitHub is an exfil path.
- Vendor caveat: with `--dangerously-skip-permissions`, "dev containers do not prevent a malicious project from exfiltrating anything accessible inside the container, including the Claude Code credentials" ([Claude Code devcontainer doc](https://code.claude.com/docs/en/devcontainer)).
- Codex ships an analogous `devcontainer.secure.json` and says to "implement DNS rebinding and DNS refresh protections" ([Codex approvals & security](https://learn.chatgpt.com/docs/agent-approvals-security.md)).
- Committing a devcontainer "is a convention rather than an enforcement boundary" ([sandbox-environments](https://code.claude.com/docs/en/sandbox-environments)).

### 5.6 Container observability
- Docker has no per-denial log for seccomp ERRNO by default. The docs don't cover it ([Docker seccomp docs](https://docs.docker.com/engine/security/seccomp/)).
- The iptables REJECT in the devcontainer is silent unless a `LOG` rule is added. **[analysis]**
- Host-level AppArmor/SELinux denials go to the audit log (see 1.5).

---

## 6. Comparison table

| Mechanism | Kernel shared | FS | Network | Resource limits | Setup | Platforms | Violation observability |
|---|---|---|---|---|---|---|---|
| Namespaces (raw) | yes | mount ns | netns (all or nothing) | no | high (DIY) | Linux | none |
| seccomp-bpf | yes | no (no path args) | family/syscall only | no | high | Linux | audit via RET_LOG/FLAG_LOG |
| Landlock | yes | yes (path-beneath) | TCP ports (ABI4), UDP (ABI10) | no | low via landrun | Linux ≥5.13 | **audit since 6.15 (ABI 7)** |
| cgroups v2 | yes | no | no | **yes** | medium | Linux | events counters |
| AppArmor/SELinux | yes | yes | coarse | no | high (root policy) | Linux | **audit.log / kernel log** |
| bubblewrap | yes | yes | netns | no | low | Linux | none (strace) |
| firejail | yes | yes | netns | some | low | Linux | limited; SUID risk |
| nsjail | yes | yes | netns/macvlan | **yes** | medium | Linux | log file / verbose |
| systemd sandboxing | yes | yes | netns / IP ACL | **yes** | low-medium | Linux | journald, `SystemCallLog=` |
| Seatbelt | yes | yes | localhost-port/addr | no | low | macOS | **unified log** |
| Claude Code / srt | yes | yes | proxy domain allowlist | no | low | mac/Linux/WSL2 (+Win alpha srt) | in-result violations, macOS log; Linux EPERM only |
| Codex | yes | yes (.git/.codex RO) | off; opt-in proxy allowlist | no | low | mac/Linux/WSL2/Win | `--log-denials` (mac), OTel |
| Gemini CLI | yes (Seatbelt/Docker) / **no-ish** (runsc) | profile/container | open or proxied | container only | low-medium | mac/Linux/Win | DEBUG only |
| Cursor | yes | yes | blocked + sandbox.json allowlist | no | none-low | mac/Linux(≥6.2)/WSL2 | constraint shown in tool output |
| Rootless Docker/Podman | yes | yes | netns / `--network none` | yes (cgroup v2) | medium | Linux | host LSM audit |
| Devcontainer + firewall | yes | yes | iptables IP allowlist | yes | medium | any Docker host | none unless LOG rules |

---

## 7. Dead ends / uncertain

- **Landlock ABI 8–11 kernel versions:** ABI 8 = Linux 7.0 comes from a search-result summary and LKML patch threads, not a primary table. The kernel versions for ABI 9 (`FS_RESOLVE_UNIX`), ABI 10 (UDP, QUIET) and ABI 11 (`NO_NEW_PRIVS` flag) are **unverified**. They appear in the docs.kernel.org "latest" doc and may be in linux-next or 7.1+ only. The man7 table I retrieved stopped being legible at ABI 6.
- **Landlock ABI 7 = 6.15:** strongly indicated but taken from the search summary, not the man-page table.
- **SOCKS5 null-byte Claude Code bypass:** sources disagree on affected and fixed versions. The Register says it was patched in 2.1.88 (2026-03-31). A secondary blog says v2.0.24 to v2.1.89, fixed in 2.1.90. There is no GHSA or CVE, and I could not find a primary Anthropic advisory.
- **Gemini CLI tool sandboxing default:** a WebFetch summary said "default on", but the raw doc only shows how to turn it off. Its default state is not confirmed. The internals of the `*-proxied` profiles and `GEMINI_SANDBOX_PROXY_COMMAND` are not documented in the current sandbox.md.
- **Cursor on Linux, network enforcement:** Cursor docs and the blog don't say how domain filtering is enforced (proxy vs netns). The docs mention a bubblewrap fallback, but the blog only mentions Landlock+seccomp.
- **minijail seccomp logging flag (`-L`)**: not confirmed from primary docs fetched.
- **systemd.exec HTML** returned 403. I used the upstream XML man source instead, and did not re-fetch the `systemd-analyze security` man page.
- **Apple App Sandbox full doc body** was not retrievable, only the abstract. The `sandbox-exec` deprecation text comes from a man page mirror, not apple.com.
- **Docker rootless limitations** (cgroup v2 for limits, AppArmor, ports) were not extracted from the fetched page. Rely on the Podman list or re-check.
- **GitHub API for advisories** was blocked in this session (repo not attached), so I used the HTML advisory pages via WebFetch.
- **Codex Windows sandbox internals** were not investigated.

# Track 2: Stronger isolation runtimes for AI agents

Research date: 2026-09-29. Every claim carries an inline source link. Most sources are primary: project docs, READMEs, GitHub security advisories, vendor bulletins and papers. Some facts were read through a summarising fetch tool, so check numbers against the linked page before quoting them in the final report.

---

## 0. Cross-cutting summary table

| Runtime | Boundary | Needs KVM / HW virt? | Startup (source) | Per-instance overhead (source) | Host-side observability of the workload |
|---|---|---|---|---|---|
| gVisor (runsc) | User-space kernel (Sentry) + seccomp + namespaces | No (systrap default); KVM platform optional | +~100-200 ms over runc under Docker ([gVisor perf](https://gvisor.dev/docs/architecture_guide/performance/)) | ~3-20 MB depending on app ([gVisor perf](https://gvisor.dev/docs/architecture_guide/performance/)) | Host eBPF sees only Sentry/Gofer host syscalls; use gVisor Runtime Monitoring (Falco) instead |
| Kata Containers | Hardware VM per pod (QEMU/CLH/FC/Dragonball/StratoVirt) | Yes | ~150-300 ms VM boot, secondary source ([Northflank](https://northflank.com/blog/what-are-kata-containers)) | Depends on VMM | kata-monitor Prometheus, OTel traces via vsock; host eBPF blind to guest syscalls |
| Firecracker | KVM microVM + jailer + seccomp | Yes (`/dev/kvm`) | ≤125 ms to guest `/sbin/init` ([SPEC](https://github.com/firecracker-microvm/firecracker/blob/main/SPECIFICATION.md)) | ≤5 MiB VMM overhead ([SPEC](https://github.com/firecracker-microvm/firecracker/blob/main/SPECIFICATION.md)) | JSON metrics/log FIFOs for the VMM only; guest needs its own agent |
| Cloud Hypervisor | KVM/MSHV VM (Rust, rust-vmm) | Yes | 64-166 ms depending on config ([secondary summary of KVM Forum 2022 talk](https://kvm-forum.qemu.org/2022/KVM-Forum-2022-Robert-Bradford-Updated-2022-09-13.pdf)) | ~13 MB (NSDI'20 comparison, via [Morning Paper](https://blog.acolyer.org/2020/03/02/firecracker/)) | REST API, VMM logs; guest agent needed |
| libkrun / krun / smolvm | KVM/HVF VM, but VMM and guest are *one security context* | Yes (KVM or macOS HVF) | smolvm claims <200 ms for packed machines ([smolvm](https://github.com/smol-machines/smolvm)) | n/a | Needs host-side isolation of the VMM process |
| Apple `container` | VM per container (Virtualization.framework) | Apple silicon + macOS 26 | "sub-second" ([Containerization](https://github.com/apple/containerization)) | Memory ballooning is only partial ([tech overview](https://github.com/apple/container/blob/main/docs/technical-overview.md)) | macOS unified logging integration |
| Sysbox | Container + always-on userns + procfs/sysfs virtualization | No | container-like | container-like | Normal host eBPF works (shared kernel) |
| Incus/LXD | Unprivileged system container, or QEMU VM | VMs: yes | container / VM | container / VM | Containers: host eBPF works; VMs: blind |
| Full VM (Proxmox/libvirt) | QEMU/KVM | Yes | seconds | 100+ MB (QEMU ~131 MB in NSDI'20 comparison, via [Morning Paper](https://blog.acolyer.org/2020/03/02/firecracker/)) | libvirt domstats; guest agent for in-guest data |
| Wasmtime/WASI | Language VM sandbox, capability-based imports | No | µs-ms | small | Only what host functions log |
| V8 isolates (Workers) | Isolate in shared process + process sandbox layers | No | "few ms", "few MB" ([InfoWorld on Dynamic Workers](https://www.infoworld.com/article/4149869/cloudflare-launches-dynamic-workers-for-ai-agent-execution.html)) | few MB | Tail Workers / per-run logs |

---

## 1. gVisor (runsc)

### Architecture
- **Sentry**: a user-space application kernel written in memory-safe Go. It "intercepts and handles system calls and page faults from the sandboxed workload" and reimplements syscalls, memory management, filesystems, a network stack (netstack), signals and namespaces ([gVisor intro](https://gvisor.dev/docs/architecture_guide/intro/)).
- **Gofer**: "a slightly-more-trusted companion process running in a slightly-more-privileged context" that services filesystem requests the Sentry cannot ([intro](https://gvisor.dev/docs/architecture_guide/intro/)). The Sentry talks to the Gofer over a connected socket ([security model](https://gvisor.dev/docs/architecture_guide/security/)).
- Security principles: no direct syscall passthrough; implement only common functionality; explicitly enumerate the host surface. The Sentry itself does not open files or create sockets on the host. Unsafe code is confined to `unsafe.go` files, with no CGo ([security model](https://gvisor.dev/docs/architecture_guide/security/)).
- **Directfs** (2023) changed the model. The Gofer now hands the Sentry mount-point FDs via SCM_RIGHTS, and the Sentry does FD-relative `openat`/`fstatat`/`mkdirat` itself. Seccomp was loosened for those calls but constrained (`O_NOFOLLOW` required, procfs forbidden), with more reliance on mount namespaces and `pivot_root`. stat(2) became more than 2x faster ([directfs blog](https://gvisor.dev/blog/2023/06/27/directfs/)).
- **Rootfs overlay**: the container rootfs is overlaid with tmpfs in the sandbox by default for performance ([rootfs overlay blog](https://gvisor.dev/blog/2023/05/08/rootfs-overlay/)).
- Limitation: gVisor relies on the host kernel for hardware side-channel defence, and "does not protect against System ABI exploits" outside intended paths ([security model](https://gvisor.dev/docs/architecture_guide/security/)).

### Platforms (syscall interception)
- **systrap**: the default since mid-2023. It intercepts syscalls via seccomp `SIGSYS`, and its fast path rewrites `mov sysno,%eax; syscall` into a `jmp` to a trampoline. It needs no virtualization and is recommended for nested-VM environments ([platforms](https://gvisor.dev/docs/architecture_guide/platforms/), [systrap blog](https://gvisor.dev/blog/2023/04/28/systrap-release/)).
- **KVM**: uses virtualization extensions. It is the best choice on bare metal, but "has a noticeable impact with nested virtualization" ([systrap blog](https://gvisor.dev/blog/2023/04/28/systrap-release/)).
- **ptrace**: deprecated because of high context-switch cost ([platforms](https://gvisor.dev/docs/architecture_guide/platforms/)).
- **Homelab implication**: gVisor runs in any Linux VM (a cloud VM, a Proxmox guest, a Lima VM) without nested virt. That is its main practical advantage over the KVM-based options.

### Compatibility
- It implements "a large portion of the Linux surface". io_uring is disabled by default. Block-device filesystems (ext4 mounts in the sandbox) are unsupported, iptables and nftables are partial, KVM inside the sandbox is unsupported, and custom devices are unsupported apart from NVIDIA GPUs and TPUs ([compatibility](https://gvisor.dev/docs/user_guide/compatibility/)).
- It runs in production for arbitrary user workloads, for example Google Cloud Run and DigitalOcean App Platform, with regression tests for Python, Java, Node, PHP and Go ([compatibility](https://gvisor.dev/docs/user_guide/compatibility/)).
- Raw sockets are disabled unless `--net-raw` is set, even when CAP_NET_RAW is granted ([blog: containing a real vulnerability](https://gvisor.dev/blog/2020/09/18/containing-a-real-vulnerability/)).

### Performance
- CPU-bound work runs at native speed. Syscall-heavy and network-heavy work (Redis, small HTTP requests) and VFS-heavy work (tmpfs, serving 100k static files) carry high overhead ([performance guide](https://gvisor.dev/docs/architecture_guide/performance/)).
- Startup adds about 100-200 ms under Docker. Memory overhead is about 3-5 MB for a sleep container, 10-15 MB for Node and 15-20 MB for Ruby ([performance guide](https://gvisor.dev/docs/architecture_guide/performance/)). Note: that page is old, and systrap and directfs changed the numbers since.
- Academic caveat: Anjali et al. (VEE'20) found that gVisor and Firecracker both "execute substantially more kernel code than native Linux", and that gVisor and Docker execute substantially the same host kernel code, at different frequencies ([VEE'20 paper](https://pages.cs.wisc.edu/~swift/papers/vee20-isolation.pdf), [NSF PAR](https://par.nsf.gov/servlets/purl/10176031)).

### GPU (nvproxy)
- nvproxy passes `ioctl`s through to the host NVIDIA driver, translating pointers and FDs, with negligible overhead. Only `/dev/nvidiactl`, `/dev/nvidia-uvm` and `/dev/nvidia#` are supported, with a curated ioctl allowlist and no MIG or DRM ([GPU guide](https://gvisor.dev/docs/user_guide/gpu/)).
- Officially supported GPUs are T4, A100, A10G, L4 and H100; consumer RTX 3090 and 4090 "likely work". `runsc nvproxy list-supported-drivers` lists the drivers ([GPU guide](https://gvisor.dev/docs/user_guide/gpu/)).
- Security caveat: "If there is a vulnerability in a given driver for a given GPU ioctl… gVisor will also be vulnerable" ([GPU guide](https://gvisor.dev/docs/user_guide/gpu/)).

### Observability
- **Runtime Monitoring (seccheck)**: streams "trace points" (syscalls and events such as container start, clone and execve) to an external process over a Unix domain socket, serialized as protobuf. One monitor can serve many sandboxes ([Runtime Monitoring](https://gvisor.dev/docs/user_guide/runtimemonitor/), [threat-detection blog](https://gvisor.dev/blog/2022/08/01/threat-detection/)).
  - Points use hierarchical names (e.g. `container/start`, `syscall/openat/enter`) and have standard, optional and context fields (PID, UID, container ID, process name). Sinks are `remote` (UDS) and `null`. Sessions are configured in JSON or dynamically with `runsc trace create|list|delete`. Warning: high sink retry counts can stall the application, and optional fields such as fd→path resolution cost CPU ([seccheck README](https://github.com/google/gvisor/blob/master/pkg/sentry/seccheck/README.md)).
- **Falco integration**: Falco supports gVisor as an event source since 0.32.1. The Sentry sends each syscall to Falco over a UDS ([Falco gVisor docs](https://falco.org/docs/event-sources/gvisor), [InfoQ](https://www.infoq.com/news/2022/09/falco-supports-gvisor/)).
- **Why this matters**: the workload runs "in a dedicated kernel that is isolated from the host" ([threat-detection blog](https://gvisor.dev/blog/2022/08/01/threat-detection/)). Host eBPF and Falco kernel drivers therefore see the Sentry's filtered host syscalls, not the application's own syscalls. That is an inference from the architecture; confirm with the Falco docs if it needs to be quoted.
- **`--strace`** logs syscalls, `--debug-log` writes debug logs, `runsc debug --stacks` dumps stacks, and `--profile-cpu`/`--profile-heap` feed pprof. `--profile` "loosens seccomp protection" ([debugging](https://gvisor.dev/docs/user_guide/debugging/)).
- **Metrics**: `runsc metric-server` is a Prometheus endpoint that runs as an unsandboxed sidecar. `runsc export-metrics` does one-off exports. These metrics "are mostly information about gVisor internals, and do not provide introspection capabilities into the workload". The metric server has "full control over all running gVisor sandboxes" ([observability](https://gvisor.dev/docs/user_guide/observability/)).

### Escape history
- **2018**: Jann Horn (Project Zero) found a race in the Gofer dentry cache that let a container overwrite host files (PoC: `/etc/crontab`). It was fixed within a week and disclosed on 2018-10-31 ([The Register](https://www.theregister.com/2018/10/31/google_project_zeroes_in_on_google_project/)).
- **CVE-2018-19333**: an shm refcount bug that allowed overwriting memory of root processes *inside* the sandbox. It was not an escape ([stack.watch](https://stack.watch/vuln/CVE-2018-19333/)).
- **CVE-2026-96812** (published 2026-09-25, CVSS 8.8): the gofer exposed a `/dev/cuse` device node from the container image to the host. That allowed registering a host CUSE device, then host root code execution through udev helper memory, on hosts with CUSE enabled. It was fixed in commit 573a9e7 "gofer: dispatch device special file opens to the sentry", which adds a character-device policy flag with default `emulated-only` ([OpenCVE](https://app.opencve.io/cve/CVE-2026-96812), [commit](https://github.com/google/gvisor/commit/573a9e73cf844f)). This is very recent; see the uncertainty notes.
- **CVE-2020-14386** (Linux AF_PACKET escape): gVisor was not affected ([gVisor blog](https://gvisor.dev/blog/2020/09/18/containing-a-real-vulnerability/)).
- The GitHub Security Advisories page for google/gvisor shows no published GHSAs ([advisories](https://github.com/google/gvisor/security/advisories)). Issues are handled via the [security page](https://gvisor.dev/security/).

### Orchestration
- It is an OCI runtime (`runsc`), usable from Docker `--runtime=runsc` and from Kubernetes RuntimeClass with the containerd shim. It is used as GKE Sandbox ([Google Cloud blog](https://cloud.google.com/blog/products/containers-kubernetes/how-gvisor-protects-google-cloud-services-from-cve-2020-14386/)).
- In Kubernetes the pod is the isolation unit: "A compromised Sentry could affect containers within a pod" ([gVisor blog](https://gvisor.dev/blog/2020/09/18/containing-a-real-vulnerability/)).

---

## 2. Kata Containers

### Architecture
- Kata runs one VM per pod and implements the containerd shimv2 API with one shim per pod. The runtime talks to the in-guest **kata-agent** (Rust) over ttRPC/vsock. The container rootfs is shared via virtio-fs, and DAX memory-maps the guest image ([architecture](https://github.com/kata-containers/kata-containers/blob/main/docs/design/architecture/README.md)).
- Kubernetes integration uses RuntimeClass `handler: kata`, and pods opt in with `runtimeClassName: kata` ([k8s how-to](https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/how-to-use-k8s-with-containerd-and-kata.md)).
- Supported hypervisors ([hypervisors.md](https://github.com/kata-containers/kata-containers/blob/main/docs/hypervisors.md)):

| Hypervisor | Lang | GPU | TDX | SEV-SNP |
|---|---|---|---|---|
| QEMU | C | yes | yes | yes |
| Cloud Hypervisor | Rust | no | no | no |
| Firecracker | Rust | no | no | no |
| Dragonball (in-process with the Rust shim, from Ant Group) | Rust | no | no | no |
| StratoVirt | Rust | no | no | no |

  QEMU is "best supported hypervisor for NVIDIA-based GPUs and for confidential computing" ([hypervisors.md](https://github.com/kata-containers/kata-containers/blob/main/docs/hypervisors.md)).
- Limitations ([Limitations.md](https://github.com/kata-containers/kata-containers/blob/main/docs/Limitations.md)):
  - no `--net=host`;
  - "privileged" only means privileged inside the guest;
  - no `subPath`, and hostPath support is limited;
  - Docker is supported via `--runtime io.containerd.kata.v2` (Docker 22.06+), but Podman is not supported;
  - OOM notifications and RDT stats are incomplete;
  - no checkpoint/restore.
- Hardware: needs KVM, so bare metal or nested virt. For example, EC2 added nested virt on non-metal C8i/M8i/R8i instances in Feb 2026 ([AWS What's New](https://aws.amazon.com/about-aws/whats-new/2026/02/amazon-ec2-nested-virtualization-on-virtual)).

### Confidential Containers (CoCo)
- CoCo "encapsulates pods inside of confidential virtual machines". TEEs are Intel TDX, AMD SEV-SNP and IBM Secure Execution. Attestation and key management is done by **Trustee**, which also covers SGX, ARM CCA and NVIDIA GPUs. **cloud-api-adaptor** provides peer pods in public clouds. The threat model treats the host and its administrators as untrusted ([CoCo overview](https://confidentialcontainers.org/docs/overview/)).
- **Agent Policy**: OPA/Rego policy evaluated in the guest on ttRPC requests (e.g. to block `ExecProcess` or filter `CopyFile`), with policies generated by `genpolicy`. "Commonly used for implementing confidential containers, where the Kata Shim and the Kata Agent have different trust properties" ([agent policy](https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/how-to-use-the-kata-agent-policy.md)).
- Observability consequence: under CoCo, host operators are deliberately locked out. exec and log access can be policy-blocked, so telemetry must be emitted from inside the TEE by design.

### Observability
- **kata-monitor** is a per-node daemon, usually a DaemonSet. It exposes Prometheus `/metrics` aggregating runtime, agent, guest OS, hypervisor and Firecracker metrics, plus `/sandboxes`, `/agent-url`, and pprof endpoints when enabled ([kata-monitor README](https://github.com/kata-containers/kata-containers/blob/main/src/runtime/cmd/kata-monitor/README.md)).
- **Tracing**: OpenTelemetry spans from the runtime. Agent spans cross vsock through a "trace forwarder" to an OTLP collector (Jaeger, OTel Collector, Tempo). They are enabled with `enable_tracing` in `[runtime]` and `[agent.kata]`. A debug console into the VM is optional ([tracing.md](https://github.com/kata-containers/kata-containers/blob/main/docs/tracing.md)).
- Host eBPF and Falco see the VMM process (QEMU/CLH) syscalls and virtio I/O, not guest process syscalls, because each VM has its own kernel. That is an inference from the architecture, and no primary Falco/Kata statement was found. For per-process telemetry, run the security agent in the guest image, or rely on agent/OTel output.

### Escape and vulnerability history
- **2020 (Unit 42, Black Hat USA)**: CVE-2020-2023 let a container access the guest rootfs device and masquerade as the kata-agent. CVE-2020-2026 let a malicious guest trick the runtime into mounting the container rootfs on an arbitrary host path, leading to host code execution. Both were fixed in 1.11.1 and 1.10.5 ([NVD CVE-2020-2023](https://nvd.nist.gov/vuln/detail/CVE-2020-2023), [cvefeed CVE-2020-2026](https://cvefeed.io/vuln/detail/CVE-2020-2026), [Cloud Native Now](https://cloudnativenow.com/topics/cloudnativesecurity/palo-alto-networks-discloses-kata-container-flaws/)).
- **2026**: a burst of advisories ([GHSA list](https://github.com/kata-containers/kata-containers/security/advisories)):
  - GHSA-2gv2-cffp-j227 / CVE-2026-47243 (Critical, CVSS 9.2): runtime-rs guest-root to host-root escape via virtio-fs. The guest takes over the virtio-fs PCI device and sends crafted FUSE requests. Fixed in 3.31.0 ([OSV](https://osv.dev/vulnerability/CVE-2026-47243)).
  - GHSA-rr59-xxvx-96qr / CVE-2026-44210: VM escape via virtiofsd argument injection through the **default-enabled** `virtio_fs_extra_args` annotation, which can serve the host `/` to the guest. Fixed in 3.31.0 ([GCVE](https://db.gcve.eu/vuln/CVE-2026-44210)).
  - GHSA-fgm4-mv68-h344: Dragonball virtio-blk missing length validation, a guest-to-host escape (High).
  - GHSA-mp2j-xm59-qfgw: config-path annotation arbitrary file load (Critical).
  - GHSA-7fhf-v3p3-rp56: untrusted pod annotation bind-mounts any host path into the guest.
  - GHSA-5fc8-gg7w-3g5c: host block device hotplug via a malformed image (Critical).
  - GHSA-q49m-57vm-c8cc: CopyFile policy bypass via symlinks.
  - GHSA-h8jv-63p2-496x: mem-agent methods bypass agent policy.
  - GHSA-wwj6-vghv-5p64: container to guest privilege escalation.
- **Lesson for the report**: most real Kata breaks are in the *host-side glue* (annotations, virtiofsd, hotplug, shim logic), not in KVM itself. Restricting pod annotations (the runtime's `enable_annotations` allowlist) is a key hardening step. That recommendation is an inference from the advisories above.

---

## 3. Firecracker

### Design
- It is a minimal KVM VMM in Rust, about 50k LoC versus more than 1M LoC for QEMU, per the NSDI'20 paper ([Morning Paper summary](https://blog.acolyer.org/2020/03/02/firecracker/), [NSDI'20](https://www.usenix.org/conference/nsdi20/presentation/agache)). It powers Lambda and Fargate ([NSDI'20](https://www.usenix.org/conference/nsdi20/presentation/agache)).
- Device model: virtio-net (TAP backed), virtio-block (file backed), vsock, serial, and i8042, which is used only for reboot. PIC, IOAPIC and PIT come from KVM ([design.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/design.md)). The metrics doc also lists balloon, entropy, RTC and vhost-user devices ([metrics.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/metrics.md)). There is no USB, video or audio ([Morning Paper](https://blog.acolyer.org/2020/03/02/firecracker/)). An opt-in virtio-PCI transport (`--enable-pci`) was added around v1.13; MMIO is the default ([AWS bulletin 2026-015](https://aws.amazon.com/security/security-bulletins/2026-015-aws)).
- Threat model: vCPU threads are assumed malicious from the first instruction. Defence in depth is KVM, then per-thread seccomp filters ("bare minimum set of system calls and parameters"), then cgroups, namespaces and privilege drop via the jailer ([design.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/design.md)).
- **Jailer**: `unshare` a mount ns, `pivot_root` into `<chroot_base>/<exec>/<id>/root`, optionally a new PID ns, join a net ns, write a cgroup, drop to a uid/gid, then exec Firecracker ([jailer.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/jailer.md)).
- Production host guidance: always use the jailer; never use `--no-seccomp` in production; disable SMT and KSM for tenant separation; use ECC/TRR RAM against Rowhammer ([prod-host-setup.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/prod-host-setup.md)).
- Rate limiting: token buckets on block and net devices ([design.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/design.md)).

### Numbers (official spec, measured on m5d.metal/m6g.metal with SMT off) ([SPECIFICATION.md](https://github.com/firecracker-microvm/firecracker/blob/main/SPECIFICATION.md))
- API socket ready within 8 CPU ms; wall clock 6-60 ms, about 12 ms on average.
- ≤125 ms from InstanceStart to guest `/sbin/init`, with a minimal kernel and the serial console disabled.
- ≤5 MiB VMM memory overhead for 1 vCPU and 128 MiB RAM.
- Network up to 14.5 Gbps at ≤80% of a host core, or 25 Gbps at 100%. Storage up to 1 GiB/s (test pending).
- NSDI'20 reported about 3 MB overhead (versus Cloud Hypervisor ~13 MB and QEMU ~131 MB), about 13k IOPS block I/O at the time, and 10x oversubscription in production, 20x tested ([Morning Paper](https://blog.acolyer.org/2020/03/02/firecracker/)).

### Snapshots
- Full and diff snapshots (diff is in developer preview). UFFD lets a userspace page-fault handler serve memory lazily. Restore latency is high on cgroups v1, so use v2 ([snapshot-support.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/snapshot-support.md)).
- Security caveat: resuming one snapshot many times clones RNG state, the entropy pool, IDs and tokens. The VMGenID device (Linux 5.18+) reseeds the kernel PRNG, but userspace must de-duplicate its own secrets. The guest wall clock resumes stale ([snapshot-support.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/snapshot-support.md)). This is relevant to agent sandbox pools that fork from a warm snapshot.

### Observability
- **Metrics**: JSON written to a FIFO or file (`--metrics-path` or the `/metrics` API), flushed every 60 s or via `FlushMetrics`. Covers 20+ categories: API, vCPU, VMM, seccomp, signals, block, net, vsock, balloon, and latencies in µs ([metrics.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/metrics.md)).
- **Logger**: human-readable logs to a FIFO or file, default level Warning ([logger.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/logger.md)). Both describe the VMM, not guest processes.
- The guest serial console is the other channel. Production guidance says to limit it (`quiet loglevel=1`) because heavy console output degrades performance ([prod-host-setup.md](https://github.com/firecracker-microvm/firecracker/blob/main/docs/prod-host-setup.md)). Guest process telemetry needs an in-guest agent exporting over vsock or the network.

### Hardware
- Needs read/write on `/dev/kvm`. On x86_64 and aarch64 the docs say "We exclusively use .metal instance types, because EC2 only supports KVM on .metal instance types" ([getting-started](https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md)). That text predates EC2 nested virt on C8i/M8i/R8i from Feb 2026 ([AWS](https://aws.amazon.com/about-aws/whats-new/2026/02/amazon-ec2-nested-virtualization-on-virtual)).

### CVE history ([GHSA list](https://github.com/firecracker-microvm/firecracker/security/advisories))
- **CVE-2019-18960**: vsock bounds bug in v0.18.0/v0.19.0 that gave guest read (≤64 KiB) and write access to Firecracker host heap. Code execution was theoretical ([oss-sec](https://seclists.org/oss-sec/2022/q3/201)).
- **CVE-2026-5747 / GHSA-776c-mpj7-jm3r** (2026-04-07, High): OOB write in the virtio-PCI transport (v1.13.0-1.14.3 and 1.15.0) that could let guest root crash the VMM or maybe run code on the host. Only affects the opt-in `--enable-pci` transport, and no AWS services were affected ([AWS bulletin](https://aws.amazon.com/security/security-bulletins/2026-015-aws)).
- **GHSA-36j2-f825-qvgc** (2026-01-23, Moderate): arbitrary host file overwrite via a symlink in the jailer ([GHSA list](https://github.com/firecracker-microvm/firecracker/security/advisories)).

---

## 4. Cloud Hypervisor, libkrun family, smolvm, Hyperlight

### Cloud Hypervisor
- A Rust VMM on KVM or the Microsoft Hypervisor (MSHV), built on rust-vmm crates it shares with Firecracker and crosvm ([README](https://github.com/cloud-hypervisor/cloud-hypervisor)).
- Guests are 64-bit Linux and Windows. It supports virtio (net, blk, pmem, fs, vsock), VFIO passthrough, vhost-user, and hotplug of CPU, memory and devices. Snapshot/restore and live migration are experimental and do not work across versions ([README](https://github.com/cloud-hypervisor/cloud-hypervisor)).
- It is more general-purpose than Firecracker: GPU and VFIO passthrough, Windows guests.
- Boot: about 166 ms with a serial console, down to 64 ms with virtio-console, pmem and hugepages. That comes from a search summary of a KVM Forum 2022 talk whose PDF returned 404, so it is unverified ([KVM Forum 2022 link](https://kvm-forum.qemu.org/2022/KVM-Forum-2022-Robert-Bradford-Updated-2022-09-13.pdf)).
- Advisories ([GHSA list](https://github.com/cloud-hypervisor/cloud-hypervisor/security/advisories)):
  - GHSA-f47p-p25q-83rh: use-after-free in virtio-block async completion (High, 2026-05-14).
  - GHSA-jmr4-g2hv-mjj6: host file exfiltration via a QCOW backing file (High, 2026-02-20).
  - GHSA-g6mw-f26h-4jgp: an HTTP API request could close arbitrary FDs (Moderate, 2023).
- Apple's Containerization package uses cloud-hypervisor + KVM as its Linux backend ([Containerization](https://github.com/apple/containerization)).

### libkrun / krunvm / crun-krun / muvm
- **libkrun** is "a dynamic library" embedding a VMM with a minimal device set, on KVM (Linux) or HVF (macOS arm64). Variants are libkrun-sev and libkrun-tdx. Networking is either TSI (Transparent Socket Impersonation over vsock, with no virtual NIC) or virtio-net with passt/gvproxy. Filesystems use virtio-fs. GPU uses virtio-gpu via venus or native context ([libkrun README](https://github.com/containers/libkrun)).
- **Critical security-model note**: "both the guest and the VMM pertain to the same security context… To prevent the guest from accessing host's resources, you need to use the host's OS security features to run the VMM inside an isolated context" ([libkrun README raw](https://raw.githubusercontent.com/containers/libkrun/main/README.md)). Three consequences follow from the same source:
  - virtio-fs gives no protection by itself, so a mount-isolation mechanism is required;
  - with TSI, the guest effectively has the VMM's network context;
  - the VM boundary is only as strong as the sandboxing around the libkrun process.
- **crun + libkrun (`krun`)**: `podman run --runtime=krun`. It is configured by annotations (`krun.cpus` up to 16, `krun.ram_mib` at least 128, `krun.gpu_flags`, `krun.nested_virt`, `krun.use_passt`) or by a `.krun_vm.json` file in the image ([krun.1.md](https://github.com/containers/crun/blob/main/krun.1.md)).
- **muvm** links libkrun to run programs in a microVM. Its main use is running 4K-page software on Asahi (16K-page) hosts, with GPU via DRM native context and x86 via FEX ([muvm](https://github.com/AsahiLinux/muvm)).
- No published GHSAs on the libkrun repo ([advisories](https://github.com/containers/libkrun/security/advisories)).

### smolvm and other libkrun/microVM agent sandboxes
- **smolvm** (smol-machines) is a libkrun and libkrunfw based microVM CLI/library for macOS (HVF), Linux (KVM) and Windows (WHP). It claims startup "under a second" and "under 200 ms" for packed `.smolmachine` files. Networking is **off by default** with egress allowlists. It offers SSH-agent forwarding and credential substitution, and ships Node, Python and Rust SDKs. Licence is Apache-2.0 ([smolvm](https://github.com/smol-machines/smolvm)).
- The ecosystem list at [awesome-agent-sandbox](https://github.com/fishman/awesome-agent-sandbox) also has:
  - microsandbox (libkrun);
  - matchlock and strangeClaw (Firecracker);
  - CubeSandbox (Tencent KVM microVMs, claims <60 ms);
  - drydock and sand (Apple `container`);
  - bromure (Virtualization.framework);
  - locki and machine (Lima).
  All of these are claims from a secondary list.
- **Docker Sandboxes** (`sbx run claude`) runs each agent in a microVM with its own Docker daemon. All outbound TCP goes through a host proxy that enforces policy and swaps sentinel credentials for real ones outside the boundary. Workspaces use virtio-fs passthrough ([Docker Sandboxes](https://docs.docker.com/ai/sandboxes.md), [architecture](https://docs.docker.com/ai/sandboxes/architecture/)). The docs do not say which hypervisor is used.

### Hyperlight (Microsoft, CNCF sandbox)
- A micro-VM manager whose guests have no kernel or OS: purpose-built binaries with host/guest typed function calls. It runs on KVM, MSHV and WHP, claims VM startup in milliseconds and calls in microseconds, and has hyperlight-wasm and hyperlight-js variants. It is pre-1.0 ([Hyperlight](https://github.com/hyperlight-dev/hyperlight)). It is a VM-grade boundary around a Wasm or JS runtime, which fits "code-mode" tool execution.

---

## 5. macOS homelab: Apple `container`, Lima, OrbStack, UTM, Tart

### Apple Containerization framework and `container` CLI
- It runs one lightweight VM per container through Virtualization.framework. It requires Apple silicon and macOS 26; macOS 15 has limited networking and is unsupported. Licence is Apache-2.0, and it is under active development ([apple/container](https://github.com/apple/container)).
- Architecture ([technical overview](https://github.com/apple/container/blob/main/docs/technical-overview.md)):
  - services: `container-apiserver` (a launch agent), `container-core-images`, `container-network-vmnet`, and a per-container `container-runtime-linux`;
  - "Each container has the isolation properties of a full VM";
  - integration with the Keychain and macOS unified logging;
  - memory ballooning is only partial, so freed memory may not return to the host.
- In-guest init is `vminitd`, a gRPC API over vsock. The kernel is optimised for "sub-second start times". Each container gets its own IP. Rosetta runs amd64 images ([Containerization](https://github.com/apple/containerization)).

### Lima
- Linux VMs with automatic file sharing and port forwarding. Backends are QEMU, VZ (Virtualization.framework), WSL2, krunkit and HCS. It became a CNCF Incubating project in Oct 2025 ([Lima docs](https://lima-vm.io/docs/)).
- AI-agent guidance ([Lima AI docs](https://lima-vm.io/docs/examples/ai/)):
  - use `--mount-only .:w` (v2.0+) to share just the project;
  - use `--mount-none` plus `--sync` to review changes before they reach the host;
  - the goal is to "prevent agents from directly reading, writing, or executing the host files".

### OrbStack
- A single lightweight VM with a shared kernel, like WSL2. Its "machines" are not separate VMs. It shares files over VirtioFS, and Mac files appear at `/mnt/mac` ([architecture](https://docs.orbstack.dev/architecture), [machines](https://docs.orbstack.dev/machines/)).
- **Isolated machines** turn off Mac file mounts, host network access, SSH agent forwarding and device passthrough. They "aren't a full security boundary" because all machines share one kernel. They are suitable for "third-party dependencies or AI agents", but for kernel-exploit-grade threats OrbStack recommends "a full virtual machine with its own kernel" ([isolated machines](https://docs.orbstack.dev/machines/isolated)).

### UTM and Tart
- **UTM** is a QEMU-based emulator/VM host for macOS and iOS with an Apple Virtualization backend option ([UTM docs](https://docs.getutm.app/)).
- **Tart** runs macOS and Linux VMs on Apple silicon via Virtualization.framework and distributes VM images through OCI registries. It is aimed at CI ([tart.run](https://tart.run/)). Its Fair Source licence is free on personal computers; organisations above 100 CPU cores pay ([licensing](https://tart.run/licensing/)).
- **macOS guest limit**: Virtualization.framework allows at most **2 concurrent macOS VMs** per host (`VZErrorVirtualMachineLimitExceeded`), in line with macOS SLA §2.B.iii ([Eclectic Light](https://eclecticlight.co/2023/09/14/current-limitations-on-macos-virtual-machines-running-on-apple-silicon-macs/), [threedots](https://threedots.ovh/blog/2020/12/macos-eula-licensing-restrictions-affecting-virtualisation/)). Linux guests are not limited.

---

## 6. Sysbox and Docker ECI

- Sysbox is an OCI runtime that replaces runc. It always uses a user namespace ("root user in the container has zero privileges on the host"), partially virtualizes procfs and sysfs, locks initial mounts, and traps selected syscalls. This lets systemd, Docker and Kubernetes run inside a container **without `--privileged`**, and with no hardware virtualization ([Sysbox README](https://github.com/nestybox/sysbox)).
- Docker acquired Nestybox in May 2022, but Sysbox is "a community open-source project and it's not officially supported by Docker". It is weaker than a VM because the kernel is shared ([Sysbox README](https://github.com/nestybox/sysbox)). No GHSAs are published ([advisories](https://github.com/nestybox/sysbox/security/advisories)).
- **Docker Desktop Enhanced Container Isolation (ECI)** uses Sysbox. It forces userns and ignores `--runtime`. It blocks Docker socket mounts by default, prevents sharing host namespaces, restricts sensitive VM bind mounts, and intercepts syscalls. It requires a Business subscription ([ECI docs](https://docs.docker.com/enterprise/security/hardened-desktop/enhanced-container-isolation/)).
- Relevance to agents: a coding agent that needs `docker build` or `docker run` can have a nested Docker daemon in a Sysbox container instead of receiving the host Docker socket, which is effectively host root.
- Observability: the kernel is shared, so host eBPF (Falco, Tetragon) sees all syscalls. This is Sysbox's main advantage over VM runtimes (an inference from the architecture).

---

## 7. Incus / LXD (system containers and VMs)

- Incus offers three instance types: system containers (shared kernel, "extremely low overhead"), QEMU VMs (for a different kernel, kernel modules or PCI passthrough), and OCI application containers pulled from registries ([instances](https://linuxcontainers.org/incus/docs/main/explanation/instances/)).
- Unprivileged containers (the default) run in a user namespace. `security.idmap.isolated` gives each container a non-overlapping UID/GID map. Privileged containers "aren't root safe" ([Incus security](https://linuxcontainers.org/incus/docs/main/explanation/security/)).
- LXC policy: unprivileged containers are "safe by design", with AppArmor, SELinux and seccomp as extra hardening. Privileged containers "aren't and cannot be root-safe", and escapes from them usually get no CVE ([LXC security](https://linuxcontainers.org/lxc/security/)).
- Advisories: the 2026 Incus GHSAs are mostly about the management plane and multi-tenancy (project-restriction bypasses, S3 bucket reads). They also include host arbitrary file writes via backup path traversal and migration symlinks, plus GHSA-wfvq-qh87-gm4j, where a malicious `incus-agent` in a VM can write arbitrary files through the CLI during recursive file pull ([Incus GHSA list](https://github.com/lxc/incus/security/advisories)). **Lesson**: guest agents and file-transfer paths are an attack surface.
- Observability: containers are visible to host eBPF; VMs are opaque, as with all VMs.
- Homelab angle: one tool, one API and one CLI moves a workload from container to VM with no other change, and Lima+Incus stacks exist (e.g. `locki` on [awesome-agent-sandbox](https://github.com/fishman/awesome-agent-sandbox)).

---

## 8. Full VMs (Proxmox VE, libvirt/QEMU)

- Proxmox says "full virtual machines provide better isolation" and should be used "if containers are provided to unknown or untrusted people". Unprivileged LXC is the default for containers ([Proxmox LXC wiki](https://pve.proxmox.com/wiki/Linux_Container)).
- TCB: QEMU is large (>1M LoC versus Firecracker's ~50k per NSDI'20, via [Morning Paper](https://blog.acolyer.org/2020/03/02/firecracker/)) and emulates many legacy devices.
- Escape history example: **VENOM (CVE-2015-3456)**, an OOB write in QEMU's virtual floppy controller, present since 2004, that allowed guest-to-host escape ([Hacker News](https://thehackernews.com/2015/05/venom-vulnerability.html), [PCWorld](https://www.pcworld.com/article/2922212/critical-vm-escape-vulnerability-impacts-business-systems-data-centers.html)).
- Mitigations: minimal device models (microvm machine type), sVirt/SELinux confinement of QEMU, and removing unused devices. General knowledge; no primary source was fetched this session.
- Observability: the host sees the QEMU process, and libvirt `virsh domstats` gives per-domain CPU, memory, block and net stats. In-guest data (filesystems, IPs) needs the QEMU Guest Agent (`domfsinfo`, `domifaddr`, `qemu-agent-command`) ([virsh manpage](https://www.libvirt.org/manpages/virsh.html)). Note that a guest agent is itself a guest-to-host channel (see the Incus advisory above).
- Trade-off: simplest to reason about and the strongest general-purpose boundary for a homelab, but boot takes seconds, memory overhead is 100+ MB per VM, and there is no native per-agent orchestration. Snapshots and templates help.

---

## 9. WebAssembly sandboxes and V8 isolates

### Wasmtime / WASI
- Wasm's in-language protections: no addressable call stack, memory access only as offsets into linear memory, type-checked indirect calls, and host interaction only via imports ([Wasmtime security](https://docs.wasmtime.dev/security.html)).
- Wasmtime adds defence in depth: a 2 GB guard region before linear memory, stack guard pages, memory zeroing after an instance is used, Spectre-hardened bounds checks, and CFI work in progress ([Wasmtime security](https://docs.wasmtime.dev/security.html)).
- **WASI capability model**: a module can only reach pre-opened directories, sockets and so on that the host grants ([Wasmtime security](https://docs.wasmtime.dev/security.html)). WASI moved from 0.1 (witx) to 0.2 (component model/WIT) to 0.3 (native async) ([WASI README](https://github.com/WebAssembly/WASI/blob/main/README.md)).
- Escape-class bug: **CVE-2023-26489** (CVSS 9.9), where Cranelift x86_64 address computation used 35 bits instead of 33. That allowed reads and writes about 34 GB beyond linear memory, including other instances' memory under the pooling allocator ([GitLab advisory](https://advisories.gitlab.com/cargo/wasmtime/CVE-2023-26489/)). JIT compiler bugs are the main escape class for Wasm.
- **Coverage trade-off**: Wasm/WASI cannot run arbitrary Linux binaries, fork, or use most native Python/Node extensions. It suits short "code-mode" snippets and tool glue, not a full coding agent that runs `npm install`, compilers and Docker.

### Pyodide and mcp-run-python (cautionary tale)
- **Pydantic's `mcp-run-python`** ran Python in Pyodide inside Deno. It was **archived on 2026-01-30** with the statement "there's just no safe way to run Python within pyodide safely with reasonable latency". The reasons given: Python in Pyodide "can run arbitrary javascript", can corrupt the JS runtime for later runs, can read any file the Deno runtime can, and has no memory limit. Pyodide and Deno "were not designed as sandboxes to run untrusted code" ([mcp-run-python](https://github.com/pydantic/mcp-run-python)).
- Pyodide itself relies on the browser security model and exposes the `js` module to Python ([Pyodide FAQ](https://pyodide.org/en/stable/usage/faq.html)). The Wasm boundary protects the *host process* but not the *embedding JS runtime's* capabilities.
- The replacement is **Monty**, a Rust Python-subset interpreter where filesystem, env and network "do not exist inside the sandbox" except via functions the host passes in. It claims <1 ms per sandbox from a pool versus about 1500 ms for container services ([Monty](https://github.com/pydantic/monty)).

### V8 isolates (Cloudflare Workers model)
- Workers run many tenants' isolates in one process ([Workers security model](https://developers.cloudflare.com/workers/reference/security-model/)). Layers:
  - the V8 isolate;
  - a process sandbox (namespaces with an empty filesystem, and seccomp that blocks all filesystem syscalls);
  - cordons that separate tenants by trust level;
  - a supervisor that mediates all I/O.
- Spectre defences: `Date.now()` is frozen during execution, there are no threads or shared memory, suspicious Workers are moved to their own process, and runtimes restart periodically. V8 patches reach production in under 24 hours ([Workers security model](https://developers.cloudflare.com/workers/reference/security-model/)).
- **workerd** (self-hosted) warns it is "not a hardened sandbox" on its own and should run inside a VM when running potentially malicious code ([workerd README](https://github.com/cloudflare/workerd)). This matters for homelab users who self-host workerd.
- **Dynamic Worker Loader** (Dynamic Workers, open beta) lets a Worker spawn isolates for AI-generated code. `globalOutbound: null` blocks network access, bindings act as capabilities, per-run limits apply, and Tail Workers collect logs ([Worker Loader docs](https://developers.cloudflare.com/workers/runtime-apis/bindings/worker-loader)). Claimed "100x faster" than containers ([InfoWorld](https://www.infoworld.com/article/4149869/cloudflare-launches-dynamic-workers-for-ai-agent-execution.html)). Used by Agents SDK "Codemode".
- **V8 heap sandbox**: 40-bit offset pointers and pointer tables that contain heap corruption, with about 1% overhead. It has been enabled by default on 64-bit since 2024. Motivation: 60% of in-the-wild Chrome renderer exploits in 2021-2023 started with a V8 memory-corruption bug ([v8.dev](https://v8.dev/blog/sandbox)).

### Capability vs coverage summary
- Wasm and isolates are strongest on the *capability* axis: nothing is reachable unless it is passed in, and startup and memory costs are tiny. They are weakest on *coverage*: no arbitrary binaries, no package managers, no Docker. Their TCB is a JIT compiler, which is itself a historical source of escapes (CVE-2023-26489, V8 bugs), so production users (Cloudflare) add OS-level sandboxing around them.

---

## 10. Unikernels / Nabla (brief)

- **Nabla containers** use Solo5 unikernels plus seccomp, allowing only 7 host syscalls (`read, write, exit_group, clock_gettime, ppoll, pwrite64, pread64`). They need specially built images ([Nabla](https://nabla-containers.github.io/)). This is a research-grade technique and not practical for agent workloads that need a general Linux userland.
- Van Rijn & Rellermeyer (Middleware'21) rated unikernels highest on isolation among the platforms they measured ([arXiv 2110.11462](https://arxiv.org/abs/2110.11462)).

---

## 11. Observability synthesis (inside vs outside the boundary)

| Runtime | Host-side view (outside) | Inside-boundary telemetry |
|---|---|---|
| runc / Sysbox / LXC | Full host eBPF, Falco, Tetragon (shared kernel) | same |
| gVisor | Host eBPF sees only Sentry/Gofer host syscalls, not app syscalls ([threat-detection blog](https://gvisor.dev/blog/2022/08/01/threat-detection/)) | Runtime Monitoring points → UDS → Falco; `--strace`; metric-server covers only gVisor internals ([observability](https://gvisor.dev/docs/user_guide/observability/)) |
| Kata | VMM process and virtio I/O; kata-monitor Prometheus ([kata-monitor](https://github.com/kata-containers/kata-containers/blob/main/src/runtime/cmd/kata-monitor/README.md)) | In-guest agent traces via the vsock trace-forwarder ([tracing](https://github.com/kata-containers/kata-containers/blob/main/docs/tracing.md)); in-guest eBPF agent if you bake one into the guest image |
| Firecracker | VMM JSON metrics and logs ([metrics](https://github.com/firecracker-microvm/firecracker/blob/main/docs/metrics.md)) | Serial console; your own agent over vsock or net |
| Full VM | libvirt domstats ([virsh](https://www.libvirt.org/manpages/virsh.html)) | Guest agent, or in-guest auditd/eBPF shipped to a collector |
| CoCo | Deliberately none (host untrusted) | Must be emitted by the workload/agent under policy ([agent policy](https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/how-to-use-the-kata-agent-policy.md)) |
| Wasm / isolates | Host process only | Whatever the host functions and bindings log; Tail Workers ([Worker Loader](https://developers.cloudflare.com/workers/runtime-apis/bindings/worker-loader)) |

Key point for the report: the stronger the boundary, the less the host's default security telemetry can see. For AI agents this is often acceptable, because the most useful audit points sit at the *egress proxy* (network and credentials), the *tool/MCP gateway* and the *filesystem diff/sync* boundary, all of which stay on the host side. Docker Sandboxes' host proxy with credential injection ([architecture](https://docs.docker.com/ai/sandboxes/architecture/)) and Lima's `--sync` review ([Lima AI](https://lima-vm.io/docs/examples/ai/)) are examples.

---

## 12. Dead ends / uncertain

- **CVE-2026-96812 (gVisor CUSE)**: published four days before this research (2026-09-25). The OpenCVE entry and the fix commit exist and match, but I did not see a gVisor-authored advisory or NVD analysis, and the CVE number is unusually high. Verify before headlining it. It also needs CUSE enabled on the host and a crafted image.
- **gVisor seccheck point count**: the fetch tool summarised the README as "approximately 998 points". I could not verify this number; treat it as "hundreds of points".
- **gVisor performance guide numbers** (100-200 ms startup, MB overheads) come from an older page and predate systrap and directfs.
- **Kata startup/overhead numbers**: I found no primary Kata benchmark page. The 150-300 ms figure comes from a vendor blog ([Northflank](https://northflank.com/blog/what-are-kata-containers)), and the academic numbers vary (600 ms+). Treat them as rough.
- **Cloud Hypervisor boot numbers** (166/89/64 ms): the KVM Forum 2022 PDF returned 404, so the numbers come only from a search snippet.
- **Falco on Kata**: no primary doc states that host Falco cannot see Kata guest syscalls. The claim is inferred from the architecture (a separate guest kernel).
- **Falco gVisor docs page** returned 404 when fetched directly; the content was taken from search results and the gVisor blog.
- **Docker Sandboxes hypervisor**: the docs do not say which VMM backs the microVMs on each OS.
- **Firecracker getting-started** still says KVM needs .metal on EC2, which is stale since the Feb 2026 nested-virt launch. Firecracker's own support stance on nested virt is unverified.
- **arXiv 2110.11462** abstract as summarised says "traditional containers close behind" unikernels on isolation. That is counter-intuitive and probably reflects their host-kernel-code metric, so do not cite it without reading the paper.
- **Tart and UTM**: minimal detail gathered. They are included for completeness, not as agent-sandbox tools.
- **OrbStack**: its "augmented KASLR" claim was not investigated.
- **libkrun startup/memory numbers**: none found in primary docs. The only figures are smolvm's claims.

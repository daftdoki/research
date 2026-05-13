# Research notes: macOS hypervisors on Apple Silicon (M-series)

## Goal

Identify hypervisors / VM solutions for modern macOS on M-series chips that score
well against this checklist:

- Free or one-time purchase (subscriptions noted but deprioritized)
- Run VMs as system services (no interactive macOS login required)
- CLI tools / maintenance utilities
- Good performing host->guest file sharing (e.g. virtiofs)
- Snapshot functionality
- Diverse Linux distros supported
- Advanced networking — VM has its own IP on the LAN without bridging through the host (e.g. macvlan, "bridged" L2, or VLAN)
- Web UI (nice to have)

## Background: what hypervisor stacks exist on Apple Silicon at all?

Apple Silicon Macs cannot run KVM (that's Linux-only). All native virtualization
goes through one of two Apple frameworks:

- **Hypervisor.framework** — low-level type-2 hypervisor primitives. Used by
  QEMU/HVF, libkrun, etc.
- **Virtualization.framework (VZ)** — Apple's higher-level Swift API on top of
  Hypervisor.framework. Provides paravirt block, net, virtio-fs, virtio-gpu,
  pre-built bootloaders for macOS and Linux. This is the modern, recommended
  path on Apple Silicon. UTM (Apple Virt mode), VirtualBuddy, Tart, vfkit,
  Lima (vz), OrbStack, Apple's own `container` tool, and Parallels/VMware all
  build on top of it (Parallels/VMware also have proprietary stacks).

Bridged networking on VZ requires the **com.apple.vm.networking entitlement**,
which Apple gates by manual approval. Most third-party VZ tools therefore
default to NAT and need to either:
1. Be code-signed with the granted entitlement (Tart got this; UTM has it on the
   non-App-Store distribution), or
2. Use a sidecar like `socket_vmnet` / `vmnet-helper` that owns the entitlement
   and proxies packets, or
3. Use "softnet" (Tart's user-mode L3 isolator) for VLAN-style separation.

## Per-product notes

### UTM (and utmctl)
- Free, open source (Apache 2.0). $9.99 on Mac App Store as a "support the
  project" purchase; identical product is a free DMG download from getutm.app.
  Source: https://github.com/utmapp/UTM
- Two backends:
  - **QEMU**: full emulation + HVF accel for ARM64. Can boot x86 guests via
    emulation (slow). qcow2 disks support snapshots natively.
  - **Apple Virtualization**: VZ-based, much faster, but more limited (no
    snapshots in the GUI, no x86 emulation, more constrained device model).
- CLI: `utmctl` is bundled inside UTM.app
  (`/Applications/UTM.app/Contents/MacOS/utmctl`). Provides `list`, `status`,
  `start`, `stop`, `suspend`, `attach`, `file`, `exec`, `ipaddress`, `clone`,
  `delete`, `usb`. Notably lacks first-class snapshot subcommands — snapshots
  on QEMU are managed via `qemu-img` against the disk.
  Source: https://github.com/utmapp/UTM/blob/main/utmctl/UTMCtl.swift
- Headless: documented mode where you delete the display device. But UTM.app
  must be running, so a true LaunchDaemon is awkward — community workarounds use
  LaunchAgents tied to the user session, not LaunchDaemons. Boot-before-login
  setup is fragile and breaks across releases.
  Sources: https://docs.getutm.app/advanced/headless/ ;
  https://github.com/utmapp/UTM/issues/2280 ;
  https://ryan.himmelwright.net/post/utmctl-nearly-headless-vms/
- File sharing: virtio-fs in Apple Virt mode; 9p (slower) in QEMU mode.
- Networking: NAT, host-only, bridged (via vmnet.framework, supported in QEMU
  mode and in Apple Virt mode on the standalone build with the entitlement).
- Linux distros: best-in-class — both ARM64 *and* x86 emulation make it the
  most flexible choice for diverse distros.
- Web UI: none.

### Tart (cirruslabs)
- Source-available (Fair Source 1.0). Free for personal use. As of 2026 (after
  Cirrus Labs joined OpenAI), licensing fees for paid commercial tiers were
  dropped and the project is moving to a more permissive open-source license.
  Sources: https://github.com/cirruslabs/tart ;
  https://tart.run/blog/2025/10/27/press-release-cirrus-labs-successfully-enforces-its-fair-source-license/
- VZ-based; macOS 13+ Apple Silicon only.
- CLI-only by design. Commands: `pull`, `push`, `clone`, `run`, `ip`, `stop`,
  `delete`, `list`, `set`, `get`. VMs are distributed as OCI images — every
  `clone` is effectively a fast COW snapshot. No traditional "snapshot stack"
  but the OCI/clone model fills the same role for CI workflows.
- Networking modes: NAT (default), `--net-bridged` (Tart was granted the
  com.apple.vm.networking entitlement, so bridged works out-of-the-box),
  `--net-softnet` (sidecar that gives each VM its own learned LAN IP and
  isolates it from peer VMs).
  Sources: https://medium.com/cirruslabs/isolating-network-between-tarts-macos-virtual-machines-9a4ae3dcf7be ;
  https://github.com/cirruslabs/tart/issues/243
- File sharing: `--dir` flag mounts host dirs as virtio-fs. Rosetta x86_64
  shim available for Linux guests.
- Service / headless: pure CLI binary, trivial to put behind a LaunchDaemon.
  CI is the design center.
- Web UI: not in Tart itself, but `cirruslabs/orchard` is an open-source
  controller with REST API + web UI for clusters of Tart hosts.
  Source: https://github.com/cirruslabs/orchard

### Lima / Colima
- Free, Apache 2.0. https://lima-vm.io / https://github.com/abiosoft/colima
- Lima is a Linux-VM-on-Mac tool (built originally to give Docker-on-Mac an
  alternative). Two backends: `qemu` and `vz` (macOS 13+ recommended).
- CLI-first: `limactl create`, `start`, `stop`, `shell`, `snapshot`, etc.
  Lima has explicit instance snapshot subcommands (since 0.16).
- File sharing: virtiofs (vz backend), reverse-sshfs, 9p — virtiofs is fastest.
- Networking on Apple Silicon:
  - Default user-mode NAT (gvisor-tap-vsock or vz NAT).
  - **Bridged** via `socket_vmnet` (sidecar daemon owning the vmnet entitlement
    + sudoers entry). Gives the VM its own DHCP lease on the LAN.
  - vz backend cannot do `VZBridgedNetworkDeviceAttachment` directly (lacks
    Apple entitlement) — bridged is achieved via socket_vmnet on a separate
    interface.
  Sources: https://lima-vm.io/docs/config/network/vmnet/ ;
  https://github.com/lima-vm/socket_vmnet
- Linux distros: 30+ official Lima templates (Ubuntu, Debian, Fedora, Alma,
  Rocky, openSUSE, Arch, Alpine, NixOS, Gentoo, etc.). x86_64 guests run via
  QEMU emulation.
- Service: easy — `limactl start` is a normal CLI invocation; install scripts
  exist for both LaunchAgent (per-user) and LaunchDaemon (system-wide).
- Web UI: none built-in. Third-party `Lima for Mac` GUI exists.

Colima is a thin wrapper specifically for spinning up a Docker/Kubernetes VM
through Lima, with sane defaults. Same trade-offs.

### OrbStack
- Commercial. Free for personal/non-commercial (under $10k/yr revenue). Pro is
  $8/user/month or $96/year, no perpetual license. Subscription only.
  Source: https://orbstack.dev/pricing
- Built specifically as a Docker-Desktop replacement for Apple Silicon. Provides
  Linux "machines" (full distros) and a Docker engine in a shared optimized VM.
- Strengths: extremely fast file sharing (custom virtio-fs caching, claimed
  near-native), 45 Gbps internal bridge, Rosetta-accelerated x86 binaries.
- Networking: internal bridge only — every machine/container has an internal IP
  reachable from macOS, but **VMs do not get LAN IPs**. Servers on `0.0.0.0`
  are reachable from other LAN devices via the host (port forwarded /
  port-published), not via a unique VM IP.
  Source: https://docs.orbstack.dev/machines/network
- CLI: `orb` / `orbctl` — create machines, ssh, run, etc.
- Snapshots: not first-class.
- Linux distros: 20+ supported (Ubuntu, Debian, Fedora, Alpine, Arch, NixOS,
  Kali, etc.).
- Web UI: a native macOS GUI; no full web admin.
- Service: launches at login as a menu-bar app; not strictly a LaunchDaemon
  (boot-before-login).

### vfkit (crc-org)
- Free, Apache 2.0. https://github.com/crc-org/vfkit
- Minimalist Go CLI wrapper over Virtualization.framework. Used as the engine
  by Podman Machine on macOS, minikube vfkit driver, and CRC.
- Networking: NAT by default; integrates with `gvisor-tap-vsock` (user-mode
  NAT/port-forward) and `vmnet-helper` for shared/bridged/host vmnet networking
  *without* requiring the VM to run as root. With `vmnet-helper` the VM gets
  its own LAN IP via DHCP. macOS 26 removes the root requirement entirely.
  Sources: https://github.com/crc-org/vfkit/blob/main/doc/usage.md ;
  https://github.com/nirs/vmnet-helper
- File sharing: virtio-fs out of the box; Rosetta share for x86 binaries.
- Snapshot: no native snapshot subcommand; can pause/save state via REST.
- Linux distros: any ARM64 Linux that fits the VZ device model. Not aimed at
  diverse ad-hoc distros — aimed at OCI/CoreOS-style images.
- Service: trivially scriptable as a LaunchDaemon — it's a single CLI binary.
- Web UI: REST API for control; no web UI.

### libkrun / krunvm / krunkit
- Free, Apache 2.0. https://github.com/containers/libkrun
- Rust micro-VM monitor on top of Hypervisor.framework. Designed to launch OCI
  images as micro-VMs in seconds. `krunkit` (Lima vmType krunkit) is the
  user-facing CLI on macOS, with GPU passthrough via Venus/Vulkan, used for AI
  inference workloads.
  Source: https://lima-vm.io/docs/config/vmtype/krunkit/
- Snapshot/networking/file-sharing: minimal, oriented toward "boot a container
  fast and tear it down". Not really a general-purpose VM tool.

### Apple `container` (and Containerization framework)
- Free, Apache 2.0. https://github.com/apple/container
- New in macOS 26 Tahoe (limited support on macOS 15). Ships an Apple-built
  CLI that runs each OCI container in its own dedicated lightweight VZ VM,
  using a Kata-style optimized kernel. Sub-second start.
- Networking: each container/VM gets its own IP on a vmnet bridge (default
  192.168.64.0/24). Reachable from the host. **Not** automatically on the
  physical LAN — you can configure additional vmnet networks but the default
  is host-shared, not L2-bridged to en0.
- Snapshot/CLI/file-sharing: `container` CLI mirrors Docker semantics; images
  are OCI-stored, so "snapshot" is image commit. Bind-mounts are
  virtio-fs-backed.
- Service: ships a daemon (`container system start`) that registers with
  launchd.
- Linux distros: anything you can package as a container image.
- Web UI: none.

### VirtualBuddy
- Free, BSD-2. https://github.com/insidegui/VirtualBuddy
- macOS-host-side GUI built on VZ. Strong on **macOS guests** (one-click
  install of macOS releases including betas); has experimental Linux ARM64
  support.
- CLI tooling: limited (mainly GUI-driven).
- Networking: NAT only. Bridged on VZ requires Apple entitlement.
- File sharing: virtio-fs share between VirtualBuddy host and guest (macOS 13+).
- Snapshots: yes — uses APFS clones for cheap full-VM duplicates, plus VZ
  save-state. Not perfectly reliable.
- Service: "Launch at login" only; not a true system service.
- Linux distros: limited — Ubuntu Server/Desktop tested; whatever VZ can boot.
- Web UI: none.

### VMware Fusion (Pro)
- Free for all use (commercial, personal, education) since Nov 2024 — Broadcom.
  Source: https://techdocs.broadcom.com/us/en/vmware-cis/desktop-hypervisors/fusion-pro/25H2/release-notes/vmware-fusion-25h2-release-notes.html
- Apple Silicon support since Fusion 13 (ARM64 guests only — no x86 emulation).
- Bridged networking: yes, mature.
- Snapshots: full snapshot tree, mature.
- CLI: `vmrun` for VM control; LaunchDaemon-friendly.
- File sharing: **shared folders are NOT supported on Apple Silicon** —
  community-driven workarounds only. This is a real limitation.
- Linux distros: any ARM64 Linux. No x86 emulation, so x86-only distros don't
  run.
- Web UI: none on Fusion (Workstation has limited web UI on Linux/Win).

### Parallels Desktop (Pro / Business)
- Subscription mostly; Standard edition has a perpetual license (~$220 in 2026).
  Pro/Business are subscription-only ($120 / $150 per year).
  Sources: https://www.parallels.com/products/desktop/buy/ ;
  https://kb.parallels.com/en/122929
- Apple Silicon: native, very polished. ARM64 guests only.
- Bridged networking: yes.
- Snapshots: yes (snapshot tree).
- CLI: `prlctl` and `prlsrvctl` — full lifecycle.
- Run as service: Pro edition supports headless "service mode" — VMs start at
  Mac boot and survive logout/login because `prl_disp_service` runs as a
  LaunchDaemon. This is the most polished "VM as system service" experience
  on macOS today.
  Sources: https://kb.parallels.com/123298 ; https://kb.parallels.com/en/120414
- File sharing: virtio-fs + Parallels Tools, fast and well-integrated.
- Web UI: separate **Parallels DevOps Service** (`prldevops`) provides a REST
  API + web management UI for hosts/VMs.
  Source: https://parallels.github.io/prl-devops-service/quick-start/
- Linux distros: ARM64 Ubuntu, Debian, Fedora, Kali, Rocky, etc. all supported.
  No x86 emulation.

### VirtualBox 7.2 (Apple Silicon)
- Free, GPL. Oracle.
  Source: https://blogs.oracle.com/virtualization/oracle-virtualbox-72
- 7.1 added macOS-on-ARM64 host support (Linux/BSD ARM64 guests).
  7.2 adds Windows-on-ARM64 guests, but is still an early/experimental host on
  macOS — many features (USB, shared folders) are immature.
- CLI: `VBoxManage`, mature; works fine on Apple Silicon.
- Bridged: yes, traditional. Snapshots: yes (snapshot tree).
- File sharing: vboxsf (vboxsf perf is poor; no virtiofs support).
- Service: `VBoxHeadless` + LaunchDaemon works.
- Web UI: optional `phpVirtualBox` third-party.
- Caveat: Apple Silicon support is still labeled developer preview / early.

### Multipass (Canonical)
- Free, GPL. https://multipass.run
- Aimed at Ubuntu VMs on Mac/Win/Linux. CLI-first (`multipass launch`,
  `shell`, `mount`, `transfer`).
- Apple Silicon: works, but **bridged networking is not implemented** — only
  NAT/host-only on macOS Apple Silicon.
- File sharing: `multipass mount` (sshfs-based, slow-ish).
- Snapshots: yes (`multipass snapshot`).
- Linux distros: Ubuntu only (officially); custom images are awkward.
- Service: runs as a LaunchDaemon (`multipassd`).
- Web UI: none.

### Veertu Anka
- Anka Develop (free) is single-VM, mostly aimed at iOS/macOS-guest CI on
  developer machines. Anka Build / Flow are subscription, host-priced (no
  one-time purchase).
  Source: https://docs.veertu.com/anka/licensing/
- Strong CLI, web UI for the Build cluster controller. Very macOS-guest focused
  — Linux guest support exists but isn't the design center.
- Snapshots: yes.
- Networking: NAT primarily; bridged available with entitlement.

### QEMU directly (Homebrew, no UTM)
- Free, GPL. The most flexible option, but you write your own command lines.
  HVF accel for ARM64. x86 emulation possible (slow).
- Networking: vmnet-shared / vmnet-bridged via QEMU's vmnet backend (macOS
  native, no socket_vmnet needed) since QEMU 7.0.
- Snapshots: full, via qcow2.
- Service: just `launchd` it. Common pattern.
- File sharing: virtio-fs (with virtiofsd), 9p.
- Web UI: pair with `libvirt` + Cockpit for a web management plane.

## Selected sources (deduped)

- https://mac.getutm.app/ ; https://github.com/utmapp/UTM ;
  https://docs.getutm.app/advanced/headless/ ;
  https://github.com/utmapp/UTM/blob/main/utmctl/UTMCtl.swift
- https://tart.run/ ; https://github.com/cirruslabs/tart ;
  https://github.com/cirruslabs/orchard ;
  https://medium.com/cirruslabs/isolating-network-between-tarts-macos-virtual-machines-9a4ae3dcf7be
- https://lima-vm.io/ ; https://lima-vm.io/docs/config/network/vmnet/ ;
  https://github.com/lima-vm/socket_vmnet ; https://github.com/abiosoft/colima
- https://orbstack.dev/ ; https://docs.orbstack.dev/architecture ;
  https://docs.orbstack.dev/machines/network ; https://orbstack.dev/pricing
- https://github.com/crc-org/vfkit ;
  https://github.com/crc-org/vfkit/blob/main/doc/usage.md ;
  https://github.com/nirs/vmnet-helper
- https://github.com/containers/libkrun ; https://github.com/containers/krunvm ;
  https://lima-vm.io/docs/config/vmtype/krunkit/
- https://github.com/apple/container ; https://github.com/apple/containerization
- https://github.com/insidegui/VirtualBuddy
- https://techdocs.broadcom.com/us/en/vmware-cis/desktop-hypervisors/fusion-pro/25H2/release-notes/vmware-fusion-25h2-release-notes.html
- https://www.parallels.com/products/desktop/buy/ ;
  https://kb.parallels.com/123298 ; https://kb.parallels.com/en/120414 ;
  https://parallels.github.io/prl-devops-service/quick-start/
- https://blogs.oracle.com/virtualization/oracle-virtualbox-72
- https://multipass.run ; https://github.com/canonical/multipass/issues/2424
- https://veertu.com/ ; https://docs.veertu.com/anka/licensing/
- https://www.qemu.org/docs/master/system/arm/vmapple.html

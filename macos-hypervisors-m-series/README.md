# Virtual Machine Hypervisors for macOS on Apple Silicon

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

Which hypervisor / VM platform is the best fit on a modern macOS Apple Silicon (M-series) Mac, given a preference for free or one-time-purchase licensing and a feature wishlist that includes: VMs as system services that survive logout, mature CLI tooling, fast host↔guest file sharing, snapshots, broad Linux distro support, true bridged networking (the VM gets its own IP on the LAN), and ideally a web UI? See the [Original Prompt](#original-prompt).

## Answer / Summary

There is no single product that wins every category. The best practical choices, in priority order:

1. **Best overall free, hits the entire wishlist: QEMU + libvirt (+ optional Cockpit web UI), or `lima` with the `vz` backend and `socket_vmnet` for bridging.** Free, fully scriptable, true L2 bridged networking with a real LAN IP, virtio-fs file sharing, native qcow2 snapshots, runs from a `LaunchDaemon` before login, and supports nearly any ARM64 Linux distro. With Cockpit you get a web UI. Cost is setup complexity.
2. **Best free GUI experience: UTM.** Free (or $9.99 on the Mac App Store as donation). The only mainstream tool that can boot diverse x86 distros on Apple Silicon (via QEMU emulation), supports snapshots in QEMU mode, and offers bridged networking. Headless / boot-before-login is workable but fiddly; CLI is `utmctl`.
3. **Best polished commercial pick if you want a service-grade host: Parallels Desktop Pro.** Subscription only ($120/yr), but it is the only product where "VM as a system service that runs before login" is a first-class feature, and it adds a separate **Parallels DevOps Service** with a REST + web UI. Bridged networking, snapshots, fast file sharing all work. Standard edition does have a one-time-purchase option (~$220) but lacks the headless-service mode.
4. **Best for CI / fleet automation: Tart + Orchard.** Free in 2026, CLI-first, OCI-distributed VM images, granted the Apple bridged-networking entitlement, plus a Rust "softnet" mode that gives each VM an isolated LAN identity. Orchard adds a REST API + simple web UI for clusters.
5. **Best for "Linux dev box on macOS" workflows: OrbStack** (subscription $8/mo, free for personal/non-commercial). Wins on file-sharing speed and developer ergonomics, but **does not** offer true LAN-bridged networking — it uses an internal bridge — and is subscription-only.
6. **Best for Docker/OCI on macOS 26+: Apple's own `container` tool.** Free, Apple-supported, every container is its own micro-VM with its own IP, but on a host-shared subnet, not a LAN bridge.

If forced to pick one **free + one-time-purchase + ticks the most boxes**, the answer is **QEMU/libvirt or Lima(+socket_vmnet)** for power users, and **UTM** for users who want a GUI. If subscriptions are tolerable, **Parallels Pro** is the most feature-complete single product on the platform.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

I surveyed the active hypervisor ecosystem on Apple Silicon (April 2026) by reading vendor docs, project READMEs, and recent issue trackers for each candidate. The survey was bounded to tools that run macOS as the host on M1/M2/M3/M4. The candidates fell into four buckets:

- **Apple Virtualization.framework (VZ) wrappers** — UTM (Apple Virt mode), Tart, VirtualBuddy, vfkit, Lima(vz), OrbStack, Apple's `container`/Containerization.
- **QEMU/HVF based** — UTM (QEMU mode), bare QEMU, Multipass.
- **Commercial type-2 hypervisors** — Parallels Desktop, VMware Fusion, Veertu Anka.
- **Other** — VirtualBox 7.2 (developer preview on Apple Silicon), libkrun/krunvm/krunkit (micro-VMs).

For each, I scored the prompt's wishlist: licensing model, system-service capability, CLI maturity, file-sharing performance, snapshot model, Linux distro breadth, networking modes (especially bridged with a unique LAN IP), and presence of a web UI.

Apple Silicon imposes two background constraints that shaped the answers:

- All native acceleration goes through `Hypervisor.framework` or the higher-level `Virtualization.framework`. There is no KVM, and there is no x86 hardware virtualization — x86 guests must be emulated via QEMU (slow).
- True L2 bridging via VZ requires the `com.apple.vm.networking` entitlement, which Apple grants by manual approval. This is why most VZ-based tools default to NAT and use `socket_vmnet`, `vmnet-helper`, or `softnet` sidecars to provide bridged-style behavior.

## Results

### Comparison matrix

Legend: ✓ = supported well, ◐ = partial / with caveats, ✗ = not supported, $ = paid.

| Tool | License | One-time? | Service / no login | CLI | Fast FS sharing | Snapshots | Diverse Linux | Bridged (LAN IP) | Web UI |
|---|---|---|---|---|---|---|---|---|---|
| **QEMU + libvirt (raw)** | GPL, free | ✓ free | ✓ LaunchDaemon | ✓ `qemu`, `virsh`, `vmrun` | ✓ virtio-fs | ✓ qcow2 | ✓ everything (incl. x86 emul) | ✓ vmnet-bridged | ◐ via Cockpit |
| **UTM** | Apache 2.0, free (or $9.99 MAS) | ✓ free | ◐ headless mode, but UTM.app must run | ◐ `utmctl` (no snapshot subcmd) | ✓ virtio-fs (Apple Virt) / ◐ 9p (QEMU) | ✓ in QEMU mode, ◐ in Apple Virt | ✓ best on Apple Silicon (incl. x86 emul) | ✓ vmnet bridged | ✗ |
| **Tart** | Fair Source → OSS in 2026, free | ✓ free | ✓ pure CLI binary | ✓ first-class | ✓ virtio-fs | ◐ via OCI clone | ◐ ARM64 only | ✓ `--net-bridged` (entitlement) + softnet | ◐ via Orchard |
| **Lima / Colima** | Apache 2.0, free | ✓ free | ✓ LaunchAgent/Daemon | ✓ `limactl` | ✓ virtio-fs | ✓ `limactl snapshot` | ✓ 30+ templates | ✓ via `socket_vmnet` | ✗ |
| **OrbStack** | Proprietary, free personal | ✗ subscription only ($96/yr) | ◐ menu-bar / login-launched | ✓ `orb` | ✓ tuned virtio-fs (fastest) | ✗ | ✓ many distros | ✗ internal bridge only | ✗ (native GUI) |
| **vfkit** | Apache 2.0, free | ✓ free | ✓ LaunchDaemon | ✓ pure CLI | ✓ virtio-fs | ✗ | ◐ image-oriented | ✓ via vmnet-helper | ◐ REST |
| **libkrun / krunvm / krunkit** | Apache 2.0, free | ✓ free | ✓ CLI | ✓ | ◐ | ✗ | ◐ OCI images | ◐ | ✗ |
| **Apple `container`** | Apache 2.0, free | ✓ free, macOS 26+ | ✓ `container system` daemon | ✓ Docker-like | ✓ virtio-fs | ◐ image commit | ✓ any OCI Linux | ◐ host-shared subnet, not LAN | ✗ |
| **VirtualBuddy** | BSD-2, free | ✓ free | ✗ launch-at-login only | ◐ GUI-first | ✓ virtio-fs | ✓ APFS clone + VZ save | ◐ Ubuntu mostly | ✗ NAT only | ✗ |
| **VMware Fusion (Pro)** | Proprietary, free | ✓ free | ✓ `vmrun` + LaunchDaemon | ✓ `vmrun` | ✗ shared folders broken on Apple Silicon | ✓ snapshot tree | ✓ ARM64 distros | ✓ bridged | ✗ |
| **Parallels Desktop Pro** | Subscription | ◐ Standard one-time ~$220 (no service mode); Pro $120/yr | ✓ first-class "service mode" (LaunchDaemon) | ✓ `prlctl` | ✓ Parallels Tools | ✓ snapshot tree | ✓ ARM64 distros | ✓ bridged | ✓ Parallels DevOps Service (REST + web) |
| **VirtualBox 7.2** | GPL, free | ✓ free | ✓ `VBoxHeadless` + LaunchDaemon | ✓ `VBoxManage` | ◐ vboxsf (slow) | ✓ snapshot tree | ◐ ARM64 Linux/BSD; dev preview | ✓ bridged | ◐ phpVirtualBox 3rd party |
| **Multipass** | GPL, free | ✓ free | ✓ `multipassd` LaunchDaemon | ✓ first-class | ◐ sshfs | ✓ `multipass snapshot` | ✗ Ubuntu-only | ✗ NAT only on Apple Silicon | ✗ |
| **Veertu Anka** | Anka Develop free; Build/Flow subscription | ✗ subscription | ✓ daemon | ✓ `anka` | ◐ | ✓ | ◐ macOS-guest focused | ◐ entitlement-gated | ✓ Anka Build cluster UI ($) |

### How each tool answers the prompt's hard requirements

**Run as a system service before login (LaunchDaemon, not LaunchAgent).** The cleanest options are **Parallels Pro** (built-in feature), **bare QEMU/libvirt**, **vfkit**, **Tart**, **Lima**, **VMware Fusion** (`vmrun`), **VirtualBox** (`VBoxHeadless`), **Multipass** (`multipassd`), and **Apple `container`**. UTM and OrbStack are awkward because the GUI app needs to be running, which ties them to a user session.

**Bridged networking — VM gets its own LAN IP.** Available in **QEMU/libvirt**, **UTM** (vmnet bridged), **Tart** (Apple-granted entitlement, `--net-bridged`), **Lima** (via `socket_vmnet`), **vfkit** (via `vmnet-helper`), **VMware Fusion**, **Parallels**, **VirtualBox**. **Not** available in OrbStack, Apple `container` (defaults to host-shared NAT, not a bridge to en0), VirtualBuddy, Multipass, or Anka without paid entitlement-equivalents.

**Snapshots.** First-class in QEMU/libvirt, UTM (QEMU mode), Lima, VMware Fusion, Parallels, VirtualBox, Multipass, VirtualBuddy (APFS clones), and Veertu Anka. Tart uses OCI image clones as its snapshot equivalent. vfkit, libkrun, OrbStack, and Apple `container` lack a true snapshot model.

**Fast file sharing (virtio-fs).** Effectively all VZ-based tools (UTM/AppleVirt, Lima/vz, vfkit, Tart, VirtualBuddy, OrbStack, Apple `container`) use virtio-fs. **OrbStack** is the fastest by reputation thanks to custom caching. **VMware Fusion's** missing-on-Apple-Silicon shared-folders feature is the most notable regression in the field.

**Diverse Linux distros.** Anything that ships an ARM64 image runs on a VZ-based tool. The only mainstream way to run **x86-only** distros (or older x86 ISOs) on Apple Silicon is QEMU emulation, which means **UTM (QEMU mode)** or **bare QEMU**. Multipass is Ubuntu-only.

**Web UI.** No mainstream tool ships one out of the box. The realistic options are: **Parallels DevOps Service** (REST + web for managing Parallels VMs), **Orchard** (Tart cluster controller), **Cockpit** (over libvirt/QEMU), Anka Build's controller (paid), and `phpVirtualBox` (third-party).

## Analysis

A few patterns to note:

- The **Apple Silicon platform punishes diverse-distro use cases.** If your distro choice is constrained to "ARM64 with virtio drivers", every tool listed handles it. If you need x86 distros, you are forced into emulation, which means UTM or bare QEMU.

- **Bridged networking is the most discriminating feature.** Many VZ-based tools default to NAT because Apple gates the bridging entitlement. If you genuinely need each VM to have its own DHCP-assigned LAN IP visible to other devices on the network, you should evaluate by this axis first. The clean answers are QEMU (vmnet-bridged), Lima with socket_vmnet, Tart, and the commercial tools. OrbStack and Apple `container` are explicitly *not* in this category — they put VMs on an internal/host-shared bridge.

- **"VM as a system service" is rarely first-class on macOS.** Parallels Pro is the only product that makes it a UI-level option. Everywhere else you build it yourself with a `LaunchDaemon` plist that calls a CLI binary; this is fine for QEMU, vfkit, Tart, Lima, Multipass, VirtualBox, VMware. UTM and OrbStack fight against this model because they assume an interactive desktop.

- **Subscription vs one-time** breakdown:
  - Free / open source: QEMU, UTM, Lima/Colima, vfkit, Tart (in 2026), libkrun, Apple `container`, VirtualBuddy, VirtualBox, Multipass, VMware Fusion (free since late 2024), Anka Develop.
  - One-time purchase available: Parallels Desktop **Standard** (~$220, but no service mode and no full Pro features).
  - Subscription only: Parallels Desktop **Pro / Business**, OrbStack (commercial), Veertu Anka Build / Flow.

- **Web UI** is essentially a non-feature on macOS hypervisors today. If you want one, you adopt **libvirt + Cockpit** (free), **Parallels DevOps Service** ($), or **Orchard** for a Tart fleet.

- **Trade-off snapshot:**
  - **Pure power, free, every box checked but takes setup work** → QEMU + libvirt + Cockpit + `vmnet-shared`/`vmnet-bridged`.
  - **Pure power, free, mostly turn-key, GUI** → UTM. Accept the awkward boot-before-login story.
  - **Polished, "set it and forget it", willing to pay** → Parallels Desktop Pro + DevOps Service.
  - **Linux dev VM with the best ergonomics, OK with subscription, no need for true LAN IPs** → OrbStack.
  - **Fleet / CI** → Tart + Orchard, free in 2026.
  - **Just want Docker on macOS 26+** → Apple's `container`.

## Files

- `notes.md` — Detailed per-product research notes with sources.
- `comparison.csv` — Machine-readable feature matrix.
- `README.md` — This report.

## Original Prompt

> Research virtual machine hypervisors for modern macOS on M series chips.  Free or one time purchase solutions are preferred and subscriptions are not ideal but those solutions should be included for completeness.  Desired features include: running VMs as system services without having to log into macOS to launch them, command line tools and maintenance utilities, good performing access from the virtual machine to macOS disk directories, snap shot functionality, ability to run diverse Linux distributions, and advanced network capabilities like providing a virtual machine the ability for it to have its own ip address on a network without having to bridge through the host. A web interface for control of the hypervisor would be nice, but not necessarily required.

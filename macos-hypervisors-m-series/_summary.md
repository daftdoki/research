Apple Silicon Macs present unique challenges for virtualization, but a combination of QEMU + libvirt (with optional Cockpit web UI) or Lima (with socket_vmnet for true bridged networking) meets nearly all feature requirements for free, including headless service VMs, mature CLI tools, fast file sharing, snapshots, broad ARM64 Linux support, and a web UI. UTM offers the best free GUI experience and x86 emulation, but its headless and bridging support is less mature. For polished commercial options, Parallels Desktop Pro (subscription-only) excels by providing robust service-grade hosting, seamless networking, snapshots, and web interfaces. Tart + Orchard suit CI/fleet automation needs (with bridgeable networking and REST/web UIs), while OrbStack is ideal for dev environments but lacks L2 bridging. Apple’s native container tool is emerging, offering micro-VM-per-container, but currently only supports host-subnet IPs.

**Key tools:**
- [QEMU/libvirt](https://libvirt.org/) + [Cockpit](https://cockpit-project.org/) (web UI)
- [Lima](https://github.com/lima-vm/lima) (with socket_vmnet bridging)
- [UTM](https://mac.getutm.app/)
- [Parallels Desktop](https://www.parallels.com/products/desktop/)
- [Tart + Orchard](https://tart.run/)
- [OrbStack](https://orbstack.dev/)

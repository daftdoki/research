# API-Driven, Cloud-Style VM Management on QNAP QuTS hero

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question

What tools let you create and maintain virtual machines on a QNAP NAS running QuTS hero through an API, the way you manage VMs on a cloud: declarative create from an image, cloud-init, lifecycle, snapshots, teardown? ([original prompt](#original-prompt))

## Answer

**No official API exists, and no tool gives you a true cloud-style experience out of the box.** Virtualization Station (QVS) does have a REST API, mounted at `/qvs/` and used by its own web UI. QNAP has never documented it, and every tool that targets VMs is a small community project built by reverse-engineering it, or by driving the bundled `virsh` over SSH.

What's usable today, best first:

1. **[arnstarn/mcp-server-qnap-qvs](https://github.com/arnstarn/mcp-server-qnap-qvs)** (Python, MIT, 2026). This is the most current and complete QVS REST client. It was tested on QuTS hero h5.2.8 with VS 4.1.x and offers 39 operations: create, clone, import/export OVA, snapshots, disks, ISOs and power state. It is packaged as an MCP server, but `qvs_client.py` is a clean async client you can call from scripts. Its gap is that it creates blank-disk VMs only: no image-based create and no cloud-init.
2. **[danisla/qvscli](https://github.com/danisla/qvscli)** (Go, 2018). This is the only tool that implements the cloud pattern: copy a base image, build a cloud-init NoCloud ISO, attach it, boot. It predates VS 4, though, so expect broken endpoints. Use it as a recipe, not as a dependency.
3. **[scttfrdmn/qnap-vm](https://github.com/scttfrdmn/qnap-vm)** (Go, MIT, 2025). It skips the REST API and runs QNAP's bundled `virsh` over SSH. libvirt is stable and well understood, but VMs defined behind QVS's back may not sit cleanly in QVS's own database.
4. **[tmeckel/qnap-qvs-sdk-for-go](https://github.com/tmeckel/qnap-qvs-sdk-for-go)** (Go, 2022). This is an AutoRest-generated SDK covering about 60 QVS endpoints. It is useful as the API map the other tools rely on. The OpenAPI specs it was generated from are not published.

**For a real cloud-like workflow, the practical path is a thin layer you write yourself**: take the MCP server's auth and `/qvs/vms` client, then add qvscli's image-copy and cloud-init-ISO step. You can wrap that in Terraform or Ansible later. No Terraform provider manages QVS VMs. The two QNAP providers that exist cover Container Station containers and read-only NAS inventory.

A different route is Container Station's LXD. It has a real, documented API, cloud-init support and a Terraform provider. It only runs VMs with the brand-new third-party [qnap-lxd-vm](https://github.com/3v1n0/qnap-lxd-vm) kernel-module package, which has been verified on QTS but not on QuTS hero.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

- Searched QNAP's site, its developer pages, community forums and release notes for an official Virtualization Station API, CLI or cloud-init support.
- Searched GitHub for `qnap virtualization`, `qvs qnap` and `qnap terraform`, and searched PyPI and pkg.go.dev for clients.
- Shallow-cloned the four VM-capable repos into a scratch directory and read the source. I did not take the READMEs on trust. I checked the auth flow, the endpoint paths (`grep WithPath` on the SDK), the create-VM payloads and how cloud-init is handled. The clones are not committed.
- Read community write-ups on using QNAP's bundled `virsh`.

I tested nothing against real hardware. Per this repo's rules, every claim comes from documentation or source code.

## Results

### The QVS REST API, as reconstructed from source

| Aspect | What the tools do |
|---|---|
| Base path | `https://<nas>/qvs/` |
| Auth step 1 | `GET /cgi-bin/authLogin.cgi?user=…&plain_pwd=…` returns `NAS_SID` (standard QTS login) |
| Auth step 2 | `POST /qvs/auth/login` (form, base64 password, `NAS_SID` cookie) returns `csrftoken` and `sessionid` cookies |
| Every call | All three cookies, an `X-CSRFToken` header and a `Referer: …/qvs/` header |
| VMs | `GET/POST /vms`, `GET/PUT/DELETE /vms/{id}`, `/vms/states`, `/vms/{id}/{start,shutdown,forceshutdown,reset,suspend,resume,clone,export,ips}` |
| Devices | `/vms/{vm_id}/{disks,adapters,cdroms,usbs,pci,gpu,graphics,serialports,share,vnc_token}` |
| Snapshots | `/vms/{vm_id}/snapshots`, `…/{id}/revert`, `…/{id}/lock` |
| Import | `/vms/import_{check,config,download,network,vm}`, `/vms/check_iso`, `/vms/mac` |

Sources: [`qvs_client.py`](https://github.com/arnstarn/mcp-server-qnap-qvs/blob/main/src/mcp_server_qnap_qvs/qvs_client.py) and the [Go SDK's `services/vms`](https://github.com/tmeckel/qnap-qvs-sdk-for-go/tree/master/services/vms).

### Tool comparison

| Tool | Mechanism | Create from image + cloud-init | Lifecycle / snapshots / clone | Last activity | Tested on | License |
|---|---|---|---|---|---|---|
| [mcp-server-qnap-qvs](https://github.com/arnstarn/mcp-server-qnap-qvs) | QVS REST | No (blank qcow2 disk, hardcoded `Opteron_G2` CPU, `qvs0` bridge) | Yes; also OVA import/export, ISO download, disk resize, guest-agent IPs | 2026-03 (v0.9.2) | QuTS hero h5.2.8, VS 4.1.x | MIT |
| [qvscli](https://github.com/danisla/qvscli) | QVS REST + File Station | **Yes**: copies a base `.img`, builds a `cidata` NoCloud ISO with `genisoimage`, injects SSH key and startup script | Start/stop/reset/delete, plus copy-based disk snapshots | 2018-06 | Pre-VS 4 (unstated) | none stated |
| [qnap-vm](https://github.com/scttfrdmn/qnap-vm) | SSH + `/QVS/usr/bin/virsh`, `virsh define` of generated XML | "Template" flag only; no cloud-init | Yes, including linked clones, stats and VNC/serial console | 2025-09 (v0.2.0) | QTS 5.1+/QuTS hero h5.1+ (claimed) | MIT |
| [qnap-qvs-sdk-for-go](https://github.com/tmeckel/qnap-qvs-sdk-for-go) | QVS REST (generated) | Building blocks only | Building blocks only | 2022-01 | Unstated | GPLv3 (samples) |
| [terraform-provider-qnap (mohamed-mfarag)](https://github.com/mohamed-mfarag/terraform-provider-qnap) | Container Station API | n/a: **containers only** | n/a | 2026-05 | — | — |
| [terraform-provider-qnap (hashneo)](https://github.com/hashneo/terraform-provider-qnap) | QTS `/api/v2` | n/a: **read-only inventory** | n/a | 2026-05 | QTS 5.2.7 | — |
| [qnap-lxd-vm](https://github.com/3v1n0/qnap-lxd-vm) + LXD | Container Station LXD 5.0.2 plus added vsock modules, QEMU 9.0.3 and OVMF | Yes, through LXD's native cloud-init support | Yes, through the LXD API | 2026-10 (days old) | QTS 5.2.10 only | GPLv3 |

### Official QNAP position

- There is no QVS API documentation. QNAP publishes Swagger for [QVR Pro](https://download.qnap.com/apidoc/qvrpro/qvr_pro_api_1.0.0.yaml) and docs for the [Container Station API](https://qnap-dev.github.io/container-station-api/index.html), but nothing for Virtualization Station. The [VS 4 how-to](https://www.qnap.com/en/how-to/tutorial/article/how-to-use-virtualization-station-4) covers the GUI only.
- The latest release notes I found, [VS 4.1.0.327 (2025-10-09)](https://community.qnap.com/t/virtualization-station-4-1-0-327-2025-10-09-released/4103), add VM High Availability (beta, QuTS hero h5.3.0+). They say nothing about an API, cloud-init or templates.
- QNAP's QTS authentication PDF, which the MCP server cites, now returns 404.

### Bundled virsh

Community write-ups ([qnapclub.de, 2020–2025](https://forum.qnapclub.de/blog/entry/525-virsh-auf-qnap-nutzen-virtuelle-maschinen-via-ssh-starten-stoppen/), [QNAP-VM-launcher](https://github.com/jamesmwatson/QNAP-VM-launcher)) agree on these points:

- Run `export LD_LIBRARY_PATH=/QVS/usr/lib:/QVS/usr/lib64/; export PATH=$PATH:/QVS/usr/bin/:/QVS/usr/sbin/`.
- Use `sudo`, and connect to QVS's own socket (`qemu:///system?socket=…`). Without them, `virsh list --all` comes back empty.
- VMs are named by UUID, and the UUID can change after a migration.
- On QTS 5.2 the binary may live under `/share/CE_CACHEDEV*_DATA/.qpkg/QKVM/usr/bin/virsh`.

## Analysis

**Why nothing feels like a cloud.** Cloud-style management needs four things: a stable, authenticated API; image-based provisioning; first-boot configuration (cloud-init); and declarative tooling on top (Terraform or Ansible). QVS supplies only the first, and even that is undocumented. Its create call builds a VM shell and an empty disk, and you then boot an installer ISO. qvscli shows that the missing pieces can be put together from parts QNAP already exposes: copy a qcow2 cloud image with File Station, generate a NoCloud ISO locally, upload it, attach it as a CD-ROM, and POST `/qvs/vms` pointing at the copied disk. Nobody maintains that recipe against VS 4.

**Recommended build, if you want this:**

1. Reuse the MCP server's `QVSClient`, or port its ~40 lines of auth to your language. Its endpoint map matches the Go SDK.
2. Do the provisioning the way qvscli does: a base cloud image on a share, a per-VM copy, a `cidata` ISO, and an attached CD-ROM. Install `qemu-guest-agent` in the image so `/vms/{id}/ips` returns addresses.
3. Wrap it as Ansible tasks (`ansible.builtin.uri`) or as a small Terraform provider built on the Go SDK. No QNAP-specific Ansible collection exists.
4. Pin the VS version. Every endpoint is undocumented and can change in any VS update.

**REST vs. virsh.** The REST API keeps VMs visible and editable in the QVS UI, and it's what QNAP's own HA, backup and snapshot features know about. Driving `virsh` directly gives you the full libvirt feature set with well-known XML, and could in principle let the generic [`dmacvicar/libvirt` Terraform provider](https://github.com/dmacvicar/terraform-provider-libvirt) work over `qemu+ssh://…?socket=`. Nobody has documented that working on QNAP. QNAP's libvirt also lives off the default PATH, which libvirt's SSH transport expects. And no source I read confirms that QVS stays consistent with domains it didn't create. Prefer REST for anything long-lived.

**The LXD alternative** is the only route to a real, documented, cloud-grade API: LXD REST, cloud-init and an LXD Terraform provider. It costs a lot, though. You load third-party kernel modules into a NAS kernel, it has been verified on QTS only, there's no graphical console, LXD 5.0.2 is old, and the VMs are invisible to Virtualization Station, so QVS snapshots, backup and HA don't apply. Whether Container Station lets you expose LXD on the network (`core.https_address`) and keeps that setting is undocumented. It's worth an experiment on a non-critical box, not a production plan.

**Security caveats** that apply to every REST tool:
- They need a QTS **admin** login. QVS has no scoped API tokens.
- The MCP client sends the password as a `plain_pwd` GET parameter, which can end up in web server logs.
- Most of them default to `verify_ssl=false`.

Keep the API behind your LAN or a VPN, and use a dedicated admin account.

## Files

- `README.md`: this report
- `notes.md`: research log, including dead ends and per-repo source-reading notes
- `_summary.md`: index summary used by the repo's root README

## Original Prompt

> Research tools for allowing API driven virtual machine creation and maintenance for Qnap QuTS that allow cloud VM-style management of VMs.

# Portable Automated Dev VM Setup

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

How can I automate the configuration of a development VM in a hypervisor-agnostic way, so that the same automation produces an identical, ready-to-use workstation whether the VM is running on a macOS laptop, a Proxmox cluster, or AWS EC2? The setup must join my tailnet, create my user with SSH keys, install my dotfiles and dev tools, run browser-accessible VS Code, expose a web file manager, install Claude Code, allow running multiple sandboxed `claude --dangerously-skip-permissions` agents in parallel, auto-update itself, and be quick to (re)provision. Claude Code should be reachable from the SSH shell, from inside VS Code, and optionally inside a constrained sandbox — all three environments sharing one common working directory. An optional browser-accessible Linux desktop should be available with guaranteed no-drift between surfaces. Every web-accessible service should live under a **single tailnet hostname** fronted by a small portal page, and container image updates should be handled with something actively maintained (watchtower was archived in December 2025). ([original prompt](#original-prompt))

## Answer / Summary

**Build the automation as three thin layers, each portable across every target hypervisor.** The single platform-independent thread that stitches them together is **cloud-init** for layer 0, **`ansible-pull`** for layer 1, and a **Docker Compose stack** for layer 2. Together they let a fresh Ubuntu 24.04 LTS cloud image become a fully configured dev environment with one SSH command (or automatically via cloud-init user-data).

| Layer | Technology | What it does |
|------|-----------|--------------|
| 0. Boot | cloud-init user-data YAML | Sets hostname, creates user, installs authorized SSH keys, installs minimal deps, fetches the bootstrap script. Works unchanged on Proxmox Cloud-Init templates, AWS EC2 user-data, and macOS Multipass. |
| 1. Configure | `bootstrap.sh` + `ansible-pull` from a git repo | Installs Ansible via pipx, then runs an idempotent playbook that configures the tailnet, Docker, **mise**-managed dev tools, dotfiles, Claude Code, and the container stack. Re-run any time to reconcile drift. |
| 2. Run | `docker compose` stack | Long-running services: **code-server** (browser VS Code), **filebrowser** (home-dir file manager), optional **webtop** (full browser desktop), and the **Claude agent pool** (one sandboxed container per parallel agent, modeled on Anthropic's reference devcontainer with ipset default-deny firewall). Every web service is reverse-proxied by a small **Caddy "portal"** container that shares a network namespace with **one** Tailscale sidecar, so the whole stack lives under a **single MagicDNS hostname** (`devvm.<tailnet>.ts.net`) served over HTTPS with no cert management. |

**Key decisions that make this work:**

- **Ubuntu 24.04 LTS** as the base image — broad cloud-init support everywhere.
- **`mise-en-place`** instead of asdf/pyenv/nvm — one Rust-based tool handles python/uv/node/rust/go/neovim/cli tools, 20-200x faster than asdf, and adding a tool is a one-line YAML change in `group_vars/all.yml` followed by a re-run.
- **`ansible-pull`** instead of a central Ansible controller — zero infra, the VM pulls its own config from git.
- **`artis3n.tailscale.machine`** Ansible role with **OAuth client** auth and **`tag:devvm`** so secrets don't expire and ACLs are tag-driven.
- **code-server** rather than openvscode-server — it can pre-install extensions non-interactively and can point `$EXTENSIONS_GALLERY` at a private marketplace.
- **Claude agent containers built on Anthropic's reference devcontainer pattern** (see [anthropics/claude-code/.devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer)) — each agent runs with a default-deny outbound firewall allowing only `api.anthropic.com`, `registry.npmjs.org`, `github.com`, and a small allowlist, which is exactly what makes `--dangerously-skip-permissions` safe to run unattended.
- **Packer** wraps the same Ansible playbook to produce a **golden image** per target, shrinking cold-boot-to-ready time from minutes to seconds — the same playbook that provisions a fresh VM also bakes the AMI/qcow2/vmdk, so there is only one source of truth.
- **Claude Code is installed via its official native installer** (`curl -fsSL https://claude.ai/install.sh | bash`), which ships a standalone Bun-compiled binary at `~/.local/bin/claude`. No Node.js or npm is required anywhere. The installer auto-updates in the background, so there is no version pin and no `mise_global_tools` entry for it.
- **Claude Code is reachable from four different surfaces that all share one common working directory** (`/home/me/work`):
  - **Plain SSH shell** — the `dev_tools` Ansible role runs the native installer as the devvm user, dropping `claude` into `~/.local/bin/`.
  - **VS Code integrated terminal** — a custom `docker/code-server-image/` reshapes the upstream `codercom/code-server` image so its `$HOME` matches the host's `/home/me`. The integrated terminal then just reads the host's `.bashrc`, the host's `claude` binary, the host's mise installs, and the host's dotfiles. Nothing is duplicated in the image; there is no Node or npm in it at all.
  - **Browser desktop** — the optional webtop container's `$HOME` is the same host `/home/me`, so `claude` is already on PATH without any extra install.
  - **Sandboxed agent containers** — each agent image bakes in the native `claude` binary (the agent firewall blocks the auto-update endpoint, so the baked version is effectively the pinned version until the image is rebuilt by the next ansible-pull). Agents run under an `init-firewall.sh` network allowlist so `claude --dangerously-skip-permissions` is safe even running many in parallel.
  - **Shared working directory** — `/home/me/work` is bind-mounted at the same absolute path into code-server and every agent container, so files written by an agent are instantly visible in the VS Code explorer and over SSH, and vice versa. It's the hand-off point between the constrained and unconstrained environments.
- **Optional full Linux desktop in the browser (KasmVNC/Selkies via `linuxserver/webtop`).** Available when `webtop_enabled: true`. The key property: the container's `$HOME` is literally the host's `/home/me` directory via a `PUID=1000` bind mount, so the desktop shares the *exact same filesystem* with the SSH shell, code-server, and the agents. There is only one set of dotfiles, one `mise` install, one `~/.ssh`, one `~/.config`, one shared working directory. **The surfaces cannot get out of sync because no state is duplicated.** Access via `https://devvm.<tailnet>.ts.net/desktop/` through the portal.
- **Single tailnet hostname for every service** (`devvm.<tailnet>.ts.net`). One Tailscale sidecar, one HTTPS cert, one ACL target. A small Caddy "portal" container sits inside the sidecar's network namespace and reverse-proxies path-based subroutes to each backend: `/code/` → code-server, `/files/` → filebrowser, `/desktop/` → webtop, `/agents/N/` → each Claude agent's browser terminal, and a tiny landing page at `/`. All other services stay in their own network namespaces (so agent firewalls don't touch the main network) and are reached via Docker DNS on the default bridge.
- **Container image updates without watchtower.** containrrr/watchtower was archived in December 2025. The primary update path is the same `ansible-pull` that provisions the VM: a systemd timer re-runs it weekly, which re-renders the compose template, rebuilds local images with `--pull`, pulls upstream images, and re-applies. A second, smaller timer runs `docker compose build --pull && pull && up -d --remove-orphans` mid-week in case the playbook hasn't changed but upstream images have. See [Container image update strategies](#container-image-update-strategies) for a survey of other options (Diun, What's Up Docker, Tugtainer, Renovate + CI).

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. Surveyed the space for each requirement (tailnet join, web VS Code, file manager, sandboxed Claude Code, dev-tool management, auto-updates) and rejected options that fail the "portable across Proxmox/EC2/macOS" test or require heavyweight central infrastructure.
2. Verified current state of the chosen tools with web searches (April 2026) to avoid stale assumptions:
   - `artis3n/ansible-role-tailscale` has OAuth-client auth with `tailscale_tags`, `_ephemeral`, `_preauthorized`.
   - Anthropic explicitly ships a devcontainer for `--dangerously-skip-permissions` with a network allowlist in `init-firewall.sh`.
   - `mise-en-place` is a drop-in asdf replacement with ~20-200x speedup and first-class env-var and task support.
   - `code-server` supports non-interactive `--install-extension`; openvscode-server does not.
   - cloud-init 26.x user-data is supported unchanged by Proxmox, EC2, and Multipass on macOS.
   - `tailscale/tailscale` Docker image accepts `TS_SERVE_CONFIG` to expose arbitrary localhost ports via MagicDNS HTTPS.
3. Drafted concrete artifacts as a skeleton that could be dropped into a private config repo and be run end-to-end:
   - Portable cloud-init user-data
   - Bootstrap script
   - Ansible playbook with seven tagged roles
   - Docker Compose template with Tailscale sidecars and a parametrized Claude agent pool
   - Claude agent Dockerfile adapted from Anthropic's reference

## Results — Architecture

```
   fresh Linux VM (Proxmox / AWS / UTM / Multipass / OrbStack)
             │
             │  cloud-init user-data (portable YAML)
             │  - hostname, timezone
             │  - user + authorized_keys
             │  - install curl, git, pipx
             │  - runcmd: curl .../bootstrap.sh | bash
             ▼
   bootstrap.sh
             │  - pipx install ansible-core
             │  - ansible-galaxy install collections
             │  - ansible-pull -U <repo> site.yml
             ▼
   Ansible roles (idempotent, tagged)
             ├─ base         apt update, unattended-upgrades, timezone,
             │               installs /usr/local/sbin/devvm-bootstrap.sh
             ├─ user         user, sudoers NOPASSWD, authorized_keys, dirs
             ├─ dotfiles     chezmoi init --apply github.com/me/dotfiles
             ├─ tailscale    artis3n OAuth + tag:devvm + ephemeral + --ssh
             ├─ docker       docker-ce + compose v2
             ├─ mise         install mise, iterate mise_global_tools
             ├─ dev_tools    chezmoi binary, Claude Code via native installer
             │               (curl https://claude.ai/install.sh | bash)
             ├─ containers   render docker-compose.yml, Caddyfile, portal
             │               HTML, ts-serve.json from templates, then up -d
             └─ updates      weekly timers:
                             - mise-upgrade (dev tools)
                             - devvm-compose-update (pull/build/up)
                             - devvm-ansible-pull (full reconcile)
             │
             ▼
   docker compose stack running on the VM

     ┌────────────────────────────────────────────────────────────────┐
     │  ts-devvm      tailscale sidecar, one MagicDNS name            │
     │                hostname = devvm, TS_SERVE_CONFIG forwards      │
     │                https://devvm.<tailnet>.ts.net  →  127.0.0.1:8000 │
     │                                                                │
     │  portal        Caddy, shares ts-devvm's netns, listens on 8000 │
     │                  /            → landing page (HTML)            │
     │                  /code/       → code-server:8080               │
     │                  /files/      → filebrowser:80  (--baseurl)    │
     │                  /desktop/    → webtop:3000      (optional)    │
     │                  /agents/N/   → agent-N:7681     (ttyd -b)     │
     └────────────────────────────────────────────────────────────────┘
             │                   │                  │           │
             ▼                   ▼                  ▼           ▼
     code-server           filebrowser          webtop       agent-0..N
     (own netns,          (own netns,          (own netns,   (own netns,
      default bridge)      default bridge)      default       ipset
      custom image         filebrowser          bridge)       default-deny
      whose $HOME IS       --baseurl /files     linuxserver   firewall)
      host /home/me        (natural subpath)    webtop,       claude pinned
      mise/claude/         home→/srv            KasmVNC /     native binary
      dotfiles all read                         Selkies,
      from host home                            home→/config  /workspace
                                                              +shared workdir

   Single source of truth = /home/me on the host
             ├─ visible natively over SSH (it IS the login shell's $HOME)
             ├─ bind-mounted as $HOME into code-server (uid 1000,
             │  container user renamed to match host at image-build time)
             ├─ bind-mounted as $HOME into webtop       (PUID/PGID=1000)
             └─ bind-mounted at the same absolute path into every agent
             - dotfiles, mise, git, ssh, claude binary, claude config,
               shared workdir all live here, so every surface sees
               identical state by construction
```

## Claude Code surfaces

| Surface | How `claude` gets there | Working directory | Permission mode |
|---|---|---|---|
| **SSH shell** (tailnet SSH or direct ssh) | `dev_tools` role runs `curl -fsSL https://claude.ai/install.sh \| bash` as the devvm user. The native installer drops a standalone Bun-compiled binary into `~/.local/bin/claude`. No Node, no npm. Auto-updates in the background at runtime. | `/home/me/work` (the shared dir, same path everywhere) | Normal prompt-based permission gating — you're on the host, so permission prompts matter. |
| **VS Code integrated terminal** (browser, via tailnet, `/code/` under the portal) | Nothing extra inside the container. The custom `docker/code-server-image/` renames the upstream `coder` user to match the host user, so the bind-mounted `/home/me` *is* the container's `$HOME`. Opening a terminal just reads the host `.bashrc`, finds `claude` at `~/.local/bin/claude`, and finds mise-managed tools under `~/.local/share/mise`. | Code-server opens into `/home/me/work` by default; explorer and integrated terminal see the same files as SSH | Same prompt-based mode as SSH — the code-server container is NOT sandboxed, it's effectively the user's normal environment on a browser face. |
| **Browser desktop** (optional, webtop via the portal `/desktop/`) | Nothing extra: the desktop's `$HOME` IS the host `/home/me`, so the same host-installed `claude` binary is already on PATH in the XFCE terminal. | Desktop terminal cd's into `/home/me/work` by default via the shared `.bashrc`. | Same as SSH: prompt-gated. |
| **Sandboxed agent** (browser terminal per agent, `/agents/N/` under the portal) | Baked into `docker/agent-image/` at build time by running the same `claude.ai/install.sh` installer as the agent user. The agent firewall blocks the auto-update endpoint, so the baked version *is* the pinned version until the next `ansible-pull` rebuilds the image. | Per-agent `/workspace` for isolated scratch, plus the shared `/home/me/work` at the same absolute path so finished work can be handed off. | `claude --dangerously-skip-permissions` runs unattended behind an ipset default-deny firewall (`init-firewall.sh`) that only allows `api.anthropic.com`, `github.com`, and a handful of others. Note `registry.npmjs.org` was **removed** from the allowlist when Claude Code stopped being an npm package. |

The common path means you can launch an agent to generate code in the constrained environment, then immediately `cd ~/work` from the SSH shell (or open the folder in code-server) to review and run it without any file copying.

## Why the surfaces cannot drift out of sync

The requirement was that SSH, VS Code, and the browser desktop must all show the same programs, files, and tools — **and it must be impossible for them to drift**. The rule the design enforces is:

> **$HOME is the single source of truth. Every surface mounts the same $HOME. Dev tools live under $HOME, not inside container images.**

What that means concretely:

| Thing | Where it lives | Surfaces that see it |
|---|---|---|
| Dotfiles (bash, zsh, git, tmux, nvim, starship...) | `/home/me/.bashrc`, `/home/me/.config/...`, managed by chezmoi | SSH, code-server integrated terminal, webtop desktop terminal — all read the same files |
| Version-managed dev tools (python, uv, node, go, rust, nvim, cli utilities) | `/home/me/.local/share/mise/installs/...` (mise is configured to prefer `$HOME` over system paths) | Every surface that sources `.bashrc` — and that's all of them |
| Shared working directory | `/home/me/work` — a plain directory in $HOME | Native to SSH and desktop (just a path); explicitly bind-mounted at the same absolute path into code-server and every agent container |
| VS Code settings | `~/.config/Code/User/settings.json` (desktop VS Code in webtop) + `~/.local/share/code-server/User/settings.json` (browser code-server). **Synced via VS Code Settings Sync** (GitHub-backed) so both read from the same profile. Also: extensions list is declared in `group_vars/all.yml` so every image installs the same set. | code-server + webtop's VS Code Desktop stay in sync through Settings Sync; the extensions list is enforced by Ansible so even a hand-added extension gets reconciled on the next `ansible-pull` |
| Git identity, SSH keys, gh auth | `~/.gitconfig`, `~/.ssh`, `~/.config/gh` | One file for all surfaces |
| Claude Code auth / config | `~/.claude/`, `~/.config/claude/` | SSH, code-server, webtop (all share $HOME); agents deliberately keep their own copy so their auth is separate per-sandbox |
| Docker daemon | Host daemon, socket at `/var/run/docker.sock`, bind-mounted into code-server and webtop | `docker ps` shows the same containers from every surface |
| APT/system packages inside webtop | Lives in the webtop container image, NOT under $HOME | Deliberately scoped to *desktop* apps (browser, office, meld). Not part of the dev-tool surface, so it can't contribute to dev-tool drift. |

### The mechanical enforcement

- **No dev tool is installed by any container image.** Every language runtime, every CLI utility used day-to-day is under `~/.local/share/mise/` or `~/.local/bin/` on the *host*. The code-server image explicitly drops Node, mise, and Claude Code and instead relies on the container's `$HOME` being literally the host's `/home/me` (via a `usermod` at image-build time). Image build is a ~3-second `usermod`; everything else is read from the bind-mount at runtime.
- **Tool list is declarative and reconciled.** Adding a tool is a one-line edit to `mise_global_tools` in `group_vars/all.yml`. Re-running `ansible-pull` installs it *on the host*, and every surface picks it up immediately via the bind-mounted `$HOME`.
- **Periodic reconciliation.** The `updates` role installs three timers: `mise-upgrade.timer` (dev tools), `devvm-compose-update.timer` (`docker compose build --pull && pull && up -d`), and `devvm-ansible-pull.timer` (the full playbook re-run). Together they cover tool updates, container image updates, and declarative reconciliation of out-of-band edits. This replaces the retired watchtower without changing the "one path, one source of truth" property.
- **Only one home per VM.** There is no "SSH home" vs "desktop home" vs "code-server home". They are literally the same inode, owned by uid 1000, mounted read-write into every relevant container.
- **Non-dev state lives in its own container and is allowed to be image-local.** Firefox binaries, LibreOffice, etc. live inside the webtop image. They can't diverge from "the dev environment" because they aren't part of it; rebuilding the webtop image on the next `ansible-pull` replaces them wholesale.

## Results — Feature → Mechanism mapping

| Requirement | Mechanism |
|---|---|
| Connect to tailnet | `artis3n.tailscale.machine` role, OAuth client auth, `tag:devvm`, ephemeral + preauthorized, `--ssh` |
| Create user, sudo, SSH keys | `user` Ansible role, `devvm_user_ssh_keys` in group_vars |
| Dotfiles | chezmoi installed by `dev_tools` role, `chezmoi init --apply` of your dotfiles repo |
| Docker + compose | `docker` role (e.g. `geerlingguy.docker`) + `community.docker.docker_compose_v2` |
| Browser VS Code w/ extensions | Custom `docker/code-server-image/` that reshapes `codercom/code-server` so its `$HOME` matches the host. No Node/mise/claude installed inside the image — everything is read from the bind-mounted host home. Extensions installed via `--install-extension` per item in `code_server_extensions`. |
| Single tailnet hostname for everything | One `ts-devvm` Tailscale sidecar. Its `TS_SERVE_CONFIG` forwards all HTTPS traffic on `devvm.<tailnet>.ts.net` to a Caddy "portal" that shares its network namespace. Caddy reverse-proxies per subpath to each backend. |
| Dev portal / landing page | Small rendered HTML (`portal-index.html.j2`) served at `/` by the Caddy portal, linking to every service. Re-rendered on every `ansible-pull`. |
| Browser-accessible full Linux desktop | Optional `webtop` service (`linuxserver/webtop:ubuntu-xfce`, KasmVNC + Selkies WebRTC streaming) with `PUID=1000` so its `$HOME` is the host's `/home/me`. Proxied by the portal at `/desktop/`. Extra desktop apps (browser, office) installed via the `universal-package-install` mod. |
| Remote desktop via native client (optional) | Webtop supports HTTPS web access out of the box through the portal; for users who prefer RDP, xrdp could be added to the webtop image. Not included by default — web access via any browser is enough for most use. |
| Desktop, SSH, VS Code and agents all in sync by construction | Every surface bind-mounts the same `/home/me`. Dev tools live under `$HOME` via mise, not in container images. The `updates` role re-runs `ansible-pull` on a timer to reconcile drift. See the "Why the surfaces cannot drift" section. |
| Claude Code in SSH shell | Official native installer (`curl https://claude.ai/install.sh \| bash`) run by the `dev_tools` role as the devvm user. No Node/npm involved. |
| Claude Code in VS Code integrated terminal | Automatic: the code-server container's `$HOME` *is* the host `/home/me`, so the single host install is already on PATH. |
| Claude Code in webtop desktop terminal | Automatic for the same reason — the desktop shares `$HOME` with SSH. |
| Claude Code in sandboxed agents | Native installer run at image build time in `docker/agent-image/Dockerfile`, plus `--dangerously-skip-permissions` wrapped in an ipset network allowlist. |
| Common working directory across all four surfaces | `shared_workdir` (default `/home/me/work`) natively visible over SSH and in the desktop, bind-mounted at the same absolute path into code-server and every agent container |
| Web file manager | `filebrowser/filebrowser` container with `--baseurl /files`, reverse-proxied by the portal at `/files/`. |
| Common dev tools (git, python, uv, pyenv replacement, nvim, ...) | mise manages everything via `mise_global_tools` list in group_vars; apt handles the few it can't |
| Adding a new tool is one line | YAML edit to `mise_global_tools` (or `apt_dev_packages` for system pkgs), re-run `ansible-pull` |
| Sandboxed multi-agent Claude Code with `--dangerously-skip-permissions` | Agent pool in compose, container image built from Anthropic's reference devcontainer with `init-firewall.sh` default-deny + domain allowlist, one container per agent, each with its own `/workspace` volume |
| Auto-updates (OS) | unattended-upgrades (apt security updates), `mise-upgrade.timer` (dev tools), systemd timer-based automatic reboot |
| Auto-updates (containers) | `devvm-compose-update.timer` runs `docker compose build --pull && pull && up -d --remove-orphans` weekly; `devvm-ansible-pull.timer` re-runs the whole playbook weekly, re-rendering compose/Caddyfile/portal from templates and rebuilding local images. Watchtower is **not** used (archived Dec 2025). |
| Fast provisioning | `ansible-pull` is idempotent and cached; for cold starts use Packer to bake a golden image from the same playbook per target hypervisor |
| Portable base | Ubuntu 24.04 LTS cloud image everywhere; cloud-init user-data unchanged across Proxmox / EC2 / Multipass |

## Analysis

### Why this is portable

The only lines of YAML specific to a particular hypervisor are in `cloud-init/user-data.yaml`, and only if you want to personalize the hostname. Every other file is plain Ubuntu plus internet connectivity. That's the entire contract we demand of a target platform:

1. "Boot an Ubuntu cloud image."
2. "Pass it this cloud-init user-data." (Proxmox's UI, `aws ec2 run-instances --user-data`, `multipass launch --cloud-init`)
3. Done.

### Why mise, not asdf

Both support `.tool-versions`, but mise is written in Rust, is 20-200x faster at lookups, modifies `PATH` directly (no shims), and adds env-var and project-task management on top. Since the user will be adding tools often, a one-line YAML change plus a re-run of ansible-pull is the right ergonomic target, and mise makes that a single command internally.

### Why not NixOS

NixOS is arguably the most "correct" answer — declarative, reproducible, immutable, exactly-once installs. It was considered and set aside because: (a) the user's requirement list is pragmatic rather than ideological, (b) Ubuntu has broader cloud-init tutorials and more pre-built cloud images on the target hypervisors, and (c) bringing the team up the NixOS learning curve has real cost. Worth revisiting if reproducibility problems bite.

### Why container-sandboxed Claude agents

Anthropic itself runs `--dangerously-skip-permissions` only inside containers with network allowlists. The ipset-based firewall in `init-firewall.sh` is the crucial mechanism: it permits `api.anthropic.com`, `registry.npmjs.org`, `github.com`, and a few others, and default-denies everything else. Nothing the agent does can escape the container or reach arbitrary network endpoints. That containment is what makes running many agents in parallel acceptable; the blast radius of a single compromised agent is one workspace directory, not the whole VM.

The compose stack runs each agent in its own container with its own `/workspace` volume. Combining that with **git worktrees** inside `/workspace` lets multiple agents work on the same repo at once without stepping on each other.

### Why `linuxserver/webtop` for the optional desktop

There are several good self-hosted web-desktop stacks; the relevant ones in April 2026 are:

| Option | What it is | Verdict |
|---|---|---|
| **`linuxserver/webtop`** | Maintained Docker image, Ubuntu/Alpine/Fedora/Arch × XFCE/KDE/MATE/i3 flavors. Rebased onto KasmVNC in 2023, then onto **Selkies** (WebRTC/GStreamer) in June 2025 for low-latency hardware-accelerated streaming. First-class PUID/PGID support for bind-mounted home directory. | **Chosen.** Drop-in, low friction, one container, and it fits the same "container fronted by a tailscale sidecar" pattern as code-server and filebrowser. |
| **Kasm Workspaces** | Multi-user platform with a control plane, disposable desktops, per-user sessions, policy, billing. | Excellent for teams, way too much machinery for a single-user dev VM. LinuxServer images are "first-class citizens" of Kasm if we ever want to migrate — same underlying KasmVNC/Selkies runtime. |
| **Apache Guacamole** | HTML5 gateway that proxies RDP/VNC/SSH to existing machines. Does not host the desktop itself. | Wrong shape for this design. We want the desktop to *be* a container on the same VM sharing `$HOME`, not a proxy to an external desktop. Would be the right answer if we wanted to unify access to *multiple* existing machines. |
| **Selkies directly** | The streaming library webtop now uses under the hood. Great if you want to build a custom image. | Webtop already wraps it; no reason to reinvent. |
| **`xrdp` + native RDP client** | Classic Windows-style RDP. Works offline without a browser. | Can be added as a secondary path (install `xrdp` into the webtop image and forward port 3389), but the browser-first requirement is already met by Selkies. Not included by default to avoid two parallel session types. |

WebRTC-based streaming (Selkies) is meaningfully lower latency than classic VNC over websockets, handles clipboard, audio, and multi-monitor, and works in any modern browser without plugins — which matches the "web interface" requirement exactly.

### Why sharing $HOME is the right answer to "cannot drift"

The original requirement was: "no matter how I'm accessing these tools, I have the same setup of programs, files and tools that are all in sync. It should not be possible for them to get out of sync."

There are two ways to satisfy "in sync":

1. **Replicate and synchronize.** Multiple copies, plus a sync protocol (rsync, Syncthing, git, Settings Sync, ...). Works, but has an out-of-sync window, conflict edge cases, and failure modes when the sync protocol breaks.
2. **Share the underlying storage.** Exactly one copy, mounted in every location that reads or writes it. Drift is eliminated because there is no second place to drift from.

Option 2 is the correct answer when the multiple "locations" are really just multiple processes on the same machine — which is exactly our situation. Every access surface is a container on the same VM. The filesystem is already right there.

The only state the shared-storage approach doesn't handle is the distinction between code-server's `~/.local/share/code-server/User/` and desktop VS Code's `~/.config/Code/User/`, because the two editor engines genuinely use different paths. For that specific case we fall back to VS Code Settings Sync (GitHub-backed), which is the one place real sync-with-conflicts exists in the design. Every other aspect — dotfiles, tools, git, ssh, claude config, project files — is single-copy.

### Why a single tailnet hostname + portal (not one hostname per service)

An earlier iteration of this design used **one Tailscale sidecar per exposed service** (`ts-code`, `ts-files`, `ts-desktop`) so each service got its own MagicDNS name. That gave clean per-service ACLs and separate HTTPS certs managed by Tailscale, but it also meant:

1. **Three things to remember.** `devvm-code`, `devvm-files`, `devvm-desktop`, plus any agents on top. Easy to forget which host serves what.
2. **Three tailnet nodes per VM.** Burns auth keys, inflates the `tailscale status` list, and adds ACL entries.
3. **No single landing page** — the user has to know which URL has what.

Switching to a **single hostname with a reverse-proxy portal** fixes all three at the cost of a slightly more complex internal routing layer. The trade-off was worth it. The resulting design:

- `ts-devvm` is the **only** Tailscale container. It advertises exactly one MagicDNS name (`devvm.<tailnet>.ts.net`) and handles HTTPS termination via `TS_SERVE_CONFIG`, forwarding everything on port 443 to a local Caddy on port 8000.
- `portal` is a [Caddy 2](https://caddyserver.com/) container started with `network_mode: "service:ts-devvm"`, meaning it **literally shares the sidecar's Linux network namespace**. From Caddy's point of view, the tailnet interface is a local interface. Tailscale hands it HTTP, Caddy routes, and the response path is symmetric. No extra docker publish rules.
- Caddy reverse-proxies each service at a predictable subpath. Path-prefix support varies per backend, which shapes the Caddy config:
  - **code-server** honors `X-Forwarded-Prefix`, so `handle_path /code/*` + `header_up X-Forwarded-Prefix /code` gives correct asset URLs inside the browser VS Code.
  - **filebrowser** has first-class `--baseurl /files`, so the backend itself serves under the prefix. Caddy just passes the request through with `handle /files*` (no prefix strip).
  - **ttyd** (browser terminal for each agent) has the equivalent `-b /agents/N` flag. Same pass-through pattern.
  - **webtop / KasmVNC** does not (yet) support a base URL cleanly, so the portal uses `handle_path /desktop/*` with rewritten paths and `X-Forwarded-Prefix` so the WebRTC session's relative asset URLs resolve. If that turns out to be brittle in practice, the fallback is to serve webtop on a second Tailscale Serve port on the same hostname, e.g. `https://devvm.<tailnet>.ts.net:8443/`, which still satisfies the "one hostname" requirement in spirit because the hostname *is* the same.
- `/` is a small static landing page (`portal-index.html.j2`) rendered by Ansible. It shows buttons to each service that actually exists in the current config — webtop only appears if `webtop_enabled` is true, and there's one button per `claude_agents` entry.
- Every non-portal service keeps its **own** network namespace. This is the critical isolation property: agent containers run their own ipset default-deny firewall that only affects their own iptables rules, which means the portal, code-server, and filebrowser are never touched by an agent compromise. Caddy reaches each backend via Docker DNS on the default bridge network.

ACL-wise, the cost of collapsing three tagged hostnames into one is small: `tag:devvm` still applies, you still control who can reach the node at all, and inside the portal you can add per-path Caddy auth (basic/jwt/forward-auth) if you want tighter per-service control. In practice we don't — tailnet ACLs to the single hostname are already gated by MagicDNS.

### Claude Code's native installer (not npm)

Claude Code used to ship as an npm package (`@anthropic-ai/claude-code`), which made the SSH-shell install trivial (use mise-managed Node) but required the code-server and agent images to both install Node.js just to run it. The native installer (`curl -fsSL https://claude.ai/install.sh | bash`) ships a standalone Bun-compiled binary at `~/.local/bin/claude`, auto-updates in the background, and has no Node.js dependency. That drove three simplifications:

1. **`docker/code-server-image/` no longer installs anything.** The image exists only to `usermod` the upstream `coder` user so the container's `$HOME` path equals the host's `/home/me`. The integrated terminal then reads the host's `.bashrc`, the host's `claude` binary, and the host's mise-managed tools through the bind mount. Image build is ~3 seconds.
2. **`docker/agent-image/` dropped its `node:22-bookworm` base** and now builds on plain `ubuntu:24.04`, installing `claude` at build time by running the same native installer as the agent user.
3. **`registry.npmjs.org` removed from the agent firewall allowlist.** The agent no longer needs to reach npm at runtime.

The native installer *does* auto-update at runtime, which would conflict with the sandbox firewall for agents. That's fine here: the agent firewall blocks the update endpoint, so the baked version is the effective pinned version, and the weekly `ansible-pull` reconciles everything by rebuilding the image against whatever the installer ships when the timer fires.

### Container image update strategies

[containrrr/watchtower was archived on December 17, 2025](https://github.com/containrrr/watchtower). Anything written after that date needs to pick something else. Options surveyed:

| Tool | Model | Maintained (Apr 2026) | Fit for this design |
|---|---|---|---|
| **[nickfedor/watchtower](https://github.com/nickfedor/watchtower)** | Fork of the original, same in-container update model | Active fork | Works, but keeps the "container that auto-pulls and recreates" model that tripped people up (silent restarts in the middle of work). |
| **[What's Up Docker (WUD)](https://github.com/fmartinou/whats-up-docker)** | Dashboard + notifications + optional auto-trigger via labels | Active | Good dashboard ergonomics, supports "notify first, require approval" workflows. Overkill for a single VM that already has a playbook. |
| **[Diun](https://github.com/crazy-max/diun)** | Notify-only: polls registries and fires webhooks/Slack/email | Active | Cleanest "don't touch anything, just tell me" option. Complements a playbook-driven reconcile loop nicely. |
| **[Tugtainer](https://github.com/tugtainer/tugtainer)** (new, 2025) | Self-hosted auto-updater with health-check rollback | Active | Interesting: runs the update, verifies health, rolls back on failure. Too new to fully trust for this research. |
| **[dockcheck](https://github.com/mag37/dockcheck)** | Single bash script, runs from cron | Active | Nice for tiny homelabs; loses the "re-render compose from template" property we want. |
| **[Renovate](https://docs.renovatebot.com/)** on the config repo | Git-based: bumps pinned image tags in YAML via PRs, gated by CI | Active | **The closest fit to "automate updating the pinning of versions based on testing or user confirmation".** |
| **Ansible-pull on a timer** | Same code path as provisioning, rebuilds from template | N/A — it's just systemd | **Chosen as the primary path.** |
| **Packer on a schedule** | Rebake golden images periodically | N/A | Best for fleets, overkill for a single VM. |

The design uses a two-layer strategy:

1. **Primary (always on): the `ansible-pull` reconciler itself.** A systemd timer runs `devvm-bootstrap.sh` once a week. That re-renders the compose template, rebuilds the local images with `docker compose build --pull`, pulls upstream images, and `up -d --remove-orphans`. It's the same code path that provisioned the VM, so there's exactly one way the stack can end up in a new state. Out-of-band edits to `docker-compose.yml` on the host get overwritten.
2. **Primary (always on): `devvm-compose-update.timer`.** A second, cheaper timer runs just the `docker compose build --pull && pull && up -d` subset mid-week. This exists for the case where upstream images publish a new tag but the config repo hasn't changed — no need to re-run the full playbook in that case.
3. **Optional (opt-in): Renovate on the config git repo.** The cleanest "test before merge" story is to let Renovate bump the image-tag pins in `group_vars/all.yml` (e.g. `code_server_version`, `filebrowser_image`, `webtop_image`, `portal_image`) via PR. CI in the config repo can build the compose stack in a throwaway VM, run smoke tests, and require human approval. Merging the PR causes the next `ansible-pull` timer to apply the new pins. This is the gold-standard "automate updating the pinning of versions based on testing or user confirmations" workflow for anyone who wants it.
4. **Optional (opt-in): Diun for notifications.** Add `crazy-max/diun` to the compose stack and point its notifier at Slack/Discord/email. It never touches a container, it just pings you when `code-server:latest` gets a new digest. Useful if you prefer manual approval via "run `ansible-pull` now" rather than a weekly cron.

The "pin-driven + ansible reconcile + optional Renovate gating" approach wins on two key properties: (a) updates follow the same path as provisioning (no second system of record), and (b) when you want testing/approval in the loop, you get it *in git* where CI and PR review already live — exactly where you'd want it for a serious workstation. Watchtower's original model (pull-and-restart inside the container itself) had neither property.

### Ideas worth considering beyond the literal requirements

- **Git worktrees per Claude agent** for parallel work on one repo.
- **Cache volumes** for `~/.cache/{pip,uv,pnpm,cargo,go-build,pre-commit}` shared across agents.
- **Shell history sync** with Atuin across all dev VMs.
- **Separate `/home` volume** so rebuilds preserve user state.
- **Observability**: node_exporter + Grafana dashboard on tailnet, or just `btop`.
- **Backups**: restic to S3/B2 on a daily timer.
- **dozzle** for centralized container log viewing.
- **1Password CLI / sops+age** for secret hydration at boot, keeping cloud-init clean.
- **Packer golden images** published per target (AMI, qcow2, vmdk) so cold-boot drops from minutes to seconds.

## Files

```
automate-vm-dev-setup/
├── README.md                       # this report
├── notes.md                        # research notes / work log
├── bootstrap.sh                    # layer-1 shell script (invoked by cloud-init)
├── cloud-init/
│   └── user-data.yaml              # layer-0 portable cloud-init (Proxmox/EC2/Multipass)
├── ansible/
│   ├── site.yml                    # top-level playbook (tagged roles)
│   ├── group_vars/
│   │   └── all.yml                 # single source of truth: user, tools,
│   │                                  images, portal hostname, timers
│   └── roles/
│       ├── base/tasks/main.yml     # apt, unattended-upgrades, timezone
│       ├── user/tasks/main.yml     # user, sudoers, authorized_keys, dirs
│       ├── tailscale/tasks/main.yml # wraps artis3n.tailscale.machine with OAuth
│       ├── mise/tasks/main.yml     # mise install + iterate mise_global_tools
│       ├── dev_tools/tasks/main.yml # chezmoi apply, Claude Code native install
│       ├── containers/tasks/main.yml # render compose + portal templates, up -d
│       ├── containers/templates/
│       │   ├── docker-compose.yml.j2   # the compose stack (single ts-devvm,
│       │   │                              portal, code-server, filebrowser,
│       │   │                              webtop, agent pool)
│       │   ├── Caddyfile.j2            # portal reverse-proxy routes
│       │   ├── portal-index.html.j2    # portal landing page
│       │   └── ts-serve.json.j2        # Tailscale serve config → Caddy
│       └── updates/tasks/main.yml  # mise-upgrade, devvm-compose-update,
│                                     devvm-ansible-pull timers
└── docker/
    ├── agent-image/
    │   ├── Dockerfile              # sandboxed Claude Code agent base image
    │   │                              (ubuntu:24.04 + native claude installer,
    │   │                               uid 1000 agent user matches host)
    │   ├── entrypoint.sh           # runs init-firewall then execs command
    │   └── init-firewall.sh        # ipset default-deny with domain allowlist
    │                                   (npm registry removed - no longer needed)
    └── code-server-image/
        └── Dockerfile              # reshapes codercom/code-server so its
                                       $HOME matches the host. No Node/npm/
                                       mise/claude install - everything is
                                       read from the bind-mounted host home.
```

The webtop service is configured in `ansible/group_vars/all.yml` (`webtop_enabled`, `webtop_image`, `webtop_apt_packages`) and rendered into the compose stack by the `containers` role — it uses the upstream `lscr.io/linuxserver/webtop` image directly, so there is no custom `docker/webtop-image/` directory. The portal uses the upstream `caddy:2` image directly with a bind-mounted Caddyfile, so there is no custom `docker/portal-image/` directory either.

The artifacts are a concrete sketch, not a one-click repo — they illustrate the shape of the solution and the specific tool choices. To use them in practice, drop them into a private git repo, replace the placeholder SSH keys / OAuth client IDs / dotfiles URL, and point `bootstrap.sh` at the repo.

## Original Prompt

> I'd like to research automating the creation and setup of a virtual machine for development environments. It should be portable to any virtual machine platform. I want to create a vm and then kick off the automation to configure that VM. Optionally it could also handle spinning up the VM but that would be platform dependent and isn't mandatory. However the possible targets for running the VM would be on a local hypervisor on MacOS, proxmox, or AWS. Assume the VM has internet access.
>
> The vm should be configured to / with:
>
> - connect to my tailnet
> - create my Unix user, give it sudo privileges, and install a set of ssh public keys for that user to login with.
> - install my dotfiles for Unix shell configuration and apps
> - install and configure docker
> - install a web browser accessible via tailnet) version of vs studio code with my plugins and profiles configured (probably via docker?)
> - install Claude code
> - have a web based file management interface to easily access my users home directory for transferring files (probably via docker)
> - install my common development tools such as git, python, uv, pyenv, nvim, etc. these should be usable by my Unix user and through vscode. This list will grow and change over time so additions should be as easy as possible since this will probably change often.
> - give me a way to securely run Claude code with —dangerously-skip-permissions as an agent in multiples
> - automatically keep software up to date
> - make creating and provisioning a new dev environment instance as quickly as possible
> - Ubuntu Linux is an ok base but other options would be ok if they offer unique value
> - any other features specific to development environments that you think would be valuable or should be considered

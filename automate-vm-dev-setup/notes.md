# Research Notes: Automated VM Dev Environment Setup

Goal: design a portable automation for provisioning a dev VM on any hypervisor (macOS local, Proxmox, AWS). Assume the VM has internet and is already booted. Focus on configuration, not necessarily creation.

## Requirements recap

- Tailnet join (Tailscale)
- Create Unix user, sudo, authorized SSH keys
- Dotfiles install (shell + apps)
- Docker installed and configured
- Web-accessible VS Code via tailnet, with plugins/profiles (likely Docker)
- Claude Code installed
- Web file manager for home dir (likely Docker)
- Dev tools (git, python, uv, pyenv, nvim, ...) — easy to extend
- Multiple, sandboxed Claude Code agents with `--dangerously-skip-permissions`
- Auto-updates
- Fast provisioning
- Ubuntu base acceptable; suggest alternatives if they add value
- Extras / stretch features

## Initial shape of the solution

Two layers:

1. **Bootstrap (shell script)** - a single `curl | bash` (or `bash <(curl ...)`) command with secrets passed via environment variables (`TS_AUTHKEY`, `GH_USER`, etc.). Script installs Ansible and minimal prerequisites.
2. **Configuration (Ansible playbook)** - idempotent playbook that declares everything (users, tailscale, docker, containers, tools). Idempotent => re-run to reconcile drift.

Platform-independent because Ansible speaks SSH or local `ansible-pull`, requires only Python on target, runs on Ubuntu/Debian/Fedora/Arch/RHEL family, no cloud-specific hooks.

Optional layer 0: cloud-init `user-data` for platforms that support it (Proxmox, AWS EC2, multipass on macOS). All three support cloud-init, so a single user-data blob can handle layer-0 bootstrap, and layer-1 invokes the Ansible pull.

---

## Tool Research

### cloud-init
- Ubuntu cloud images (and most modern distros) ship with cloud-init.
- Supported by: Proxmox (Cloud-Init template feature), AWS EC2 (user-data), Multipass on macOS (cloud-init native), UTM (via ISO), OrbStack (has its own setup but cloud-init works for Linux machines).
- Standard NoCloud datasource = works with ISO-attached seed or local filesystem `/var/lib/cloud/seed/nocloud/`.
- User-data can: create users, install packages, write files, run commands (`runcmd`), pull down additional scripts.
- This is the portable "layer 0" - same YAML works on all three target platforms.

### Ansible vs alternatives
- **Ansible**: agentless (needs Python on target), YAML playbooks, huge ecosystem (roles for Tailscale, Docker, etc.), idempotent. `ansible-pull` mode runs from git on the target itself - zero infra.
- **Chef/Puppet**: require more infra.
- **Nix/NixOS**: declarative, reproducible, but learning curve and not Ubuntu; could be a powerful alt for stretch "reproducibility first" approach.
- **Shell script**: simplest, but loses idempotency and drift-reconciliation.
- **Chezmoi**: specifically for dotfiles; can be called from Ansible.

Decision: **Ansible with `ansible-pull` from a git repo**, bootstrapped by a small shell script that can itself be run by cloud-init or SSH.

### Tailscale bootstrap
- Use `tailscale up --authkey=$TS_AUTHKEY --hostname=$HOSTNAME --ssh`
- Auth keys: prefer **ephemeral, reusable, pre-authorized, tagged** keys so new VMs auto-join tagged ACL group.
- `--ssh` gives you Tailscale SSH (MagicDNS + ACL-controlled), no need to manage ~/.ssh/authorized_keys for tailnet access.
- Tag-based ACLs: `tag:devvm` can be defined in tailnet policy to allow e.g. browser access to ports 3000/8443, ssh from your primary device, etc.
- Can use `tailscale funnel` to expose something publicly, but we want tailnet-only access here.
- `tailscale serve` useful to put code-server behind HTTPS on tailnet without extra certs.

### Web VS Code
Three candidates:

1. **code-server (Coder)** - most popular, OSS, runs VS Code OSS with browser UI. Supports extensions via Open VSX or side-loading. Runs as Docker container `codercom/code-server`. Config via `~/.config/code-server/config.yaml`.
2. **openvscode-server (Gitpod)** - closer to upstream VS Code. OSS. Single-user, simpler.
3. **Microsoft devtunnels / VS Code Remote Tunnel** (`code tunnel`) - officially supported by Microsoft, uses Microsoft account; can tunnel into Azure, and lets you use full VS Code web (vscode.dev). Not fully local though - relies on Microsoft tunnels service.

For a fully self-hosted tailnet-only experience: **code-server**, since it supports Marketplace/Open VSX extensions list and user profile sync more naturally.

Binding it to tailnet:
- Run code-server in Docker
- Expose via `tailscale serve` → routes `https://vm.tailnet-name.ts.net` to local `:8080`
- Or use `caddy` + tailscale sidecar container
- OR bind 0.0.0.0 but firewall so only tailnet interface reachable (via `ufw allow in on tailscale0`)

Extensions:
- code-server ships with Open VSX by default; most popular extensions are there.
- `code-server --install-extension ms-python.python` at startup.
- Profile import: VS Code Settings Sync uses GitHub, works in code-server too.

### Claude Code
- `npm install -g @anthropic-ai/claude-code` (requires node).
- Config lives in `~/.claude/` and `~/.config/claude-code/`.
- Can be installed once, used by all users or per-user.
- `claude` CLI works inside terminal and VS Code integrated terminal.

### Web file manager (home dir)
Options:
- **filebrowser** (`filebrowser/filebrowser`) - single-binary Go app, Docker image, authenticated web UI, upload/download/rename/share. Simple.
- **Cloud Commander** (`cloudcmd`) - two-pane file manager, editor, terminal.
- **Syncthing** - not really a file manager, but pairs well for sync.
- **Tailscale Taildrop** - not browser-based but simplest for ad-hoc transfer from your phone/desktop.

Pick **filebrowser** in Docker, mounted at `/srv` → `/home/user`, served via tailscale serve on its own sub-path or port.

### Multi-instance sandboxed Claude Code agents
Three approaches:

1. **Docker containers per agent**. Each agent is a container running a shell with claude code installed, mount a scratch workspace read-write, mount secrets read-only. `--dangerously-skip-permissions` is far less scary inside a throw-away container.
2. **Firecracker / Kata microVMs** - stronger isolation but more plumbing.
3. **Systemd-nspawn** - OS-native lightweight container.
4. **tmux panes under bubblewrap** - per-process sandbox on the same host.

Docker is the simplest, most portable (given we're already installing docker). Base image: `ubuntu` + node + claude-code + common tools. Use docker compose to spin up N replicas each with its own workspace volume.

Bonus: add a tiny web dashboard that lists running agent containers, shows logs, attach via `ttyd` / `gotty`. Or use `dozzle` for logs + `portainer` for control.

Additional pattern: **`claude-code` inside a docker container with no mounted secrets**, and give it a scoped API token so compromise has limited blast radius. Use pass-through of `ANTHROPIC_API_KEY` via env from a root-only secret file.

### Dev tools, easily extendable
Two complementary patterns:

1. **mise (ex-rtx)** - modern polyglot version manager (python, node, rust, go, uv, etc). Single config `~/.config/mise/config.toml` or `.mise.toml` in repo. Installs tools on demand, pins versions. Replaces pyenv, nvm, asdf. Fast (Rust).
2. **Ansible variable list** - a `dev_tools:` list in the playbook vars file. Adding a tool == adding a line to a YAML list + rerun pull.

Use mise as the actual installer, Ansible to ensure mise is installed and to declare which global tools to install.

### Auto-updates
- **unattended-upgrades** for Ubuntu security updates.
- **Watchtower** for Docker containers (pulls new image tags automatically).
- **mise self-update / mise upgrade** on a systemd timer.
- **`apt-get update && apt-get upgrade` weekly timer** via systemd.

### Fast provisioning
- Bake a **golden image** with Packer. Same Ansible playbook feeds Packer for Proxmox/AWS/macOS multipass.
- If not baking: pre-fetch the Docker images inside the playbook using `docker pull` so the first run is slow but subsequent boots are fast. But a cold new VM would still pay the docker pull cost.
- Packer builds once, publishes AMI for AWS, qcow2 for Proxmox, vmdk or raw for macOS hypervisors, reducing first-boot to just "join tailnet + personalize".

### Base OS options
- **Ubuntu 24.04 LTS**: broad support, cloud-init first-class, most tutorials.
- **Debian 12**: leaner, more stable, same cloud-init support.
- **Fedora Cloud / CoreOS**: newer packages, CoreOS is immutable — excellent pairing with container-first design.
- **NixOS**: declarative to the bone. Whole VM described in one config. Biggest lift but arguably the purest answer to "identical dev environments every time."

Recommend Ubuntu 24.04 LTS for simplicity, with a note that NixOS is the ideological upgrade path.

---

## Extras worth considering

- **Workspace persistence**: mount `/home/user` on a separate disk/volume so rebuilds don't lose state.
- **Secrets handling**: 1Password CLI, `sops` + age, or Bitwarden CLI to hydrate env vars/config.
- **Shared cache volumes**: pip/npm/cargo/go mod caches as Docker volumes to speed repeated container builds.
- **GitHub SSH + GPG key preloading** (from chezmoi or Ansible vault).
- **Observability**: `node_exporter` + tailnet-accessible Grafana; or just `btop` CLI.
- **Backups**: `restic` to S3/B2, daily systemd timer.
- **Git worktrees for parallel Claude agents**: each agent gets its own worktree so they can work on the same repo simultaneously without conflict.
- **devcontainers**: support `.devcontainer` directories in repos so VS Code remote opens into a per-project container.
- **Ngrok/Cloudflare tunnel fallback** if tailnet access is temporarily unavailable.
- **Shell history sync** across VMs via Atuin (self-hosted or free tier).
- **Claude Code "orchestrator" script** that spawns N containers, hands each a branch/task file, and aggregates results.

## Next steps

1. Draft cloud-init YAML for layer 0.
2. Draft shell bootstrap script for layer 1 (installs ansible + ansible-pulls).
3. Sketch Ansible playbook structure: roles for users, tailscale, docker, code-server, filebrowser, dev-tools, claude-agents, updates.
4. Describe Packer wrapper option for golden image.
5. Produce README with architecture diagram and implementation notes.

---

## Findings from web verification (April 2026)

### Tailscale / Ansible
- **`artis3n.tailscale.machine`** is the canonical Ansible Galaxy role for installing and joining Tailscale. It supports OAuth-client auth (with `tailscale_tags`, `tailscale_oauth_ephemeral`, `tailscale_oauth_preauthorized`), which is preferable to plain auth keys because OAuth secrets don't expire (plain auth keys max out at 90 days).
- Tag-based ACLs + ephemeral nodes are the best fit for throwaway dev VMs.

### Claude Code sandboxing
- **Anthropic ships a reference devcontainer in the `anthropics/claude-code` repo at `.devcontainer/`**, specifically designed to let you run `claude --dangerously-skip-permissions` safely.
- The devcontainer uses an `init-firewall.sh` that installs ipset-based allowlisting: only `registry.npmjs.org`, `api.anthropic.com`, GitHub, `statsig.com`, etc. are reachable from inside the container; everything else is default-deny.
- Nicholas Carlini (Anthropic Safeguards) publicly runs 16 parallel Claude Code instances in a while-loop inside containers. The official guidance is "never on bare metal".
- This is exactly the pattern to reuse for the multi-agent use case.
- Best practice: base my agent container image on Anthropic's reference Dockerfile (or copy its init-firewall.sh verbatim), so each agent gets the same network containment.

### mise vs asdf
- **mise-en-place** is the modern successor: 20-200x faster than asdf, written in Rust, drop-in replacement for `.tool-versions`, and also manages env vars and project tasks. No shims, so `which python` returns the real binary.
- It is the right tool to manage python/uv/pyenv/node/rust/go/etc. for the Unix user AND for the VS Code integrated terminal.
- Installing a new tool globally = `mise use -g python@3.13 node@22 uv rust go`. Adding one to the Ansible config is a one-line YAML change.

### code-server vs openvscode-server
- **code-server** (Coder) is preferred. OpenVSCode Server cannot pre-install extensions in non-interactive mode (e.g. during `docker build`), while code-server supports `code-server --install-extension ...` at build/start time and allows pointing `$EXTENSIONS_GALLERY` at a private marketplace.
- Both use Open VSX (the open fork of the VS Marketplace). Most mainstream extensions are mirrored there. The Python, Pylance-equivalent, Copilot, and Microsoft-proprietary ones are not — that's the trade-off of self-hosting.
- `coder/code-marketplace` is an OSS gallery if a fully self-hosted marketplace is desired.

### filebrowser in Docker
- `filebrowser/filebrowser` image, bind-mount `/srv -> /home/$USER`, runs as UID 1000:1000 by default (matches the user we create), exposes :80 inside the container. Put it behind tailscale serve for HTTPS.

### cloud-init portability
- cloud-init 26.x is current. All three target platforms (Proxmox Cloud-Init templates, AWS EC2 user-data, macOS Multipass via `--cloud-init`) consume the same YAML. The portable approach is confirmed.
- Minimal layer-0 user-data: set hostname, create user with SSH keys, install a handful of packages, run the bootstrap script. Everything else is punted to Ansible.

### ansible-pull pattern
- Widely endorsed. Run `ansible-pull -U <repo> -e "@vars.yaml"` on the target, using a small local vars file for secrets. No Ansible controller infra required — ideal for ephemeral VMs.
- Install Ansible via `pipx` (2026 recommended method).

### Tailscale serve + Docker
- `tailscale/tailscale` Docker image supports `TS_SERVE_CONFIG` / `TS_SIMPLE_SERVE_CONFIG` env vars to front arbitrary localhost ports with HTTPS via MagicDNS. No cert management.
- Pattern: one tailscale sidecar container per exposed service, each with its own auth-key and hostname (e.g. `devvm-code`, `devvm-files`). Or a single "gateway" container that funnels multiple subpaths.

## Design implications

- **Layer 0** = cloud-init user-data (portable across Proxmox/EC2/Multipass)
- **Layer 1** = ansible-pull from a private git repo, with a local `vars.yml` containing non-secret config
- **Secrets** = injected via environment variables at `ansible-pull` time (Tailscale OAuth, API keys)
- **Layer 2** = Docker compose stack for code-server, filebrowser, claude-agents, watchtower
- **Extensibility** = mise config + Ansible YAML list of tools

## Architecture sketch

```
   new VM (any hypervisor)
        │
        │  cloud-init user-data
        │  - set hostname, user, authorized_keys
        │  - install: curl, git, ca-certificates
        │  - runcmd: curl .../bootstrap.sh | bash
        ▼
   bootstrap.sh
        │
        │  - install ansible via pipx
        │  - clone config repo
        │  - ansible-pull -U <repo> site.yml
        ▼
   Ansible playbook (roles)
        ├─ base          apt update, unattended-upgrades, timezone
        ├─ user          create user, groups, sudoers, authorized_keys
        ├─ dotfiles      chezmoi init --apply github.com/me/dotfiles
        ├─ tailscale     artis3n.tailscale.machine with tag:devvm, ephemeral
        ├─ docker        geerlingguy.docker + compose v2
        ├─ mise          install mise, bootstrap global tools
        ├─ dev-tools     git config, neovim config, claude-code (npm -g)
        ├─ containers    render docker-compose.yml and `docker compose up -d`
        │                (code-server, filebrowser, watchtower, claude-agent-pool)
        └─ updates       unattended-upgrades + watchtower + mise upgrade timer
```


---

## Work log: drafted artifacts

Final artifacts in this folder:

- `cloud-init/user-data.yaml` - portable layer-0 bootstrap (works on Proxmox, EC2, Multipass)
- `bootstrap.sh` - layer-1 shell script: installs ansible via pipx, runs ansible-pull
- `ansible/site.yml` - top-level playbook (tags per role)
- `ansible/group_vars/all.yml` - single source of truth: user, tools list, images, secrets placeholders
- `ansible/roles/base/` - apt baseline, unattended-upgrades
- `ansible/roles/user/` - primary user creation, sudoers, authorized_keys
- `ansible/roles/tailscale/` - wraps artis3n.tailscale.machine with OAuth + tag:devvm
- `ansible/roles/mise/` - installs mise and iterates `mise_global_tools`
- `ansible/roles/dev_tools/` - chezmoi apply, claude-code npm global
- `ansible/roles/containers/` - renders docker-compose, brings up stack
- `ansible/roles/containers/templates/docker-compose.yml.j2` - the service stack
- `ansible/roles/updates/` - mise weekly upgrade timer
- `docker/agent-image/` - Dockerfile + init-firewall.sh for the sandboxed Claude agent pool

## Open questions / things left as exercises

1. **Secret delivery on first boot.** cloud-init user-data is not a secure place for long-lived secrets. Options:
   - EC2: use EC2 Instance Metadata Service + IAM role to fetch from Secrets Manager in bootstrap.sh
   - Proxmox: pre-bake secrets into a cloud-init snippet on the host, deleted after first boot
   - Multipass on macOS: user-data is local so passing TS OAuth secret directly is usually acceptable
   - Universal: use a short-lived provisioning token that grants `sops` / `age` access to a small vault, then destroy it.

2. **Golden image vs cold install.** For fastest provisioning, wrap the Ansible playbook in Packer:
   - `packer build` once, publishing AMI + qcow2 + vmdk
   - On cold boot the only steps are: tailscale auth, user personalization, and `mise install`
   - Expected cold-boot-to-ready time: < 60 seconds instead of 5-10 minutes

3. **Claude agent orchestration UI.** Not covered in this sketch. Options:
   - `dozzle` container for aggregated agent logs
   - Tiny FastAPI dashboard listing containers, their last N lines of output, and buttons to restart / add new agent / assign a git worktree + task
   - Nice-to-have: each agent writes a JSON "status" file into its workspace that the dashboard polls.

4. **Dotfile secrets.** chezmoi supports `encrypted_` files via gpg or age. Out of scope here but worth wiring up.

5. **Shell history sync.** Atuin (self-hosted or free tier) would let all the VMs share shell history. One-liner to add to mise_global_tools + a role tweak.

6. **Disk layout.** For production use, separate `/home` on its own virtual disk so rebuilds preserve state. For Proxmox: attach a second qcow2. For EC2: second EBS volume mounted at `/home`. For Multipass: `--disk` on a separate mount.

7. **Project-level devcontainers.** VS Code's remote dev containers still work inside the VM; recommend preserving `.devcontainer` support for per-project isolation on top of the VM-level environment.


---

## Follow-up: Claude Code in all three surfaces + shared working dir

User asked for `claude` to be reachable from:

1. Normal SSH shell
2. Inside VS Code
3. Optionally inside a constrained environment

...and for all three environments to share a common working directory.

### Surface analysis

| Surface | How it reaches `claude` today | Gap |
|---|---|---|
| SSH shell | `dev_tools` role does `npm install -g @anthropic-ai/claude-code` on the host via mise-managed Node | none |
| VS Code integrated terminal | code-server runs in a container that does NOT have Node or claude-code installed | needed a custom image |
| Sandboxed agent | agent image already installs claude-code | needed to also mount the shared work dir |

### Design decisions

- **Custom code-server image** (`docker/code-server-image/Dockerfile`) extending `codercom/code-server:latest` with:
  - `nodejs` from NodeSource (matches host mise Node version closely)
  - `npm i -g @anthropic-ai/claude-code`
  - `mise` installed so `python`, `uv`, `node`, etc. are on PATH inside the integrated terminal, giving it the same tool chain as the SSH shell without duplicating mise state.
  - Activated in `/home/coder/.bashrc` so new integrated terminals pick it up automatically.

- **Why not install-on-startup?** Would slow every restart and isn't idempotent-friendly across upgrades. Baking it into an image is deterministic and fast.

- **Image updates:** Watchtower pulls base image updates, but a locally-built image won't be replaced by watchtower alone. The weekly `ansible-pull` is expected to rebuild these local images. For extra safety, could add a systemd timer that runs `docker compose build --pull` weekly — noted in open questions.

### Shared working directory choice: `/home/me/work`

Simplest path that satisfies every constraint:

- Under `$HOME`, so it is automatically visible:
  - Over SSH (it's just a directory)
  - In code-server (already bind-mounts `/home/me:/home/me`)
  - In filebrowser (already bind-mounts `/home/me:/srv`)
- Bind-mounted at the SAME absolute path into each agent container so paths are invariant across environments — you can write `/home/me/work/foo.py` and it's the same file whether you write it from SSH, from the VS Code explorer, or from inside an agent.
- Created by the `user` Ansible role so it's owned by the devvm user with mode 0755.

### Agent container permission fix

Agents originally used `uid 1100 agent`. With the new shared bind-mount that's owned by host uid 1000, the agent could not write to it. Changed the agent Dockerfile to create the `agent` user at uid 1000 (and remove the base `node` user that owned that uid). Now host/container UIDs align and no chown dance is needed.

### What changed

Files added:
- `docker/code-server-image/Dockerfile`

Files modified:
- `ansible/group_vars/all.yml` — added `shared_workdir`, renamed `code_server_image` to `code_server_version`
- `ansible/roles/user/tasks/main.yml` — creates `{{ shared_workdir }}`
- `ansible/roles/containers/templates/docker-compose.yml.j2`:
  - code-server now built from `../code-server-image` (tagged `devvm/code-server:local`)
  - code-server bind-mounts the shared workdir and opens into it
  - each Claude agent bind-mounts the shared workdir at the same absolute path
  - agent working_dir changed to the shared workdir; ttyd command cds into it before starting claude
- `docker/agent-image/Dockerfile` — agent user uid changed to 1000 to match host for bind-mount permissions

### Open follow-ups

- Consider adding a systemd timer that runs `ansible-pull` weekly — this would re-pull the repo, rebuild local images, and restart the stack without manual intervention. Right now only `mise-upgrade.timer` runs; everything else assumes a person re-runs ansible-pull periodically.
- Consider running claude-code itself from a single source of truth (e.g. a global `/opt/claude/bin` directory shared across all contexts via bind-mount) to avoid three separate installs. The three-install approach is simpler and was chosen for this iteration.
- Sharing the Claude Code session/auth state (`~/.claude/`) between the SSH shell and the VS Code integrated terminal is automatic because both see `/home/me`. Agent containers are deliberately kept separate — each agent maintains its own auth state inside its isolated workspace.

---

## Follow-up: optional remote-desktop surface with guaranteed sync

Requirement: add a desktop environment accessible only remotely through an RDP-like protocol and also via a web interface, integrated with the existing environments so that "no matter how I'm accessing these tools, I have the same setup of programs, files and tools that are all in sync. It should not be possible for them to get out of sync."

### Option survey

| Option | Category | Pros | Cons |
|---|---|---|---|
| **linuxserver/webtop** (Ubuntu × XFCE) | Single container desktop | One image, KasmVNC+Selkies streaming (rebased June 2025), PUID/PGID for bind-mounted home, fits existing "container + tailscale sidecar" pattern, low latency WebRTC, audio, clipboard, fully HTML5 | Image is opinionated; desktop app set needs to be declared via linuxserver `DOCKER_MODS` |
| Kasm Workspaces | Multi-user platform | Enterprise features, per-user disposable sessions, web-based management UI | Way too much machinery for single-user dev VM |
| Apache Guacamole | Web gateway to RDP/VNC/SSH | Great if you already have machines to proxy | Wrong shape — does not host the desktop, only proxies. Requires a secondary desktop somewhere. |
| Selkies (direct) | WebRTC streaming library | Fastest possible, hardware-accelerated | More plumbing; webtop already wraps this |
| noVNC + TigerVNC | Classic | Simplest, widest compat | Higher latency than Selkies; less polished UX |
| xrdp | Native RDP | Works with Microsoft RDP clients and Remmina | Needs a full desktop session in the container to be useful; duplicates webtop's job |
| Sunshine/Moonlight | Game-streaming | Very low latency | Optimized for gaming, not desktop productivity; no browser client by default |
| RustDesk | TeamViewer clone, self-hostable | Simple | Standalone product, doesn't integrate with compose stack as cleanly |

**Pick:** `linuxserver/webtop:ubuntu-xfce`. Same reasoning as code-server: Docker-first, browser-first, integrates into the tailscale sidecar pattern we're already using. Selkies under the hood gives near-native latency.

### Anti-drift design: "share storage, don't sync it"

There are two classes of solution to "all surfaces must be in sync":

1. **Replicate + sync protocol** (rsync / Syncthing / git / VS Code Settings Sync across separate homes). Has an out-of-sync window and failure modes.
2. **Single filesystem, multiple mounts.** All access surfaces on the same VM; `$HOME` is the same inode everywhere. No drift possible because there is no second copy.

Approach 2 is strictly better here because the surfaces are all processes on the same machine. It works like this:

- The host user `me` lives in `/home/me` on the VM filesystem.
- code-server container: bind-mount `/home/me:/home/me`, run as uid 1000.
- webtop container: bind-mount `/home/me:/config`, set `PUID=1000 PGID=1000`. Linuxserver's abc user effectively IS the host's me user.
- Each agent container: bind-mount `/home/me/work` at the same absolute path, run as uid 1000.
- Dotfiles (chezmoi), mise tools, git config, ssh keys, Claude config all live under `$HOME` → single copy visible to every surface.

The only state that *genuinely* differs between code-server and VS Code Desktop (running inside webtop) is:
- `~/.local/share/code-server/User/settings.json` (code-server)
- `~/.config/Code/User/settings.json` (desktop)

because the two engines use different storage paths. For that one case we use VS Code Settings Sync backed by GitHub — this is the only piece of "sync-with-protocol" in the design, and it's scoped to editor preferences, not to files, tools, or source state.

### Mechanical reconciliation

Even with single-copy state, a human can edit a config file on one surface and change it. To ensure the *declared* configuration is still authoritative:

- `updates` role runs `ansible-pull` on a weekly timer (TODO: add this if not already present).
- Watchtower updates container images nightly.
- `mise-upgrade.timer` upgrades mise tools weekly.
- `unattended-upgrades` applies security patches daily.

Re-running `ansible-pull` will:
- Rebuild the custom code-server image if the Dockerfile changed
- Re-render the docker-compose.yml and recreate containers with up-to-date image references
- Re-apply chezmoi dotfiles
- Re-install any new tools listed in `mise_global_tools`
- Re-install the `code_server_extensions` list

Net effect: out-of-band changes get overwritten back to the declared state on the next timer fire.

### Artifacts changed

- `ansible/group_vars/all.yml` — added `webtop_enabled`, `webtop_image`, `webtop_timezone`, `webtop_apt_packages`
- `ansible/roles/containers/templates/docker-compose.yml.j2` — added `webtop` service and `ts-desktop` tailscale sidecar (guarded by `webtop_enabled`). The webtop container:
  - Runs as `PUID=1000 PGID=1000`
  - Bind-mounts `/home/{{ devvm_user }}:/config` (home-dir sharing)
  - Bind-mounts `{{ shared_workdir }}` at the same absolute path
  - Bind-mounts the host docker socket
  - Uses the linuxserver `universal-package-install` DOCKER_MOD to layer in a declared list of desktop apt packages at first boot
  - `shm_size: 2gb` for Chromium/Firefox
- `README.md` — new sections:
  - Desktop added to the "Claude Code surfaces" table
  - "Why the surfaces cannot drift out of sync" with the specific mechanisms
  - "Why linuxserver/webtop for the optional desktop" comparing alternatives
  - Architecture diagram shows the desktop container and the "single $HOME" principle
  - Files section updated

### Decisions left to the user

- **Desktop flavor**: XFCE is lightweight and the default; KDE is prettier but needs more RAM. Changed via `webtop_image`.
- **Native RDP access**: Not enabled by default. If wanted, install `xrdp` in a custom webtop-derived image and expose port 3389 via Tailscale serve. Recommended only if browser access isn't sufficient for some reason (e.g. Microsoft Remote Desktop mobile app ergonomics).
- **GPU acceleration**: If the underlying VM has a GPU passed through, set `DRINODE` and add `/dev/dri/renderD128`. Selkies will use NVENC/VAAPI for encoding.


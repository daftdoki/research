# Portable Automated Dev VM Setup

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

How can I automate the configuration of a development VM in a hypervisor-agnostic way, so that the same automation produces an identical, ready-to-use workstation whether the VM is running on a macOS laptop, a Proxmox cluster, or AWS EC2? The setup must join my tailnet, create my user with SSH keys, install my dotfiles and dev tools, run browser-accessible VS Code, expose a web file manager, install Claude Code, allow running multiple sandboxed `claude --dangerously-skip-permissions` agents in parallel, auto-update itself, and be quick to (re)provision. ([original prompt](#original-prompt))

## Answer / Summary

**Build the automation as three thin layers, each portable across every target hypervisor.** The single platform-independent thread that stitches them together is **cloud-init** for layer 0, **`ansible-pull`** for layer 1, and a **Docker Compose stack** for layer 2. Together they let a fresh Ubuntu 24.04 LTS cloud image become a fully configured dev environment with one SSH command (or automatically via cloud-init user-data).

| Layer | Technology | What it does |
|------|-----------|--------------|
| 0. Boot | cloud-init user-data YAML | Sets hostname, creates user, installs authorized SSH keys, installs minimal deps, fetches the bootstrap script. Works unchanged on Proxmox Cloud-Init templates, AWS EC2 user-data, and macOS Multipass. |
| 1. Configure | `bootstrap.sh` + `ansible-pull` from a git repo | Installs Ansible via pipx, then runs an idempotent playbook that configures the tailnet, Docker, **mise**-managed dev tools, dotfiles, Claude Code, and the container stack. Re-run any time to reconcile drift. |
| 2. Run | `docker compose` stack | Long-running services: **code-server** (browser VS Code), **filebrowser** (home-dir file manager), the **Claude agent pool** (one sandboxed container per parallel agent, modeled on Anthropic's reference devcontainer with ipset default-deny firewall), and **watchtower** for self-updating images. Each public service is fronted by a **Tailscale sidecar container** using `TS_SERVE_CONFIG` so it is reachable via MagicDNS with HTTPS and no cert management. |

**Key decisions that make this work:**

- **Ubuntu 24.04 LTS** as the base image — broad cloud-init support everywhere.
- **`mise-en-place`** instead of asdf/pyenv/nvm — one Rust-based tool handles python/uv/node/rust/go/neovim/cli tools, 20-200x faster than asdf, and adding a tool is a one-line YAML change in `group_vars/all.yml` followed by a re-run.
- **`ansible-pull`** instead of a central Ansible controller — zero infra, the VM pulls its own config from git.
- **`artis3n.tailscale.machine`** Ansible role with **OAuth client** auth and **`tag:devvm`** so secrets don't expire and ACLs are tag-driven.
- **code-server** rather than openvscode-server — it can pre-install extensions non-interactively and can point `$EXTENSIONS_GALLERY` at a private marketplace.
- **Claude agent containers built on Anthropic's reference devcontainer pattern** (see [anthropics/claude-code/.devcontainer](https://github.com/anthropics/claude-code/tree/main/.devcontainer)) — each agent runs with a default-deny outbound firewall allowing only `api.anthropic.com`, `registry.npmjs.org`, `github.com`, and a small allowlist, which is exactly what makes `--dangerously-skip-permissions` safe to run unattended.
- **Packer** wraps the same Ansible playbook to produce a **golden image** per target, shrinking cold-boot-to-ready time from minutes to seconds — the same playbook that provisions a fresh VM also bakes the AMI/qcow2/vmdk, so there is only one source of truth.

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
             ├─ base         apt update, unattended-upgrades, timezone
             ├─ user         user, sudoers NOPASSWD, authorized_keys, dirs
             ├─ dotfiles     chezmoi init --apply github.com/me/dotfiles
             ├─ tailscale    artis3n OAuth + tag:devvm + ephemeral + --ssh
             ├─ docker       docker-ce + compose v2
             ├─ mise         install mise, iterate mise_global_tools
             ├─ dev_tools    chezmoi binary, claude-code via mise-managed npm
             ├─ containers   render docker-compose.yml from template, up -d
             └─ updates      mise-upgrade.timer (weekly), watchtower schedule
             │
             ▼
   docker compose stack running on the VM
             ├─ code-server           browser VS Code, extensions pre-installed
             ├─ ts-code  (sidecar)    exposes code-server as https://devvm-code.<tailnet>.ts.net
             ├─ filebrowser           home-dir web UI
             ├─ ts-files (sidecar)    exposes filebrowser as https://devvm-files.<tailnet>.ts.net
             ├─ agent-0..agent-N      one sandboxed Claude Code container each
             │                          - ipset default-deny firewall
             │                          - only /workspace is writable from host
             │                          - `claude --dangerously-skip-permissions`
             │                            wrapped in ttyd for a browser terminal
             └─ watchtower            nightly pull+recreate of every image
```

## Results — Feature → Mechanism mapping

| Requirement | Mechanism |
|---|---|
| Connect to tailnet | `artis3n.tailscale.machine` role, OAuth client auth, `tag:devvm`, ephemeral + preauthorized, `--ssh` |
| Create user, sudo, SSH keys | `user` Ansible role, `devvm_user_ssh_keys` in group_vars |
| Dotfiles | chezmoi installed by `dev_tools` role, `chezmoi init --apply` of your dotfiles repo |
| Docker + compose | `docker` role (e.g. `geerlingguy.docker`) + `community.docker.docker_compose_v2` |
| Browser VS Code w/ extensions | `code-server` container, `--install-extension` per item in `code_server_extensions` list |
| VS Code via tailnet | `ts-code` sidecar container running `tailscale/tailscale` with `TS_SERVE_CONFIG`, fronted by MagicDNS HTTPS |
| Claude Code | npm global install inside `dev_tools` role, plus per-agent install in the agent Dockerfile |
| Web file manager | `filebrowser/filebrowser` container, `/home/$USER` bind mount, `ts-files` sidecar |
| Common dev tools (git, python, uv, pyenv replacement, nvim, ...) | mise manages everything via `mise_global_tools` list in group_vars; apt handles the few it can't |
| Adding a new tool is one line | YAML edit to `mise_global_tools` (or `apt_dev_packages` for system pkgs), re-run `ansible-pull` |
| Sandboxed multi-agent Claude Code with `--dangerously-skip-permissions` | Agent pool in compose, container image built from Anthropic's reference devcontainer with `init-firewall.sh` default-deny + domain allowlist, one container per agent, each with its own `/workspace` volume |
| Auto-updates | unattended-upgrades (apt), watchtower (containers), mise-upgrade.timer (dev tools), systemd Automatic-Reboot at 04:30 |
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

### Why Tailscale sidecars per exposed service

You *could* install Tailscale on the host and have it serve code-server/filebrowser from the host network namespace. The sidecar pattern is cleaner because:

- Each service gets its own MagicDNS name (`devvm-code.<tailnet>.ts.net`, `devvm-files.<tailnet>.ts.net`), so Tailscale ACLs can apply separately per service.
- HTTPS is handled by Tailscale, no Caddy or certs.
- Tearing down a service removes its tailnet presence without touching anything else.
- Scoped auth keys: a sidecar gets exactly one key, tagged, ephemeral.

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
│   │   └── all.yml                 # single source of truth: user, tools, images, secrets placeholders
│   └── roles/
│       ├── base/tasks/main.yml     # apt, unattended-upgrades, timezone
│       ├── user/tasks/main.yml     # user, sudoers, authorized_keys, dirs
│       ├── tailscale/tasks/main.yml # wraps artis3n.tailscale.machine with OAuth
│       ├── mise/tasks/main.yml     # mise install + iterate mise_global_tools
│       ├── dev_tools/tasks/main.yml # chezmoi apply, claude-code npm global
│       ├── containers/tasks/main.yml # render compose template and up -d
│       ├── containers/templates/docker-compose.yml.j2 # the compose stack
│       └── updates/tasks/main.yml  # mise-upgrade.timer
└── docker/
    └── agent-image/
        ├── Dockerfile              # sandboxed Claude Code agent base image
        ├── entrypoint.sh           # runs init-firewall then execs command
        └── init-firewall.sh        # ipset default-deny with domain allowlist
```

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

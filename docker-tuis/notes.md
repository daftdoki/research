# Docker TUIs: notes

## Goal

Survey terminal user interfaces for managing a Docker engine: what exists, which are still maintained, what each does well, and which one to reach for.

## Scope decision

The prompt is two words, so scope is my call. In: TUIs that manage a running Docker (or Docker-compatible) engine from the terminal. Out: web UIs (Portainer, Dockge), Kubernetes-only tools (k9s), and single-purpose inspectors (dive looks at image layers only). Adjacent tools get a mention, not a full row.

## Constraints

Nothing gets installed or run on this machine. Every claim comes from a README, docs page, release page, or source file I read. GitHub API for stars, last push, license, latest release.

## Work log

- Searched GitHub (`topic:docker topic:tui`, `docker tui in:name,description`, `docker terminal ui`). The topic search is noisy: dive, witr, process-compose and a BitTorrent client outrank most real Docker TUIs, and the biggest names (lazydocker, ctop, dry, dockly) do not carry the `tui` topic at all, so I fetched those by name. The `docker terminal ui` search returned mostly political spam repos, so I dropped that query.
- Checked whether Docker ships its own TUI. docker/cli has one open proposal from 2019 ("Proposal: Add TUI interface to operate resources more easily") and nothing else. No official TUI exists.
- Cross-checked the candidate list against the Terminal section of veggiemonk/awesome-docker. Nothing established was missing; it did surface a long tail of 2026 one-person projects (bosun, wharf, dprs, DockTUI, easydocker) that I list but do not review.
- Found dtop by reading ctop issue #366, where the Dozzle author announces it as a ctop replacement. It was not in any of my searches because its description does not say "TUI".
- Pulled repo metadata (stars, pushed_at, license, open issues, archived) and latest release for every candidate through the GitHub API. Saved raw JSON in scratchpad only, not in the folder.
- Pulled Homebrew formula API for each name. Install counts over 365 days are the closest thing to real usage numbers I could find: lazydocker 44k, podman-tui 7.2k, ctop 4.4k, dtop 1.7k, lazyjournal 1.6k, oxker 1.3k, ducker 960, dry 525, dockly 332. d4s, dcv, DockMate, tdocker, gomanagedocker, sen are not in core.
- Read READMEs for lazydocker, ctop, dry, dockly, oxker, sen, ducker, gomanagedocker, podman-tui, dcv, DockMate, d4s, tdocker, dtop. podman-tui's raw README URL 404ed on both main branches, so I used the API `/readme` endpoint instead.

### Things that turned out to matter

- Docker Engine 29 (Nov 2025) raised the minimum API version to 1.44 and broke lazydocker (issues #715, #704; fixed by PR #703 "Update Docker client to support API version 1.52", release v0.24.x). Docker 29.3 later lowered the floor to 1.40. Any TUI that pins an old client library and stopped shipping before late 2025 deserves a check before use.
- ctop's last commit is 2022-08-01. The `pushed_at` of 2024-07 is a branch push, not master. Open issues include I/O stats reading 0/0 on cgroup v2 (#375) and no logs shown (#370). It still uses fsouza/go-dockerclient v1.7.0 and an unversioned endpoint, so I did not find evidence it fails outright on Docker 29, but nobody is fixing anything.
- dry looked dead (v0.11.2 in Feb 2024 after a 2021 release) but shipped v0.12.0 through v0.13.0 between Feb and Mar 2026 and was pushed to on 2026-09-04. Its README now documents compose project views with a drift column, SSH connection with known_hosts checking, and a `--workspace` layout. It does not read `docker context`; you pass `-H` or `DOCKER_HOST`.
- lazydocker does read the current docker context (PR #464, 2023) and tunnels `ssh://` hosts itself (pkg/commands/docker.go), though several SSH-context issues are open (#559, #644, #815).
- oxker is containers only. The `src/ui/draw_blocks` directory has containers, logs, cpu/mem chart, bandwidth chart, ports, inspect, exec. No image, volume or network panel, and nothing about compose in the README.
- ducker has containers, images, volumes, networks. No stats view (issue #171 open), no compose view. Exec assumes bash (README note). Cargo only or brew/pacman/nix, no prebuilt binary.
- gomanagedocker's last release is v1.5 from Dec 2024 and the repo has not been pushed to since. Its Podman support is real (separate `gmd p` entry point).
- sen's README states "maintenance mode", and its PyPI install needs urwidtrees from a git commit because the PyPI version is broken.
- dockly is a Node app on blessed; requires `npm install -g`. Last release Apr 2025.
- d4s is one person shipping 97 releases since Jan 2026, built on tview with docker/cli v29 and docker/docker v28. Reads docker contexts, does swarm, SSH tunnel. Too young to call stable, but the Docker library versions are current.
- podman-tui is the containers org's own tool, Podman only, v2.0.0 for Podman 6 in Sept 2026. It is the one option here with an institutional maintainer.

### Not reviewed

lazycontainer (Apple Containers, not Docker), lazyjournal (log viewer, no lifecycle control), dive and layerx (image layers only), logforge and Portainer (web), k9s (Kubernetes).

### Corrections from review

- First draft said lazydocker was "the only Docker TUI with both Compose project management and docker context support", but my own table gives d4s a yes on contexts and dry full Compose up/down. Reworded to the precise claim: lazydocker is the only one that does both.
- First draft said only dry shows Swarm nodes and stacks. d4s's README lists nodes, stacks, services, tasks, secrets and configs. dockly's source (`src/dockerUtil.js`) has only `listServices`. Fixed.
- Docker 29.0.0 release date is 2025-11-10 per the release notes; the lazydocker fix merged 2025-11-14, so "four days", not "two weeks".
- lazydocker's "300 open issues" from the repo API counts pull requests. Issue search gives 201 open issues, 86 enhancement, 83 bug. I had written "mostly feature requests", which was a guess. Fixed.
- ctop's cgroup v2 I/O bug is an issue report with no comments, not something I confirmed. Attributed it.

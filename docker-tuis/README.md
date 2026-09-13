# Docker TUIs in 2026 and which one to install

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

Which terminal UIs exist for managing a Docker engine, which of them are still maintained as of September 2026, and which one should a person actually install? ([original prompt](#original-prompt))

The prompt is two words, so scope is my call. In scope: TUIs that manage a running Docker (or Docker-compatible) engine from the terminal. Out of scope: web UIs (Portainer, Dockge, Dozzle), Kubernetes tools (k9s), and single-purpose inspectors (dive looks at image layers only). Nothing was installed or run; every claim comes from a README, release page, issue thread, or source file linked below.

## Answer / Summary

Install [lazydocker](https://github.com/jesseduffield/lazydocker). It is the only Docker TUI that can bring Compose projects up and down and also reads the active `docker context` (dry does the first, d4s the second), it is in Homebrew core with about 44,000 installs in the last year (ten times the next Docker-specific tool), and it survived the Docker Engine 29 API break in November 2025 with a fix four days after the release. Its weak spot is Podman, which has been an open issue since 2019.

Three other picks depending on what you want:

- A monitor rather than a manager, especially across several hosts: [dtop](https://github.com/amir20/dtop), from the Dozzle author. It replaces ctop, which has had no commit since August 2022.
- Podman: [podman-tui](https://github.com/containers/podman-tui), maintained by the containers org itself and the only tool here with an institutional owner.
- Swarm or an SSH-only remote with no contexts: [dry](https://github.com/moncho/dry), which came back from the dead in early 2026 with Compose drift detection and an SSH client that checks `known_hosts`.

If you come from k9s, [d4s](https://github.com/jr-k/d4s) is the closest match in feel and is built on current Docker libraries, but it is eight months old with one contributor. [ducker](https://github.com/robertpsoane/ducker) is the more settled k9s-style option and is in Homebrew, but it has no stats view and no Compose view.

Docker itself ships no TUI. The one proposal in `docker/cli` has sat open since 2019.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

1. Built the candidate list from three GitHub searches (`topic:docker topic:tui`, `docker tui in:name,description`, `docker terminal ui`), then cross-checked against the Terminal section of [awesome-docker](https://github.com/veggiemonk/awesome-docker#terminal). The biggest names do not carry the `tui` topic, so lazydocker, ctop, dry and dockly were fetched by name. dtop turned up only by reading a ctop issue.
2. Pulled stars, last push, license, archived flag, open issues and latest release for each repo from the GitHub API on 2026-09-12.
3. Pulled the Homebrew formula API for each name. The 365-day install count is the closest thing to a usage number that exists for these tools.
4. Read each README, and for the questions the README did not answer (does it read `docker context`, what happens on Docker 29, is it really containers-only) read the relevant source file or issue thread.
5. Left the machine untouched: no installs, no `docker` commands, no screenshots.

## Results

### Maintenance status

| Tool | Language | Stars | Latest release | Last push | Open issues | Brew installs (365d) |
|---|---|---:|---|---|---:|---:|
| [lazydocker](https://github.com/jesseduffield/lazydocker) | Go (gocui) | 52,807 | v0.25.2, 2026-04-19 | 2026-04-19 | 300 | 44,375 |
| [ctop](https://github.com/bcicen/ctop) | Go | 17,836 | v0.7.7, 2022-03-22 | last commit 2022-08-01 | 120 | 4,406 |
| [dockly](https://github.com/lirantal/dockly) | JavaScript (blessed) | 4,031 | v3.24.5, 2025-04-17 | 2026-07-23 | 5 | 332 |
| [dry](https://github.com/moncho/dry) | Go | 3,277 | v0.13.0, 2026-03-29 | 2026-09-04 | 27 | 525 |
| [docui](https://github.com/skanehira/docui) | Go | 2,327 | archived 2021 | | | |
| [oxker](https://github.com/mrjackwills/oxker) | Rust (ratatui, bollard) | 1,837 | v0.13.4, 2026-08-22 | 2026-08-22 | 23 | 1,254 |
| [dtop](https://github.com/amir20/dtop) | Rust | 1,412 | v0.9.3, 2026-09-10 | 2026-09-10 | 1 | 1,690 |
| [podman-tui](https://github.com/containers/podman-tui) | Go (tview) | 1,224 | v2.0.0, 2026-09-06 | 2026-09-11 | 9 | 7,185 |
| [sen](https://github.com/TomasTomecek/sen) | Python (urwid) | 1,048 | 0.8.1, 2025-08-11 | 2025-08-12 | 35 | not in core |
| [ducker](https://github.com/robertpsoane/ducker) | Rust (ratatui) | 931 | v0.6.5, 2026-03-21 | 2026-08-03 | 15 | 962 |
| [gomanagedocker](https://github.com/ajayd-san/gomanagedocker) | Go (bubbletea) | 641 | v1.5, 2024-12-23 | 2024-12-28 | 12 | not in core |
| [DockMate](https://github.com/shubh-io/DockMate) | Go | 338 | v0.1.0, 2026-01-05 | 2026-04-06 | 3 | tap only |
| [dcv](https://github.com/tokuhirom/dcv) | Go | 254 | v0.4.0, 2026-05-25 | 2026-09-10 | 15 | not in core |
| [d4s](https://github.com/jr-k/d4s) | Go (tview) | 128 | v0.49.109, 2026-09-12 | 2026-09-12 | 0 | not in core |
| [tdocker](https://github.com/pivovarit/tdocker) | Go | 89 | v0.7.2, 2026-07-27 | 2026-08-28 | 1 | tap only |

All MIT except podman-tui and d4s (Apache-2.0). ctop's GitHub `pushed_at` reads 2024-07, but that is a branch; master stopped on 2022-08-01. sen's README declares "maintenance mode". docui is archived and points at lazydocker.

### Features

| Tool | Compose | Images / volumes / networks | Stats | Exec / attach | Podman | Remote host | `docker context` |
|---|---|---|---|---|---|---|---|
| lazydocker | projects and services, up/down/rebuild | yes | CPU/mem graphs, configurable | both | via socket, unofficial ([#4](https://github.com/jesseduffield/lazydocker/issues/4)) | `DOCKER_HOST`, `ssh://` tunnel | yes |
| ctop | no | no | per-container top view | exec, logs | no | `DOCKER_HOST` | no |
| dockly | no | images, services (Swarm) | container stats | exec, logs | no | `-H`, `-T ssh` | no |
| dry | projects, services, drift column, up/down | yes, plus Swarm nodes/services/stacks | yes | exec, attach | no | `-H`, `DOCKER_HOST=ssh://` with `known_hosts` check | no, by design |
| oxker | no | no, containers only | CPU/mem and bandwidth charts | exec (not Windows) | no | `--host`, `DOCKER_HOST` | no |
| dtop | no | no | CPU/mem/disk across hosts | logs, start/stop/remove | no | multiple `-H`, ssh/tcp/tls | no |
| podman-tui | no (pods instead) | yes, plus secrets and pods | no, system info only | exec | Podman only | SSH to podman machine | n/a |
| sen | no | images with tree view | `:df` disk usage | attach, logs | no | `DOCKER_HOST` (docker-py) | no |
| ducker | no | yes | no ([#171](https://github.com/robertpsoane/ducker/issues/171)) | exec (bash only) | via socket path, untested by the author ([#9](https://github.com/robertpsoane/ducker/issues/9)) | `docker_path` in config | no |
| gomanagedocker | no | yes, plus pods on Podman | no | exec, run-and-exec from image | yes, `gmd p` | socket only | no |
| DockMate | full lifecycle, Docker and Podman compose | no | CPU/mem/disk/net | exec, configurable shell | yes | socket only | no |
| dcv | ps, top, project switcher, dind | yes | yes | exec, file browser | no | socket only | no |
| d4s | grouping by project | yes, plus Swarm | yes | shell | no | SSH tunnel | yes, plus plugins |
| tdocker | no | no | no | exec, logs, restart, copy ID | no | socket only | no |

## Analysis

### The Docker 29 break is the best signal of who is home

Docker Engine 29.0, released 2025-11-10, dropped support for API versions below 1.44, which is Docker 25 ([release notes](https://docs.docker.com/engine/release-notes/29/)). Any TUI that pinned an older API version stopped working with "client version 1.25 is too old". lazydocker, which had been pinning 1.24, hit this immediately ([#715](https://github.com/jesseduffield/lazydocker/issues/715), [#704](https://github.com/jesseduffield/lazydocker/issues/704)), merged a fix on 2025-11-14 ([#703](https://github.com/jesseduffield/lazydocker/pull/703)), and bumped its README requirement to Docker 29. The `lazyteam/lazydocker:latest` Docker image lagged behind and was still failing in February 2026 ([#767](https://github.com/jesseduffield/lazydocker/issues/767)), so install the binary rather than the image. Docker 29.3 (March 2026) lowered the floor to 1.40, so a client pinned anywhere from 1.40 up works again. A dormant tool that happens to sit in that window is working by luck, not maintenance.

ctop is the cautionary tale. 17,800 stars, in every package manager, and no commit in four years. An open issue reports I/O stats as 0/0 on cgroup v2 hosts ([#375](https://github.com/bcicen/ctop/issues/375)), which is every modern Linux, and nobody has answered it. The Dozzle author wrote dtop specifically because of this ([ctop #366](https://github.com/bcicen/ctop/issues/366)). ctop still gets 4,400 Homebrew installs a year on reputation alone.

### Why lazydocker and not one of the Rust ones

oxker and ducker are both well made and both in Homebrew core, but each is missing half the job. oxker's source has panels for containers, logs, charts, ports and inspect and nothing else; there is no images, volumes or networks view. ducker has the four resource types but no stats and no Compose, and its exec assumes bash exists in the container. lazydocker does all of it and, uniquely among the older tools, reads the active `docker context` ([pkg/commands/docker.go](https://github.com/jesseduffield/lazydocker/blob/master/pkg/commands/docker.go)), which matters on a Mac running Docker Desktop, Colima or Rancher Desktop, where the active context may not point at `/var/run/docker.sock`. dry's README names exactly those three, says it does not read contexts, and tells you to pass `-H`.

lazydocker's issue count looks bad next to oxker's 23, but the 300 GitHub shows includes pull requests; 201 are issues, split almost evenly between the `enhancement` (86) and `bug` (83) labels, on a project with 52,000 stars. In 2026 the author landed changes in January, March and April, then nothing through September. That is not a fast pace, and the SSH context path has several open bugs ([#559](https://github.com/jesseduffield/lazydocker/issues/559), [#644](https://github.com/jesseduffield/lazydocker/issues/644), [#815](https://github.com/jesseduffield/lazydocker/issues/815)). If you manage a remote daemon over SSH every day, dry or d4s handle it more deliberately.

### dry is the surprise

dry looked abandoned: v0.11.2 in February 2024 was the first release since 2021. Then between February and March 2026 it shipped v0.12.0 through v0.13.0 and the README grew a Compose Projects view with a SYNC column that reports `ok`, `drift` or `absent` per service, an SSH connector that honors `~/.ssh/config` and refuses unknown host keys, and an experimental `--workspace` layout. It and d4s are the two tools here that cover Swarm nodes, services and stacks; dockly stops at services. Brew installs are low (525) because it lives in a tap, not core. Worth watching, and the right pick if you run Swarm.

### The 2026 wave

A third of the table was created in 2025 or 2026: dtop, d4s, DockMate, dcv, tdocker, and a long tail below the star cutoff (bosun, wharf, easydocker, DockTUI, dprs). Most are one person and a ratatui or bubbletea skeleton. Two stand out. dtop has a known author with a track record (Dozzle), a narrow scope it has already filled, and one open issue. d4s is shipping several releases a week on `docker/cli` v29 and `docker/docker` v28, so it will not suffer the API problem, and its feature list (contexts, plugins, Swarm, SSH tunnel, command palette) is the most complete of the k9s-alikes. Its risk is entirely bus factor: 256 of 267 commits are one person, and the version number (v0.49.109) suggests automated tagging rather than considered releases.

### Podman

gomanagedocker and DockMate both claim Podman support and both are small. podman-tui is the one that will still work next year: it lives in the `containers` GitHub org next to Podman itself, its release branches track Podman major versions (2.x for Podman 6), and it has 7,000 Homebrew installs, second only to lazydocker in this table. It is Podman only and does pods rather than Compose.

## Files

- `README.md`: this report.
- `notes.md`: work log, dead ends, and per-tool findings in the order they were found.
- `_summary.md`: one-paragraph summary for the repository index, written by the summarizer.

## Original Prompt

> Research docker TUIs

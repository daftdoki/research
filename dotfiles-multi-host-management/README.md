# Maintaining Dotfiles Across Multiple Hosts on macOS and Linux

<!-- AI-GENERATED-NOTE -->
> [!NOTE]
> This is an AI-generated research report. All text and code in this report was created by an LLM (Large Language Model). For more information on how these reports are created, see the [main research repository](https://github.com/daftdoki/research).
<!-- /AI-GENERATED-NOTE -->

## Question / Goal

What are the realistic options for keeping one set of dotfiles in sync across
several machines when those machines are a mix of macOS and Linux?
([original prompt](#original-prompt))

The easy half of this question — "put them in git" — is not the interesting
half. The interesting half is what happens when the *same* file must differ
per host or per OS, and what happens to secrets. This report compares ten
tools on those axes, plus the cross-OS facts that bite you no matter which
one you pick.

## Answer / Summary

**There are only four real shapes of answer, and you should pick the cheapest
one that covers the divergence you actually have:**

| If your divergence is… | Use | Why |
|---|---|---|
| Basically none | **bare git repo** or **GNU Stow** | Nothing new to install or learn |
| Whole files differ per OS/host | **GNU Stow** packages, or **yadm** alternates | Divergence is a file-selection problem, not a templating problem |
| Content *inside* shared files differs, and/or you need secrets in the repo | **chezmoi** | The only tool that does in-file templating, per-file encryption, and password-manager lookups, from a single static binary |
| You also want packages, services and program config declared, and will pay the Nix learning cost | **home-manager** | 107 of its 1327 modules already handle the macOS/Linux split internally, so you never write the conditional |

**For the prompt as asked — several hosts, macOS and Linux — the default
recommendation is [chezmoi](https://github.com/twpayne/chezmoi)**, because it
is the only option that is a single static binary with *no* bootstrap
requirement, handles divergence inside a shared file, and stores secrets
per-file (so git history stays readable) rather than as an opaque blob.
**[yadm](https://github.com/yadm-dev/yadm)** is the runner-up if you would
rather keep a plain-git workflow, and its `##os.Darwin` filename convention is
a genuinely elegant answer to the macOS/Linux split.

Two things are true regardless of tool, and both are load-bearing:

1. **Do not key per-host config on the hostname on macOS.** Two unrelated
   projects document this independently: rcm's man page says macOS's hostname
   "is unpredictable, and can even change as part of the DHCP handshake", and
   chezmoi's macOS guide tells you to use `scutil --get ComputerName` instead.
   Use an explicit self-declared label (yadm's `class`, chezmoi's `[data]`,
   rcm's tags).
2. **Homebrew's prefix differs three ways** — `/opt/homebrew` on Apple
   Silicon, `/usr/local` on Intel Macs, `/home/linuxbrew/.linuxbrew` on Linux.
   This one fact is the most common reason people need per-host dotfiles at
   all.

For additional and more detailed information see the [research notes](notes.md).

## Methodology

Two halves: reading primary sources, and two sandboxed experiments.

**Sources.** Every claim below comes from the project's own documentation *as
committed in its repository* — READMEs, man-page sources, mkdocs trees —
fetched with `curl` from `raw.githubusercontent.com`. (The network egress
proxy in this environment blocks `chezmoi.io`, `yadm.io`, `gnu.org` and
`api.github.com`, so the rendered doc sites were unreachable; the repos were
not.) Where chezmoi's own [comparison table][cmp] makes a claim about a
competitor, that row was re-checked against the competitor's docs — see
[Analysis](#analysis) for the one row that did not survive.

**Project health** was measured directly on 2026-09-12 with
`git clone --depth 1` plus `git ls-remote --tags`, not from the GitHub API.

**Experiments.** Per this repo's portability rules nothing was installed on
the host; both scripts need only `git` and `ln`, and both write exclusively
into a throwaway sandbox directory:

```bash
./bare-repo-demo.sh    /tmp/sandbox    # output captured in bare-repo-demo.out
./symlink-farm-demo.sh /tmp/sandbox2   # output captured in symlink-farm-demo.out
```

- `bare-repo-demo.sh` builds a fake `remote.git` plus two fake `$HOME`s (a
  "mac laptop" and a "linux server") and runs the real bare-repo workflow
  across both.
- `symlink-farm-demo.sh` reimplements GNU Stow's linking rule with `ln`
  (Stow itself is not installed here) to show the package-selection model.

## Results

### The landscape

| Tool | Language / distribution | Bootstrap needs | Dotfiles are… | Per-host / per-OS mechanism | Secrets |
|---|---|---|---|---|---|
| **chezmoi** | Go, single static binary | none | rendered files | Go `text/template` over `.chezmoi.os`/`.hostname`/`.arch` + user `[data]`; `.chezmoiignore` is itself a template | age/gpg/rage/git-crypt/transcrypt per file, + 17 password managers |
| **yadm** | Bash, single script | `git` | files (+ symlinks for alternates) | filename suffixes: `##os.Darwin`, `##class.Work`, `##hostname.h2`, `##distro_family.debian`, `##arch.arm64`, `##default` | gpg/openssl, but as **one tarball** |
| **GNU Stow** | Perl | Perl (ships with macOS) | symlinks | none built in — make more packages, stow different sets | none |
| **rcm** | Bash, multiple files | Bash | symlinks | `tag-*/` directories + host-specific files via `mkrc -o` | none |
| **dotbot** | Python, git submodule | Python + git | symlinks | `if:` key on a link, e.g. ``if: '[ `uname` = Darwin ]'`` | none |
| **vcsh** | POSIX shell | `sh` + git | files | one git repo per app; clone a different *set* per machine (usually driven by `myrepos`/`mr`) | none |
| **dotdrop** | Python | Python + git | files or symlinks | "profiles" — named sets of dotfiles, plus Jinja2 templating | transformations for encrypted storage |
| **dotter** | Rust binary | none | files or symlinks | `global.toml` packages + per-machine `local.toml`, with templating | none |
| **homeshick** | Bash | Bash + git | symlinks | multiple "castles" (repos); clone different sets | none |
| **home-manager** | Nix | a working Nix install | generated files in the Nix store | the full Nix language; `pkgs.stdenv.hostPlatform.isDarwin` | via Nix + sops-nix/agenix (external) |
| **bare git repo** | — | `git` | files | **none** — see the experiment below | none |

### Project health, measured 2026-09-12

| Project | Last commit | Latest tag |
|---|---|---|
| nix-community/home-manager | 2026-09-11 | release branches; newest `release-26.05` |
| deadc0de6/dotdrop | 2026-09-09 | v1.17.0 |
| twpayne/chezmoi | 2026-09-07 | v2.72.1 |
| SuperCuber/dotter | 2026-07-13 | v0.13.5 |
| anishathalye/dotbot | 2026-07-11 | v1.24.1 |
| RichiH/vcsh | 2025-12-30 | v2.0.10 |
| aspiers/stow | 2025-12-02 | v2.4.1 |
| yadm-dev/yadm | 2025-03-23 | 3.5.0 |
| andsens/homeshick | 2024-09-29 | v2.0.1 |
| thoughtbot/rcm | 2024-08-16 | v1.3.6 |

> **Note:** yadm has moved organisation, from `TheLocehiliosan/yadm` to
> `yadm-dev/yadm`. The old path still redirects, but pin the new one.

Stow and rcm being quiet is not a red flag — they are small, finished tools.
rcm at two years and homeshick at two years are the two worth thinking twice
about.

### Experiment 1 — where "just use a bare git repo" breaks

The bare-repo technique (`git --git-dir=~/.dotfiles --work-tree=~`, plus
`status.showUntrackedFiles no` so `$HOME` isn't a wall of untracked files)
is the zero-dependency baseline. It works, and the `showUntrackedFiles`
trick genuinely does hide the sandbox's `Downloads/movie.mkv`. It fails in
two specific places, both reproduced in `bare-repo-demo.out`.

**Failure 1 — cloning into a `$HOME` that already has files:**

```
error: The following untracked working tree files would be overwritten by checkout:
	.bashrc
Please move or remove them before you switch branches.
Aborting
```

Every new machine hits this, because every new machine ships a `.bashrc`. You
must move files aside by hand before the first checkout.

**Failure 2 — the divergence problem.** The mac host sets
`PATH=/opt/homebrew/bin:$PATH`; the Linux host needs
`/home/linuxbrew/.linuxbrew/bin`. Both commit. The next pull:

```
Auto-merging .bashrc
CONFLICT (content): Merge conflict in .bashrc

<<<<<<< HEAD
export PATH="/opt/homebrew/bin:$PATH"
alias ll="ls -lG"
=======
export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
>>>>>>> origin/master
```

Nothing here is a mistake — both edits are correct *for their host*. Plain git
has no way to express "this line is per-OS", so every sync re-litigates it.
**That conflict is the entire reason the rest of these tools exist.**

### Experiment 2 — the same divergence, solved by package selection

`symlink-farm-demo.sh` lays the repo out as Stow packages
(`shell-common/`, `shell-darwin/`, `shell-linux/`, `git/`), using Stow's
`--dotfiles` convention where a file named `dot-shrc` installs as `~/.shrc`.
Each host stows the common packages plus exactly one OS package:

```
=== mac-laptop: stow common + git + shell-darwin
  links created:
    .gitconfig -> $REPO/git/dot-gitconfig
    .shrc -> $REPO/shell-common/dot-shrc
    .shrc.common -> $REPO/shell-common/dot-shrc.common
    .shrc.local -> $REPO/shell-darwin/dot-shrc.local
  effective ~/.shrc after sourcing:
    | set -o vi
    | alias g=git
    | export PATH="/opt/homebrew/bin:$PATH"

=== linux-server: stow common + git + shell-linux
    ...
    .shrc.local -> $REPO/shell-linux/dot-shrc.local
  effective ~/.shrc after sourcing:
    | set -o vi
    | alias g=git
    | export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
```

Identical tree on both hosts, no conflict, no templating engine. The costs are
real but small: the per-OS bits must be split into separate files up front,
and *which* packages a host stows is not itself version-controlled — you
record it in a bootstrap script.

This "stable file `source`s a per-host local file" pattern is tool-agnostic.
It works under Stow, bare git, rcm, and yadm alike, and it is the single
highest-leverage change you can make before reaching for a heavier tool.

## Analysis

### Where each tool's design actually pays off

**chezmoi** treats your repo as *source state* and renders it into `$HOME`,
which is why it can do things the symlink tools cannot. The macOS/Linux case
it handles best is the one nobody else does cleanly: the same content needing
to live at `~/Library/Application Support/App/file.conf` on macOS and
`~/.config/app/file.conf` on Linux. You put the content once in
`.chezmoitemplates/`, create two thin template files that both say
`{{- template "file.conf" . -}}`, and let a templated `.chezmoiignore` switch
off the wrong one per OS. Its secrets story is also the most serious:
per-file `encrypted_` ASCII-armored blobs (age, gpg, rage, git-crypt,
transcrypt) plus template functions for 17 password managers, so a *public*
dotfiles repo is actually viable.

The cost is that your repo no longer looks like your home directory —
`dot_gitconfig.tmpl` is not `.gitconfig` — and you must run `chezmoi apply`
after every edit. That indirection is the whole objection to chezmoi, and it
is a fair one.

**yadm's** alternates are the most elegant expression of the macOS/Linux
split specifically. You commit `example.txt##os.Darwin` and
`example.txt##os.Linux`; yadm scores every candidate (`class` outranks `os`
outranks nothing, more conditions beat fewer, `~` negates) and symlinks the
winner. No template language, no code in your rc files, and the repo still
looks like your home directory. Conditions cover user, hostname, class,
distro, distro_family, os, and arch — and WSL reports as its own OS despite
`uname` saying Linux.

Two caveats, both from yadm's own man page. Its built-in template processor
is *an awk program* with Jinja-ish syntax and case-insensitive `if`
comparisons; the good Jinja processors (j2cli, envtpl) are external and
stale. And **yadm's encryption is a tarball**: matching paths get bundled
into `$HOME/.local/share/yadm/archive`, so git sees one opaque binary blob.
No per-secret diffs, and every secret change is a full re-encrypt. chezmoi's
per-file approach is strictly better here.

**home-manager** is the outlier, and the measurement that makes the case for
it is this: **107 of its 1327 module `.nix` files reference `isDarwin`.** For
example `modules/programs/tealdeer.nix` contains

```nix
configDir =
  if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support" else config.xdg.configHome;
```

That is the macOS/Linux path split being solved *by the maintainers, inside
the module*, so it never appears in your config at all. No other tool here
offers that; they all hand you a conditional and wish you luck. home-manager
also manages packages and services, not just files, so "new laptop" becomes
one command rather than a bootstrap script.

The price is steep and the project says so itself, warning in its README that
"it is quite possible to get difficult to understand errors" and that you
"should therefore be comfortable using the Nix language". It also needs a
working Nix install before anything happens — the heaviest bootstrap on the
list, against chezmoi's zero.

**Stow** deserves more credit than its feature row suggests. It has no
templating, no secrets and no per-host logic, and for a large number of
people that is the correct feature set: your dotfiles stay plain files, `git
diff` shows what you think it shows, and divergence is handled by stowing
different packages. `--dotfiles` (new in 2.4.0, with fixes in 2.4.1 for
directories and ignore-list interaction) removes the one real ergonomic wart
by letting the repo hold `dot-bashrc` instead of `.bashrc`.

**vcsh** and **homeshick** attack a different axis — many repos, pick a subset
per machine — which is powerful for "my server doesn't need my mplayer
config" but does nothing for "this one file differs by two lines". **dotbot**
and **dotter** are good middles: dotbot in particular is more capable than
chezmoi's table admits (see below). **rcm** is the most Unix-traditional of
the bunch (tags, host files, multiple source dirs, and it can emit a
standalone `install.sh`), but it is also the quietest repo on the list.

### One row of chezmoi's comparison table does not survive checking

chezmoi's [comparison table][cmp] is a genuinely useful document and mostly
holds up — the yadm-needs-external-template-processors claim, for instance,
checks out against yadm's own man page. But it is a vendor table, and one row
is materially misleading: it credits dotbot only with **"Alternative files"**
for machine-to-machine differences. In fact dotbot's README documents an `if`
parameter on link entries — *"Execute this in your `$SHELL` and only link if
it is successful"* — and the README's own example is:

```yaml
~/.hammerspoon:
  if: '[ `uname` = Darwin ]'
  path: hammerspoon
```

That is a real per-OS conditional evaluated at deploy time, not alternative
files. Read the table as a starting point, then verify anything that would
change your decision.

### The traps that are not about tooling at all

- **Hostname is not a stable key on macOS.** rcm's man page BUGS section and
  chezmoi's macOS guide independently document this; chezmoi's fix is
  `{{ output "scutil" "--get" "ComputerName" | trim }}`. Anything keyed on
  hostname (yadm `##hostname.x`, rcm `mkrc -o`, chezmoi `.chezmoi.hostname`)
  inherits the problem. Prefer a label you declare yourself.
- **Three Homebrew prefixes.** Per Homebrew's own `docs/Installation.md`:
  `/opt/homebrew` (Apple Silicon), `/usr/local` (Intel macOS),
  `/home/linuxbrew/.linuxbrew` (Linux). A hardcoded prefix is wrong on two
  machines out of three. Use `$(brew --shellenv)` or branch on the OS.
- **macOS's `/bin/bash` is 3.2**, and zsh has been the default login shell
  since Catalina. `declare -A`, `${var^^}` and `mapfile` are all bash 4+ and
  will break there. *(Secondary-sourced — the proxy here blocks Apple's
  site — so verify before relying on the exact version.)*
- **BSD vs GNU userland**: `sed -i` takes an argument on macOS; `ls` wants
  `-G` not `--color`. This one bit me *inside this very investigation* — the
  first draft of `symlink-farm-demo.sh` used `find -printf`, which is GNU
  only. It is fixed, and the irony is noted.

### Recommendation

Start from the divergence you have, not the features you might want:

1. **Try the two-layer pattern first**, whatever tool you use: a committed,
   host-invariant `~/.shrc` that ends by sourcing a `~/.shrc.local`. A
   surprising amount of per-host difference disappears, and nothing gets
   installed.
2. **If whole files differ**, Stow packages or yadm alternates are enough and
   keep your repo legible.
3. **If content inside shared files differs, or secrets need to live in the
   repo, use chezmoi.** It is actively developed (last commit five days
   before this report), installs as one static binary with no prerequisites,
   and is the only tool here whose secrets model produces reviewable diffs.
4. **Reach for home-manager only if you want reproducible machines**, not
   just synced files — and only if you are willing to learn Nix. When it
   fits, it is the strongest answer on this page; when it doesn't, it is the
   most expensive way to sync a `.vimrc` ever devised.

## Files

- `README.md` — this report
- `notes.md` — research notes, dead ends, and the raw measurements
- `bare-repo-demo.sh` — sandboxed demo of the bare-git-repo technique and its
  two failure modes (needs only `git`; writes only into a sandbox dir)
- `bare-repo-demo.out` — captured output of the above
- `symlink-farm-demo.sh` — reimplements GNU Stow's linking rule with `ln` and
  demonstrates per-OS package selection
- `symlink-farm-demo.out` — captured output of the above

## Sources

- [chezmoi](https://github.com/twpayne/chezmoi) — `comparison-table.md`,
  `user-guide/manage-machine-to-machine-differences.md`,
  `user-guide/encryption/index.md`,
  `user-guide/password-managers/index.md`, `user-guide/machines/macos.md`,
  `user-guide/machines/general.md`, `mkdocs.yml`
- [yadm](https://github.com/yadm-dev/yadm) — `README.md` and `yadm.md`
  (man page source: ALTERNATES, TEMPLATES, ENCRYPTION)
- [GNU Stow](https://github.com/aspiers/stow) — `README.md`, `NEWS`
- [rcm](https://github.com/thoughtbot/rcm) — `README.md`,
  `man/rcm.7.mustache` (TAGGED DOTFILES, HOST-SPECIFIC DOTFILES, BUGS)
- [dotbot](https://github.com/anishathalye/dotbot) — `README.md`
- [vcsh](https://github.com/RichiH/vcsh) — `README.md`
- [home-manager](https://github.com/nix-community/home-manager) —
  `README.md`, `docs/manual/installation/standalone.md`,
  `modules/programs/tealdeer.nix`
- [dotdrop](https://github.com/deadc0de6/dotdrop) — `README.md`
- [dotter](https://github.com/SuperCuber/dotter) — `README.md`
- [homeshick](https://github.com/andsens/homeshick) — `README.md`
- [Homebrew](https://github.com/Homebrew/brew) — `docs/Installation.md`
- macOS shell background (secondary):
  [Apple support](https://support.apple.com/en-au/HT208050),
  [pawelgrzybek.com](https://pawelgrzybek.com/apple-changed-the-default-shell-from-bash-to-zsh-so-did-i/)

[cmp]: https://github.com/twpayne/chezmoi/blob/master/assets/chezmoi.io/docs/comparison-table.md

## Original Prompt

> Research options for maintaining dotfiles across multiple hosts and macOS and Linux

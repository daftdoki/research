# Dotfiles across multiple hosts (macOS + Linux) — Notes

## Goal

Find and compare the realistic options for keeping dotfiles in sync across
several machines when those machines are a mix of macOS and Linux. The
interesting part is not "put them in git" — it is what happens when the same
file must differ per host or per OS, and what happens to secrets.

## Axes I decided to compare on

- **Deployment mechanism**: symlink farm vs. copy/render vs. the repo *being*
  $HOME.
- **Per-host / per-OS divergence**: does the tool have a first-class answer, or
  do you hand-roll `if [[ $(uname) == Darwin ]]` inside your shell rc?
- **Secrets**: built-in encryption, password-manager integration, or nothing.
- **Bootstrap cost on a brand-new box**: what has to already be installed.
- **Language/runtime**: matters because macOS ships ancient bash 3.2 and no
  GNU coreutils; a tool written in POSIX sh or a static binary dodges that.
- **Project health**: still maintained in 2026?

## Work log

- Created folder, started notes.
- Network note: the egress proxy here blocks `chezmoi.io`, `yadm.io`, `gnu.org`
  and `api.github.com`, but `raw.githubusercontent.com` and plain `git` over
  HTTPS both work. So every primary source below is the project's own docs
  **as committed in its repo** (READMEs, man-page sources, mkdocs trees),
  fetched with curl. Project-health numbers come from `git clone --depth 1`
  plus `git ls-remote --tags`, not from the GitHub API.

### Sources read

- chezmoi `assets/chezmoi.io/docs/comparison-table.md` — useful but it is
  *chezmoi's own* table, so treat it as a claim to verify, not a neutral one.
  Verified the yadm, rcm and vcsh rows against those projects' own docs.
- yadm `yadm.md` (the man page source, 36 KB) — ALTERNATES, TEMPLATES,
  ENCRYPTION sections.
- chezmoi `user-guide/manage-machine-to-machine-differences.md`,
  `user-guide/encryption/index.md`, `user-guide/password-managers/index.md`,
  and the `mkdocs.yml` nav (which enumerates the supported password managers).
- GNU Stow `README.md` + `NEWS` (for when `--dotfiles` landed).
- rcm `man/rcm.7.mustache` — TAGGED DOTFILES, HOST-SPECIFIC DOTFILES, BUGS.
- vcsh `README.md`.

### Findings worth keeping

- **yadm alternates** are a filename-suffix scheme: `file##os.Darwin`,
  `file##class.Work,~os.Darwin`, `##hostname.h2`, `##distro_family.debian`,
  `##arch.arm64`, `##default`. Attributes are scored, most-specific wins, and
  yadm materialises the choice as a *symlink* to the winning variant. So the
  macOS/Linux split is first-class and needs no code in your rc files.
- **yadm templates** exist but the built-in processor is an awk program with
  Jinja-ish syntax and case-insensitive `if`. The good Jinja processors
  (j2cli, envtpl) are external and both are stale, which is the one concrete
  point in chezmoi's comparison table I could confirm independently.
- **yadm encryption is a tarball**, not per-file: matching paths get bundled
  into `$HOME/.local/share/yadm/archive` by `yadm encrypt`, and that single
  blob is what git sees. Consequence: no meaningful diffs on secrets, and
  every secret change is a full re-encrypt. chezmoi instead encrypts
  per-file with an `encrypted_` prefix in ASCII armor, so git history stays
  per-file.
- **chezmoi's divergence story is Go `text/template`** over `.chezmoi.os`,
  `.chezmoi.hostname`, `.chezmoi.arch` plus arbitrary user `[data]` in
  `~/.config/chezmoi/chezmoi.toml`. `.chezmoiignore` is itself a template,
  which is how you say "this file only exists on the work laptop".
  `.chezmoitemplates/` + `include` covers "same content, different path on
  macOS vs Linux" — the `~/Library/Application Support` vs `~/.config`
  problem, which is THE macOS/Linux dotfiles problem.
- **chezmoi secrets**: 17 password-manager integrations listed in the docs nav
  (1Password, Bitwarden, KeePassXC, pass, gopass, Vault, Keychain, LastPass,
  Dashlane, Doppler, Keeper, Proton Pass, ejson, passhole, AWS Secrets
  Manager, Azure Key Vault, custom) + age/gpg/rage/git-crypt/transcrypt for
  whole-file encryption.
- **Stow** is Perl, symlink-only, no templating, no secrets, no per-host
  logic. `--dotfiles` (new in 2.4.0) lets the repo hold `dot-bashrc` instead
  of `.bashrc` so the source tree isn't all hidden files; 2.4.1 fixed
  `--dotfiles` interacting badly with ignore lists and with directories.
  Per-host divergence in Stow is "make more packages and stow different sets"
  — which genuinely works, it is just manual.
- **rcm** has *tags* (`tag-zsh/` dirs, `rcup -t zsh`) and host-specific files
  (`mkrc -o`), plus multiple source dirs. No templating, no encryption.
- **rcm's man page has a macOS-specific BUGS entry**: it resolves the host via
  `hostname(1)`, which is not POSIX-specified, and on macOS "the hostname is
  unpredictable, and can even change as part of the DHCP handshake" — it
  recommends pinning `HOSTNAME` in `rcrc`. This generalises: ANY tool that
  keys per-host config on the hostname inherits this on macOS.
- **vcsh** is a different axis entirely: many git repos sharing `$HOME` as
  their work tree, one per application (`vcsh init vim`). Divergence is
  handled by cloning a different *set* of repos per machine, or by branches.
  Usually paired with `myrepos`/`mr` to drive them all at once.

### Project health (measured 2026-09-12, shallow clone + ls-remote)

| project | last commit | latest tag |
|---|---|---|
| twpayne/chezmoi | 2026-09-07 | v2.72.1 |
| nix-community/home-manager | 2026-09-11 | (release branches, newest release-25.11) |
| deadc0de6/dotdrop | 2026-09-09 | v1.17.0 |
| SuperCuber/dotter | 2026-07-13 | v0.13.5 |
| anishathalye/dotbot | 2026-07-11 | v1.24.1 |
| aspiers/stow | 2025-12-02 | v2.4.1 |
| RichiH/vcsh | 2025-12-30 | v2.0.10 |
| yadm-dev/yadm | 2025-03-23 | 3.5.0 |
| andsens/homeshick | 2024-09-29 | v2.0.1 |
| thoughtbot/rcm | 2024-08-16 | v1.3.6 |

- Note: yadm has **moved org**, from `TheLocehiliosan/yadm` to
  `yadm-dev/yadm` (the old path still redirects; all badge links in the
  README now point at `yadm-dev`). Worth knowing before pinning a URL.

### Cross-OS facts that bite regardless of which tool you pick

- **Homebrew's prefix differs three ways.** Homebrew's own
  `docs/Installation.md` (main branch): "`/opt/homebrew` for Apple Silicon,
  `/usr/local` for macOS Intel and `/home/linuxbrew/.linuxbrew` for Linux".
  So a hardcoded `export PATH=/usr/local/bin:...` is wrong on two of three.
  This is the single most common thing that forces per-host divergence.
- **Config paths differ.** macOS apps want
  `~/Library/Application Support/<app>`, Linux apps want
  `$XDG_CONFIG_HOME` (`~/.config`). chezmoi documents this as its
  `.chezmoitemplates` + `include` use case. home-manager instead absorbs it
  *inside the module*: e.g. `modules/programs/tealdeer.nix` has
  `configDir = if pkgs.stdenv.hostPlatform.isDarwin then
  "Library/Application Support" else config.xdg.configHome;`.
  Measured: **107 of 1327 module .nix files** in home-manager reference
  `isDarwin`. That is the strongest single argument for home-manager — the
  OS split is the maintainers' problem, not yours.
- **The hostname is not a stable key on macOS.** rcm's man page BUGS section
  says outright that macOS's hostname "is unpredictable, and can even change
  as part of the DHCP handshake" and tells you to pin `HOSTNAME` in `rcrc`.
  chezmoi's macOS guide reaches the same conclusion independently and
  recommends `{{ output "scutil" "--get" "ComputerName" | trim }}`.
  Two unrelated projects documenting the same trap is strong evidence.
  Anything keyed on hostname (yadm `##hostname.x`, rcm `-o`,
  chezmoi `.chezmoi.hostname`) inherits this. Prefer an explicit,
  self-declared label: yadm's `class`, chezmoi's `[data]`, rcm's tags.
- **macOS's bash is 3.2** (GPLv2-era; Apple has not shipped a GPLv3 bash),
  and zsh has been the default login shell since Catalina. So a `.bashrc`
  using `declare -A`, `${var^^}` or `mapfile` breaks on macOS's `/bin/bash`.
  Couldn't reach an Apple primary source through this proxy; this is
  secondary-sourced and flagged as such in the report.
- **BSD vs GNU userland**: `sed -i` takes an argument on macOS, `ls` colour
  flag is `-G` not `--color`. My own demo script tripped the mirror image of
  this — I wrote `find -printf`, which is GNU-only — and I fixed it.

### Experiments actually run (only git and ln needed, nothing installed)

1. `bare-repo-demo.sh` — the bare-repo-in-$HOME technique in a sandbox.
   Reproduced two real failure modes:
   - `checkout` into a non-empty `$HOME` aborts with "The following untracked
     working tree files would be overwritten by checkout: .bashrc". You have
     to move files aside by hand. Every new machine hits this.
   - When two hosts legitimately need different content in the same file, the
     second pull is a **merge conflict** with both sides correct. Captured in
     `bare-repo-demo.out`. This is the concrete demonstration of why "just use
     git" stops working at host #2.
   - Also confirmed the `status.showUntrackedFiles no` trick works: a
     `Downloads/movie.mkv` in the sandbox `$HOME` stays invisible to status.
   - Gotcha while writing it: pushing to a local bare repo in this container
     printed `fatal: expected 'acknowledgments', received 'packfile'` +
     "push negotiation failed". Harmless, but I pinned
     `-c push.negotiate=false` to keep the captured output clean.
2. `symlink-farm-demo.sh` — reimplements GNU Stow's linking rule with `ln`
   (Stow is not installed and this repo's rules say not to install it), and
   shows the same macOS/Linux PATH divergence resolved cleanly by choosing
   *which packages to stow* per host. Output in `symlink-farm-demo.out`.
   - Second pass fixed two portability bugs of my own: `find -printf` (GNU
     only) and a `${rel//dot-/.}` global substitution that would have mangled
     a file called `not-dot-foo`. Stow only translates a *leading* `dot-` per
     path component.

### Dead ends / things that did not work

- `WebFetch` on `chezmoi.io`, `yadm.io`, `gnu.org`, `atlassian.com`: all
  EGRESS_BLOCKED. Pivoted to `raw.githubusercontent.com`, which works, so the
  docs came from the repos rather than the rendered sites. `api.github.com`
  is 403 too, hence shallow clones for project-health data.
- Wanted a primary Apple source for the bash 3.2 / zsh-default claim; the
  proxy blocks `support.apple.com`. Left it secondary-sourced and said so.
- Nearly wrote the comparison table straight from chezmoi's own
  `comparison-table.md`. Stopped: it is a vendor table. Re-derived the yadm,
  rcm, dotbot and vcsh rows from those projects' own docs, and found one row
  is materially misleading — it credits dotbot only with "alternative files"
  for machine differences, but dotbot's README documents an `if:` key on link
  entries whose own example is `if: '[ `uname` = Darwin ]'`. That is a real
  conditional, not alternative files.

### Conclusion I landed on

Ranked by "how much machinery do you need for the divergence you actually
have", not by feature count:

- No real divergence -> bare git repo or Stow. Zero new tools.
- Divergence confined to whole files -> Stow packages, or yadm alternates.
- Divergence *inside* shared files, plus secrets -> chezmoi.
- You also want packages/services declared, and will pay the Nix tax ->
  home-manager.

chezmoi is the default recommendation for the prompt as asked (several
hosts, macOS and Linux), mostly because it is the only one that is a single
static binary with no bootstrap requirement, handles in-file divergence, and
does secrets per-file rather than as an opaque tarball.

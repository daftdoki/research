#!/usr/bin/env bash
# Emulate the GNU Stow model (a symlink farm of per-topic "packages") with
# nothing but ln, and show how per-OS packages solve the divergence that
# plain bare-git could not. This does NOT run stow -- stow is not installed
# here and this repo's research must not install things -- it reproduces the
# layout and linking rule stow implements, per its README and manual.
#
# Touches only $SANDBOX.
set -euo pipefail

SANDBOX="${1:?usage: symlink-farm-demo.sh <sandbox-dir>}"
rm -rf "$SANDBOX"; mkdir -p "$SANDBOX"

REPO="$SANDBOX/dotfiles"
say() { printf '\n=== %s\n' "$*"; }

# --- the repo: one directory per "package", stow --dotfiles naming ----------
# With --dotfiles (GNU Stow >= 2.4.0) a file named dot-foo in the package is
# installed as ~/.foo, so the repo isn't full of hidden files.
mkdir -p "$REPO"/{shell-common,shell-darwin,shell-linux,git}
printf 'set -o vi\nalias g=git\n'                  > "$REPO/shell-common/dot-shrc.common"
printf 'export PATH="/opt/homebrew/bin:$PATH"\n'   > "$REPO/shell-darwin/dot-shrc.local"
printf 'export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"\n' \
                                                   > "$REPO/shell-linux/dot-shrc.local"
printf '. ~/.shrc.common\n. ~/.shrc.local\n'       > "$REPO/shell-common/dot-shrc"
printf '[core]\n\teditor = vim\n'                  > "$REPO/git/dot-gitconfig"

# --- stow's linking rule, reduced to its essentials ------------------------
# For each file in the package, create a symlink at the same relative path
# under the target dir, translating a leading "dot-" to ".".
stow_pkg() {
  local pkg="$1" target="$2" f rel link seg out
  while IFS= read -r f; do
    rel="${f#"$REPO/$pkg/"}"
    # stow --dotfiles translates a LEADING "dot-" in each path component
    # only, so a file named "not-dot-foo" is left alone.
    out=""
    while [ -n "$rel" ]; do
      seg="${rel%%/*}"
      case "$seg" in dot-*) seg=".${seg#dot-}" ;; esac
      out="${out:+$out/}$seg"
      [ "$rel" = "${rel#*/}" ] && break
      rel="${rel#*/}"
    done
    link="$target/$out"
    mkdir -p "$(dirname "$link")"
    ln -sfn "$f" "$link"
  done < <(find "$REPO/$pkg" -type f)
}

for host in mac-laptop linux-server; do
  case "$host" in
    mac-laptop)   os_pkg=shell-darwin ;;
    linux-server) os_pkg=shell-linux  ;;
  esac
  home="$SANDBOX/$host"; mkdir -p "$home"

  say "$host: stow common + git + $os_pkg"
  # This is the line a real user runs:  stow --dotfiles -t ~ shell-common git $os_pkg
  for p in shell-common git "$os_pkg"; do stow_pkg "$p" "$home"; done

  printf '  links created:\n'
  # find -printf is GNU-only; readlink -f is not on macOS. Stay portable.
  for l in "$home"/.*; do
    [ -L "$l" ] || continue
    printf '    %s -> %s\n' "$(basename "$l")" "$(readlink "$l")"
  done | sed "s|$REPO|\$REPO|" | sort

  printf '  effective ~/.shrc after sourcing:\n'
  # Show what the shell would actually load on this host.
  { cat "$home/.shrc.common"; cat "$home/.shrc.local"; } | sed 's/^/    | /'
done

say "The same repo, no conflict, no templating engine."
echo "Every host commits and pulls the identical tree; divergence lives in"
echo "WHICH packages a host stows, not in the contents of a shared file."
echo "Cost: the per-OS bits must be split into separate files up front, and"
echo "the choice of packages per host is not itself version-controlled --"
echo "you record it in a bootstrap script or type it on each new machine."

say "sandbox left at $SANDBOX"

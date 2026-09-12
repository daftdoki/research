#!/usr/bin/env bash
# Demonstrate the "bare git repo in $HOME" dotfiles technique in a sandbox,
# then show where it breaks down once two hosts need different content.
#
# Needs nothing but git. Touches only $SANDBOX; never the real $HOME.
set -euo pipefail

SANDBOX="${1:?usage: bare-repo-demo.sh <sandbox-dir>}"
rm -rf "$SANDBOX"; mkdir -p "$SANDBOX"

REMOTE="$SANDBOX/remote.git"
LAPTOP="$SANDBOX/mac-laptop"      # pretend macOS host
SERVER="$SANDBOX/linux-server"    # pretend Linux host

say() { printf '\n=== %s\n' "$*"; }

git init --quiet --bare "$REMOTE"

# dot() is the alias people put in .bashrc: git with an explicit git-dir and
# work-tree, so one repo can live alongside an unrelated $HOME.
dot() { local home="$1"; shift; git -c push.negotiate=false --git-dir="$home/.dotfiles" --work-tree="$home" "$@"; }

say "HOST 1 (macOS laptop): create the bare repo and commit a .gitconfig"
mkdir -p "$LAPTOP"
git init --quiet --bare "$LAPTOP/.dotfiles"
# Without this, `dot status` lists every file in $HOME as untracked.
dot "$LAPTOP" config status.showUntrackedFiles no
dot "$LAPTOP" config user.email demo@example.invalid
dot "$LAPTOP" config user.name "Demo"
printf '[core]\n\teditor = vim\n[user]\n\temail = me@home.example\n' > "$LAPTOP/.gitconfig"
printf 'export PATH="/opt/homebrew/bin:$PATH"\n' > "$LAPTOP/.bashrc"
# Unrelated junk that happens to live in $HOME and must NOT be committed:
mkdir -p "$LAPTOP/Downloads"; echo "huge" > "$LAPTOP/Downloads/movie.mkv"
dot "$LAPTOP" add .gitconfig .bashrc
dot "$LAPTOP" commit --quiet -m "initial dotfiles"
dot "$LAPTOP" remote add origin "$REMOTE"
dot "$LAPTOP" push --quiet -u origin master
say "status on host 1 (note: Downloads/movie.mkv is invisible, as intended)"
dot "$LAPTOP" status --short --branch

say "HOST 2 (Linux server): clone into a NON-empty \$HOME"
mkdir -p "$SERVER"
echo "pre-existing file that the clone must not clobber" > "$SERVER/.bashrc"
# The documented failure: checkout refuses to overwrite an existing .bashrc.
git clone --quiet --bare "$REMOTE" "$SERVER/.dotfiles"
if dot "$SERVER" checkout 2>"$SANDBOX/checkout.err"; then
  echo "checkout succeeded"
else
  echo "checkout FAILED as expected; git said:"
  sed 's/^/    | /' "$SANDBOX/checkout.err"
  echo "  -> you must back up/remove the conflicting files by hand first"
  mv "$SERVER/.bashrc" "$SERVER/.bashrc.backup"
  dot "$SERVER" checkout
  echo "  -> checkout succeeded after moving .bashrc aside"
fi
dot "$SERVER" config status.showUntrackedFiles no
dot "$SERVER" config user.email demo@example.invalid
dot "$SERVER" config user.name "Demo"

say "THE DIVERGENCE PROBLEM: the same file must differ per host"
# Linux host needs a different PATH and a different git email.
printf 'export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"\n' > "$SERVER/.bashrc"
sed -i 's/me@home.example/me@work.example/' "$SERVER/.gitconfig"
dot "$SERVER" commit --quiet -am "linux-specific PATH and work email"
dot "$SERVER" push --quiet origin master

say "back on host 1: pull the other host's commit"
# Host 1 meanwhile made its own edit to the same lines.
printf 'export PATH="/opt/homebrew/bin:$PATH"\nalias ll="ls -lG"\n' > "$LAPTOP/.bashrc"
dot "$LAPTOP" commit --quiet -am "mac: add ll alias"
dot "$LAPTOP" fetch --quiet origin
if dot "$LAPTOP" merge --no-edit origin/master >"$SANDBOX/merge.out" 2>&1; then
  echo "merge clean -- unexpected"
else
  echo "MERGE CONFLICT, which is the whole problem:"
  sed 's/^/    | /' "$SANDBOX/merge.out"
  echo
  echo "  .bashrc now contains conflict markers:"
  sed 's/^/    | /' "$LAPTOP/.bashrc"
  echo
  echo "  Nothing here is a mistake. Both edits are correct FOR THEIR HOST."
  echo "  Plain git has no way to say 'this line is per-OS', so every sync"
  echo "  re-litigates it. That is the gap tools like chezmoi/yadm fill."
fi

say "sandbox left at $SANDBOX"

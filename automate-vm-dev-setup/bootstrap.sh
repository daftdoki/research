#!/usr/bin/env bash
# devvm layer-1 bootstrap
#
# Installs ansible and runs ansible-pull against the config repo. Designed to
# be invoked from cloud-init runcmd or by hand over SSH:
#
#     curl -fsSL https://raw.githubusercontent.com/me/devvm-config/main/bootstrap.sh | sudo bash
#
# Secrets are read from /etc/devvm/bootstrap.env (written by cloud-init) or
# from the environment of the invoking shell. Non-secret config lives in the
# playbook's group_vars.

set -euo pipefail

log() { printf '[bootstrap] %s\n' "$*" >&2; }

# ---- 1. Load config -------------------------------------------------------
ENV_FILE="${DEVVM_ENV_FILE:-/etc/devvm/bootstrap.env}"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

: "${CONFIG_REPO:?CONFIG_REPO must be set (git URL of the playbook repo)}"
CONFIG_BRANCH="${CONFIG_BRANCH:-main}"
PLAYBOOK="${PLAYBOOK:-site.yml}"
ANSIBLE_TAGS="${ANSIBLE_TAGS:-}"

# Secrets injected from the environment. Any of these may be empty on the
# first run if the role will fetch them from a secrets manager later.
: "${TS_OAUTH_CLIENT_SECRET:=}"
: "${ANTHROPIC_API_KEY:=}"
: "${GITHUB_TOKEN:=}"

# ---- 2. Install ansible ---------------------------------------------------
if ! command -v ansible-pull >/dev/null 2>&1; then
    log "installing ansible via pipx"
    DEBIAN_FRONTEND=noninteractive apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        git pipx python3-venv ca-certificates
    pipx ensurepath --global
    PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin \
        pipx install --global "ansible-core>=2.17"
fi

# ---- 3. Install required Ansible collections -----------------------------
# ansible-pull will also do this if requirements.yml exists, but doing it
# here catches errors earlier and lets us cache between runs.
log "installing ansible collections"
ansible-galaxy collection install -r "$(mktemp --suffix=.yml <<'EOF'
collections:
  - name: community.general
  - name: community.docker
  - name: ansible.posix
  - name: artis3n.tailscale
EOF
)"

# ---- 4. Run ansible-pull --------------------------------------------------
# ansible-pull clones the repo, then runs the playbook locally against
# localhost. This is the canonical pattern for self-configuring nodes.
log "running ansible-pull from $CONFIG_REPO ($CONFIG_BRANCH)"

EXTRA_VARS=()
[[ -n "$TS_OAUTH_CLIENT_SECRET" ]] && EXTRA_VARS+=(-e "ts_oauth_client_secret=$TS_OAUTH_CLIENT_SECRET")
[[ -n "$ANTHROPIC_API_KEY"      ]] && EXTRA_VARS+=(-e "anthropic_api_key=$ANTHROPIC_API_KEY")
[[ -n "$GITHUB_TOKEN"           ]] && EXTRA_VARS+=(-e "github_token=$GITHUB_TOKEN")

TAG_ARGS=()
[[ -n "$ANSIBLE_TAGS" ]] && TAG_ARGS+=(--tags "$ANSIBLE_TAGS")

ansible-pull \
    -U "$CONFIG_REPO" \
    -C "$CONFIG_BRANCH" \
    -d /var/lib/devvm/repo \
    -i localhost, \
    --connection=local \
    "${TAG_ARGS[@]}" \
    "${EXTRA_VARS[@]}" \
    "$PLAYBOOK"

log "bootstrap complete"

#!/usr/bin/env bash
# Simplified replica of anthropics/claude-code/.devcontainer/init-firewall.sh.
# Installs a default-deny outbound firewall, allowing only the endpoints
# Claude Code actually needs. Run once at container start, then agent user
# proceeds with `claude --dangerously-skip-permissions`.
#
# In production, copy the upstream file verbatim from
# https://github.com/anthropics/claude-code/blob/main/.devcontainer/init-firewall.sh

set -euo pipefail

# Allowed destinations. Add to this list judiciously.
# Note: registry.npmjs.org was dropped when Claude Code switched from an npm
# package to a standalone Bun-compiled binary. The agent image bakes the
# binary in at build time, so no npm install happens at runtime.
ALLOWED_DOMAINS=(
    api.anthropic.com
    statsig.com
    statsig.anthropic.com
    sentry.io
    github.com
    api.github.com
    objects.githubusercontent.com
    codeload.github.com
    pypi.org
    files.pythonhosted.org
    archive.ubuntu.com
    security.ubuntu.com
)

ipset create -exist allowed-domains hash:ip

# Flush any previous state
iptables -F OUTPUT
iptables -P OUTPUT DROP

# Always allow loopback and established connections
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# DNS is required in order to resolve allowed domains in the first place.
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Resolve each domain and add to the ipset
for domain in "${ALLOWED_DOMAINS[@]}"; do
    for ip in $(getent ahosts "$domain" | awk '{print $1}' | sort -u); do
        ipset add allowed-domains "$ip" 2>/dev/null || true
    done
done

iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT

echo "[init-firewall] default-deny outbound enabled, ${#ALLOWED_DOMAINS[@]} domains allowlisted"

# Sandboxed Claude Code agent container.
#
# Modeled on Anthropic's reference devcontainer:
#   https://github.com/anthropics/claude-code/tree/main/.devcontainer
#
# Hardening:
#   - runs as an unprivileged "agent" user
#   - init-firewall.sh installs an ipset-based default-deny outbound firewall,
#     allowing only api.anthropic.com, registry.npmjs.org, github.com, and a
#     handful of other required endpoints
#   - /workspace is the only writable host bind-mount
#
# Once inside, running `claude --dangerously-skip-permissions` is safe
# because the container is its own blast radius.

FROM node:22-bookworm

ARG TZ=UTC
ENV TZ=$TZ

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates sudo iptables ipset dnsutils jq less \
        python3 python3-pip python3-venv \
        build-essential \
        ttyd \
    && rm -rf /var/lib/apt/lists/*

# Claude Code
RUN npm install -g @anthropic-ai/claude-code

# Unprivileged agent user. uid/gid 1000 matches the host-side devvm user
# so bind-mounted directories (the per-agent /workspace and the shared
# working directory) are readable and writable without chown dance.
# NOPASSWD sudo is scoped to the firewall boot step only.
RUN userdel -r node 2>/dev/null || true \
 && useradd -m -s /bin/bash -u 1000 agent \
 && echo 'agent ALL=(root) NOPASSWD: /usr/local/sbin/init-firewall.sh' > /etc/sudoers.d/agent-firewall

# Firewall script (verbatim from anthropics/claude-code/.devcontainer/init-firewall.sh
# in production; stub shown here for portability of the research example).
COPY init-firewall.sh /usr/local/sbin/init-firewall.sh
RUN chmod 0755 /usr/local/sbin/init-firewall.sh

# Entrypoint runs the firewall setup first, then drops into whatever command
# docker-compose passed (typically ttyd wrapping claude code).
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

USER agent
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash", "-l"]

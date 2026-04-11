# Sandboxed Claude Code agent container.
#
# Modeled on Anthropic's reference devcontainer:
#   https://github.com/anthropics/claude-code/tree/main/.devcontainer
#
# Hardening:
#   - runs as an unprivileged "agent" user (uid 1000 matches host)
#   - init-firewall.sh installs an ipset-based default-deny outbound firewall,
#     allowing only api.anthropic.com, github.com, and a handful of other
#     required endpoints (no longer needs registry.npmjs.org since Claude
#     Code is a standalone Bun-compiled binary, not an npm package)
#   - /workspace is the per-agent scratch bind-mount; /home/{{ devvm_user }}/work
#     is the shared hand-off directory bind-mounted at the same absolute path
#     the host uses, so files produced here are immediately visible over SSH
#     and inside code-server
#
# Once inside, running `claude --dangerously-skip-permissions` is safe
# because the container is its own blast radius.
#
# Base image is now ubuntu:24.04 (not node:22) because the Claude Code native
# installer ships a standalone Bun-compiled binary - no Node.js required.

FROM ubuntu:24.04

ARG TZ=UTC
ENV TZ=$TZ
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates sudo iptables ipset dnsutils jq less \
        python3 python3-pip python3-venv \
        build-essential \
        ttyd \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

# Unprivileged agent user. uid/gid 1000 matches the host-side devvm user
# so bind-mounted directories (the per-agent /workspace and the shared
# working directory) are readable and writable without chown dance.
# Ubuntu 24.04 already has a built-in `ubuntu` user at uid 1000, which we
# rename to `agent` rather than recreate.
# NOPASSWD sudo is scoped to the firewall boot step only.
RUN if id ubuntu >/dev/null 2>&1; then \
        usermod -l agent -d /home/agent -m ubuntu \
        && groupmod -n agent ubuntu; \
    else \
        useradd -m -s /bin/bash -u 1000 agent; \
    fi \
 && echo 'agent ALL=(root) NOPASSWD: /usr/local/sbin/init-firewall.sh' > /etc/sudoers.d/agent-firewall

# Claude Code native installer. Drops a standalone Bun-compiled `claude`
# binary into ~/.local/bin. The installer auto-updates in the background at
# runtime, but because the agent firewall blocks outbound to the update
# endpoint by default, we consider the baked-in version the pinned version
# until the image is rebuilt by the next ansible-pull.
USER agent
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/home/agent/.local/bin:${PATH}"

USER root

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

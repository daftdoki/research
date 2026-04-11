# Custom code-server image that bakes in Claude Code so the `claude` CLI is
# available inside the VS Code integrated terminal alongside a full dev tool
# chain managed by mise.
#
# Built by docker compose from the rendered compose file in the containers
# role; rebuilt on each `ansible-pull` run so it tracks upstream updates.
#
# Why a custom image instead of installing at startup:
#   - deterministic start time (no npm install on every boot)
#   - image is cached and portable
#   - watchtower can still pull the upstream codercom/code-server base
#     during its update window; the next ansible-pull run rebuilds on top.

ARG CODE_SERVER_VERSION=latest
FROM codercom/code-server:${CODE_SERVER_VERSION}

USER root

# Node.js (required for the Claude Code CLI) plus a handful of things that
# match the SSH shell experience so the integrated terminal feels identical.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git sudo jq unzip \
        python3 python3-venv python3-pip pipx \
        build-essential \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Claude Code CLI - baked in so `which claude` works in the integrated terminal.
RUN npm install -g @anthropic-ai/claude-code

# mise for the same reason: the user's Python/uv/Go/Rust toolchains managed
# on the host by the `mise` Ansible role are also usable here. When the home
# directory is bind-mounted into this container, the mise state in
# ~/.local/share/mise is shared too, so `python`, `uv`, `node`, etc. all
# resolve to the same versions the SSH shell sees.
RUN curl -fsSL https://mise.run | sh \
    && mv /root/.local/bin/mise /usr/local/bin/mise

# The coder user is the default uid 1000 in the upstream image. Activate
# mise for its shell so the integrated terminal picks it up automatically.
RUN printf '\n# mise\nexport PATH="$HOME/.local/bin:$PATH"\neval "$(mise activate bash)"\n' \
        >> /home/coder/.bashrc

USER coder

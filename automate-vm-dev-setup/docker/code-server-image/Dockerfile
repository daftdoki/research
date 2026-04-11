# Custom code-server image.
#
# The only job of this image is to reshape the upstream `codercom/code-server`
# user so its $HOME matches the host's /home/{{ devvm_user }}. Once we bind
# mount the host home directory into the container, the integrated terminal
# reads the host's `.bashrc`, the host's mise install in ~/.local/share/mise,
# the host's Claude Code binary in ~/.local/bin/claude (installed by the
# `dev_tools` Ansible role via the official native installer), and the host's
# chezmoi-managed dotfiles. Nothing needs to be duplicated inside the image.
#
# That means:
#   - NO nodejs / npm install (Claude Code is a standalone Bun-compiled binary
#     now, so the code-server container no longer needs Node at all for the
#     `claude` command)
#   - NO @anthropic-ai/claude-code npm global (the host install is shared)
#   - NO in-image mise install (the host install is shared)
#
# The image is rebuilt on every `ansible-pull` so it tracks upstream
# code-server releases naturally.

ARG CODE_SERVER_VERSION=latest
FROM codercom/code-server:${CODE_SERVER_VERSION}

USER root

ARG DEVVM_USER=me
ARG DEVVM_UID=1000

# Rename the built-in `coder` user to the host dev user so $HOME inside the
# container lines up with the bind-mounted host home directory at the same
# absolute path. This is what makes `source ~/.bashrc` just work and lets
# mise/claude resolve naturally via PATH.
RUN if id coder >/dev/null 2>&1; then \
        usermod -d "/home/${DEVVM_USER}" -l "${DEVVM_USER}" coder \
        && groupmod -n "${DEVVM_USER}" coder || true; \
    fi \
 && install -d -m 0755 -o "${DEVVM_USER}" -g "${DEVVM_USER}" "/home/${DEVVM_USER}"

USER ${DEVVM_USER}
ENV HOME=/home/${DEVVM_USER}
WORKDIR /home/${DEVVM_USER}

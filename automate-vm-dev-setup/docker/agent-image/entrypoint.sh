#!/usr/bin/env bash
set -euo pipefail

# One-shot firewall install. Needs root, hence sudoers rule.
sudo /usr/local/sbin/init-firewall.sh

exec "$@"

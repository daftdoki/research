[lazydocker](https://github.com/jesseduffield/lazydocker) is the pick for most people. It is the only Docker TUI that both brings Compose projects up and down and reads the active docker context, it ships in Homebrew core with 44,000 installs a year, and it recovered from the Docker Engine 29 API break in four days. That break in November 2025 is the clearest way to tell which of the fifteen tools surveyed still have a maintainer; ctop, the second most starred, has had no commit since 2022.

Three alternatives for specific needs:
- [dtop](https://github.com/amir20/dtop) for monitoring several hosts, from the Dozzle author
- podman-tui for Podman, maintained by the containers org
- dry for Swarm, or SSH remotes without docker contexts

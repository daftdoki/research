Syncing dotfiles across macOS and Linux requires choosing a solution that matches your actual divergence rather than feature-creeping. Four practical patterns emerge: bare git for nearly-identical configs, GNU Stow packages for whole-file differences, [chezmoi](https://github.com/twpayne/chezmoi) for in-file content divergence and per-file encrypted secrets, and home-manager for declarative machine configuration if you embrace Nix. The default recommendation is chezmoi as a single static binary that handles cross-OS path splits (e.g., Homebrew's three different prefixes), template rendering, and password-manager lookups without bootstrap requirements; [yadm](https://github.com/yadm-dev/yadm) is the runner-up for those preferring a plain-git workflow with elegant filename-based alternates.

- **Four solution shapes**: bare git, Stow packages, chezmoi (templating), or home-manager (Nix-based)
- **macOS trap**: hostname is unpredictable; use `scutil --get ComputerName` or declare your own label instead
- **Homebrew trap**: three different prefixes across Intel Mac, Apple Silicon, and Linux require conditional setup
- **Chezmoi advantages**: zero bootstrap, per-file encrypted secrets, 17 password-manager integrations, template-based divergence
- **Yadm advantages**: plain-git workflow, elegant `##os.Darwin` file alternates, no templating overhead

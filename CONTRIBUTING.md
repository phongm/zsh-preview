# Contributing to zsh-preview

Thanks for your interest in improving zsh-preview! This guide covers how to set up a development environment, the conventions the code follows, and how to submit changes.

## Development setup

1. Fork and clone the repository:

```bash
git clone https://github.com/<YOUR_GITHUB_USERNAME>/zsh-preview
cd zsh-preview
```

2. Load the plugin in a throwaway shell without touching your real `~/.zshrc`:

```zsh
zsh -f
source ./zsh-preview.plugin.zsh
```

`zsh -f` starts Zsh with no startup files, so you can test the plugin in isolation. Define a few test aliases first:

```zsh
alias gco='git checkout'
alias gcm='git commit -m'
alias dps='docker ps'
```

3. Alternatively, symlink the repo into your Oh My Zsh custom plugins directory and add it to `plugins` for a full integration test:

```bash
ln -s "$PWD" ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-preview
```

## Code conventions

- **Naming.** Internal functions and widgets are prefixed with `_ap_` (or `_alias_preview_` for the original hook) to avoid colliding with the user's shell. Keep this prefix for anything new that is not meant to be user-facing.
- **State variables.** Global state is declared with a bare `typeset -g` (no `=value`) so that re-sourcing the plugin does not wipe runtime state. Follow the same pattern and guard one-time setup with a sentinel flag (see `_ap_originals_saved`).
- **Key bindings.** Always save the original widget before rebinding and fall back to it when the menu is inactive, so normal editing is never interrupted.
- **Portability.** Stick to features available in a reasonably recent Zsh; avoid Bashisms and external dependencies beyond coreutils.

## Testing

ZLE widgets are hard to unit-test, but the core logic can be exercised non-interactively by mocking `zle`:

```zsh
zsh -f
zle() { [[ $1 == -M ]] && print -r -- "$2"; }   # capture message output
source ./zsh-preview.plugin.zsh
alias gco='git checkout'
BUFFER='gco'; LASTWIDGET=self-insert
_preview_alias_message                              # triggers the hook logic
```

Before submitting a change, please verify it in a real interactive shell too — source the plugin, type a partial alias, and confirm the menu, digit insertion, and arrow-key navigation all behave.

## Pull requests

1. Create a topic branch from `main` (e.g. `git checkout -b fix/menu-flicker`).
2. Keep changes focused; one concern per PR.
3. Follow the existing code style (2-space indent, lowercase function names).
4. Describe what the change does and how you tested it.
5. Update the README (both `README.md` and `README_zh-CN.md`) if your change affects usage or configuration.

## Issues

Bug reports are welcome. Please include:

- Your Zsh version (`zsh --version`) and OS.
- Your terminal emulator.
- A minimal set of aliases that reproduces the problem.
- What you expected vs. what happened.

## License

By contributing, you agree that your contributions will be licensed under the project's [MIT License](./LICENSE).

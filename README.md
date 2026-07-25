# zsh-preview

An interactive alias finder for [Zsh](https://www.zsh.org/). As you type a command, it fuzzy-matches your aliases and shows the most relevant ones right in the terminal — then lets you pick one with a single keystroke.

<!-- Demo GIF coming soon -->
> 🎬 *Demo GIF coming soon.*

If you rely on short aliases (`gco`, `gcm`, `dps`, …) but can never remember exactly which one does what, this plugin shows you the top matches live and lets you insert one instantly — no more guessing, no more `alias | grep`.

## Features

- **Live fuzzy suggestions.** As you type, the top 5 most relevant aliases are shown in the message area, ranked by relevance: exact match > prefix > substring > subsequence.
- **Numbered candidates.** Each suggestion is numbered `1`–`5`; press the matching digit to insert it immediately.
- **Arrow-key selection.** Press `↓` to engage the menu, navigate with `↑`/`↓`, and confirm with `Tab`.
- **Non-intrusive.** Until you engage the menu with `↓`, `↑` still navigates your shell history, and digits/`Tab` behave normally when no menu is shown.
- **Command filter.** Only suggest aliases that expand to commands you care about (e.g. `git`, `docker`).
- **Smart dismissal.** After you insert an alias, the menu hides and reappears only when you edit the word again.

## Usage

Type the beginning of an alias. A numbered menu appears:

```
   1. gc: git commit --verbose
   2. gcs: git commit --gpg-sign
   3. gcp: git cherry-pick
   4. gco: git checkout
   5. gcn: git commit --verbose --no-edit
```

Then choose one of three ways:

| Action | Key |
| --- | --- |
| Insert suggestion #N directly | `1` … `5` |
| Engage the menu / move selection down | `↓` |
| Move selection up | `↑` (after engaging) |
| Insert the highlighted suggestion | `Tab` |
| Navigate shell history | `↑` (before engaging the menu) |

The selected **alias name** is inserted into your command line (e.g. `gco`), preserving anything you already typed after it — press `Enter` to run it as usual.

## Installation

### Oh My Zsh

1. Clone this repo into your custom plugins directory:

```bash
git clone https://github.com/<YOUR_GITHUB_USERNAME>/zsh-preview \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-preview
```

2. Add `zsh-preview` to the `plugins` array in your `~/.zshrc`:

```zsh
plugins=(git zsh-preview)
```

3. Reload your shell:

```bash
source ~/.zshrc
```

### Manual (any Zsh setup)

Clone the repo and source the plugin file from your `~/.zshrc`:

```zsh
source /path/to/zsh-preview/zsh-preview.plugin.zsh
```

## Configuration

### `ALIAS_PREVIEW_COMMANDS`

Only aliases whose expansion starts with one of these commands are suggested. Defaults to `git docker`. Edit the array at the top of `zsh-preview.plugin.zsh`:

```zsh
typeset -ga ALIAS_PREVIEW_COMMANDS=(git docker)
```

For example, `gco='git checkout'` is suggested (`git` matches), while `ll='ls -alF'` is not — unless you add `ls` to the list.

### `ALIAS_PREVIEW_MAX`

Maximum number of suggestions to display (default `5`). You can override it in your `~/.zshrc` **before** the plugin loads:

```zsh
ALIAS_PREVIEW_MAX=8
```

## How it works

The plugin hooks Zsh's `line-pre-redraw` event to refresh the suggestion list on every keystroke. It scores every alias against the word you are typing — exact matches rank highest, then prefix, substring, and finally subsequence (fuzzy) matches — and keeps the top `ALIAS_PREVIEW_MAX`. Selection is handled by lightweight ZLE widgets that fall back to your original key bindings whenever the menu is not active, so normal editing is never interrupted.

## Compatibility

- Zsh (tested with [Oh My Zsh](https://ohmyz.sh/); works with any Zsh configuration)
- Plays nicely with `zsh-autosuggestions` and `zsh-syntax-highlighting`

## License

[MIT](./LICENSE)

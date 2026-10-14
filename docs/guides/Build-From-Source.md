# Build From Source

Run these commands in order and stop if one fails.

```bash
git clone https://github.com/itwasallcode/default-app-switcher.git "$HOME/.default-app-switcher"
cd "$HOME/.default-app-switcher"
make build
```

Add this line once to the startup file for your shell.

```bash
export PATH="$HOME/.default-app-switcher/dist:$PATH"
```

| Shell | Startup File |
| --- | --- |
| `zsh` | `${ZDOTDIR:-$HOME}/.zshrc` |
| Login `bash` | `~/.bash_profile`, or an existing `~/.bash_login` or `~/.profile` |
| Non-login `bash` | `~/.bashrc` |

For other shells, use their `PATH` syntax.

Open a new terminal, or reload the file you edited to update your current terminal.

For `zsh`, reload the file with `source "${ZDOTDIR:-$HOME}/.zshrc"`.

Then check the active command and run `das`.

```bash
command -v das && das --version
das
```

Keep `dist/das` and `dist/das-helper.app` together.

Moving the clone or running `make clean` makes this source installation unavailable.

When both methods are installed, `command -v das` shows which one will run.

## Optional Update

To use newer source changes, pull them into a clean clone and rebuild.

Stop if any command fails.

```bash
cd "$HOME/.default-app-switcher"
git pull --ff-only
make build
```

## Remove

Remove the source `PATH` line from your shell configuration, then open a new terminal.

Delete the clone if you no longer need it.

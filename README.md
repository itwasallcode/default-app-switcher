# Default App Switcher

Switch macOS default applications from the terminal.

## Preview

<img src="docs/assets/preview.png" alt="Default App Switcher" width="500" />

## Installation

### Requirements

- `macOS 14.5` or later to build and install.
- `Xcode Command Line Tools` with `Swift 6` or later.
- `Git` and `make` for building from source.

Install missing command line tools with `xcode-select --install`.

### Quick Start

Run this command in your terminal to download and build the latest published release.

```bash
curl -fsSL https://raw.githubusercontent.com/itwasallcode/default-app-switcher/master/scripts/install.sh | bash
```

Open a new terminal and run `das` to choose an app; use `das --help` or `das --version` for details.

_If `das` is not found, follow the installer's instructions to add `$HOME/.local/bin` to your shell's `PATH`._

#### Update

Run the installation command again to update to the latest release.

#### Uninstall

To uninstall the release installation, run:

```bash
curl -fsSL https://raw.githubusercontent.com/itwasallcode/default-app-switcher/master/scripts/install.sh | bash -s -- --uninstall
```

This removes the installed files and command link; your default apps and shell configuration are preserved.

### Build From Source

Follow the [Build From Source](docs/guides/Build-From-Source.md) guide to build, update or remove a source installation.

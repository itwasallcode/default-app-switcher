# Contributing

This document contains some information about development and contributing.

## Requirements

- `macOS 12` or later.
- `Git` and `make`.
- `Xcode Command Line Tools` with `Swift 6` or later.

Install missing command line tools with `xcode-select --install`.

## Clone And Build

```bash
git clone https://github.com/itwasallcode/default-app-switcher.git && cd default-app-switcher && make build
```

## Run

Run the app in an interactive macOS terminal.

```bash
make run
```

## Check Changes

Apply Swift formatting after editing code.

```bash
make format
```

Run lint, check formatting, test, and build in that order.

```bash
make check
```

Run both commands to check formatted changes.

```bash
make format && make check
```

Run `make run` again to check the result manually.

## Commits & Pull Requests

- Use English `Conventional Commits` titles for commits and pull requests.

## Notes

- The build creates `dist/das` and `dist/das-helper.app` without adding a global `das` command.
- Automated tests do not change macOS defaults; verify assignment behavior manually.

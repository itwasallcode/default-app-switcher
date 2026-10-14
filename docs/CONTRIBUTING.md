# Contributing

See the [installation guide](../README.md#installation) for requirements and setup.

## Run

Build and run your checkout.

```bash
make run
```

## Check Changes

Run `make check` to lint, check formatting, test and build.

```bash
make check
```

`make format` edits Swift files.

After editing Swift code, format it before checking.

```bash
make format && make check
```

Run `make run` again to check the result manually.

Automated tests do not change macOS defaults; verify assignment behavior manually.

## Commits & Pull Requests

- Use English `Conventional Commits` titles for commits and pull requests.

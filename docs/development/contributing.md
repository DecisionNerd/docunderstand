# Contributing

Contributions are welcome! Please open an issue or pull request on [GitHub](https://github.com/DecisionNerd/docunderstand).

## Setup

```bash
git clone https://github.com/DecisionNerd/docunderstand
cd docunderstand
uv sync --all-extras
pre-commit install
```

## Running checks

```bash
make pre-push
```

## Pull request guidelines

- Update `CHANGELOG.md` under `[Unreleased]` for any user-facing changes.
- Add tests for new functionality.
- Ensure `make pre-push` passes before opening a PR.

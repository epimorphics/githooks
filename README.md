# Epimorphics Git Hooks

Shared git hooks and local tooling for Epimorphics projects.

## Contents

- [Overview](#overview)
- [Hook versions](#hook-versions)
- [Installation](#installation)
  - [Streamlined installation](#streamlined-installation)
  - [Manual installation](#manual-installation)
- [Skipping hooks](#skipping-hooks)
- [Removing hooks](#removing-hooks)
- [Local tooling](#local-tooling)
  - [Changelog generation](#changelog-generation)

---

## Overview

This repository provides versioned git hook scripts that can be installed into
any Epimorphics project. Once installed, the hooks run automatically at key
points in the git workflow:

| Hook | When it runs | What it does |
|---|---|---|
| `pre-commit` | Before each commit | Lints Ruby files; aborts the commit if linting fails |
| `post-commit` | After each commit | Runs the test suite; resets[^1] if tests fail |
| `pre-push` | Before each push | Builds and verifies Docker images; blocks the push if the build fails |

[^1]: Reset uses `HEAD^` to find the first parent ref of `HEAD`.

---

## Hook versions

Three versions of the hooks are available under `hooks/`:

| Version | Notes |
|---|---|
| [`hooks/v1/`](hooks/v1/README.md) | Original hooks — `pre-commit` and `pre-push` only |
| [`hooks/v2/`](hooks/v2/README.md) | Adds `post-commit`; supports branch-based skip list |
| [`hooks/v3/`](hooks/v3/README.md) | Current version — shared utilities extracted to `common.sh` |

Use **v3** for all new projects unless there is a specific reason to use an
earlier version.

---

## Installation

### Streamlined installation

The `makehooks.sh` script (or `make hooks`) handles installation automatically.
It clones this repository into a temporary directory, copies the hooks, sets
permissions, configures git, and commits the result.

**Prerequisites:** the target repository must have a `package.json` with a
`"name"` field.

Run the following from the root of the target repository:

```sh
curl -fsSL https://raw.githubusercontent.com/epimorphics/githooks/main/makehooks.sh | sh
```

Or, if you have already copied `makehooks.sh` into the target repository:

```sh
sh makehooks.sh
```

Or, if the target repository has this repository's `Makefile`:

```sh
make hooks
```

The script will:

1. Clone `git@github.com:epimorphics/githooks.git` into a temp directory
2. Copy the `hooks/` directory to `.githooks/` in the target repository
3. Strip the `.sh` extension from each hook file and make it executable
4. Set `core.hooksPath` to `.githooks` in the local git config
5. Stage and commit the new hooks

### Manual installation

If you prefer to install the hooks by hand:

1. Create the `.githooks` directory and copy the hooks:

    ```sh
    mkdir -p ./.githooks
    cp -R hooks/v3/* ./.githooks/
    ```

2. Make the hook files executable:

    ```sh
    chmod +x .githooks/pre-commit .githooks/post-commit .githooks/pre-push
    ```

3. Point git at the hooks directory:

    ```sh
    git config core.hooksPath '.githooks'
    ```

4. Stage and commit:

    ```sh
    git add .githooks
    git commit -m "chore(hooks): add Epimorphics git hooks"
    ```

---

## Skipping hooks

To bypass hooks on a single commit or push, use the `--no-verify` flag:

```sh
git commit --no-verify -m "your message"
git push --no-verify
```

The v2 and v3 hooks also skip automatically on the following branches:

- `hotfix`
- `rebase`
- `production`

---

## Removing hooks

Delete the `.githooks` directory from the target repository and unset the git
config entry:

```sh
rm -rf .githooks
git config --unset core.hooksPath
```

---

## Local tooling

### Changelog generation

`generate_changelog_local.sh` generates a `CHANGELOG.md` from the repository's
git history, following [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
and [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
conventions.

Run it via Make from the root of this repository:

```sh
make changelog
```

The script will:

1. Fetch the latest tags
2. Collect commits not yet recorded in `CHANGELOG.md`
3. Group them into Keep a Changelog sections (`Added`, `Changed`, `Fixed`, etc.)
4. Warn about any suspected duplicate entries (using word-overlap similarity)
5. Display the proposed entries for review
6. Prompt for confirmation before writing to `CHANGELOG.md`

> **Note:** The script must be run locally — it will abort if no TTY is
> detected (e.g. in a CI pipeline).

#### References

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- [Git hooks documentation](https://git-scm.com/docs/githooks)

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and to [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## Unreleased

### Added

- feat(build): introduce Makefile for common automation tasks
  [`c826660`](git@github.com:epimorphics/githooks/commit/c826660)
- feat(githooks): implement pre-push hook for Docker verification
  [`169a639`](git@github.com:epimorphics/githooks/commit/169a639)
- feat(githooks): implement post-commit hook for testing
  [`67df031`](git@github.com:epimorphics/githooks/commit/67df031)
- feat(githooks): implement pre-commit hook for linting
  [`923bb72`](git@github.com:epimorphics/githooks/commit/923bb72)
- feat(githooks): add common utilities for hooks
  [`14d2ac8`](git@github.com:epimorphics/githooks/commit/14d2ac8)
- feat(changelog): implement local changelog generation
  [`d6330c0`](git@github.com:epimorphics/githooks/commit/d6330c0)
- feat(hooks): enhance pre-push hook with Ruby and JS test detection
  [`0facea5`](git@github.com:epimorphics/githooks/commit/0facea5)
- feat: update to check for specific file types to test
  [`6f00fc8`](git@github.com:epimorphics/githooks/commit/6f00fc8)

### Changed

- refactor(hooks): relocate git hooks installation directory
  [`ccbdf0c`](git@github.com:epimorphics/githooks/commit/ccbdf0c)
- refactor(githooks): relocate hook scripts to top-level directory
  [`c30ae43`](git@github.com:epimorphics/githooks/commit/c30ae43)
- build: added shell script as alternative installation method
  [`62cf30e`](git@github.com:epimorphics/githooks/commit/62cf30e)
- build: intial creation of hook files
  [`a79556a`](git@github.com:epimorphics/githooks/commit/a79556a)
- ci(hooks): add pre-push Docker image validation hook
  [`37bef4f`](git@github.com:epimorphics/githooks/commit/37bef4f)
- ci(hooks): add post-commit test runner hook
  [`c5d24ef`](git@github.com:epimorphics/githooks/commit/c5d24ef)
- ci(hooks): add pre-commit Ruby linting hook
  [`f932af9`](git@github.com:epimorphics/githooks/commit/f932af9)
- docs(changelog): add initial changelog file
  [`4e0a439`](git@github.com:epimorphics/githooks/commit/4e0a439)
- docs(githooks): add README for githooks setup and usage
  [`e0a0720`](git@github.com:epimorphics/githooks/commit/e0a0720)
- docs(hooks): add Git hooks setup guide
  [`2ae5d37`](git@github.com:epimorphics/githooks/commit/2ae5d37)
- docs(readme): revise hooks documentation and installation instructions
  [`b441f7e`](git@github.com:epimorphics/githooks/commit/b441f7e)
- docs: updated README
  [`9cead0f`](git@github.com:epimorphics/githooks/commit/9cead0f)
  [`c68297c`](git@github.com:epimorphics/githooks/commit/c68297c)
  [`43d4025`](git@github.com:epimorphics/githooks/commit/43d4025)
- chore(vscode): add recommended extensions file
  [`a15f599`](git@github.com:epimorphics/githooks/commit/a15f599)
- chore(hooks): move pre-commit.sh to hooks/v1
  [`01301cc`](git@github.com:epimorphics/githooks/commit/01301cc)

### Fixed

- fix: updated equality operator
  [`3752d30`](git@github.com:epimorphics/githooks/commit/3752d30)

### Other

- Initial commit
  [`1181b31`](git@github.com:epimorphics/githooks/commit/1181b31)


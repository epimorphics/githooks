.PHONY: hooks changelog

## Install Epimorphics git hooks into the target repository
hooks:
	@sh makehooks.sh

## Generate a CHANGELOG.md from git tags in the target repository
changelog:
	@sh generate_changelog_local.sh

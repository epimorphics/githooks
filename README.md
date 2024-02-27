# Adding Git Hooks

## Current Git Hooks

- Language: sh
- Path: ./hooks/pre-commit.sh
- Path: ./hooks/pre-push.sh

## Table of Contents

- [Streamlined Installation](#streamlined-installation)
- [Manual Installation](#manual-installation-instructions)
- [Skip the pre-commit hook](#to-skip-the-pre-commit-hook)
- [Skip the pre-push hook](#to-skip-the-pre-push-hook)
- [Remove hooks from repository](#remove-the-hooks-files-from-the-repository)

## Streamlined installation

1. Copy the [makehooks.sh](./makehooks.sh) file to the root of your repository
2. Open a command line in the root of your repository
3. To set permissions on the file, run the following command:

```sh
chmod +x makehooks.sh
```

4. To trigger the hook installation, run the following command:

```sh
sh makehooks
```

5. Push your latest commit with the newly installed hooks for your repository


## Manual Installation Instructions

1. Add the hooks to an existing repository

Copy this repository's `hooks` directory to the required repository's 
`.github` directory and remove the `.sh` suffix from each file; or, you can also 
add the files manually by creating each named `.github/hooks/pre-commit` and
`.github/hooks/pre-push` and then copy &amp; pasting the contents into their 
respective counterparts or writing your own version of each.

The contents of these files will be executed before each commit and push actions.

2. Set permissions on the hooks files

You will need to set the files to be executable by the shell by running the
following command in terminal from the root of the repository:

```sh
chmod +x .github/hooks/pre-commit && chmod +x .github/hooks/pre-push
```

3. Set the path in the repository gitconfig

```sh
# set the hooksPath config to point to a versioned directory:
git config core.hooksPath './.github/hooks'
```

## To skip the pre-commit hook

```sh
git commit -m "$COMMIT_MESSAGE" # the --no-verify flag will skip the pre-commit hook
```

## To skip the pre-push hook

```sh
git push origin $BRANCH # the --no-verify flag will skip the pre-push hook
```

## Remove the hooks files from the repository

Simply delete the files in the respository's `.github/hooks` directory and run:

```sh
git config --unset core.hooksPath
```

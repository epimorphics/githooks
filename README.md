# Adding Git Hooks

## Current Git Hooks

- Language: sh
- Path: ./hooks/pre-commit.sh
- Path: ./hooks/pre-push.sh

## 1. Add the hooks to an existing repository

Copy this repository's `hooks` directory to the required repository's 
`.github` directory and remove the `.sh` suffix from each file; or, you can also 
add the files manually by creating each named `.github/hooks/pre-commit` and
`.github/hooks/pre-push` and then copy &amp; pasting the contents into their 
respective counterparts or writing your own version of each.

The contents of these files will be executed before each commit and push actions.

## 2. Set permissions on the hooks files

You will need to set the files to be executable by the shell by running the
following command in terminal from the root of the repository:

```sh
chmod +x .github/hooks/pre-commit && chmod +x .github/hooks/pre-push
```

## 3. Set the path in the repository gitconfig

```sh
# set the hooksPath config to point to a versioned directory:
git config core.hooksPath './.github/hooks'
```

### To run the pre-commit hook

```sh
git commit -m "$COMMIT_MESSAGE" # the --no-verify flag will skip the pre-commit hook
```

### To run the pre-push hook

```sh
git push origin $BRANCH # the --no-verify flag will skip the pre-push hook
```

## Remove the hooks files from the repository

Simply delete the files in the respository's `.github/hooks` directory and run:

```sh
git config --unset core.hooksPath
```

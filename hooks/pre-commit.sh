#!/bin/sh
# caveat: this script assumes all modifications to a file were staged in the commit
# beware if you are in the habit of committing only partial modifications to a file:
# THIS HOOK WILL ADD ALL MODIFICATIONS TO A FILE TO THE COMMIT IF ANY FILE WAS CHANGED BY LINTING

list="issue spike task"

listRE="^($(printf '%s\n' "$list" | tr ' ' '|'))/"

BRANCH_NAME=$(git branch --show-current | grep -E "$listRE" | sed 's/* //')

printf '\n\033[0;105mChecking "%s"... \033[0m\n', "$BRANCH_NAME"

if echo "$BRANCH_NAME" | grep -q '^(rebase)|(production)*$'; then
 	printf '\n\033[0;32mNo checks necessary on "%s", pushing now... 🎉\033[0m\n', "$BRANCH_NAME"
	exit 0
fi

RUBY_FILES="$(git diff --diff-filter=d --name-only --cached | grep -E '(Gemfile|Rakefile|\.(rb|rake|ru))$')"
ESLINT_FILES="$(git diff --diff-filter=d --name-only --cached | grep -E '\.(js|js.erb|vue)$')"
PRETTIER_FILES="$(git diff --diff-filter=d --name-only --cached | grep -E '\.(css|scss|json|md)$')"
PRE_STATUS="$(git status | wc -l)"
WORK_DONE=0

if [ -n "$RUBY_FILES" ]; then
  printf '\nRunning Rubocop...'
  bundle exec rubocop --autocorrect "$RUBY_FILES"
  RUBOCOP_EXIT_CODE=$?
  WORK_DONE=1
else
  RUBOCOP_EXIT_CODE=0
fi

if [ -n "$PRETTIER_FILES" ]; then
  printf '\nRunning Prettier...'
  npx prettier app --write "$PRETTIER_FILES"
  PRETTIER_EXIT_CODE=$?
  WORK_DONE=1
else
  PRETTIER_EXIT_CODE=0
fi

if [ -n "$ESLINT_FILES" ]; then
  printf '\nRunning ESLint...'
  npx eslint app --fix "$ESLINT_FILES"
  ESLINT_EXIT_CODE=$?
  WORK_DONE=1
else
  ESLINT_EXIT_CODE=0
fi

POST_STATUS="$(git status | wc -l)"

if [ ! $RUBOCOP_EXIT_CODE -eq 0 ] || [ ! $ESLINT_EXIT_CODE -eq 0 ] || [ ! $PRETTIER_EXIT_CODE -eq 0 ]; then
  git reset HEAD
  printf '\n\033[0;31mLinting has unfixable errors; please fix and restage your commit. 😖\033[0m\n'
  exit 1
elif [ "$PRE_STATUS" != "$POST_STATUS" ]; then
  git add "$RUBY_FILES" "$ESLINT_FILES" "$PRETTIER_FILES"
fi

if [ $WORK_DONE == 1 ]; then
  printf '\n\033[0;32mLinting completed successfully! 🎉\033[0m\n'
fi

exit 0

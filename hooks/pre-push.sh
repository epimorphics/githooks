#!/bin/sh

list="issue spike task"

listRE="^($(printf '%s\n' "$list" | tr ' ' '|'))/"

BRANCH_NAME=$(git branch --show-current | grep -E "$listRE" | sed 's/* //')

printf '\n\033[0;105mChecking "%s"... \033[0m\n', "$BRANCH_NAME"

if echo "$BRANCH_NAME" | grep -q '^(rebase)|(production)*$'; then
 	printf '\n\033[0;32mNo checks necessary on "%s", pushing now... 🎉\033[0m\n', "$BRANCH_NAME"
	exit 0
fi

# Check for existence of "new or modified" test files
TEST_FILES="$(git diff --diff-filter=ACDM --name-only --cached | grep -E '(_test\.rb)$')"
WORK_DONE=0

if [ -z "$TEST_FILES" ]; then
  printf 'There are no new tests created in "%s".\n', "$BRANCH_NAME"
	while : ; do
    read -r 'Are you sure you want to continue (y/n)? ' RESPONSE < /dev/tty
    case "${RESPONSE}" in
      [Yy]* )
        printf '\n\033[0;31mContinuing without new tests... 😖\033[0m\n'
        # exit 0;;
        break;;
      [Nn]* )
        printf '\n\033[0;32mExiting now to allow tests to be added... 🎉\033[0m\n'
        exit 1;;
    esac
	done
fi


  if [ -n "$TEST_FILES" ]; then
    printf '\nRunning Rails Tests...'
    bundle exec rails test
    TEST_EXIT_CODE=$?
    WORK_DONE=1
  else
    TEST_EXIT_CODE=0
  fi

  if [ -n "$TEST_FILES" ]; then
    printf '\nRunning System Tests...'
    bundle exec rails test:system
    SYSTEM_EXIT_CODE=$?
    WORK_DONE=1
  else
    SYSTEM_EXIT_CODE=0
  fi

  if [ ! $TEST_EXIT_CODE -eq 0 ] || [ ! $SYSTEM_EXIT_CODE -eq 0 ]; then
    printf '\n\033[0;31mCannot push, tests are failing. Use --no-verify to force push. 😖\033[0m\n'
    exit 1
  fi

  if [ $WORK_DONE -eq 1 ]; then
    printf '\n\033[0;32mAll tests are green, pushing... 🎉\033[0m\n'
  fi

  exit 0

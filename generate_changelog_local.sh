#!/bin/sh

# Exit on error
set -e

# Error handling
trap 'echo "An error occurred at line $LINENO. Exiting."' ERR

# ─── Configuration ────────────────────────────────────────────────────────────

REPO_DIR="."
CHANGELOG_FILE="$REPO_DIR/CHANGELOG.md"
GITHUB_REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//')
if [ -z "$GITHUB_REPO_URL" ]; then
    GITHUB_REPO_URL=0
fi

# All recognised CC types — used to identify conventional commits
CC_TYPES="feat fix perf refactor style build ci docs chore gitops deploy test demo deprecated removed security"
CONVENTIONAL_COMMIT_REGEX="^.* (feat|fix|perf|refactor|style|build|ci|docs|chore|gitops|deploy|test|demo|deprecated|removed|security)(\(.*\))?: "

# Keep a Changelog section order
KAC_SECTIONS="Added Changed Deprecated Removed Fixed Security Other"

# ─── Single-purpose helpers ───────────────────────────────────────────────────

# Maps a CC type to its Keep a Changelog section name.
cc_to_kac_section() {
    case $1 in
        feat)                       echo "Added" ;;
        fix)                        echo "Fixed" ;;
        deprecated)                 echo "Deprecated" ;;
        removed)                    echo "Removed" ;;
        security)                   echo "Security" ;;
        perf|refactor|style|build|ci|docs|chore|gitops|deploy|test|demo) echo "Changed" ;;
    esac
}


# Writes the standard changelog preamble to a given file (creates/overwrites it).
write_changelog_header() {
    cat > "$1" << 'HEADER'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and to [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## Unreleased
HEADER
}

# Writes commits grouped into Keep a Changelog sections to a target file.
# CC type prefix is preserved in each entry's message text.
# Args: all_commits (newline-separated oneline log), target_file path.
write_commit_categories() {
    ALL_COMMITS="$1"
    TARGET_FILE="$2"
    FIRST_WRITTEN=1

    for SECTION in $KAC_SECTIONS; do
        if [ "$SECTION" = "Other" ]; then
            # Commits with no recognised CC prefix (excluding merge commits)
            SECTION_COMMITS=$(echo "$ALL_COMMITS" \
                | grep -v -E "$CONVENTIONAL_COMMIT_REGEX" \
                | grep -v -iE "^[^ ]+ Merge " || true)
        else
            # Collect all CC types that map to this KaC section
            SECTION_COMMITS=""
            for KEY in $CC_TYPES; do
                if [ "$(cc_to_kac_section "$KEY")" = "$SECTION" ]; then
                    MATCHING=$(echo "$ALL_COMMITS" | grep -E "^.* $KEY(\(.*\))?: " || true)
                    if [ -n "$MATCHING" ]; then
                        SECTION_COMMITS=$(printf '%s\n%s' "$SECTION_COMMITS" "$MATCHING")
                    fi
                fi
            done
            # Strip leading blank line from concatenation
            SECTION_COMMITS=$(echo "$SECTION_COMMITS" | sed '/^$/d')
        fi

        if [ -n "$SECTION_COMMITS" ]; then
            # Blank line before each section except the first
            if [ "$FIRST_WRITTEN" != "1" ]; then
                echo "" >> "$TARGET_FILE"
            fi
            FIRST_WRITTEN=0
            echo "### $SECTION" >> "$TARGET_FILE"
            echo "" >> "$TARGET_FILE"
            echo "Listing commits for section: $SECTION"
            echo "$SECTION_COMMITS" | awk -v url="$GITHUB_REPO_URL" '
            {
                hash = $1
                message = substr($0, length($1)+2)
                key = tolower(message)
                if (!(key in hashes)) {
                    order[++count] = key
                    display[key] = message
                    hashes[key] = hash
                } else {
                    hashes[key] = hashes[key] "|" hash
                }
            }
            END {
                for (i = 1; i <= count; i++) {
                    k = order[i]
                    printf "- %s\n", display[k]
                    if (url != "0") {
                        n = split(hashes[k], ha, "|")
                        for (j = 1; j <= n; j++) {
                            printf "  [`%s`](%s/commit/%s)\n", ha[j], url, ha[j]
                        }
                    }
                }
            }' >> "$TARGET_FILE"
        fi
    done
}

# Writes a section heading followed by categorised commits to a target file.
write_section() {
    ALL_COMMITS="$1"
    HEADING="$2"
    TARGET_FILE="$3"

    echo "$HEADING" >> "$TARGET_FILE"
    echo "" >> "$TARGET_FILE"
    write_commit_categories "$ALL_COMMITS" "$TARGET_FILE"
}

# Writes a tagged release section (heading + commits) directly to CHANGELOG_FILE.
write_tag_section() {
    TAG_FROM="$1"
    TAG_TO="$2"

    echo "Processing tag: $TAG_TO"
    TAG_DATE=$(git log -1 --format=%ai "$TAG_TO" | cut -d ' ' -f 1)

    if [ "$TAG_TO" = "HEAD" ]; then
        if [ "$(git rev-parse "$TAG_FROM")" != "$(git rev-parse HEAD)" ]; then
            echo "## Unreleased changes" >> "$CHANGELOG_FILE"
            echo "" >> "$CHANGELOG_FILE"
        fi
    else
        echo "## $TAG_TO ($TAG_DATE)" >> "$CHANGELOG_FILE"
        echo "" >> "$CHANGELOG_FILE"
    fi

    if [ -z "$TAG_FROM" ]; then
        ALL_COMMITS=$(git log "$TAG_TO" --oneline)
    else
        ALL_COMMITS=$(git log "$TAG_FROM".."$TAG_TO" --oneline)
    fi

    write_commit_categories "$ALL_COMMITS" "$CHANGELOG_FILE"
    echo "Completed processing tag: $TAG_TO"
}

# Returns commits whose short hashes do not already appear in CHANGELOG_FILE.
# Falls back to all commits when the file is absent, empty, or has no embedded
# hashes (e.g. written without a GitHub URL).
get_unrecorded_commits() {
    ALL_COMMITS=$(git log --oneline | grep -v -iE "^[^ ]+ Merge " || true)

    if [ ! -f "$CHANGELOG_FILE" ] || [ ! -s "$CHANGELOG_FILE" ]; then
        echo "$ALL_COMMITS"
        return
    fi

    KNOWN_HASHES=$(grep -oE '\`[0-9a-f]{7,40}\`' "$CHANGELOG_FILE" \
        | tr -d '`' | cut -c1-7 | sort -u)

    if [ -z "$KNOWN_HASHES" ]; then
        echo "$ALL_COMMITS"
        return
    fi

    echo "$ALL_COMMITS" | while read -r COMMIT; do
        HASH=$(echo "$COMMIT" | awk '{print $1}' | cut -c1-7)
        if ! echo "$KNOWN_HASHES" | grep -qx "$HASH"; then
            echo "$COMMIT"
        fi
    done
}

# Prints proposed entries to the terminal, prompts for approval,
# and appends to CHANGELOG_FILE if confirmed.
# Aborts immediately when not run from a TTY (e.g. CI).
prompt_and_append() {
    TEMP_FILE="$1"

    [ -t 0 ] || {
        echo "Not a TTY — aborting to avoid hanging in CI. Run this script locally."
        rm -f "$TEMP_FILE"
        exit 1
    }

    echo ""
    echo "--- Proposed unreleased entries ---"
    cat "$TEMP_FILE"
    echo "-----------------------------------"
    printf "Add these entries to %s? [y/N] " "$CHANGELOG_FILE"
    read -r ANSWER
    case "$ANSWER" in
        [Yy]|[Yy][Ee][Ss])
            printf '\n' >> "$CHANGELOG_FILE"
            cat "$TEMP_FILE" >> "$CHANGELOG_FILE"
            echo "Entries appended to $CHANGELOG_FILE."
            ;;
        *)
            echo "Aborted. No changes made to $CHANGELOG_FILE."
            ;;
    esac
    rm -f "$TEMP_FILE"
}

print_completion_notes() {
    echo "Reminder: Generated changelog entries are a starting point."
    echo "Please review and edit CHANGELOG.md before committing."
    echo "Done."
}

# ─── Main flow ────────────────────────────────────────────────────────────────

echo "Starting changelog generation script..."
echo "Repository: $GITHUB_REPO_URL"

cd "$REPO_DIR"
git fetch --tags
echo "Fetched latest tags."

TAGS=$(git tag --sort=-v:refname)

# ─── No-tags path ─────────────────────────────────────────────────────────────

if [ -z "$TAGS" ]; then
    echo "No tags found. Checking for unrecorded commits..."

    UNRECORDED=$(get_unrecorded_commits)

    if [ -z "$UNRECORDED" ]; then
        echo "All commits are already recorded in $CHANGELOG_FILE. Nothing to add."
        print_completion_notes
        exit 0
    fi

    if [ ! -f "$CHANGELOG_FILE" ] || [ ! -s "$CHANGELOG_FILE" ]; then
        write_changelog_header "$CHANGELOG_FILE"
    fi

    TEMP_FILE=$(mktemp)
    if grep -q "^## Unreleased" "$CHANGELOG_FILE" 2>/dev/null; then
        # Heading already present — append only the category entries
        write_commit_categories "$UNRECORDED" "$TEMP_FILE"
    else
        write_section "$UNRECORDED" "## Unreleased" "$TEMP_FILE"
    fi

    if [ ! -s "$TEMP_FILE" ]; then
        echo "No new changelog entries found after applying filters."
        rm -f "$TEMP_FILE"
        print_completion_notes
        exit 0
    fi

    prompt_and_append "$TEMP_FILE"
    print_completion_notes
    exit 0
fi

# ─── Tagged path ──────────────────────────────────────────────────────────────

echo "Found tags: $TAGS"
LATEST_TAG=$(echo "$TAGS" | head -n 1)

if [ ! -f "$CHANGELOG_FILE" ] || [ ! -s "$CHANGELOG_FILE" ]; then
    write_changelog_header "$CHANGELOG_FILE"

    TAG_TO=HEAD
    for TAG_FROM in $TAGS; do
        write_tag_section "$TAG_FROM" "$TAG_TO"
        TAG_TO=$TAG_FROM
    done
    write_tag_section "" "$TAG_FROM"
    echo "Changelog generation complete."
fi

# Check for unreleased commits above the latest tag
UNRELEASED=$(git log "${LATEST_TAG}..HEAD" --oneline | grep -v -iE "^[^ ]+ Merge " || true)
if [ -n "$UNRELEASED" ]; then
    echo "Found unreleased commits above $LATEST_TAG."
    TEMP_FILE=$(mktemp)
    write_section "$UNRELEASED" "## Unreleased" "$TEMP_FILE"
    if [ -s "$TEMP_FILE" ]; then
        prompt_and_append "$TEMP_FILE"
    else
        echo "No new changelog entries found after applying filters."
        rm -f "$TEMP_FILE"
    fi
else
    echo "No unreleased commits above $LATEST_TAG."
fi

print_completion_notes

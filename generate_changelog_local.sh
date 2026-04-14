#!/bin/sh

# ─── Configuration ────────────────────────────────────────────────────────────

REPO_DIR="."
CHANGELOG_FILE="$REPO_DIR/CHANGELOG.md"
CHANGELOG_RELATIVE_PATH=$(echo "$CHANGELOG_FILE" | sed 's#^\./##')
GITHUB_REPO_URL=$(git remote get-url origin 2>/dev/null \
    | sed 's/\.git$//' \
    | sed 's#^git@\([^:]*\):\(.*\)#https://\1/\2#')
if [ -z "$GITHUB_REPO_URL" ]; then
    GITHUB_REPO_URL=0
fi

# All recognised CC types — used to identify conventional commits
CC_TYPES="feat fix perf refactor style build ci docs chore gitops deploy test demo deprecated removed security"
_CC_PATTERN=$(echo "$CC_TYPES" | tr ' ' '|')
CONVENTIONAL_COMMIT_REGEX="^.* ($_CC_PATTERN)(\(.*\))?: "
unset _CC_PATTERN

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

# Returns success when a commit modifies only CHANGELOG.md.
is_changelog_only_commit() {
    COMMIT_HASH="$1"
    CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT_HASH" 2>/dev/null || true)

    if [ -z "$CHANGED_FILES" ]; then
        return 1
    fi

    NON_CHANGELOG_FILES=$(echo "$CHANGED_FILES" | awk -v changelog="$CHANGELOG_RELATIVE_PATH" '
        $0 != changelog && $0 != ("./" changelog)
    ')

    [ -z "$NON_CHANGELOG_FILES" ]
}

# Filters commit lines to exclude merge commits and changelog-only commits.
filter_commits_for_changelog() {
    while IFS= read -r COMMIT_LINE; do
        [ -z "$COMMIT_LINE" ] && continue
        echo "$COMMIT_LINE" | grep -qiE "^[^ ]+ Merge " && continue

        COMMIT_HASH=$(echo "$COMMIT_LINE" | awk '{print $1}')
        if is_changelog_only_commit "$COMMIT_HASH"; then
            continue
        fi

        echo "$COMMIT_LINE"
    done
}

# Writes the standard changelog preamble to a given file (creates/overwrites it).
write_changelog_header() {
    cat > "$1" << 'HEADER'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
and to [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
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

    echo "Processing tag $TAG_TO..."

    if [ -z "$TAG_FROM" ]; then
        ALL_COMMITS=$(git log "$TAG_TO" --oneline | filter_commits_for_changelog)
    else
        ALL_COMMITS=$(git log "$TAG_FROM".."$TAG_TO" --oneline | filter_commits_for_changelog)
    fi

    if [ -z "$ALL_COMMITS" ]; then
        echo "No commits found for $TAG_TO after filtering — skipping."
        return
    fi

    TAG_DATE=$(git log -1 --format=%ai "$TAG_TO" | cut -d ' ' -f 1)

    if [ "$TAG_TO" = "HEAD" ]; then
        echo "## Unreleased" >> "$CHANGELOG_FILE"
    else
        echo "## $TAG_TO ($TAG_DATE)" >> "$CHANGELOG_FILE"
    fi
    echo "" >> "$CHANGELOG_FILE"

    write_commit_categories "$ALL_COMMITS" "$CHANGELOG_FILE"
    echo "Completed tag $TAG_TO."
}

# Returns commits whose short hashes do not already appear in CHANGELOG_FILE.
# Falls back to all commits when the file is absent, empty, or has no embedded
# hashes (e.g. written without a GitHub URL).
get_unrecorded_commits() {
    ALL_COMMITS=$(git log --oneline | filter_commits_for_changelog)

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

# Scans proposed entries for suspected duplicates and prints flagged pairs to
# the terminal before the review prompt. Two comparisons are made:
#   1. Proposed vs proposed  — catches duplicates within the new entries
#   2. Proposed vs existing  — catches entries that overlap with the existing changelog
# Uses Jaccard similarity on meaningful words (CC prefix and stop words removed).
# Threshold: 0.4 — entries sharing 40% or more of their word union are flagged.
warn_suspected_duplicates() {
    TEMP_FILE="$1"
    EXISTING_FILE="${2:-/dev/null}"

    awk '
    # Strips the CC type prefix and optional scope, removes stop words,
    # and returns a normalised space-separated string of meaningful words.
    function normalize(msg,    parts, n, i, w, result) {
        sub(/^[a-zA-Z]+(\([^)]+\))?: /, "", msg)
        msg = tolower(msg)
        gsub(/[^a-z ]/, " ", msg)
        n = split(msg, parts, /[ \t]+/)
        result = ""
        for (i = 1; i <= n; i++) {
            w = parts[i]
            if (!is_stop(w) && w != "")
                result = result (result == "" ? "" : " ") w
        }
        return result
    }

    function is_stop(w) {
        return (w == "a"    || w == "an"   || w == "the"     || w == "and"       ||
                w == "or"   || w == "for"  || w == "to"      || w == "of"        ||
                w == "in"   || w == "on"   || w == "with"    || w == "add"       ||
                w == "adds" || w == "update" || w == "implement" || w == "introduce" ||
                w == "change" || w == "from"  || length(w) <= 2)
    }

    # Computes Jaccard similarity between two normalised strings.
    function jaccard(a, b,    wa, wb, na, nb, i, seen, common, total) {
        na = split(a, wa, /[ \t]+/)
        nb = split(b, wb, /[ \t]+/)
        for (i = 1; i <= na; i++) seen[wa[i]] = 1
        common = 0
        for (i = 1; i <= nb; i++) {
            if (wb[i] in seen) {
                common++
                delete seen[wb[i]]
            }
        }
        total = na + nb - common
        return (total > 0) ? common / total : 0
    }

    # First file: collect existing changelog entries.
    NR == FNR {
        if (/^- /) {
            raw = substr($0, 3)
            existing_raw[++ne] = raw
            existing_norm[ne] = normalize(raw)
        }
        next
    }

    # Second file: collect proposed entries.
    /^- / {
        raw = substr($0, 3)
        proposed_raw[++np] = raw
        proposed_norm[np] = normalize(raw)
    }

    END {
        found = 0

        # 1. Proposed vs proposed
        for (i = 1; i <= np; i++) {
            for (j = i + 1; j <= np; j++) {
                if (jaccard(proposed_norm[i], proposed_norm[j]) >= 0.4) {
                    if (!found) { print "--- Suspected duplicate entries (please review before confirming) ---"; found = 1 }
                    printf "  NEW:      - %s\n  NEW:      - %s\n\n", proposed_raw[i], proposed_raw[j]
                }
            }
        }

        # 2. Proposed vs existing
        for (i = 1; i <= np; i++) {
            for (j = 1; j <= ne; j++) {
                if (jaccard(proposed_norm[i], existing_norm[j]) >= 0.4) {
                    if (!found) { print "--- Suspected duplicate entries (please review before confirming) ---"; found = 1 }
                    printf "  NEW:      - %s\n  EXISTING: - %s\n\n", proposed_raw[i], existing_raw[j]
                }
            }
        }

        if (found) { print "--------------------------------------------------------------------"; print "" }
    }
    ' "$EXISTING_FILE" "$TEMP_FILE"
}

# Prints proposed entries to the terminal, prompts for approval,
# and appends to CHANGELOG_FILE if confirmed.
# Aborts immediately when not running from a TTY (e.g. in CI).
prompt_and_append() {
    TEMP_FILE="$1"

    [ -t 0 ] || {
        echo "Not a TTY — aborting to avoid blocking a CI pipeline. Please run this script locally."
        rm -f "$TEMP_FILE"
        exit 1
    }

    echo ""
    warn_suspected_duplicates "$TEMP_FILE" "$CHANGELOG_FILE"
    echo "--- Proposed unreleased entries ---"
    cat "$TEMP_FILE"
    echo "-----------------------------------"
    printf "Add these entries to %s? [y/N] " "$CHANGELOG_FILE"
    read -r ANSWER
    case "$ANSWER" in
        [Yy]|[Yy][Ee][Ss])
            printf '\n' >> "$CHANGELOG_FILE"
            cat "$TEMP_FILE" >> "$CHANGELOG_FILE"
            normalize_unreleased_sections
            echo "Entries appended to $CHANGELOG_FILE."
            ;;
        *)
            echo "Aborted — no changes made to $CHANGELOG_FILE."
            ;;
    esac
    rm -f "$TEMP_FILE"
}

# Merges duplicate section headings inside the ## Unreleased block,
# deduplicates entries within each merged section by message text,
# and combines hashes from duplicate entries.
# Preserves section order from first appearance.
normalize_unreleased_sections() {
    TMP_OUT=$(mktemp)

    awk '
    BEGIN {
        state = "pre"
    }

    function trim_trailing_newlines(s) {
        sub(/\n+$/, "", s)
        return s
    }

    function trim_leading_newlines(s) {
        sub(/^\n+/, "", s)
        return s
    }

    function collapse_internal_blank_lines(s) {
        while (gsub(/\n\n+/, "\n", s)) {}
        return s
    }

    # Deduplicates bullet entries within a section body string.
    # Entries with identical messages (case-insensitive) are merged,
    # with hash continuation lines combined under the first occurrence.
    function dedup_body(body,    lines, n, i, line, cur_key, cur_msg,
                                 ec, eo, em, eh, k, result) {
        n = split(body, lines, "\n")
        ec = 0
        cur_key = ""

        for (i = 1; i <= n; i++) {
            line = lines[i]
            if (line ~ /^- /) {
                cur_msg = substr(line, 3)
                cur_key = tolower(cur_msg)
                if (!(cur_key in em)) {
                    eo[++ec] = cur_key
                    em[cur_key] = cur_msg
                    eh[cur_key] = ""
                }
            } else if (cur_key != "" && line ~ /^  \[/) {
                # Assumes all indented lines are commit links in the form:
                #   [`hash`](url)
                # Manually added continuation lines that do not start with `[`
                # will not be preserved by this function.
                eh[cur_key] = eh[cur_key] line "\n"
            }
        }

        result = ""
        for (i = 1; i <= ec; i++) {
            k = eo[i]
            result = result "- " em[k] "\n"
            if (eh[k] != "") {
                result = result eh[k]
            }
        }

        return result
    }

    {
        line = $0

        if (state == "pre") {
            if (line == "## Unreleased") {
                state = "unreleased"
                unreleased_found = 1
            } else {
                pre = pre line "\n"
            }
            next
        }

        if (state == "unreleased") {
            if (line ~ /^## /) {
                state = "post"
                post = post line "\n"
                current = ""
                next
            }

            if (line ~ /^### /) {
                current = substr(line, 5)
                if (!(current in seen)) {
                    seen[current] = 1
                    order[++count] = current
                }
                next
            }

            if (current == "") {
                unreleased_intro = unreleased_intro line "\n"
            } else {
                section_body[current] = section_body[current] line "\n"
            }
            next
        }

        if (state == "post") {
            post = post line "\n"
        }
    }

    END {
        if (!unreleased_found) {
            printf "%s%s", pre, post
            exit
        }

        printf "%s", pre
        printf "## Unreleased\n"

        unreleased_intro = trim_trailing_newlines(unreleased_intro)
        if (unreleased_intro != "") {
            printf "\n%s\n", unreleased_intro
        } else {
            printf "\n"
        }

        for (i = 1; i <= count; i++) {
            sec = order[i]
            body = trim_trailing_newlines(section_body[sec])
            body = trim_leading_newlines(body)
            body = collapse_internal_blank_lines(body)
            body = dedup_body(body)

            printf "### %s\n\n", sec
            if (body != "") {
                printf "%s\n", body
            }

            if (i < count) {
                printf "\n"
            }
        }

        post = trim_trailing_newlines(post)
        if (post != "") {
            printf "\n%s\n", post
        } else {
            if (count == 0) {
                printf "\n"
            }
        }
    }
    ' "$CHANGELOG_FILE" > "$TMP_OUT"

    mv "$TMP_OUT" "$CHANGELOG_FILE"
}

print_completion_notes() {
    echo "Reminder: generated entries are a starting point — please review and edit CHANGELOG.md before committing."
    echo "Done."
}

# ─── Main flow ────────────────────────────────────────────────────────────────

echo "Starting changelog generation..."
echo "Repository: $GITHUB_REPO_URL"

cd "$REPO_DIR"
git fetch --tags
echo "Fetched latest tags."

TAGS=$(git tag --sort=-v:refname)

# ─── No-tags path ─────────────────────────────────────────────────────────────

if [ -z "$TAGS" ]; then
    echo "No tags found — checking for unrecorded commits..."

    UNRECORDED=$(get_unrecorded_commits)

    if [ -z "$UNRECORDED" ]; then
        echo "All commits are already recorded in $CHANGELOG_FILE — nothing to add."
        if [ -f "$CHANGELOG_FILE" ] && [ -s "$CHANGELOG_FILE" ]; then
            normalize_unreleased_sections
        fi
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
        if [ -f "$CHANGELOG_FILE" ] && [ -s "$CHANGELOG_FILE" ]; then
            normalize_unreleased_sections
        fi
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
    print_completion_notes
    exit 0
fi

# Check for unreleased commits above the latest tag
UNRELEASED=$(git log "${LATEST_TAG}..HEAD" --oneline | filter_commits_for_changelog)
if [ -n "$UNRELEASED" ]; then
    echo "Found unreleased commits above $LATEST_TAG."
    TEMP_FILE=$(mktemp)
    write_section "$UNRELEASED" "## Unreleased" "$TEMP_FILE"
    if [ -s "$TEMP_FILE" ]; then
        prompt_and_append "$TEMP_FILE"
    else
        echo "No new changelog entries found after applying filters."
        rm -f "$TEMP_FILE"
        if [ -f "$CHANGELOG_FILE" ] && [ -s "$CHANGELOG_FILE" ]; then
            normalize_unreleased_sections
        fi
        print_completion_notes
    fi
else
    echo "No unreleased commits above $LATEST_TAG."
    if [ -f "$CHANGELOG_FILE" ] && [ -s "$CHANGELOG_FILE" ]; then
        normalize_unreleased_sections
    fi
fi

print_completion_notes

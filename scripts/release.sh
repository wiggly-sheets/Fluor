#!/usr/bin/env bash
#
# Fluor — prepare a release.
#
# The script builds the release artifacts of a version, checks that the
# version really reached the bundle, takes the release notes from
# CHANGELOG.md and prints the plan of the release. It never pushes, never
# tags and never publishes: the release workflow does that.
#
# Usage: scripts/release.sh 2.8.0

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT
cd "$ROOT"

readonly APP_NAME="Fluor"
readonly BUNDLE="dist/${APP_NAME}.app"
readonly DMG="release/${APP_NAME}.dmg"
readonly CHECKSUMS="release/checksums.txt"
readonly NOTES="release-notes.md"
readonly VERSION_PATTERN='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'

fail() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

# The version comes from the command line.
version="${1:-}"
if [[ -z "$version" ]]; then
	printf 'usage: scripts/release.sh <version>\n' >&2
	printf 'example: scripts/release.sh 2.8.0\n' >&2
	exit 1
fi
if [[ ! "$version" =~ $VERSION_PATTERN ]]; then
	fail "the version \"$version\" is not valid. Use MAJOR.MINOR.PATCH, for example 2.8.0, or add a suffix, for example 2.8.0-beta.1."
fi

# The working tree must be clean. The notes file belongs to the script, so it
# never blocks a second run.
dirty="$(git status --porcelain -- . ":(exclude)$NOTES")"
if [[ -n "$dirty" ]]; then
	printf 'error: the working tree is dirty. Commit or stash your changes first.\n' >&2
	printf '%s\n' "$dirty" >&2
	exit 1
fi

# The release notes come from the section of CHANGELOG.md for the version. The
# headings look like "## 2.7.0 — 2026-08-15", so the section starts at the
# heading and ends at the next heading. The changelog is read before the build,
# so a missing section stops the release without a build.
notes=""
notes_found="no"
read_notes() {
	local line heading
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ "$notes_found" == "yes" ]]; then
			if [[ "$line" == "## "* ]]; then
				break
			fi
			notes+="${line}"$'\n'
			continue
		fi
		if [[ "$line" == "## "* ]]; then
			heading="${line#\#\# }"
			if [[ "$heading" == "$version" || "$heading" == "$version "* ]]; then
				notes_found="yes"
				notes+="${line}"$'\n'
			fi
		fi
	done <CHANGELOG.md
}
read_notes

if [[ "$notes_found" == "no" ]]; then
	if [[ "$version" == *-* ]]; then
		notes="Fluor ${version}"$'\n'
		printf 'warning: CHANGELOG.md has no section for %s. The notes fall back to one line.\n' "$version" >&2
	else
		fail "CHANGELOG.md has no section for ${version}. Add a \"## ${version}\" section to CHANGELOG.md before the release."
	fi
fi

# The release must sit on the default branch. The branch comes from the remote
# HEAD, with main as the fallback.
default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
default_branch="${default_branch#origin/}"
if [[ -z "$default_branch" ]]; then
	default_branch="main"
fi
if ! git rev-parse --verify --quiet "refs/remotes/origin/${default_branch}" >/dev/null; then
	fail "the default branch origin/${default_branch} is not in this checkout. Fetch the branches of the repository first."
fi

if git merge-base --is-ancestor HEAD "refs/remotes/origin/${default_branch}"; then
	branch_state="on the default branch ${default_branch}"
elif [[ "$version" == *-* ]] && git merge-base --is-ancestor "refs/remotes/origin/${default_branch}" HEAD; then
	# A draft may be cut from a branch that the default branch does not hold yet.
	branch_state="ahead of the default branch ${default_branch}, not merged yet"
	printf 'warning: the tag would sit on a commit that is not on the default branch %s.\n' "$default_branch" >&2
	printf 'warning: a published release must be tagged on the default branch.\n' >&2
else
	fail "the commit $(git rev-parse --short HEAD) is not on the default branch ${default_branch}. Tag the release on the default branch."
fi

# The artifacts carry the version, so the tag is the only version source.
printf 'Building the release artifacts of %s...\n' "$version"
make release-artifacts VERSION="$version"

plist="${BUNDLE}/Contents/Info.plist"
if [[ ! -f "$plist" ]]; then
	fail "the bundle ${BUNDLE} does not exist. The build did not produce it."
fi
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
if [[ "$bundle_version" != "$version" ]]; then
	fail "the bundle reports the version ${bundle_version}, but ${version} was asked for."
fi
printf 'The bundle reports the version %s.\n' "$bundle_version"

# The release notes were read above. The file holds the body of the release.
while [[ "$notes" == *$'\n' ]]; do
	notes="${notes%$'\n'}"
done
printf '%s\n' "$notes" >"$NOTES"

draft="no"
if [[ "$version" == *-* ]]; then
	draft="yes"
fi

printf '\n'
printf 'Release plan\n'
printf '  version:          %s\n' "$version"
printf '  default branch:   %s (%s)\n' "$default_branch" "$branch_state"
printf '  published files:  %s, %s\n' "$DMG" "$CHECKSUMS"
printf '  notes file:       %s (the body of the release, uploaded as well)\n' "$NOTES"
printf '  draft:            %s\n' "$draft"
printf '\n'
printf 'The script does not push, tag or publish. The release workflow does that.\n'

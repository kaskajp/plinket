#!/usr/bin/env bash
# Files the changelog's Unreleased notes under the app's current version and build, as set in
# Xcode's General tab (or project.yml), then commits and tags. Bump them first. Pushing is left to you.
#
# Usage: scripts/release.sh
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

changelog=CHANGELOG.md
project=project.yml
xcode_project=Plinket.xcodeproj

fail() {
    echo "release: $*" >&2
    exit 1
}

[[ $# -eq 0 ]] || fail "usage: scripts/release.sh (takes the version and build from Xcode)"
[[ -z "$(git status --porcelain)" ]] || fail "commit or stash your changes first"

project_yml_setting() {
    sed -n "s/^ *$1: \"\(.*\)\"$/\1/p" "$project"
}

xcode_setting() {
    sed -n "s/^ *$1 = //p" <<< "$xcode_settings"
}

# Xcode's General tab edits the generated project, which XcodeGen overwrites, so its values win and are copied back.
if [[ -d $xcode_project ]]; then
    xcode_settings=$(xcodebuild -project "$xcode_project" -target Plinket -configuration Release -showBuildSettings 2> /dev/null)
    version=$(xcode_setting MARKETING_VERSION)
    build=$(xcode_setting CURRENT_PROJECT_VERSION)
else
    version=$(project_yml_setting MARKETING_VERSION)
    build=$(project_yml_setting CURRENT_PROJECT_VERSION)
fi
[[ -n $version && -n $build ]] || fail "no MARKETING_VERSION or CURRENT_PROJECT_VERSION found"

release="$version ($build)"
tag="v$version-build.$build"
git rev-parse -q --verify "refs/tags/$tag" > /dev/null && fail "$release is already released; bump the version or build in Xcode first"

# Notes are the lines between "## [Unreleased]" and the next version heading, minus link definitions.
notes=$(awk '/^## \[Unreleased\]/ { inside = 1; next } /^## \[/ { inside = 0 } inside && NF && !/^\[[^]]+\]: /' "$changelog")
[[ -n $notes ]] || fail "nothing under ## [Unreleased] in $changelog"

repo_url=$(git remote get-url origin | sed -E 's#^(ssh://)?git@([^/:]+)[:/]#https://\2/#; s#\.git$##')
previous_tag=$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2> /dev/null || true)
if [[ -n $previous_tag ]]; then
    release_link="$repo_url/compare/$previous_tag...$tag"
else
    release_link="$repo_url/releases/tag/$tag"
fi
unreleased_link="$repo_url/compare/$tag...HEAD"

awk -v release="$release" -v date="$(date +%F)" -v release_link="$release_link" -v unreleased_link="$unreleased_link" '
    /^## \[Unreleased\]/ { print; print ""; print "## [" release "] - " date; next }
    /^\[Unreleased\]: / { print "[Unreleased]: " unreleased_link; print "[" release "]: " release_link; linked = 1; next }
    { print }
    END { if (!linked) { print ""; print "[Unreleased]: " unreleased_link; print "[" release "]: " release_link } }
' "$changelog" > "$changelog.tmp"
mv "$changelog.tmp" "$changelog"

sed -i '' -E \
    -e "s/^( *MARKETING_VERSION: )\".*\"$/\1\"$version\"/" \
    -e "s/^( *CURRENT_PROJECT_VERSION: )\".*\"$/\1\"$build\"/" \
    "$project"

git add "$changelog" "$project"
git commit -q -m "Release $release"
git tag -a "$tag" -m "Plinket $release"

echo "Released $release as $tag."
echo "Push with: git push --follow-tags"

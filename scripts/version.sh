#!/bin/bash
# The version, read and written in the one place that holds it.
#
# `project.yml` is the single source of truth. `Sorty.xcodeproj` is generated
# and gitignored, so a version typed into Xcode's UI survives exactly until the
# next `xcodegen generate` and then vanishes - which is the failure this script
# exists to make impossible. Every bump goes through here or through an edit to
# `project.yml`, never through the project file.
#
# Two numbers live there and they are not the same thing:
#
#   MARKETING_VERSION        CFBundleShortVersionString - the SemVer the humans
#                            read. Apple requires one to three dot-separated
#                            integers and NOTHING else, so `0.2.0-beta.1` is
#                            rejected at upload. A pre-release is expressed as
#                            the release version plus a build number, and the
#                            `-beta.N` lives only in the git tag.
#
#   CURRENT_PROJECT_VERSION  CFBundleVersion - the build number. Must strictly
#                            increase within a MARKETING_VERSION train or
#                            TestFlight refuses the upload as a duplicate. It is
#                            not reset per release; treat it as a counter that
#                            only ever goes up.
#
# Usage:
#   version.sh                    print the marketing version
#   version.sh build              print the build number
#   version.sh set 0.2.0          write the marketing version
#   version.sh bump-build         increment the build number by one
#   version.sh set-build 42       write the build number (CI passes its run number)
#   version.sh check v0.2.0       assert a tag agrees with project.yml, and exit
#                                 non-zero if it does not. `v0.2.0-beta.1` also
#                                 matches 0.2.0 - the suffix is a tag concern.
#
# Exit codes: 0 agreement, 1 disagreement or bad input.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$root/project.yml"

[[ -f "$project" ]] || { echo "no project.yml at $project" >&2; exit 1; }

# Read a settings key. Fails loudly on zero or multiple matches rather than
# silently picking one - if project.yml grows a per-target override, the sed
# below would write to the wrong line and this is the guard that catches it.
read_key() {
  local key="$1" count
  count=$(grep -c "^ *${key}:" "$project" || true)
  if [[ "$count" != "1" ]]; then
    echo "expected exactly one ${key} in project.yml, found ${count}" >&2
    exit 1
  fi
  grep "^ *${key}:" "$project" | sed -E 's/.*: *"?([^"]*)"?.*/\1/'
}

write_key() {
  local key="$1" value="$2"
  read_key "$key" >/dev/null   # same guard, before we write
  # BSD and GNU sed disagree about -i, so write through a temp file instead.
  sed -E "s|^([ ]*${key}:).*|\1 \"${value}\"|" "$project" >"$project.tmp"
  mv "$project.tmp" "$project"
}

is_semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

case "${1:-get}" in
  get)
    read_key MARKETING_VERSION
    ;;

  build)
    read_key CURRENT_PROJECT_VERSION
    ;;

  set)
    version="${2:-}"
    is_semver "$version" || {
      echo "not a MAJOR.MINOR.PATCH version: '${version}'" >&2
      echo "a pre-release is tagged -beta.N; the bundle version stays plain" >&2
      exit 1
    }
    write_key MARKETING_VERSION "$version"
    echo "MARKETING_VERSION = $version"
    echo "run 'xcodegen generate' to carry it into the project"
    ;;

  set-build)
    n="${2:-}"
    # One to three dot-separated integers - the same shape CFBundleVersion
    # accepts. CI passes a UTC timestamp as YYYYMMDD.HHMM, which is strictly
    # increasing without any shared counter for the two workflows to fight over.
    [[ "$n" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || {
      echo "build number must be 1-3 dot-separated integers: '${n}'" >&2
      exit 1
    }
    write_key CURRENT_PROJECT_VERSION "$n"
    echo "CURRENT_PROJECT_VERSION = $n"
    ;;

  bump-build)
    current=$(read_key CURRENT_PROJECT_VERSION)
    [[ "$current" =~ ^[0-9]+$ ]] || { echo "build number is not an integer: '${current}'" >&2; exit 1; }
    next=$((current + 1))
    write_key CURRENT_PROJECT_VERSION "$next"
    echo "CURRENT_PROJECT_VERSION = $current -> $next"
    ;;

  check)
    tag="${2:-}"
    [[ -n "$tag" ]] || { echo "usage: version.sh check vX.Y.Z" >&2; exit 1; }
    # vX.Y.Z, vX.Y.Z-beta.N -> X.Y.Z
    bare="${tag#v}"
    bare="${bare%%-*}"
    is_semver "$bare" || { echo "tag '${tag}' is not vX.Y.Z or vX.Y.Z-beta.N" >&2; exit 1; }
    actual=$(read_key MARKETING_VERSION)
    if [[ "$bare" != "$actual" ]]; then
      echo "tag ${tag} disagrees with project.yml" >&2
      echo "  tag says:         ${bare}" >&2
      echo "  MARKETING_VERSION: ${actual}" >&2
      echo "run: ./scripts/version.sh set ${bare}" >&2
      exit 1
    fi
    echo "${tag} agrees with MARKETING_VERSION ${actual}"
    ;;

  *)
    sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac

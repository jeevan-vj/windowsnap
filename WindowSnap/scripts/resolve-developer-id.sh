#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

requested="${1:-}"
[[ -n "$requested" ]] || die "A Developer ID Application identity name or SHA-1 fingerprint is required"

identities="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null)"

if [[ "$requested" =~ ^[[:xdigit:]]{40}$ ]]; then
  requested="$(printf '%s' "$requested" | /usr/bin/tr '[:lower:]' '[:upper:]')"
  resolved="$(printf '%s\n' "$identities" | /usr/bin/awk -v fingerprint="$requested" '
    index($0, fingerprint) && index($0, "\"Developer ID Application:") { print fingerprint; exit }
  ')"
  [[ -n "$resolved" ]] || die "The configured fingerprint is not a valid Developer ID Application identity"
  printf '%s\n' "$resolved"
  exit 0
fi

[[ "$requested" == Developer\ ID\ Application:* ]] || \
  die "The identity must be a Developer ID Application name or SHA-1 fingerprint"

matches="$(printf '%s\n' "$identities" | /usr/bin/awk -v name="$requested" '
  index($0, "\"" name "\"") { count++; fingerprint=$2 }
  END {
    if (count == 1) print fingerprint
    else if (count > 1) exit 2
    else exit 1
  }
')" || {
  status=$?
  if [[ "$status" -eq 2 ]]; then
    die "Multiple Developer ID Application identities share that name; use the SHA-1 fingerprint"
  fi
  die "The configured Developer ID Application identity is not installed or valid"
}

printf '%s\n' "$matches"

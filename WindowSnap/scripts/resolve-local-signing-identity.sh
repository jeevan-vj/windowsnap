#!/usr/bin/env bash
set -euo pipefail

# Picks ONE stable code-signing identity for local/dev builds so macOS TCC
# (Screen Recording, Accessibility) keeps matching the same code requirement
# across rebuilds. Output: "<identity>|<team id or empty>|<label>" (pipe-delimited so an
# empty team field survives `IFS=| read`).
#
# Order:
#   1. $SIGNING_IDENTITY (name or SHA-1), used verbatim
#   2. Developer ID Application for team $WINDOWSNAP_TEAM_ID (default 88282K637B)
#   3. First Apple Development identity
# Prints nothing and exits 1 when no identity is available (ad-hoc).
# When several identities share a name, the SHA-1 fingerprint is printed so
# codesign does not fail with "ambiguous".

PREFERRED_TEAM="${WINDOWSNAP_TEAM_ID:-88282K637B}"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  team=""
  if [[ "$SIGNING_IDENTITY" == Developer\ ID\ Application:* && "$SIGNING_IDENTITY" =~ \(([A-Z0-9]{10})\)$ ]]; then
    team="${BASH_REMATCH[1]}"
  elif [[ "$SIGNING_IDENTITY" == Apple\ Development:* ]]; then
    team="$(/usr/bin/security find-certificate -c "$SIGNING_IDENTITY" -p 2>/dev/null \
      | /usr/bin/openssl x509 -noout -subject -nameopt multiline 2>/dev/null \
      | /usr/bin/awk -F' = ' '/organizationalUnitName/ { print $2; exit }' || true)"
  fi
  printf '%s|%s|%s\n' "$SIGNING_IDENTITY" "$team" "SIGNING_IDENTITY"
  exit 0
fi

identities="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null || true)"

pick() {
  # $1 = identity name prefix, $2 = optional "(TEAMID)" suffix
  printf '%s\n' "$identities" | /usr/bin/awk -v prefix="\"$1" -v suffix="${2:-}" '
    index($0, prefix) && (suffix == "" || index($0, suffix "\"")) {
      fp=$2
      name=$0; sub(/^[^"]*"/, "", name); sub(/"[^"]*$/, "", name)
      team=""
      if (match(name, /\([A-Z0-9]+\)$/)) team=substr(name, RSTART+1, RLENGTH-2)
      printf "%s|%s|%s\n", fp, team, name
      exit
    }'
}

# The "(XXXXXXXXXX)" suffix of an Apple Development name is a personal ID,
# not the team. Read the team from the certificate's OU instead.
team_from_certificate() {
  /usr/bin/security find-certificate -c "$1" -p 2>/dev/null \
    | /usr/bin/openssl x509 -noout -subject -nameopt multiline 2>/dev/null \
    | /usr/bin/awk -F' = ' '/organizationalUnitName/ { print $2; exit }'
}

fix_team() {
  local fp team name cert_team
  IFS='|' read -r fp team name <<<"$1"
  cert_team="$(team_from_certificate "$name" || true)"
  printf '%s|%s|%s\n' "$fp" "${cert_team:-$team}" "$name"
}

result="$(pick "Developer ID Application:" "($PREFERRED_TEAM)")"
if [[ -z "$result" ]]; then
  result="$(pick "Apple Development:")"
fi
if [[ -n "$result" ]]; then
  result="$(fix_team "$result")"
fi

[[ -n "$result" ]] || exit 1
printf '%s\n' "$result"

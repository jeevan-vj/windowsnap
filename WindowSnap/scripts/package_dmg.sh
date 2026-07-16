#!/usr/bin/env bash
set -euo pipefail
echo "ERROR: scripts/package_dmg.sh is retired because it created an unverified DMG." >&2
echo "Use scripts/release.sh for a signed, notarized, stapled, and verified production DMG." >&2
exit 1

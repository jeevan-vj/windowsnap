#!/usr/bin/env bash
set -euo pipefail
echo "ERROR: scripts/notarize-dist.sh is retired as a standalone release path." >&2
echo "Use scripts/release.sh so signing, notarization, packaging, and verification remain atomic." >&2
exit 1

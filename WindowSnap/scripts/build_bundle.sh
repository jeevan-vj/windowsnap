#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible entrypoint. Distribution builds must be universal so the
# app runs natively on both Apple Silicon and Intel Macs.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT_DIR/scripts/build-universal-bundle.sh"

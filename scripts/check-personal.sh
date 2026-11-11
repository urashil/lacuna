#!/usr/bin/env bash
# Fails if anything personal ended up in the image (PLAN invariant 5). Scans the parts of the root we write ourselves
# (/opt only holds vendor bundles: Tor Browser, PIA, SimpleX).
set -euo pipefail
root=$1
# the patterns are personal themselves, so they live outside this repo: $PERSONAL/patterns.txt (one regex)
patfile=${PERSONAL:-/nonexistent}/patterns.txt
if [[ ! -s $patfile ]]; then
    echo "   personal-data check skipped (no $patfile)"; exit 0
fi
pat=$(cat "$patfile")
hits=$(cd "$root" && grep -rIlE "$pat" home etc root usr/local 2>/dev/null || true)
if [[ -n $hits ]]; then
    echo "personal data found in the image:" >&2; echo "$hits" >&2; exit 1
fi
echo "   no personal data found"

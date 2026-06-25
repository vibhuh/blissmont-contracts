#!/usr/bin/env bash
# check-import-direction.sh — the dependency-direction guard.
#
# Enforces the family rule that the README states and v1.1.0 relies on:
#
#   terminal/v1 MAY import common/v1.
#   terminal/v1 MUST NOT import pos/v1 (the server-domain contract).
#
# The engine translates server-domain models (pos.v1.*) into device-domain models
# (terminal.v1.*); the device wire never sees server concerns (GL accounts, posting,
# server-fiscal flags). buf has no native import-direction rule, so this guard is wired
# into the Buf/CI gate (`make guard`, and a CI step) — a real failing check, not a
# convention. It scans BOTH `import` statements and fully-qualified `blissmont.pos.*`
# type references inside proto/terminal.
#
# Exit 0 = direction respected. Exit 1 = a forbidden pos/v1 dependency was found.
set -euo pipefail

cd "$(dirname "$0")/.."

TERMINAL_DIR="proto/terminal"
status=0

# 1) Forbidden import statements: import "pos/...".
import_violations="$(grep -rEn '^[[:space:]]*import[[:space:]]+"pos/' "$TERMINAL_DIR" || true)"
if [ -n "$import_violations" ]; then
  echo "✗ dependency-direction violation: terminal/v1 imports pos/v1"
  echo "$import_violations"
  status=1
fi

# 2) Forbidden fully-qualified references: blissmont.pos.<something>.
typeref_violations="$(grep -rEn 'blissmont\.pos\.' "$TERMINAL_DIR" || true)"
if [ -n "$typeref_violations" ]; then
  echo "✗ dependency-direction violation: terminal/v1 references a blissmont.pos.* type"
  echo "$typeref_violations"
  status=1
fi

if [ "$status" -ne 0 ]; then
  echo ""
  echo "terminal/v1 is device-oriented and MUST NOT depend on pos/v1 (the server-domain"
  echo "contract). Map server-domain types into terminal-domain twins in the engine instead."
  exit 1
fi

echo "✓ dependency direction OK — terminal/v1 does not depend on pos/v1"

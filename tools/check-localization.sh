#!/bin/bash
# Fails the build when a localization key is used but missing, or when the
# tables have drifted apart. Both directions are checked.
set -euo pipefail

cd "$(dirname "$0")/.."

status=0
base="Resources/en.lproj/Localizable.strings"

keys_of() {
  grep -oE '^"[^"]+"' "$1" | tr -d '"' | sort -u
}

# 1. Every key referenced from the sources exists in English.
used=$(grep -rhoE '\bL?\.?[tf]\("[^"]+"' Sources | grep -oE '"[^"]+"' | tr -d '"' | sort -u)
for key in $used; do
  if ! grep -q "^\"$key\"[[:space:]]*=" "$base"; then
    echo "used in code but missing from $base: $key"
    status=1
  fi
done

# 2. Every translation carries exactly the English key set.
expected=$(keys_of "$base")
for table in Resources/*.lproj/Localizable.strings; do
  [[ "$table" == "$base" ]] && continue
  diff <(echo "$expected") <(keys_of "$table") > /dev/null || {
    echo "key sets differ between $base and $table:"
    diff <(echo "$expected") <(keys_of "$table") || true
    status=1
  }
done

[[ $status -eq 0 ]] && echo "✓ $(echo "$expected" | wc -l | tr -d ' ') keys, all tables in sync"
exit $status

#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"
need_age

if [ -f "$here/app.tar.age" ] && [ "$(app_hash)" = "$(recorded app)" ]; then
  echo "market gauge: nothing to pack"
  exit 0
fi
if [ -f "$here/app.tar.age" ] && [ "$(archive_hash)" != "$(recorded archive)" ]; then
  echo "market gauge: app.tar.age is newer than this PC's copy; unlock it elsewhere and merge first" >&2
  exit 1
fi
app_tar | age -R "$here/recipient" -o "$here/app.tar.age.tmp"
mv "$here/app.tar.age.tmp" "$here/app.tar.age"
record
echo "market gauge: packed"

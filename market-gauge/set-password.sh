#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$here/lib.sh"
need_age

echo "key.age is public once pushed: use a long passphrase of several unrelated words."
age -p -o "$here/key.age.tmp" "$key"
mv "$here/key.age.tmp" "$here/key.age"
echo "market gauge: password set"

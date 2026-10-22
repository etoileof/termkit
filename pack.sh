#!/bin/sh
# sh pack.sh          pack payload/ into payload.tar.gz (commit and push it to build a release)
# sh pack.sh unpack   unpack payload.tar.gz into payload/
set -eu
cd "$(dirname "$0")"

if [ "${1:-}" = unpack ]; then
  rm -rf payload
  mkdir payload
  tar -xzf payload.tar.gz -C payload
  exit 0
fi

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R payload/. "$stage/"
find "$stage" -name '.DS_Store' -delete
# Windows scripts need CRLF; patches must stay byte-exact.
find "$stage" -type f \( -name '*.cmd' -o -name '*.ps1' -o -name '*.txt' \) -exec perl -pi -e 's/\r?\n/\r\n/' {} +
if grep -rIlE 'sk-[A-Za-z0-9]{30,}|'"close"'router_[A-Za-z0-9_-]{20,}' "$stage"; then
  echo 'pack: refusing, an API key is in the files above' >&2
  exit 1
fi
COPYFILE_DISABLE=1 tar --no-mac-metadata -czf payload.tar.gz -C "$stage" .
echo "packed payload.tar.gz"

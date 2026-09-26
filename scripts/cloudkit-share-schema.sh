#!/usr/bin/env bash
# T39: add the share channel's record types (Journey / Log / Artifact, see
# ShareChannel) to the CloudKit *Development* schema. Production never
# creates record types on the fly, so until these are deployed there, every
# share fails to save ("couldn't create a link" in TestFlight).
#
#   CK_TOKEN=<management token> scripts/cloudkit-share-schema.sh
#
# The token: CloudKit Console → (top right) Settings / API Access → Tokens →
# CloudKit Management Token → Generate. Paste it into CK_TOKEN only for this
# command; it never needs saving.
#
# It exports the current Development schema, appends the three types (skipped
# if they already exist), validates, and imports — existing types are carried
# over untouched. Then deploy to Production in the Console (the last step
# this script prints).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM="A7Z9M6N48N"
CONTAINER="iCloud.ca.carelogue.app"
ADDITIONS="$ROOT/config/cloudkit/share-record-types.ckdb"
WORK="$ROOT/build/cloudkit"
mkdir -p "$WORK"

: "${CK_TOKEN:?Set CK_TOKEN to a CloudKit management token (see the header of this script).}"
ck() { xcrun cktool "$@" --token "$CK_TOKEN" --team-id "$TEAM" --container-id "$CONTAINER"; }

echo "==> Exporting the Development schema"
ck export-schema --environment development --output-file "$WORK/development.ckdb"
cp "$WORK/development.ckdb" "$WORK/development.before.ckdb"

if grep -qE 'RECORD TYPE "?Journey"? \(' "$WORK/development.ckdb"; then
  echo "==> Share record types already in Development — nothing to import"
else
  echo "==> Appending Journey / Log / Artifact"
  { cat "$WORK/development.ckdb"; echo; cat "$ADDITIONS"; } > "$WORK/development.new.ckdb"

  echo "==> Validating"
  ck validate-schema --environment development --file "$WORK/development.new.ckdb"

  echo "==> Importing into Development"
  ck import-schema --environment development --file "$WORK/development.new.ckdb"
fi

cat <<'NEXT'

==> Done with Development. Last step (Console only):
    CloudKit Console → iCloud.ca.carelogue.app → Development
    → Deploy Schema Changes → confirm the three new types → Deploy to Production.
    Then share again from the TestFlight build — no new build needed.
NEXT

#!/usr/bin/env bash
# Run Carelogue's XCUITest suite on a simulator, fully unattended.
#
#   scripts/ui-test.sh                                   # all UI tests
#   scripts/ui-test.sh -only-testing:CarelogueUITests/SmokeUITests
#   APPEARANCE=dark scripts/ui-test.sh                   # run in dark mode
#   SIM_ID=<udid> scripts/ui-test.sh                     # pick a simulator
#   INTERNAL_ACCESS_KEY=... scripts/ui-test.sh           # also run real-relay tests
#   CARELOGUE_RELAY_URL=http://127.0.0.1:8787 ...        # ... against a local Worker
#
# Before testing it provisions the simulator once: fixture photos go into the
# Photos library and fixture PDFs into Files > On My iPhone, so the picker
# tests have something to pick. Screenshots land in build/ui-screenshots/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURES="$ROOT/scripts/fixtures"
OUT="${SCREENSHOT_DIR:-$ROOT/build/ui-screenshots}"
RESULT="$ROOT/build/ui-test.xcresult"
LOG="$ROOT/build/ui-test.log"

# Simulator: explicit SIM_ID, else the first booted iPhone, else boot one.
if [[ -z "${SIM_ID:-}" ]]; then
  SIM_ID="$(xcrun simctl list devices booted | grep -m1 -E 'iPhone' | grep -oE '[0-9A-F-]{36}' || true)"
fi
if [[ -z "${SIM_ID:-}" ]]; then
  SIM_ID="$(xcrun simctl list devices available | grep -m1 -E 'iPhone 1[5-9] Pro' | grep -oE '[0-9A-F-]{36}')"
  xcrun simctl boot "$SIM_ID"
fi
xcrun simctl bootstatus "$SIM_ID" -b >/dev/null
echo "==> Simulator $SIM_ID"

DEVICE_DATA="$HOME/Library/Developer/CoreSimulator/Devices/$SIM_ID/data"
MARKER="$DEVICE_DATA/.carelogue-uitest-provisioned"
if [[ ! -f "$MARKER" ]]; then
  echo "==> Provisioning fixtures (photos + PDFs)"
  xcrun simctl addmedia "$SIM_ID" "$FIXTURES"/photo_*.jpg
  touch "$MARKER"
fi

# Files > On My iPhone is the Files app's local provider storage. Launch
# Files once so the folder exists, then copy the PDFs in (idempotent).
provider_dir() {
  find "$DEVICE_DATA/Containers/Shared/AppGroup" -maxdepth 2 -type d -name "File Provider Storage" 2>/dev/null | head -1
}
if [[ -z "$(provider_dir)" ]]; then
  xcrun simctl launch "$SIM_ID" com.apple.DocumentsApp >/dev/null 2>&1 || true
  sleep 3
  xcrun simctl terminate "$SIM_ID" com.apple.DocumentsApp >/dev/null 2>&1 || true
fi
PROVIDER="$(provider_dir)"
if [[ -n "$PROVIDER" ]]; then
  cp "$FIXTURES"/report_*.pdf "$PROVIDER"/
  # Oversized PDF for the 20MB import cap (m2-bugs #3): generated here, and
  # never committed — the importer checks the size before reading the file,
  # so zero padding is enough to make it too big.
  if [[ ! -f "$PROVIDER/report_oversize.pdf" ]]; then
    cp "$FIXTURES/report_a.pdf" "$PROVIDER/report_oversize.pdf"
    dd if=/dev/zero bs=1048576 count=21 >> "$PROVIDER/report_oversize.pdf" 2>/dev/null
  fi
else
  echo "warning: Files storage not found; file-import test may fail" >&2
fi

# Skip the one-time keyboard "slide to type" tutorial that covers the UI.
xcrun simctl spawn "$SIM_ID" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool true

if [[ -n "${APPEARANCE:-}" ]]; then
  xcrun simctl ui "$SIM_ID" appearance "$APPEARANCE"
fi

# The real round trip (ExplainUITests.testRealExplain) goes through the relay
# since T31 — the prompt only exists there. It runs when the internal
# credential (T30) is in the environment, and otherwise skips.
if [[ -n "${INTERNAL_ACCESS_KEY:-}" ]]; then
  export TEST_RUNNER_INTERNAL_ACCESS_KEY="$INTERNAL_ACCESS_KEY"
  export TEST_RUNNER_CARELOGUE_RELAY_URL="${CARELOGUE_RELAY_URL:-}"
fi

rm -rf "$OUT" "$RESULT"
mkdir -p "$OUT"

echo "==> Running UI tests (screenshots -> ${OUT#$ROOT/})"
set +e
TEST_RUNNER_SCREENSHOT_DIR="$OUT" xcodebuild test \
  -project "$ROOT/Carelogue.xcodeproj" \
  -scheme Carelogue \
  -destination "id=$SIM_ID" \
  -derivedDataPath "$ROOT/build/dd" \
  -resultBundlePath "$RESULT" \
  "$@" > "$LOG" 2>&1 &
XCB=$!
# Watchdog: xcodebuild sometimes keeps running long after the suite has
# finished. Once the final summary is logged, give it 60s, then stop it.
while kill -0 "$XCB" 2>/dev/null; do
  if grep -qE "^Test Suite 'Selected tests' (passed|failed)|^Test Suite 'All tests' (passed|failed)" "$LOG" 2>/dev/null; then
    for _ in $(seq 60); do kill -0 "$XCB" 2>/dev/null || break; sleep 1; done
    if kill -0 "$XCB" 2>/dev/null; then
      echo "==> xcodebuild still running 60s after the suite finished; stopping it"
      kill "$XCB" 2>/dev/null
    fi
    break
  fi
  sleep 2
done
wait "$XCB"
STATUS=$?
if grep -qE "^Test Suite '(Selected|All) tests' failed" "$LOG"; then STATUS=1
elif grep -qE "^Test Suite '(Selected|All) tests' passed" "$LOG"; then STATUS=0; fi
grep -E "Test Case .*(passed|failed)|error:|\*\* TEST" "$LOG"
set -e

echo "==> Screenshots:"
ls -1 "$OUT" 2>/dev/null | sed 's/^/    /'
echo "==> Result bundle: ${RESULT#$ROOT/}  (full log: ${LOG#$ROOT/})"
exit "$STATUS"

#!/usr/bin/env bash
# T39 acceptance walk-through: the CKShare channel on two real devices with
# two Apple IDs — the one part a simulator cannot stand in for.
#
#   scripts/t39-two-device-check.sh
#
# It is a guided checklist, not an automation: each step says what to do and
# what you should see, and you answer y (matches) / n (does not). Anything you
# answer n to is collected into the report at the end — paste that back into
# the T39 card when you are done.
#
# Device A = the owner's phone (your Apple ID, the one that starts the share).
# Device B = the participant's phone (the second Apple ID, freshly installed).
set -euo pipefail

failures=()
step=0

ask() { # ask <question> ; returns 0 on y
  local answer
  read -r -p "   $1 [y/n] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

check() { # check <title> <do> <expect>
  step=$((step + 1))
  printf '\n== Step %d · %s ==\n   DO:     %s\n   EXPECT: %s\n' "$step" "$1" "$2" "$3"
  if ask "Did you see the expected result?"; then
    printf '   OK\n'
  else
    failures+=("Step $step · $1")
    printf '   MARKED AS FAILURE\n'
  fi
}

clear
cat <<'INTRO'
================================================----------
 T39 · CKShare acceptance — two devices, two Apple IDs
==========================================================
Before starting:
  - Device A and B are both signed in to iCloud (Settings → your name),
    on Wi-Fi, and awake with the screen unlocked.
  - Both run the same Carelogue build.
  - Device A has a journey with a few records in it (a visit, a
    measurement, a photo attachment is ideal).

Press Return to start; answer y/n after each step.
INTRO
read -r

check "Open the share entry (A)" \
      "A: open the journey → tap the person icon at the top right of the timeline" \
      "The system sharing sheet appears (Add People / invite options)"

check "Send the invite (A)" \
      "A: choose Messages or Mail, send the invite to B's Apple ID" \
      "An invite link goes out; the journey header now shows the 共享中 pill"

check "Accept the share (B)" \
      "B: tap the link in Messages → Carelogue opens → tap 好加入/Join" \
      "B's journey list shows the shared journey with the 共享中 marker"

check "Full data arrived (B)" \
      "B: open the shared journey" \
      "The records A had are all there, including photo attachments (thumbnails load)"

check "B → A edit sync" \
      "B: add one quick note (随手记); wait ~10–20s with both screens on" \
      "A: the note appears on A's timeline without relaunching the app"

check "A → B edit sync" \
      "A: add one quick note; wait ~10–20s" \
      "B: the note appears on B's timeline without relaunching"

check "Edit of the same record" \
      "B: edit an existing note's text; A: leave the app, edit the SAME note a
       minute later; wait ~30s" \
      "Both sides settle on the newer edit (last write wins), no duplicate rows"

check "Deletion syncs (B → A)" \
      "B: delete the note B created in the earlier step" \
      "A: that note disappears on the next sync"

check "Recording stays intact (B)" \
      "B: open a visit that has a recording; tap play" \
      "The audio plays on B (audio is part of the shared journey)"

check "Stop sharing (A)" \
      "A: journey → share icon → 管理共享 → Stop Sharing (确认)" \
      "Sheet closes; the 共享中 pill disappears on A"

check "Revocation lands (B)" \
      "B: keep Carelogue open ~30–60s (or relaunch the app)" \
      "B sees 共享已结束; the journey and its records stay on B, edits no longer sync"

check "Merge tail (B, optional but recommended)" \
      "B: before accepting an invite, create a local journey with the SAME name
       as A's shared journey, add one note to it, THEN accept the invite" \
      "B is offered 并入共享旅程？ — choose 并入: both note sets end up in one journey"

printf '\n==========================================================\n'
if [[ ${#failures[@]} -eq 0 ]]; then
  printf ' All %d steps matched. T39 real-device acceptance: PASS\n' "$step"
else
  printf ' FAILURES (%d of %d steps):\n' "${#failures[@]}" "$step"
  printf '   - %s\n' "${failures[@]}"
  printf '\n Paste the list above back into the T39 card,\n'
  printf ' along with: iOS version of each device, and whether the failing\n'
  printf ' side was signed in to iCloud the whole time.\n'
fi
printf '==========================================================\n'

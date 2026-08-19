#!/bin/bash
# Record every remaining Season 1 chapter through the gen-esv-verse-audio
# edge function (must be deployed live first; re-stub it when this exits).
#
#   SUPABASE_ANON=... bash tools/record-season1.sh
#
# Idempotent and resumable: the function skips verses that already exist, so
# rerunning after a crash costs nothing but the ESV text fetches. Aborts
# after 3 consecutive failed calls (e.g. an exhausted ElevenLabs quota)
# rather than hammering a dead key.
set -u
FN="https://tkesywmshaicjmywbovn.supabase.co/functions/v1/gen-esv-verse-audio"
[ -n "${SUPABASE_ANON:-}" ] || { echo "SUPABASE_ANON missing"; exit 1; }

# Season 1, in journey order. ESV versification, matching by_reading_sections.
CHAPTERS=(
  "Colossians 2:1-23" "Colossians 3:1-25" "Colossians 4:1-18"
  "John 2:1-25" "John 3:1-36" "John 4:1-54" "John 5:1-47" "John 6:1-71"
  "John 7:1-53" "John 8:1-59" "John 9:1-41" "John 10:1-42" "John 11:1-57"
  "John 12:1-50" "John 13:1-38" "John 14:1-31" "John 15:1-27" "John 16:1-33"
  "John 17:1-26" "John 18:1-40" "John 19:1-42" "John 20:1-31" "John 21:1-25"
  "Genesis 1:1-31" "Genesis 2:1-25" "Genesis 3:1-24" "Genesis 4:1-26"
  "Genesis 5:1-32" "Genesis 6:1-22" "Genesis 7:1-24" "Genesis 8:1-22"
  "Genesis 9:1-29" "Genesis 10:1-32" "Genesis 11:1-32" "Genesis 12:1-20"
  "Genesis 13:1-18" "Genesis 14:1-24" "Genesis 15:1-21" "Genesis 16:1-16"
  "Genesis 17:1-27" "Genesis 18:1-33" "Genesis 19:1-38" "Genesis 20:1-18"
  "Genesis 21:1-34" "Genesis 22:1-24" "Genesis 23:1-20" "Genesis 24:1-67"
  "Genesis 25:1-34" "Genesis 26:1-35" "Genesis 27:1-46" "Genesis 28:1-22"
  "Genesis 29:1-35" "Genesis 30:1-43" "Genesis 31:1-55" "Genesis 32:1-32"
  "Genesis 33:1-20" "Genesis 34:1-31" "Genesis 35:1-29" "Genesis 36:1-43"
  "Genesis 37:1-36" "Genesis 38:1-30" "Genesis 39:1-23" "Genesis 40:1-23"
  "Genesis 41:1-57" "Genesis 42:1-38" "Genesis 43:1-34" "Genesis 44:1-34"
  "Genesis 45:1-28" "Genesis 46:1-34" "Genesis 47:1-31" "Genesis 48:1-22"
  "Genesis 49:1-33" "Genesis 50:1-26"
  "Psalm 1:1-6" "Psalm 8:1-9" "Psalm 19:1-14" "Psalm 29:1-11" "Psalm 33:1-22"
  "Psalm 90:1-17" "Psalm 104:1-35" "Psalm 139:1-24" "Psalm 148:1-14"
)

total_generated=0
fails=0
for REF in "${CHAPTERS[@]}"; do
  echo "=== $REF ==="
  while :; do
    R=$(curl -s --max-time 180 -X POST "$FN" \
        -H "Authorization: Bearer $SUPABASE_ANON" -H "Content-Type: application/json" \
        -d "{\"reference\":\"$REF\",\"max\":12}")
    GEN=$(echo "$R" | python3 -c "import json,sys
try:
  d=json.load(sys.stdin); print(len(d.get('generated',[])), d.get('remaining',-1), d.get('error',''))
except Exception: print('-1 -1 parse_error')" 2>/dev/null)
    read -r ngen remaining err <<< "$GEN"
    if [ "$ngen" = "-1" ] || [ -n "$err" ]; then
      fails=$((fails + 1))
      echo "  !! call failed ($err) — attempt $fails/3"
      if [ $fails -ge 3 ]; then
        echo "ABORTED at $REF after 3 consecutive failures. Generated $total_generated verses this run."
        echo "Rerun this script to resume — existing verses are skipped automatically."
        exit 2
      fi
      sleep 20
      continue
    fi
    fails=0
    total_generated=$((total_generated + ngen))
    echo "  +$ngen (remaining $remaining, run total $total_generated)"
    [ "$remaining" = "0" ] && break
    sleep 1
  done
done
echo "DONE — generated $total_generated verses this run."

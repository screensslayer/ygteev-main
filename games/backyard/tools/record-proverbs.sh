#!/bin/bash
# Record all of Proverbs (915 ESV verses) through gen-esv-verse-audio.
# Same resumable driver as record-season1.sh: existing verses are skipped,
# 3 consecutive failures abort instead of hammering a dead key.
#   SUPABASE_ANON=... bash tools/record-proverbs.sh
set -u
FN="https://tkesywmshaicjmywbovn.supabase.co/functions/v1/gen-esv-verse-audio"
[ -n "${SUPABASE_ANON:-}" ] || { echo "SUPABASE_ANON missing"; exit 1; }

CHAPTERS=(
  "Proverbs 1:1-33"  "Proverbs 2:1-22"  "Proverbs 3:1-35"  "Proverbs 4:1-27"
  "Proverbs 5:1-23"  "Proverbs 6:1-35"  "Proverbs 7:1-27"  "Proverbs 8:1-36"
  "Proverbs 9:1-18"  "Proverbs 10:1-32" "Proverbs 11:1-31" "Proverbs 12:1-28"
  "Proverbs 13:1-25" "Proverbs 14:1-35" "Proverbs 15:1-33" "Proverbs 16:1-33"
  "Proverbs 17:1-28" "Proverbs 18:1-24" "Proverbs 19:1-29" "Proverbs 20:1-30"
  "Proverbs 21:1-31" "Proverbs 22:1-29" "Proverbs 23:1-35" "Proverbs 24:1-34"
  "Proverbs 25:1-28" "Proverbs 26:1-28" "Proverbs 27:1-27" "Proverbs 28:1-28"
  "Proverbs 29:1-27" "Proverbs 30:1-33" "Proverbs 31:1-31"
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

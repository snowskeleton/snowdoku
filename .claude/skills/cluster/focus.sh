#!/bin/sh
# focus.sh <job> <chapters> <kinds> <threads>: mine in chunks until ~/snowdoku/<job>/STOP exists.
# Each chunk climbs from the archive's and earlier chunks' best puzzles (--seeds).
J=$1; B=$HOME/new/Engine/.build/release/sudokugen
cd ~/snowdoku && mkdir -p $J
i=$(ls $J/chunk*.jsonl 2>/dev/null | wc -l)
while [ ! -e $J/STOP ]; do
  i=$((i+1))
  S=archive.jsonl; for f in $J/chunk*.jsonl; do [ -s "$f" ] && S="$S,$f"; done
  M=120; [ $i -eq 1 ] && M=3   # a short smoke chunk first
  nice -n 10 $B campaign --chapter $2 --kind $3 --threads $4 --minutes $M --iterations 400 \
    --bank Puzzles.tsv --seeds "$S" > $J/chunk$i.jsonl 2> $J/chunk$i.log
done

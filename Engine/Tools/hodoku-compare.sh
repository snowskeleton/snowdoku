#!/bin/bash
# Cross-checks our technique detectors against HoDoKu's "Find All Steps" on the same positions.
#
#   Engine/Tools/hodoku-compare.sh [--min D] [--limit N] [--examples N] [PUZZLE_FILE]
#   Engine/Tools/hodoku-compare.sh --ratings      # bank tiers against HoDoKu's own levels
#
# PUZZLE_FILE defaults to App/Resources/Puzzles.tsv, --min to hard. Downloads HoDoKu 2.2.0 (GPL,
# run as a separate program; none of its code is used) into .build/hodoku once, checking its
# SHA-256, and needs a JDK (java, jshell). Prints the comparison; work files stay in .build/hodoku.
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT=$PWD
W=$ROOT/.build/hodoku
G=$ROOT/Engine/.build/release/sudokugen
JAR_URL=https://downloads.sourceforge.net/project/hodoku/hodoku/hodoku_2.2.0/hodoku.jar
JAR_SHA=6e5f0c865b6915acf9fa688eb0e43588139ef40d7375b0965677be5fe42294bc

MIN=hard; LIMIT=; EXAMPLES=3; FILE=App/Resources/Puzzles.tsv; RATINGS=
while [ $# -gt 0 ]; do
  case $1 in
    --min) MIN=$2; shift 2 ;;
    --limit) LIMIT=$2; shift 2 ;;
    --examples) EXAMPLES=$2; shift 2 ;;
    --ratings) RATINGS=1; shift ;;
    *) FILE=$1; shift ;;
  esac
done

mkdir -p "$W"
if [ ! -f "$W/hodoku.jar" ] || [ "$(shasum -a 256 "$W/hodoku.jar" | cut -d' ' -f1)" != "$JAR_SHA" ]; then
  curl -sfL -o "$W/hodoku.jar.part" "$JAR_URL"
  [ "$(shasum -a 256 "$W/hodoku.jar.part" | cut -d' ' -f1)" = "$JAR_SHA" ] || { echo "hodoku.jar checksum mismatch" >&2; exit 1; }
  mv "$W/hodoku.jar.part" "$W/hodoku.jar"
fi

# Find All Steps searches only basic and Franken fish and skips Kraken by default; widen it to
# everything we have a counterpart for.
if [ ! -f "$W/snowdoku.hcfg" ]; then
  cat > "$W/makecfg.jsh" <<EOF
import sudoku.*;
var o = Options.getInstance();
o.setAllStepsMaxFishType(2);
for (var s : o.solverSteps) if (s.getType().getStepName().startsWith("Kraken Fish")) s.setAllStepsEnabled(true);
o.writeOptions("$W/snowdoku.hcfg");
/exit
EOF
  jshell --class-path "$W/hodoku.jar" -R-Djava.awt.headless=true "$W/makecfg.jsh" >/dev/null 2>&1
fi

JOBS=$(( $(sysctl -n hw.ncpu 2>/dev/null || nproc) * 2 / 3 ))
[ "$JOBS" -lt 1 ] && JOBS=1

# Runs HoDoKu with the given options on every file in $W/$1 (relative paths only: HoDoKu takes any
# argument starting with "/" for an option), in parallel. Each process gets its own temp dir,
# since HoDoKu rewrites a config file there at startup.
run_hodoku() {
  local dir=$1; shift
  (cd "$W" && ls "$dir"/part.??? | xargs -P "$JOBS" -I{} sh -c \
    'f=$1; shift; mkdir -p "$f.tmp" && java -Xmx1g -Djava.awt.headless=true -Djava.io.tmpdir="$f.tmp" -jar hodoku.jar "$@" "$f" /o "$f.out" >"$f.log" 2>&1' _ {} "$@")
  for f in "$W/$dir"/part.???; do
    [ -s "$f.out" ] || { echo "HoDoKu failed on $f; see $f.log" >&2; exit 1; }
  done
}

if [ -n "$RATINGS" ]; then
  # HoDoKu's default solver (its own order and enabled steps) on every bank puzzle.
  rm -rf "$W/ratings"; mkdir "$W/ratings"
  cut -f1 "$FILE" > "$W/ratings/givens.txt"
  split -l $(( ($(wc -l < "$W/ratings/givens.txt") + JOBS - 1) / JOBS )) -a 3 "$W/ratings/givens.txt" "$W/ratings/part."
  run_hodoku ratings /vp /bs
  cat "$W"/ratings/part.???.out > "$W/ratings/hodoku.txt"
  printf 'import sudoku.*;\nfor (var s : Options.getInstance().solverSteps) System.out.println(StepConfig.getLevelName(s.getLevel()) + "\\t" + s.getType().getStepName());\n/exit\n' > "$W/levels.jsh"
  jshell --class-path "$W/hodoku.jar" -R-Djava.awt.headless=true "$W/levels.jsh" 2>/dev/null | grep -E $'^[A-Za-z]+\t' > "$W/ratings/levels.tsv"
  swift build -c release --package-path Engine >/dev/null
  "$G" bank-tiers "$FILE" > "$W/ratings/tiers.tsv"
  python3 -I "$ROOT/Engine/Tools/hodoku-ratings.py" "$W/ratings/tiers.tsv" "$W/ratings/hodoku.txt" "$W/ratings/levels.tsv"
  exit 0
fi

swift build -c release --package-path Engine >/dev/null
"$G" hodoku-positions --min "$MIN" ${LIMIT:+--limit "$LIMIT"} "$FILE" > "$W/positions.txt"
N=$(wc -l < "$W/positions.txt" | tr -d ' ')
echo "$N positions; running HoDoKu in $JOBS processes" >&2

rm -rf "$W/chunks"; mkdir "$W/chunks"
split -l $(( (N + JOBS - 1) / JOBS )) -a 3 "$W/positions.txt" "$W/chunks/part."
run_hodoku chunks /c snowdoku.hcfg /bsaf

# Each chunk numbers its positions from 1; renumber them to match positions.txt.
OFFSET=0; : > "$W/hodoku.txt"
for f in "$W"/chunks/part.???; do
  awk -v off=$OFFSET '/ #[0-9]+$/ && !/^ / { n = $NF; sub(/#/, "", n); sub(/ #[0-9]+$/, " #" (n + off)) } { print }' "$f.out" >> "$W/hodoku.txt"
  OFFSET=$(( OFFSET + $(wc -l < "$f" | tr -d ' ') ))
done

"$G" hodoku-compare --examples "$EXAMPLES" "$W/positions.txt" "$W/hodoku.txt"

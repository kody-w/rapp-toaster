#!/usr/bin/env bash
# bridges/openclaw.sh — bolt the toaster onto openclaw's skill corpus.
#                       WITHOUT openclaw doing anything.
#
# This script is the thesis proving itself. A migration needs the platform's
# buy-in: someone has to change a format, ship a converter, deprecate a path.
# A SHIM needs nobody's permission — that is what makes it a shim.
#
# So the honest test of the claim "this is not a migration tool" is whether it
# can be run unilaterally, today, against a live third-party registry, with
# zero involvement from its maintainers. That is exactly what this does.
#
# It fetches openclaw's public skills, toasts them (deriving whatever
# deterministic layer their prose actually evidences), emits a single-file
# stdlib-only agent for each, and proves every one converts BACK byte-exact.
# openclaw's repository is never modified. Nothing is upstreamed. No permission
# is requested.
#
# If openclaw adopts this natively it gets better for everyone -- authors get
# the oracle in CI, the capsule travels from the source, and provenance starts
# at publication rather than at our fetch. But nobody has to wait for that.
#
#   ./bridges/openclaw.sh              # fetch, toast, verify, report
#   ./bridges/openclaw.sh --limit 5    # smaller run
#   ./bridges/openclaw.sh --out DIR    # where to write the bolted-on corpus
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOASTER="$HERE/toaster.py"
OUT="$HERE/.openclaw-bridge"
LIMIT=0
SOAK_DEPTH=2
SOAK_CYCLES=10

while [ $# -gt 0 ]; do
  case "$1" in
    --limit) LIMIT="$2"; shift 2 ;;
    --out)   OUT="$2"; shift 2 ;;
    --deep)  SOAK_DEPTH=3; SOAK_CYCLES=25; shift ;;
    -h|--help) sed -n '2,26p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
done

command -v gh >/dev/null || { echo "FATAL: gh required to enumerate skills" >&2; exit 69; }

rm -rf "$OUT"; mkdir -p "$OUT/skills"

echo "== enumerating openclaw's public skill corpus =="
{
  gh api "repos/openclaw/openclaw/git/trees/HEAD?recursive=1" \
    --jq '.tree[]|select(.path|test("^\\.agents/skills/[^/]+/SKILL\\.md$"))|"openclaw/openclaw\t\(.path)"' 2>/dev/null
  gh api "repos/openclaw/agent-skills/git/trees/HEAD?recursive=1" \
    --jq '.tree[]|select(.path|test("SKILL\\.md$"))|"openclaw/agent-skills\t\(.path)"' 2>/dev/null
} > "$OUT/corpus.tsv"

total=$(wc -l < "$OUT/corpus.tsv" | tr -d ' ')
[ "$LIMIT" -gt 0 ] && { head -"$LIMIT" "$OUT/corpus.tsv" > "$OUT/c.tmp"; mv "$OUT/c.tmp" "$OUT/corpus.tsv"; }
n=$(wc -l < "$OUT/corpus.tsv" | tr -d ' ')
echo "   $total skill(s) found; processing $n"

echo "== fetching (read-only; openclaw is never modified) =="
fetched=0
while IFS=$'\t' read -r repo path; do
  [ -z "$path" ] && continue
  slug=$(printf '%s' "$path" | sed 's|.*/skills/||; s|/SKILL.md$||; s|/|-|g')
  [ "$slug" = "$path" ] && slug=$(printf '%s' "$path" | sed 's|/SKILL.md$||; s|/|-|g')
  mkdir -p "$OUT/skills/$slug"
  if curl -fsSL "https://raw.githubusercontent.com/$repo/HEAD/$path" \
       -o "$OUT/skills/$slug/SKILL.md" 2>/dev/null; then
    fetched=$((fetched+1))
  else
    rmdir "$OUT/skills/$slug" 2>/dev/null
  fi
done < "$OUT/corpus.tsv"
echo "   fetched $fetched"

echo "== toasting: derive a deterministic layer from each skill's own prose =="
params=0; steps=0; toasted=0; barren=0
for d in "$OUT"/skills/*/; do
  f="$d/SKILL.md"; [ -f "$f" ] || continue
  rep=$(python3 "$TOASTER" toast "$f" 2>&1)
  echo "$rep" | grep -q "toasted" || continue
  toasted=$((toasted+1))
  p=$(echo "$rep" | sed -n 's/.*typed params  [0-9]* -> \([0-9]*\).*/\1/p' | head -1)
  s=$(echo "$rep" | sed -n 's/.*steps lifted  \([0-9]*\).*/\1/p' | head -1)
  params=$((params + ${p:-0})); steps=$((steps + ${s:-0}))
  { [ "${p:-0}" -eq 0 ] && [ "${s:-0}" -eq 0 ]; } && barren=$((barren+1))
done
echo "   toasted $toasted  |  $params typed param(s), $steps step(s) derived"
echo "   $barren skill(s) yielded NOTHING machine-recoverable"

echo "== projecting each into a single-file, stdlib-only agent =="
agents=0; runnable=0
for d in "$OUT"/skills/*/; do
  f="$d/SKILL.md"; [ -f "$f" ] || continue
  if python3 "$TOASTER" convert "$f" --to agent -o "$d/agent.py" >/dev/null 2>&1; then
    agents=$((agents+1))
    python3 "$d/agent.py" --tool >/dev/null 2>&1 && runnable=$((runnable+1))
  fi
done
echo "   $agents agent(s) emitted; $runnable run standalone and declare a tool contract"

echo "== proving each converts BACK to openclaw's own file, byte-exact =="
exact=0; drifted=0
for d in "$OUT"/skills/*/; do
  [ -f "$d/agent.py" ] || continue
  python3 "$TOASTER" convert "$d/agent.py" --to skill -o "$d/back.md" >/dev/null 2>&1 || continue
  if cmp -s "$d/SKILL.md" "$d/back.md"; then exact=$((exact+1)); else drifted=$((drifted+1)); echo "   DRIFT: $(basename "$d")"; fi
done
echo "   $exact byte-exact, $drifted drifted"

echo "== drift oracle over the corpus (fixed point / path independence / idempotence) =="
# NOTE: no mapfile/readarray -- macOS ships bash 3.2 and this must run on the
# machine people actually have, not the one the CI image has.
find "$OUT/skills" -name SKILL.md -print0 2>/dev/null > "$OUT/all.z"
if [ -s "$OUT/all.z" ]; then
  xargs -0 python3 "$TOASTER" soak --depth "$SOAK_DEPTH" --cycles "$SOAK_CYCLES" < "$OUT/all.z" 2>&1 | tail -4
else
  echo "   no skills to soak"
fi

echo
echo "RESULT: $exact/$agents openclaw skills are now portable single-file agents"
echo "        that convert back to openclaw's own bytes exactly."
echo "        openclaw was not modified, not asked, and not waited on."
[ "$drifted" -eq 0 ] || exit 1

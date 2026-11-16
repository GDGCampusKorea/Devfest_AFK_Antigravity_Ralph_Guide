#!/usr/bin/env bash
# Ralph Loop runner for Antigravity (agy CLI) — AFKathon edition
# Each iteration = a FRESH agy session that re-reads PRD.md + progress.txt from disk,
# does exactly ONE task, marks it [x], appends progress, and commits.
#
# Hardened control loop:
#   - FAILURE detection : non-zero agy exit = non-progress iteration, not a silent success.
#   - STALL detection   : compares checked-off task count before/after each iteration and
#                         aborts after RALPH_MAX_STALLS consecutive non-progress iterations.
#   - TIME budget       : RALPH_MINUTES stops the loop before the next session break.
#   - KEEP AWAKE        : macOS re-execs itself under `caffeinate -i`.
#   - LOG FILE          : everything is tee'd to logs/ for the 20-minute checkpoint.
set -uo pipefail
# agy does NOT inherit the shell cwd as its workspace, so pass it via --add-dir and the prompt.
REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO"

# macOS: keep the machine awake while the loop runs (lid must stay open).
if [ "$(uname)" = "Darwin" ] && [ -z "${RALPH_CAFFEINATED:-}" ] && command -v caffeinate >/dev/null; then
  RALPH_CAFFEINATED=1 exec caffeinate -i bash "$0" "$@"
fi

MODEL="${RALPH_MODEL:-Gemini 3.8 Flash (High)}"
MAX_ITERS="${RALPH_MAX_ITERS:-15}"
MAX_STALLS="${RALPH_MAX_STALLS:-2}"
MINUTES="${RALPH_MINUTES:-0}"          # 0 = no time budget
ITER_TIMEOUT_MIN=15
MIN_ITER_MIN=3                         # don't start an iteration with less time than this left
PRD="PRD.md"
PROGRESS="progress.txt"

mkdir -p logs
LOG="logs/ralph-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

# Refuse to run on an unfilled template (placeholders look like {{...}}).
if grep -q '{{' "$PRD"; then
  echo "🛑 $PRD 에 아직 채우지 않은 {{ }} 칸이 있습니다:"
  grep -n '{{' "$PRD"
  exit 1
fi

case "$(uname -s)" in
  Darwin) echo "☕ caffeinate 로 절전을 막고 있습니다. 노트북 덮개는 닫지 마세요." ;;
  *)      echo "⚠ Windows/Linux: 전원 설정에서 '절전 모드 안 함'으로 바꾸고 덮개를 닫지 마세요." ;;
esac

count_done() { grep -cE '^- \[x\]' "$PRD" 2>/dev/null || true; }
# Done when the agent wrote the sentinel OR no unchecked task line is left (saves one agy call).
all_done() { grep -q "ALL TASKS COMPLETE" "$PROGRESS" 2>/dev/null || ! grep -qE '^- \[ \]' "$PRD"; }

if all_done; then
  echo "✅ 남은 태스크가 없습니다. PRD.md 에 새 태스크를 추가한 뒤 다시 실행하세요."
  exit 0
fi

PROMPT="The project directory is: $REPO
All file reads, file writes, and git commits MUST happen inside that exact directory.
cd into it first, then read ./PRD.md and ./progress.txt there.
"'You are running ONE iteration of a Ralph Loop.
Follow the "Agent Operating Rules (Ralph Loop)" section of PRD.md EXACTLY:
- Do the single lowest-numbered unchecked "[ ]" task only.
- Verify it against its "Done when" criteria.
- Mark that task "[x]" in PRD.md.
- Append one line to progress.txt: "TASK <n> DONE — <one-line summary>" (never delete lines).
- Commit ONLY this task with message "feat: task <n> — <summary>".
- Do NOT start a second task. Stop after one.
- If every task is already "[x]", append "ALL TASKS COMPLETE" to progress.txt and stop.'

deadline=0
[ "$MINUTES" -gt 0 ] && deadline=$(( $(date +%s) + MINUTES * 60 ))
echo "▶ model=$MODEL  max_iters=$MAX_ITERS  minutes=$MINUTES  log=$LOG"

stalls=0
for i in $(seq 1 "$MAX_ITERS"); do
  timeout_min=$ITER_TIMEOUT_MIN
  if [ "$deadline" -gt 0 ]; then
    left=$(( (deadline - $(date +%s)) / 60 ))
    if [ "$left" -lt "$MIN_ITER_MIN" ]; then
      echo "⏰ 시간 예산 ${MINUTES}분을 다 썼습니다. 점검 후 다시 실행하세요: bash ralph.sh"
      exit 0
    fi
    [ "$left" -lt "$timeout_min" ] && timeout_min=$left
  fi

  echo "───────────────────────────── Ralph iteration $i / $MAX_ITERS  ($(date +%H:%M), model: $MODEL)"
  before_head="$(git rev-parse HEAD 2>/dev/null || echo none)"
  before_done="$(count_done)"; before_done="${before_done:-0}"

  # exit code 3 = --print-timeout cut the turn short (counted as non-progress below)
  agy -p "$PROMPT" \
      --model "$MODEL" \
      --add-dir "$REPO" \
      --mode accept-edits \
      --dangerously-skip-permissions \
      --print-timeout "${timeout_min}m" 2>&1
  rc=$?

  after_head="$(git rev-parse HEAD 2>/dev/null || echo none)"
  after_done="$(count_done)"; after_done="${after_done:-0}"

  if all_done; then
    echo "✅ 모든 태스크 완료 — $i 회 반복 후 종료합니다."
    exit 0
  fi

  if [ "$rc" -ne 0 ]; then
    stalls=$((stalls + 1))
    echo "❌ agy 비정상 종료 (rc=$rc). 무진전 $stalls/$MAX_STALLS"
  elif [ "$after_done" -gt "$before_done" ]; then
    [ "$after_head" != "$before_head" ] \
      && echo "✔ 진행: 태스크 $before_done → $after_done, 커밋 $after_head" \
      || echo "✔ 태스크 $before_done → $after_done, 그러나 새 커밋 없음 (커밋 확인 필요)"
    stalls=0
  else
    stalls=$((stalls + 1))
    echo "⚠ 이번 반복에서 완료된 태스크 없음 (완료 $after_done 개 유지). 정체 $stalls/$MAX_STALLS"
  fi

  if [ "$stalls" -ge "$MAX_STALLS" ]; then
    echo "🛑 연속 $stalls 회 진전이 없어 중단합니다. docs/checkpoint-20min.md 순서대로 점검하세요."
    echo "   확인: git log --oneline -5 ; git status ; tail progress.txt ; tail -50 $LOG"
    exit 1
  fi

  if [ "$stalls" -gt 0 ]; then sleep 15; else sleep 2; fi
done

echo "⚠️ RALPH_MAX_ITERS=$MAX_ITERS 에 도달했습니다. 다시 실행하면 이어서 진행합니다."
exit 1

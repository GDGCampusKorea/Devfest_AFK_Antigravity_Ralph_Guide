#!/usr/bin/env bash
# Ralph Loop runner for Antigravity (agy CLI) — AFKathon edition
# Each iteration = a FRESH agy session that re-reads PRD.md + progress.txt (+ AGENTS.md)
# from disk, does exactly ONE task, verifies it, marks [x], appends progress, and commits.
#
# Hardened control loop:
#   - LOCK              : prevents concurrent ralph.sh runs in the same repo (.ralph.lock).
#   - CLEAN TREE        : refuses to start or continue with uncommitted changes.
#   - FAILURE detection : non-zero agy exit = non-progress iteration (unless all tasks already
#                         completed with a clean working tree).
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

LOCK_DIR="$REPO/.ralph.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "🛑 이미 다른 ralph.sh 프로세스가 실행 중입니다 (.ralph.lock 존재)."
  echo "   실행 중인 루프가 없다면 'rmdir .ralph.lock' 후 다시 시도하세요."
  exit 1
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

MODEL="${RALPH_MODEL:-}"               # empty = use account default model (recommended)
MAX_ITERS="${RALPH_MAX_ITERS:-15}"
MAX_STALLS="${RALPH_MAX_STALLS:-2}"
MINUTES="${RALPH_MINUTES:-0}"          # 0 = no time budget
ITER_TIMEOUT_MIN=15
MIN_ITER_MIN=3                         # don't start an iteration with less time than this left
PRD="PRD.md"
PROGRESS="progress.txt"

model_args=()
[ -n "$MODEL" ] && model_args=(--model "$MODEL")

mkdir -p logs
LOG="logs/ralph-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

if [ ! -f "$PRD" ]; then
  echo "🛑 $PRD 파일이 없습니다. 템플릿 저장소 루트에서 실행하세요."
  exit 1
fi

# Refuse to run on an unfilled template (placeholders look like {{...}}).
if grep -q '{{' "$PRD"; then
  echo "🛑 $PRD 에 아직 채우지 않은 {{ }} 칸이 있습니다:"
  grep -n '{{' "$PRD"
  exit 1
fi

if ! grep -qE '^- \[[ xX]\]' "$PRD"; then
  echo "🛑 $PRD 에 태스크 항목('- [ ] ...')이 없습니다. Tasks 섹션을 확인하세요."
  exit 1
fi

is_clean_tree() { [ -z "$(git status --porcelain 2>/dev/null)" ]; }
count_done() { grep -cE '^- \[[xX]\]' "$PRD" 2>/dev/null || true; }
# Done ONLY when PRD.md exists and has no unchecked "- [ ]" tasks left.
all_done() { [ -f "$PRD" ] && ! grep -qE '^- \[ \]' "$PRD"; }

if ! is_clean_tree; then
  echo "🛑 작업 트리에 커밋되지 않은 변경이 있습니다. 먼저 커밋하거나 정리한 뒤 실행하세요."
  git status -s
  exit 1
fi

case "$(uname -s)" in
  Darwin) echo "☕ caffeinate 로 절전을 막고 있습니다. 노트북 덮개는 닫지 마세요." ;;
  *)      echo "⚠ Windows/Linux: 전원 설정에서 '절전 모드 안 함'으로 바꾸고 덮개를 닫지 마세요." ;;
esac

if all_done; then
  echo "✅ 남은 태스크가 없습니다. PRD.md 에 새 태스크('- [ ] ...')를 추가한 뒤 다시 실행하세요."
  exit 0
fi

# Keep operating rules in PRD.md as the single source of truth; prompt only points to them.
PROMPT="The project directory is: $REPO
All file reads, file writes, and git commits MUST happen inside that exact directory.
cd into it first, then read ./PRD.md, ./progress.txt, and ./AGENTS.md (if it exists).
You are running ONE iteration of a Ralph Loop.
Follow the \"Agent Operating Rules (Ralph Loop)\" section of PRD.md EXACTLY."

deadline=0
[ "$MINUTES" -gt 0 ] && deadline=$(( $(date +%s) + MINUTES * 60 ))
echo "▶ model=${MODEL:-account-default}  max_iters=$MAX_ITERS  minutes=$MINUTES  log=$LOG"

stalls=0
for i in $(seq 1 "$MAX_ITERS"); do
  if all_done && is_clean_tree; then
    echo "✅ 모든 태스크 완료 — 루프를 종료합니다."
    exit 0
  fi

  timeout_min=$ITER_TIMEOUT_MIN
  if [ "$deadline" -gt 0 ]; then
    left=$(( (deadline - $(date +%s)) / 60 ))
    if [ "$left" -lt "$MIN_ITER_MIN" ]; then
      echo "⏰ 시간 예산 ${MINUTES}분을 다 썼습니다. 점검 후 다시 실행하세요: bash ralph.sh"
      exit 0
    fi
    [ "$left" -lt "$timeout_min" ] && timeout_min=$left
  fi

  echo "───────────────────────────── Ralph iteration $i / $MAX_ITERS  ($(date +%H:%M), model: ${MODEL:-account-default})"
  before_head="$(git rev-parse HEAD 2>/dev/null || echo none)"
  before_done="$(count_done)"; before_done="${before_done:-0}"

  # exit code 3 = --print-timeout cut the turn short (requires agy >= 1.5.0)
  agy -p "$PROMPT" \
      ${model_args[@]+"${model_args[@]}"} \
      --add-dir "$REPO" \
      --mode accept-edits \
      --dangerously-skip-permissions \
      --print-timeout "${timeout_min}m" 2>&1
  rc=$?

  after_head="$(git rev-parse HEAD 2>/dev/null || echo none)"
  after_done="$(count_done)"; after_done="${after_done:-0}"

  if [ "$rc" -ne 0 ]; then
    if all_done && is_clean_tree; then
      echo "✅ 모든 태스크 완료 (커밋 후 agy 종료 코드 rc=$rc) — $i 회 반복 후 종료합니다."
      exit 0
    fi
    stalls=$((stalls + 1))
    if [ "$rc" -eq 3 ]; then
      echo "❌ agy 타임아웃 종료 (rc=3, ${timeout_min}m 초과). 무진전 $stalls/$MAX_STALLS"
    else
      echo "❌ agy 비정상 종료 (rc=$rc). 무진전 $stalls/$MAX_STALLS"
    fi
  elif [ "$after_done" -gt "$before_done" ]; then
    if [ "$after_head" = "$before_head" ] || ! is_clean_tree; then
      echo "🛑 태스크($before_done → $after_done)는 체크됐지만 커밋이 누락되었거나 작업 트리가 깨끗하지 않습니다."
      echo "   작업 트리를 그대로 보존하고 중단합니다. docs/checkpoint-20min.md 2장을 확인하세요."
      git status -s
      exit 1
    fi
    echo "✔ 진행: 태스크 $before_done → $after_done, 커밋 $after_head"
    stalls=0
    if all_done; then
      echo "✅ 모든 태스크 완료 — $i 회 반복 후 종료합니다."
      exit 0
    fi
  else
    if ! is_clean_tree; then
      echo "🛑 태스크 완료 표시는 늘지 않았지만 작업 트리에 커밋되지 않은 변경이 남아 있습니다."
      echo "   작업 트리를 그대로 보존하고 중단합니다. docs/checkpoint-20min.md 2장을 확인하세요."
      if [ -f "$PROGRESS" ]; then
        blocked="$(grep 'BLOCKED' "$PROGRESS" | tail -n 3 || true)"
        [ -n "$blocked" ] && { echo "   최근 BLOCKED 기록:"; echo "$blocked" | sed 's/^/     /'; }
      fi
      git status -s
      exit 1
    fi
    stalls=$((stalls + 1))
    echo "⚠ 이번 반복에서 완료된 태스크 없음 (완료 $after_done 개 유지). 정체 $stalls/$MAX_STALLS"
  fi

  if [ "$stalls" -ge "$MAX_STALLS" ]; then
    echo "🛑 연속 $stalls 회 진전이 없어 중단합니다. docs/checkpoint-20min.md 순서대로 점검하세요."
    if [ -f "$PROGRESS" ]; then
      blocked="$(grep 'BLOCKED' "$PROGRESS" | tail -n 3 || true)"
      if [ -n "$blocked" ]; then
        echo "   최근 BLOCKED 기록:"
        echo "$blocked" | sed 's/^/     /'
      fi
    fi
    echo "   확인: git log --oneline -5 ; git status ; tail progress.txt ; tail -50 $LOG"
    exit 1
  fi

  if [ "$stalls" -gt 0 ]; then sleep 15; else sleep 2; fi
done

echo "⚠️ RALPH_MAX_ITERS=$MAX_ITERS 에 도달했습니다. 다시 실행하면 이어서 진행합니다."
exit 1

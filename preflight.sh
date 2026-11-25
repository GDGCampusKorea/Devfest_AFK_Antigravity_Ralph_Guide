#!/usr/bin/env bash
# AFKathon preflight: checks everything ralph.sh needs, prints ✅/❌ per item.
# Usage: bash preflight.sh          (full check, includes one real agy tool-write test)
#        bash preflight.sh --quick  (skip the real agy call)
set -uo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO"

MODEL="${RALPH_MODEL:-}"
model_args=()
[ -n "$MODEL" ] && model_args=(--model "$MODEL")

probe_file=""
trap '[ -n "$probe_file" ] && rm -f "$probe_file"' EXIT

fail=0
ok()   { echo "✅ $1"; }
warn() { echo "⚠️  $1"; echo "   → $2"; }
bad()  { echo "❌ $1"; echo "   → $2"; fail=1; }

echo "== AFKathon preflight ($(uname -s)) =="

if command -v git >/dev/null; then ok "git 설치됨"; else bad "git 없음" "https://git-scm.com 에서 설치하세요."; fi

if [ -n "$(git config user.name)" ] && [ -n "$(git config user.email)" ]; then
  ok "git 사용자 설정: $(git config user.name)"
else
  bad "git 사용자 설정 없음" 'git config --global user.name "이름"; git config --global user.email "메일"'
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then ok "git 저장소 안에서 실행 중"
else bad "git 저장소가 아님" "템플릿 저장소를 clone 한 폴더 안에서 실행하세요."; fi

if command -v node >/dev/null; then
  ok "Node.js 설치됨: $(node --version 2>/dev/null)"
else
  warn "Node.js 미설치 (선택 사항)" "랜딩 페이지 예제 등 JS 검증 명령(node)을 쓰려면 https://nodejs.org 에서 설치하세요."
fi

if command -v agy >/dev/null; then
  ok "agy 설치됨: $(command -v agy)"
else
  bad "agy 를 찾을 수 없음" "Antigravity 설치 후 'agy install' 로 PATH 를 설정하고 터미널을 다시 여세요."
  echo; echo "❌ 위 항목을 먼저 해결하세요."; exit 1
fi

ver_raw="$(agy --version 2>/dev/null | head -1 | tr -d '\r')"
ver_mm="$(echo "$ver_raw" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
if [ -n "$ver_mm" ]; then
  major="${ver_mm%%.*}"
  minor="${ver_mm#*.}"
  if [ "$major" -gt 1 ] || { [ "$major" -eq 1 ] && [ "$minor" -ge 5 ]; }; then
    ok "agy 버전: $ver_raw (>= 1.5.0, 타임아웃 종료 코드 3 지원)"
  else
    warn "agy 버전: $ver_raw (1.5.0 미만)" "agy update 로 업데이트하는 것을 권장합니다."
  fi
else
  warn "agy 버전을 파싱할 수 없음 (출력: ${ver_raw:-없음})" "agy --version 출력을 확인하세요."
fi

if ! models="$(agy models 2>&1)"; then
  bad "agy models 실패 (로그인 확인)" "Antigravity 앱을 열어 Google 계정으로 로그인하세요. 출력: $(echo "$models" | tail -1)"
elif [ -z "$MODEL" ]; then
  ok "모델: 계정 기본값 사용 (지정하려면 RALPH_MODEL 설정, 목록: agy models)"
elif echo "$models" | grep -qF "$MODEL"; then
  ok "모델 사용 가능: $MODEL"
else
  bad "모델 '$MODEL' 이 목록에 없음" "agy models 로 이름을 확인하고 RALPH_MODEL 로 지정하세요."
fi

if [ "${1:-}" != "--quick" ] && [ "$fail" -eq 0 ]; then
  token="ralph-probe-$$-$(date +%s)-${RANDOM:-0}"
  probe_file="$REPO/.preflight-probe-$$.txt"
  rm -f "$probe_file"
  echo "… agy 단발 실행 + 실제 파일 쓰기 도구 검증 (ralph.sh 와 동일 옵션, 최대 2분)"
  out="$(agy -p "Use your file-writing tool to write the exact string '$token' (no extra text) into the file $probe_file, then stop." \
      ${model_args[@]+"${model_args[@]}"} \
      --add-dir "$REPO" \
      --mode accept-edits \
      --dangerously-skip-permissions \
      --print-timeout 2m 2>&1)"
  rc=$?
  actual=""
  [ -f "$probe_file" ] && actual="$(tr -d '[:space:]' < "$probe_file")"
  if [ "$rc" -eq 0 ] && [ "$actual" = "$token" ]; then
    ok "agy 단발 실행 및 실제 도구 호출(파일 쓰기) 성공"
  else
    bad "agy 도구 호출 검증 실패 (rc=$rc, 파일 생성/내용 불일치)" "도구 권한·쿼터·네트워크를 확인하세요. 출력: $(echo "$out" | tail -3)"
  fi
fi

echo
if [ "$fail" -eq 0 ]; then echo "🎉 준비 완료. 다음: PRD.md 의 {{ }} 칸을 채우고 bash ralph.sh"; else echo "❌ 위 항목을 해결한 뒤 다시 실행하세요."; fi
exit "$fail"

#!/usr/bin/env bash
# AFKathon preflight: checks everything ralph.sh needs, prints ✅/❌ per item.
# Usage: bash preflight.sh          (full check, includes one real agy call)
#        bash preflight.sh --quick  (skip the real agy call)
set -uo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"

MODEL="${RALPH_MODEL:-Gemini 3.8 Flash (High)}"
fail=0
ok()  { echo "✅ $1"; }
bad() { echo "❌ $1"; echo "   → $2"; fail=1; }

echo "== AFKathon preflight ($(uname -s)) =="

if command -v git >/dev/null; then ok "git 설치됨"; else bad "git 없음" "https://git-scm.com 에서 설치하세요."; fi

if [ -n "$(git config user.name)" ] && [ -n "$(git config user.email)" ]; then
  ok "git 사용자 설정: $(git config user.name)"
else
  bad "git 사용자 설정 없음" 'git config --global user.name "이름"; git config --global user.email "메일"'
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then ok "git 저장소 안에서 실행 중"
else bad "git 저장소가 아님" "템플릿 저장소를 clone 한 폴더 안에서 실행하세요."; fi

if command -v agy >/dev/null; then
  ok "agy 설치됨: $(command -v agy)"
else
  bad "agy 를 찾을 수 없음" "Antigravity 설치 후 'agy install' 로 PATH 를 설정하고 터미널을 다시 여세요."
  echo; echo "❌ 위 항목을 먼저 해결하세요."; exit 1
fi

if ! models="$(agy models 2>&1)"; then
  bad "agy models 실패 (로그인 확인)" "Antigravity 앱을 열어 Google 계정으로 로그인하세요. 출력: $(echo "$models" | tail -1)"
elif echo "$models" | grep -qF "$MODEL"; then
  ok "모델 사용 가능: $MODEL"
else
  bad "모델 '$MODEL' 이 목록에 없음" "agy models 로 이름을 확인하고 RALPH_MODEL 로 지정하세요."
fi

if [ "${1:-}" != "--quick" ] && [ "$fail" -eq 0 ]; then
  echo "… agy 단발 실행 테스트 (최대 2분)"
  if out="$(agy -p "Reply with exactly: OK" --model "$MODEL" --print-timeout 2m 2>&1)" && echo "$out" | grep -q "OK"; then
    ok "agy 단발 실행 성공"
  else
    bad "agy 단발 실행 실패 (쿼터·네트워크 확인)" "출력: $(echo "$out" | tail -3)"
  fi
fi

echo
if [ "$fail" -eq 0 ]; then echo "🎉 준비 완료. 다음: PRD.md 의 {{ }} 칸을 채우고 bash ralph.sh"; else echo "❌ 위 항목을 해결한 뒤 다시 실행하세요."; fi
exit "$fail"

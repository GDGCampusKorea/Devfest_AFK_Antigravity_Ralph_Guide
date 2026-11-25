# [DevFest 26] What is Ralph? Going AFK with Antigravity

**GDG 2026 DevFest: AFK (Away From Keyboard)** 랄프톤 참가자를 위한 Antigravity CLI(`agy`) 기반 Ralph Loop 실전 가이드입니다.

---

## 준비물

시작하기 전에 아래 4가지를 준비하세요. (`bash preflight.sh`로 한 번에 점검할 수 있습니다.)

1. **Antigravity 설치 (`agy` CLI)**: 설치 후 터미널에서 `agy`가 잡히지 않으면 `agy install`로 PATH를 설정하고 터미널을 다시 엽니다.
2. **Google 계정 로그인**: Antigravity 앱에서 본인 Google 계정으로 로그인합니다.
3. **Git 사용자 설정**: `git config --global user.name "이름"` / `git config --global user.email "메일"`
4. **Node.js (권장)**: 랜딩 페이지 예제 등 JS 문법·HTML 검증 명령(`node`)을 실행할 때 필요합니다.

---

## 1. Ralph Loop란 무엇인가?

**Ralph Loop**는 사람이 매 턴 채팅창에서 지시하고 기다리는 대신, **명확한 목표(PRD)와 완료 조건**을 주고 AI 에이전트가 목표를 달성할 때까지 **스스로 실행 → 검증 → 기록을 반복**하게 두는 자율 개발 패턴입니다.

Antigravity에서는 크게 두 가지 방식으로 자율 실행을 구성할 수 있습니다.
> 아래의 **Level 1 / Level 2**는 품질의 우열이 아니라 **준비물과 통제 수준의 차이**를 뜻합니다.

| 구분 | 방식 | 특징 | 추천 상황 |
|------|------|------|-----------|
| **Level 1 (`/goal`)** | **같은 대화 세션**을 이어가는 방식 | Google이 장시간 자율 실행의 기본 방식으로 안내하는 내장 커맨드 | 별도 파일 준비 없이 바로 장시간 자율 실행을 쓰고 싶을 때 |
| **Level 2 (`ralph.sh`)** | **매 반복마다 새 세션**을 여는 Ralph의 원형 방식 | 컨텍스트 초기화, 태스크별 Git 커밋, 시간 예산·정체 자동 감지 | **이번 랄프톤(AFK)**, 여러 태스크를 통제하며 완주할 때 |

---

## 2. Level 1 — 내장 커맨드로 시작하기: `/goal`

Claude Code의 공식 **Ralph Loop 플러그인(`/ralph-loop`)**과 유사하게, Antigravity에서는 Google이 장시간 자율 실행의 기본 방식으로 안내하는 내장 슬래시 커맨드 **`/goal`**을 사용할 수 있습니다.

```text
# agy 대화창 안에서 실행
/goal index.html에 반응형 타이머 앱을 만들고 모든 버튼 동작을 검증해줘
```

`/goal`은 에이전트의 **종료를 가로채 같은 대화에서 계속 이어가게** 만듭니다.

### 랄프톤에서 Level 2(`ralph.sh`)를 추가로 쓰는 이유
- **승인 프롬프트 때문에 자리를 비울 수 없음**: `/goal`은 도구 권한을 바꾸지 않으므로, 파일 수정·명령 실행 시 승인 프롬프트가 뜨면 사람이 돌아올 때까지 멈춥니다.
- **반복 상한이 없어 사용량 한도를 소진할 수 있음**: 반복 횟수나 시간 예산 상한이 없어, 에이전트가 헤매기 시작하면 계정 쿼터를 빠르게 소모할 수 있습니다.
- **컨텍스트 누적 (Context Rot)**: 같은 대화가 길어질수록 이전 시도와 오류 로그가 쌓여 판단력이 떨어질 수 있습니다.
- **태스크 단위 롤백이 어려움**: 중간에 방향이 틀어졌을 때 태스크별로 끊어서 되돌리기 어렵습니다.

---

## 3. Level 2 — 고도화된 Ralph Loop (`agy` + `ralph.sh`)

### 동작 방식 (Fresh-Context 외부 루프)
[ralph.sh](ralph.sh)는 매 반복(iteration)마다 **완전히 새로운 `agy` 세션**을 실행합니다.

1. 새 세션이 디스크에서 [PRD.md](PRD.md), [progress.txt](progress.txt), (있다면) `AGENTS.md`를 읽습니다.
2. 미완료(`[ ]`) 태스크 중 **가장 앞 번호 딱 1개**만 구현합니다.
3. 해당 태스크의 **`Done when` 기준을 직접 실행해 검증**합니다.
   - 검증 통과 → `PRD.md`에 `[x]` 표시 + `progress.txt`에 한 줄 추가 + 코드와 문서를 함께 **단일 Git 커밋** 후 종료
   - 검증 실패 → 수정 후 재검증, 그래도 안 되면 `[ ]` 그대로 두고 `progress.txt`에 `BLOCKED` 기록 후 미커밋 상태로 종료
4. `ralph.sh`가 종료 코드·완료 수·커밋 여부·작업 트리 청결 상태를 확인하고 다음 반복을 진행합니다.

---

### ⚠️ 실행 전 안전 안내 & 계정 원칙

`ralph.sh`는 비대화형(AFK) 실행을 위해 `--dangerously-skip-permissions` 플래그를 사용합니다.
> **왜 이 플래그를 유지하나요?** 비대화형(`agy -p`) 모드에서 이 플래그를 빼면, 승인받지 못한 도구 호출이 오류 없이 조용히 거부되고 종료 코드 `0`으로 끝나버려 참가자가 원인 모를 정체만 겪게 됩니다.

실행 전 아래 사항을 **반드시** 이해하고 지켜주세요:
1. **폴더 격리가 아님을 인지하기**: `--dangerously-skip-permissions`가 켜져 있으면 에이전트는 **현재 폴더 밖의 파일에도 접근할 수 있으며**, `--add-dir`은 샌드박스가 아닙니다. 행사 전용으로 `git clone`한 폴더에서 실행하는 것은 **Git 이력 분리와 실수 최소화**를 위한 습관일 뿐 보안 경계가 아닙니다.
2. **`.env`에는 행사용 키만 보관**: API 키가 필요하다면 `.env`에 행사용(임시) 키만 넣고, 절대 커밋하지 마세요. (`.gitignore`에 `.env`가 기본 등록되어 있습니다.)
3. **계정 사용 원칙**: **본인 계정으로만 실행하고, 계정을 공유하거나 교대로 쓰지 않습니다.**
4. **(고급) `permissions.allow`로 권한 범위 좁히기**: 모든 권한 자동 승인을 원하지 않는다면 `ralph.sh`에서 `--dangerously-skip-permissions` 플래그를 **직접 제거**한 뒤 `~/.gemini/antigravity-cli/settings.json`의 `permissions.allow`로 허용 도구를 지정할 수 있습니다. 단, 허용 목록이 너무 좁으면 필요한 도구 호출이 조용히 거부되어 정체로 보일 수 있습니다.

---

### Quick Start (4단계 따라하기)

#### Step 1. 저장소 클론 및 이동
```bash
git clone <이-저장소-URL> my-afk-project
cd my-afk-project
```

#### Step 2. 사전 점검 (`preflight.sh`)
```bash
bash preflight.sh
```
- `git`, `agy` 설치/버전(1.5.0 이상 권장), 로그인, 모델, Node.js(선택), 그리고 `ralph.sh`와 동일한 옵션으로 **실제 파일 쓰기 도구 호출**까지 한 번에 검증합니다.
- `agy` 명령을 찾을 수 없다면 Antigravity 설치 후 `agy install`로 PATH를 설정하고 터미널을 다시 여세요.
- Windows 사용자는 **Git Bash** 또는 **WSL**에서 실행하세요.
- `agy` 단발 테스트만 건너뛰고 빠르게 확인하려면 `bash preflight.sh --quick`을 사용합니다.

#### Step 3. `PRD.md` 작성 및 커밋
[PRD.md](PRD.md)를 열어 `{{ }}`로 표시된 빈칸을 모두 채운 뒤 커밋합니다. (`ralph.sh`는 커밋되지 않은 변경이 있으면 시작을 거부합니다.)
```bash
git add PRD.md
git commit -m "docs: fill PRD for AFKathon"
```
- 작성 예시는 [examples/landing-page/PRD.md](examples/landing-page/PRD.md)를 참고하세요.

#### Step 4. Ralph Loop 실행
```bash
# 기본 실행 (계정 기본 모델, 최대 15회 반복)
bash ralph.sh

# 시간 예산 60분 지정 실행 (권장)
RALPH_MINUTES=60 bash ralph.sh
```
- macOS에서는 `caffeinate -i`로 절전을 자동 방지합니다. **단, 노트북 덮개는 닫지 마세요.**
- Windows/Linux에서는 전원 설정에서 **절전 모드 안 함**으로 변경해 두세요.

---

### PRD 작성 원칙 (성공의 80%가 여기서 결정됩니다)

1. **태스크 크기**: 한 번의 세션(**10분 목표, 15분 타임아웃**) 안에 끝낼 수 있는 크기로 나누세요.
2. **검증 가능한 `Done when`**: 에이전트가 스스로 실행해서 통과 여부를 판단할 수 있는 **실행 가능한 명령과 기대 출력**으로 작성하세요.

| 구분 | ❌ 나쁜 `Done when` (주관적·검증 불가) | ✅ 좋은 `Done when` (명령 + 기대 출력) |
|------|----------------------------------------|-----------------------------------------|
| **웹 화면** | "깔끔한 헤더가 보이고 디자인이 예쁘다." | "`grep -q '<header' index.html && grep -q 'aria-label=\"Main navigation\"' index.html`이 종료 코드 0이고, 링크가 3개 이상 존재한다." |
| **CLI / 스크립트** | "CSV 파싱이 잘 동작한다." | "`python3 parse.py sample.csv`가 종료 코드 0으로 끝나고 출력에 `TOTAL: 3`이 포함된다." |
| **문법 / 빌드** | "오류 없이 실행된다." | "`node --check scripts/main.js`가 종료 코드 0으로 통과하고, `index.html`의 모든 로컬 `href`/`src` 파일이 실제로 존재한다." |

---

### 모델 안내 및 환경변수

- **기본값으로 시작**: `RALPH_MODEL`을 비워 두고 시작하면 본인 계정의 기본 모델을 사용합니다.
- **요금제별 참고**:
  - **Gemini 4 Hydrogen**은 모든 요금제에서 사용할 수 있고 Free와 Plus의 기본 모델입니다.
  - **Gemini 4 Neon**은 Pro와 Ultra에서만 사용할 수 있습니다.
  - **Gemini 3.8 Flash**는 2026년 11월 30일에 제거되므로 지정하지 마세요.
- 다른 모델이 필요하거나 모델 오류가 나면 **`agy models`의 출력 결과를 기준으로** `RALPH_MODEL`을 지정하세요.

```bash
# 내 계정에서 사용 가능한 모델 목록 확인
agy models

# 특정 모델 지정 실행 예시 (모든 요금제에서 사용 가능한 Hydrogen 예시)
RALPH_MODEL="gemini-4-hydrogen-medium" RALPH_MINUTES=60 bash ralph.sh
```

| 환경변수 | 기본값 | 설명 |
|----------|--------|------|
| `RALPH_MODEL` | *(비어 있음 = 계정 기본 모델)* | 사용할 모델 ID 또는 표시 이름 (`agy models`로 확인) |
| `RALPH_MAX_ITERS` | `15` | 최대 반복 횟수 |
| `RALPH_MAX_STALLS` | `2` | 연속 무진전(오류·타임아웃·태스크 미완료) 시 자동 중단 임계치 |
| `RALPH_MINUTES` | `0` *(제한 없음)* | 전체 실행 시간 예산(분). 남은 시간이 3분 미만이면 안전하게 종료 |

---

### 종료 메시지 해석표

| 메시지 | 의미 | 다음 행동 |
|--------|------|-----------|
| `✅ 모든 태스크 완료` | `PRD.md`의 모든 `[ ]`가 `[x]`로 완료되고 작업 트리도 깨끗함 | 결과물을 직접 실행해 최종 검증 |
| `⏰ 시간 예산 N분을 다 썼습니다` | `RALPH_MINUTES`에 도달해 안전 종료 | 점검 후 필요하면 `bash ralph.sh` 재실행 |
| `🛑 PRD.md 파일이 없습니다` | 저장소 루트에 `PRD.md`가 없음 | 템플릿을 clone한 루트 폴더에서 실행 |
| `🛑 PRD.md 에 아직 채우지 않은 {{ }} 칸이 있습니다` | 템플릿 빈칸 미작성 | `PRD.md`의 모든 `{{ }}`를 채우고 커밋 후 재실행 |
| `🛑 PRD.md 에 태스크 항목('- [ ] ...')이 없습니다` | Tasks 섹션에 체크박스 항목 없음 | `PRD.md`에 `- [ ] 1. ...` 형식으로 태스크 추가 |
| `🛑 작업 트리에 커밋되지 않은 변경이 있습니다` | 시작 전 작업 트리가 깨끗하지 않음 | `git status` 확인 후 커밋 또는 정리 후 재실행 |
| `🛑 이미 다른 ralph.sh 프로세스가 실행 중입니다` | `.ralph.lock` 존재(동시 실행 방지) | 실행 중인 터미널 확인; 잔여 락이면 `rmdir .ralph.lock` |
| `🛑 태스크(...)는 체크됐지만 커밋이 누락되었거나...` | 반복 후 커밋 누락 또는 작업 트리 미정리 | [docs/checkpoint-20min.md](docs/checkpoint-20min.md) 2장 참고해 정리 |
| `❌ 모델 '...' 이 목록에 없음` (`preflight.sh`) | 지정한 `RALPH_MODEL`이 계정에 없음 | `agy models`로 확인 후 올바른 이름으로 재지정 |
| `❌ agy 타임아웃 종료 (rc=3)` | 1회 반복이 15분(또는 남은 시간 예산) 초과 | 태스크가 너무 큼 → `PRD.md`에서 태스크를 더 작게 쪼개기 |
| `❌ agy 비정상 종료 (rc=...)` | 네트워크 오류, 로그인 만료, 모델 오류 등 | `logs/` 마지막 줄과 `/usage` 확인 후 재실행 |
| `⚠ 이번 반복에서 완료된 태스크 없음` | 에이전트가 종료했으나 `[x]` 수가 늘지 않음 | `progress.txt`와 `logs/` 확인 |
| `🛑 연속 N회 진전이 없어 중단합니다` | `RALPH_MAX_STALLS` 도달로 자동 중단 | [docs/checkpoint-20min.md](docs/checkpoint-20min.md) 3장 순서대로 복구 |
| `⚠️ RALPH_MAX_ITERS=N 에 도달했습니다` | 설정한 최대 반복 횟수 도달 | 진행 상황 확인 후 `bash ralph.sh`로 이어서 실행 |

---

### `AGENTS.md`로 반복 실수 막기

Antigravity는 프로젝트 루트의 **`AGENTS.md`**를 매 세션 자동으로 읽습니다.
에이전트가 같은 실수를 반복한다면 코드를 직접 고치기 전에 `AGENTS.md`에 금지 규칙을 한 줄 추가해 두세요.

```markdown
# AGENTS.md
- 외부 라이브러리를 설치하지 마세요.
- 기존 테스트 파일을 삭제하거나 건너뛰지 마세요.
- API 키를 소스 코드에 하드코딩하지 마세요.
```

---

### 사용량 한도(Quota) 확인

- `agy` 대화창에서 **`/usage`**를 입력하면 현재 계정의 남은 사용량을 확인할 수 있습니다.
- 사용량 한도가 소진되었을 때의 정확한 종료 코드는 확인되지 않았으며, 어느 경우든 `ralph.sh`에서 정체로 집계되어 멈추므로 중단 시 `logs/`와 `/usage`를 함께 확인하세요.

---

## 4. 20분 중간 점검

루프를 돌려 둔 뒤에는 **20분마다** 돌아와 진행 상황을 점검하세요.
자세한 점검 명령, 출력 예시, PRD-Git 불일치 복구, 안전한 롤백(스냅샷 커밋 + 백업 브랜치), 남은 시간별 범위 축소 기준은 **[docs/checkpoint-20min.md](docs/checkpoint-20min.md)**에 정리되어 있습니다.

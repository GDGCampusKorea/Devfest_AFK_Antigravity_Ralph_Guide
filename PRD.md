# PRD — {{프로젝트 이름}}

> 이 파일은 에이전트가 매 반복마다 다시 읽는 유일한 기준 문서입니다.
> 이중 중괄호로 표시된 빈칸을 모두 채워야 `ralph.sh` 가 실행됩니다.

## Problem (한 문장)
{{누가, 어떤 생산적인 활동에서, 무엇 때문에 불편한지. 예: "대학원생이 매주 논문 20편의 초록을 읽고 분류하는 데 3시간이 걸린다."}}

## User & Core Feature
- 사용자: {{누가 쓰는가}}
- 핵심 기능 1개: {{이것 하나만 돌아가면 데모가 되는 기능}}
- 형태: {{예: 브라우저에서 index.html 을 여는 정적 웹페이지 / Python CLI / Gemini API 를 호출하는 Streamlit 앱}}

## Team Roles
| 역할 | 담당 | 하는 일 |
|------|------|---------|
| PRD 작성 | {{이름}} | 태스크와 완료 기준을 쓰고 고친다 |
| 검증 | {{이름}} | 20분 점검 때 결과를 직접 실행해 확인한다 |
| 랄프 관리 | {{이름}} | 루프 실행·재실행, 로그 확인 |
| 영상·발표 | {{이름}} | 데모 영상과 1분 피칭 준비 |

## Tech Constraints
- {{예: 외부 의존성 없이 HTML/CSS/JS 만 사용 / Python 3.11 + google-genai}}
- API 키는 코드에 쓰지 않고 `.env` 에 두며 `.env` 는 커밋하지 않는다.

## Agent Operating Rules (Ralph Loop)
- Complete **exactly ONE unchecked task** per iteration (the lowest-numbered `[ ]`).
- After finishing, mark it `[x]` here, then **append** a line to `progress.txt`
  (format: `TASK <n> DONE — <one-line summary>`). Never delete progress history.
- Commit the changes for that single task with message `feat: task <n> — <summary>`.
- Verify each task against its **Done when** criteria before marking complete.
- Do NOT start the next task in the same iteration. Stop after one.
- If all tasks are `[x]`, append `ALL TASKS COMPLETE` to `progress.txt` and stop.

## Tasks
<!-- 태스크 하나 = 에이전트가 10분 안에 끝낼 수 있는 크기. 완료 기준은 눈으로 확인 가능하게. -->
- [ ] 1. Create `TEAM.md` containing the project name, the one-sentence problem, and the team
      roles table copied from this PRD.
      **Done when:** `TEAM.md` exists and matches the PRD sections above.
- [ ] 2. {{첫 번째 실제 작업: 프로젝트 뼈대 만들기}}
      **Done when:** {{확인 방법}}
- [ ] 3. {{핵심 기능 구현}}
      **Done when:** {{확인 방법}}
- [ ] 4. {{다듬기·오류 처리}}
      **Done when:** {{확인 방법}}
- [ ] 5. Write `README.md` with how to run the project and a short feature description.
      **Done when:** following README from a clean clone runs the project.

## Definition of Done
{{심사 때 보여줄 장면 한 줄. 예: "PDF 3개를 올리면 분류 표가 화면에 나온다."}}

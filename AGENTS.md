# Codex 작업 안내 (주사위 영웅전)

이 저장소는 혼자 만드는 Godot 4 모바일 게임이다. Claude가 작업 지시서를 `codex_jobs/`에 쓰고, Codex가 그대로 작업한다.

## 꼭 먼저 읽을 것

1. `CLAUDE.md` — 프로젝트 규칙과 구조 전체. 여기 적힌 규칙을 모두 따른다.
2. 지시받은 `codex_jobs/<이름>.md` — 이번 작업의 내용. 지시서에 없는 기능은 더하지 않는다.

## 핵심 규칙 (CLAUDE.md 요약)

- 코드 주석, 커밋 메시지, PR 설명은 한국어로 쓴다.
- 판 규칙은 `scripts/rules/`(game.gd·profile.gd), 화면은 `scripts/screens/`·`scripts/ui/`. 규칙 로직을 화면 코드에 넣지 않는다.
- 게임 수치는 코드에 박지 않고 `data/*.json`에 둔다.
- 주사위는 `scripts/rules/game.gd` 한 곳에서만 굴린다.
- 규칙을 바꾸거나 더하면 `tests/run_tests.gd`에 검사를 더한다.
- GDScript에서 `:=`는 타입이 분명할 때만 쓴다. 딕셔너리·배열에서 꺼낸 값은 `var x: int = ...`처럼 타입을 적는다.
- 화면 글을 새로 넣거나 바꾸면:
  1. `python3 tools/i18n_extract.py` (번역표에 빈 자리 생성)
  2. `data/i18n/en.json`·`vi.json`의 빈 번역 채우기 (`python3 tools/i18n_extract.py --missing en`으로 확인)
  3. `python3 tools/build_font.py --fetch` (처음 한 번) 뒤 `python3 tools/build_font.py` (글꼴 다시 만들기)
- 사용자에게 알릴 변화는 `scripts/screens/lobby_screen.gd`의 `NEWS` 맨 위에 한 줄 더한다. `main.gd`의 VERSION은 손대지 않는다.
- 새 기능·결정은 `CLAUDE.md`의 '구조' 목록에 한 줄로 적어 둔다.

## 올리는 방법

- `main`에 직접 올리지 않는다. `codex/`로 시작하는 브랜치로 PR을 만든다.
- PR의 Build(GitHub Actions `build.yml`)가 통과하면 자동으로 합쳐지고 배포된다.
- 이 작업 공간에 Godot가 없으면 실행 확인은 PR의 Build 결과로 한다. Build가 실패하면 로그를 보고 같은 브랜치에 고쳐 올린다.
- 작업이 끝나면 지시서 맨 아래 '결과' 칸에 한 일과 남은 문제를 짧게 적는다.

## 그림 작업

그림 지시서(`codex_jobs/job_*.md`)는 그 지시서에 적힌 대로 결과를 `codex_out/<이름>/`에 넣어 `codex/<이름>` 브랜치로 올린다. 그림 작업은 PR을 만들지 않는다.

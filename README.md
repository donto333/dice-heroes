# 주사위 영웅전 (dice-heroes)

주사위로 보드를 달리고, 길에서 마주친 상대와 주사위로 싸워 먼저 골에 도착하면 이기는 2D 도트 보드 RPG.
역사와 신화 속 인물 200명을 모아 ATTACK / DEFENSE / SUPPORT 3인 파티를 꾸린다.

## 지금 단계

**2단계: 규칙 프로토타입.** 캐릭터 12명, 40칸 보드, 카드 8종으로 사람 대 AI 한 판을 끝까지 할 수 있다.
그림은 아직 없고 색 칸과 글자만 쓴다. 다음은 3단계(규칙 다듬기)다.

규칙 코드는 `scripts/rules/game.gd`, 화면은 `scripts/main.gd`와 `scripts/ui/`에 있다.

## 폴더 구조

| 폴더 | 내용 |
| --- | --- |
| `scenes/` | Godot 장면 파일 |
| `scripts/` | 게임 코드 (GDScript) |
| `data/` | 캐릭터·칸·카드 데이터 (JSON) |
| `assets/` | 글꼴, 그림, 소리 |
| `tests/` | 화면 없이 도는 자동 검사 |
| `.github/workflows/` | 올릴 때마다 도는 자동 빌드 |

## 빌드와 실행

- **자동 빌드**: `main`에 올리거나 PR을 열면 GitHub Actions가 Godot 4.7로 웹 버전을 빌드한다. 결과는 실행 기록의 `web-build`에서 내려받을 수 있다.
- **웹에서 해 보기**: 저장소 Settings → Pages → Source를 "GitHub Actions"로 두면 `main` 빌드가 Pages 주소로 배포된다.
- **PC에서 열기**: Godot 4.7을 설치하고 이 폴더의 `project.godot`를 연다.

## 만드는 도구

- 엔진: Godot 4.7 (GDScript)
- 대전 서버: Nakama (7단계에서 추가)
- 글꼴: Noto Sans CJK KR 일부 글자 (SIL OFL 1.1, `assets/fonts/LICENSE.md` 참고)

# 주사위 영웅전 작업 안내

혼자 만드는 Godot 4.7 모바일 게임이다. 사용자는 개발자가 아니므로 설명은 쉬운 한국어로 한다.

## 규칙

- 코드 주석, 커밋 메시지, 문서는 한국어로 쓴다.
- 이 작업 공간에는 Godot가 없다. 실행 확인은 GitHub Actions(`.github/workflows/build.yml`) 결과로 한다.
- 규칙 로직은 화면 코드와 분리해 `scripts/rules/`에 두고, `tests/run_tests.gd`에서 검사한다.
- 게임 수치는 코드에 박지 말고 `data/`의 JSON에 둔다.
- 주사위는 반드시 한 곳(규칙 코드)에서만 굴린다. 7단계에서 서버가 굴리도록 옮기기 위해서다.
- 그래픽: 영웅은 반실사 채색 일러스트(assets/portraits, 사용자 결정), 보드 칸 아이콘은 2D 도트. 원작(주사위의 잔영)과 창세기전의 이름, 아이콘, 캐릭터는 쓰지 않는다.
- `main`에 직접 올리지 않고 `claude/`로 시작하는 브랜치와 PR로 올린다.
  Build가 통과하면 `.github/workflows/auto-merge.yml`이 자동으로 합치고 배포한다. 사용자가 승인할 필요는 없다.
  Build가 실패하면 합쳐지지 않으므로, 실패 원인을 고쳐 같은 브랜치에 다시 올린다.

## 구조

- `scripts/main.gd`: 화면 전환 틀(app). `scripts/screens/`: 타이틀·로그인·로비·영웅·상점·미션·설정·파티·대전 화면.
- `scripts/rules/game.gd`: 판 규칙. `scripts/rules/profile.gd`: 게임 밖 성장(재화·소환·강화·보상·랭크·미션·출석). 수치는 `data/economy.json`.
- 게임 밖 콘텐츠: 모험(`data/adventure.json`), 업적(`data/achievements.json`), 오늘의 특가·행운의 룰렛·AI 난이도(`data/economy.json`), 연습 리그 순위표·프로필 창(`scripts/ui/profile_card.gd`).
- 대전 화면 배치(모두의 마블·원작 영상의 구성만 참고): 판이 화면 대부분, 정보판은 판 모서리, 아이템 카드는 판 왼쪽 세로 줄, 오른쪽 아래 동그란 주사위 버튼, 오른쪽 가운데 한마디 버튼.
- 화면 모양(2026-11 리뉴얼, 밝고 통통한 캐주얼): 하늘색 바탕(`Kit.sky()`), 파란 판에 흰 글자, 주황=가장 중요한 버튼(`Kit.PRIMARY`), 초록=가기·확인(`Kit.ACCENT`), 연파랑=닫기 같은 보조(`Kit.PANEL_LIGHT`), 빨강=나가기. 색과 모양은 `scripts/ui/kit.gd`에서만 정하고 화면에 어두운 남색을 새로 박지 않는다. 로비는 위 띠 → 랭크 카드 → 대표 영웅(양옆 동그란 바로가기) → 모드 타일 4개(`Kit.tile_button`) → 큰 '랭크전 시작' → 아래 메뉴.
- 연출 부품(`scripts/ui/`): `big_dice.gd`(굴러가는 주사위), `versus_overlay.gd`(시작 VS), `turn_banner.gd`(내 차례! START!), `battle_overlay.gd`(공격→방어 굴림, WIN·LOSE), `result_overlay.gd`+`confetti.gd`, `roulette_wheel.gd`.
- 글꼴은 한글 부분집합이라 없는 기호가 있다(예: ◆). 새 기호를 쓰면 tests의 글꼴 검사(`_test_font_coverage`)가 잡는다.
- 기다림 화면: `scripts/ui/loading_overlay.gd`. 큰 전환(게임 진입, 접속, 대전 준비, 소환)은 `app.go_loading()`·`app.wait_loading()`을 쓰고, 나머지 `app.go()`는 짧게 스르륵 나타난다. 자동 사진 도구는 `app.instant = true`로 모두 건너뛴다.
- 저장은 `scripts/save_store.gd`(기기 안 user://). 온라인 서버(Nakama)는 아직 없음.
- 보드 바탕 지형·꾸밈 그림은 `tools/make_terrain.py`로 만든다(assets/terrain, 직접 그린 도트). 키퍼·습격·골 칸 위에 서 있는 적 그림(monsters.png, 7종)도 같은 도구로 만들고, 이름의 낱말로 종류를 고른다(`board_view.gd`의 MONSTER_KINDS). 칸은 두께 있는 육각형으로 그린다(scripts/ui/board_view.gd).
- 화면 확인은 CI의 `tools/capture.gd` 자동 사진(로그에 base64로 남음).
  마지막에 한 판을 끝까지 자동으로 플레이한다(`_play_full_game`, 로그의 `FULLGAME` 줄). 이 단계의 오류는 빌드를 실패시키지 않으므로 로그에서 `SCRIPT ERROR`와 `ERROR:`를 직접 찾아본다.
- 편의·운영: 모험 소탕(`Profile.sweep`, economy.json의 sweep), 오늘 할 일 창(`lobby_screen.gd`의 `open_todo`), 일괄 강화(`Profile.upgrade_all`), 최근 전적·맵별 전적(`profile["history"]`, `profile["map_stats"]`), 초보자 길잡이 과제(`data/guide.json`, `Profile.claim_guide`), 우편·쿠폰·공지·이벤트(`data/mails.json` 등), 시즌 패스·주사위 상점. 결제는 없고 보석 상품·묶음은 '준비 중'으로만 보인다(economy.json의 gem_packs).
- 어빌리티 컷인: `scripts/ui/cutin.gd`. 전투 창의 예상 승률은 `Game.win_chance()`(주사위를 굴리지 않고 셈만 함).
- 매일 바뀌는 것(날짜 씨앗): 오늘의 미션 6개(`Profile.active_missions`), 오늘의 특가, 오늘의 도전(상대·맵). 하루 기록은 `profile["daily"]`.

## 게임 요약

- 파티 3자리: ATTACK(이동·공격), DEFENSE(방어), SUPPORT(지력)
- 능력: 이동(주사위 1~2개), 공격·방어(주사위 1~5개), 지력(1~5), 속성, 어빌리티
- 분류 = 속성: 영웅(공격), 위인(지력), 신화(방어), 근현대(이동). 맵 속성과 맞으면 +2
- 등급 ★★★/★★/★ = 소환 포인트 3/2/1, 파티 합계 6 이하
- 전투: 이동해 온 쪽이 공격. 양쪽이 주사위를 굴려 합이 큰 쪽이 이김. 지면 직전 거점으로
- 주사위 컨트롤: 굴리기 버튼을 꾹 눌러 낮게·높게를 노리면 35% 확률로 그쪽 눈 비율을 쓴다(`game.roll_move(aim)`, data/rules.json의 dice_control, 화면은 `scripts/ui/aim_bar.gd`). AI는 늘 높게 노린다
- 더블: 이동 주사위 2개 이상이 모두 같은 눈이면 어빌리티 게이지 +12%(data/rules.json의 double_gauge)
- 따라잡기: 상대보다 10칸 이상 뒤처진 쪽은 이동 주사위에서 큰 눈이 더 잘 나온다(data/rules.json의 catchup_gap·catchup_move_weights). 전투 주사위는 그대로
- 보드 약 120칸, 맵 8종(유턴형·피라미드형·나선형·직선형·계단형·산맥형·세로 S자형·쌍고리형, tools/make_maps.py로 생성), 거점은 10칸 안팎마다, 갈림길(마름모) 3개, 50턴 제한(data/rules.json)
- 규칙 검사(tests)는 칸 번호가 정해진 작은 고정 맵 tests/fixtures/board_small.json으로 한다

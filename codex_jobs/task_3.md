# task_3: 창 제목 리본 글자를 띠 정가운데에

먼저 `AGENTS.md`와 `CLAUDE.md`를 읽고 규칙을 따른다.

## 할 일
사용자가 '내 프로필' 창(로비 프로필 띠를 누르면 뜸, `scripts/ui/profile_card.gd`) 사진에서 제목 리본 글자가 보라 띠 가운데에 있지 않다고 다시 지적했다. 앞서(PR #314) `scripts/ui/ribbon.gd`의 `_place_label`이 그림 리본 `assets/ui_kit/ribbon_violet.png`의 띠 위치(ART_BAND 9~95px / 130px)로 글자 칸을 맞췄지만, 9~95px는 위아래 금테까지 포함한 값이라 정작 안쪽 보라 띠의 가운데와 어긋날 수 있다. 또 글꼴은 `tools/build_font.py`의 `center_metrics`로 한글을 줄 칸 가운데 오게 맞춰 둔 상태다.

## 고칠 곳
- `assets/ui_kit/ribbon_violet.png`에서 가운데 세로줄(및 몇 군데)의 픽셀을 재서 **안쪽 보라 띠(금테 제외)의 위·아래**를 구하고, `ribbon.gd`의 ART_BAND를 그 값으로 바꾼다. 리본을 그리는 `_draw`의 그림 칸(Rect2(0, -8, 너비, 높이+12))과 `UiSkin.draw_bar`가 그림을 어떻게 늘리는지(세로로 그대로 늘리는지, 끝 조각만 늘리는지) 확인해 계산이 맞는지 본다.
- 글자의 실제 잉크(한글 글자 모양)가 보라 띠 위·아래 한가운데 오게 한다. Label의 vertical_alignment, 글자 효과(`text_style.gd`의 gold: 그림자·외곽선이 아래로 치우치면 그만큼 보정)까지 고려한다.
- `Kit.ribbon`을 쓰는 모든 곳(창 제목 `dialog.gd`, 프로필 창, AI 연습전 난이도, 행운의 룰렛, 구역 제목 등)이 같이 맞아야 한다. 리본 크기(font_size 28~40)가 달라도 맞게 비율로 계산한다.

## 확인
- Godot로 직접 화면을 찍어 본다(1280×720). 최소 세 장: '내 프로필' 창, 'AI 연습전 난이도' 창, '행운의 룰렛' 창.
- 찍은 사진에서 **보라 띠의 위·아래 경계와 글자 잉크의 위·아래를 픽셀로 재서** 위 여백과 아래 여백 차이가 2px 이하인지 숫자로 확인하고, PR 설명에 세 창의 측정값(띠 위·아래, 글자 위·아래, 위·아래 여백)을 적는다.
- 자동 사진 `tools/capture.gd`에 `05d_profile_card`(로비에서 프로필 창 연 모습)가 없으면 더한다.
- `tests/run_tests.gd`는 그대로 통과해야 한다.

## 올리기
- 브랜치: `codex/task-3-ribbon-center`, PR 제목 "창 제목 리본 글자를 띠 정가운데에".
- `CLAUDE.md`에 한 줄 기록, NEWS는 필요 없음.

## 결과 (Codex가 채움)

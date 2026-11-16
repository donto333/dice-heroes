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
- 연출 그림(2026-11-16): 연출은 도형을 조합하지 않고 그려 둔 효과 그림 `assets/fx/`를 겹쳐서 만든다. 검은 바탕 그림(빛·불·얼음·번개·마법진·충격)은 더하기 섞기(`Fx.additive()` 재질을 단 층)로 그리고, 자홍 바탕으로 그려 바탕을 지운 그림(금화·별·색종이 조각 `confetti_N`·꽃잎 `petal_N`)은 보통 섞기로 그린다. 말 아래에 깔려야 하는 바닥 효과는 밝기를 투명도로 바꾼 `<이름>_a.png`를 판 자체에 그린다(`board_view.gd`의 `_flat_sprite`). `Fx.tex(이름)`으로 불러오고, 한 번의 터짐은 `fx.stamp`(커지며 사라지는 큰 그림)와 그림 알갱이를 겹친다(`fx.burst` 종류: spark·coin·smoke·star·petal·ember·ice·impact·heal·dust·bolt). 그림이 없으면 예전 도형으로 대신한다. 자동 사진 `14x_fx_bursts`·`14y_fx_screen`이 연출 확인용이다.
- 그림 UI 부품(2026-11-16): 버튼·창·칸 테두리·리본·막대는 Codex가 그린 그림 `assets/ui_kit/`을 조각내어(끝·귀퉁이 장식은 그대로, 가운데만 늘림) 그린다. 그리는 곳은 `scripts/ui/skin.gd`(UiSkin: `draw_bar`·`draw_frame`·`tone`), 버튼은 `gloss.gd`의 `_draw_skin`(긴 버튼 btn_색, 짧은 버튼 sq_색, 동그란 버튼 round_색, 큰 금색 버튼 btn_start), 판은 `ornate_box.gd`의 `_draw_skin`(보통 판은 card_ 얇은 금테, `grand = true`인 창은 win_ 화려한 틀), 리본은 `ribbon.gd`, 진행 막대는 `skin_bar.gd`. 틀 그림은 안쪽을 투명하게 뚫어 두고 안쪽 색은 코드가 칠한다. 넣는 도구는 `tools/import_ui.py <out/ui 폴더>`(치수는 `assets/ui_kit/meta.json`), ic_ 그림은 `assets/ui_icons`로 들어간다. 그림이 없으면 예전 도형으로 그린다. 그림 주문서는 `codex_work/job13~15.md`(참고 사진 `codex_work/ref/`).
- 새 로비(2026-11-16, 밝은 캐주얼 + 명일방주식 배치): `lobby_screen.gd`. 왼쪽 절반은 대표 영웅 큰 그림(가장자리를 하늘로 흐리게 지우는 셰이더)·말풍선·이름표, 오른쪽 절반은 타일 묶음(1줄 주황 랭크전[진행 중 이벤트 띠를 타일 안에]+초록 모험, 2줄 흰 타일 AI전·친구 대전·오늘의 도전, 3줄 진파랑 타일 영웅·상점·미션·시즌 패스), 위는 프로필 띠·시스템 버튼(설정·공지·우편·출석·룰렛·리그·방법)·골드·보석, 아래 띠는 출전 파티·시너지·오늘 할 일. 타일마다 영어 부제. 그림 부품은 `assets/ui_lobby/`(Codex 주문서 job16, 넣는 도구 `tools/import_lobby.py <out/lobby>`), 타일·띠는 NinePatch로 가운데만 늘린다. 그림이 없으면 단색 상자로 대신한다. 기준 그림은 ChatGPT 대화 '로비 UI 시안'.
- 그림 주문 방식(2026-11-16 사용자 결정): Claude가 주문서를 PC의 `dice-heroes\codex_work\`에 넣고, 사용자에게 Codex 앱에 붙여 넣을 한 줄(예: "codex_work/job17.md 읽고 그려줘")을 준다. 결과는 `codex_work/out/`에서 기기 연결로 가져온다.
- 3D 모델(트리포, 2026-11-16 시험): 꼬마 모형 그림 한 장을 트리포(Tripo) API로 3D 모델 → 뼈대 → 동작(idle·walk·slash)까지 만들고, 블렌더(화면 없이, GitHub 서버)로 찍어 12칸 가로 그림 `assets/standees_anim/<id>_<동작>.png`으로 넣는다(`GameData.standee_anims`, `board_view.gd`의 `piece_anims`: 서 있으면 idle, 이동 중이면 walk). 주문서는 `tripo/jobs.json`, 도구는 `tools/tripo_run.py`(API 키는 저장소 비밀값 `TRIPO_API_KEY`, 예전 v2 주소로 연결됨)·`tools/tripo_render.py`, 작업 흐름은 `.github/workflows/tripo.yml`(`claude/tripo`로 시작하는 브랜치에서 `tripo/`가 바뀌면 돈다. 결과는 실행 결과물 `tripo-out`). 한 명에 약 85크레딧. 찍는 방향은 주문서의 `view`(도, 90이 트리포 정면)로 영웅마다 정한다. 뼈대를 못 넣는 모델(말 탄 마초, 목란)은 멈춘 그림 그대로 둔다. 파티원 두 명도 `party_anims`로 움직인다. API 크레딧이 없을 때는 트리포 웹(studio.tripo3d.ai, 크롬)에서 만든다: 그림 올리기 → 생성(55) → 리토폴로지 삼각형 1만(35) → 자동 리깅(20) → 프리셋 걷기·베기·대기 선택(무료) → 내보내기(GLB, 텍스처 1k, 애니메이션 모두, 제자리). 내려받은 GLB를 `tripo/web/<id>.glb`로 넣고 주문서에 `"local"`로 적으면 찍는다. 웹에서 내보낸 모델은 정면이 대체로 0도라 `view`는 -15쯤이지만 옆을 보는 것도 있어, 찍은 그림을 보고 영웅마다 고친다(값을 키우면 그림에서 왼쪽으로 돈다). 여러 명을 내보낼 때는 크롬이 둘째 파일부터 막으므로 사용자가 '여러 파일 자동 다운로드'를 허용해야 한다. 2026-11-16에 48명 모두 넣었다(웹 38명). 새 그림은 256색으로 줄여 넣는다(한 장 약 80KB). 이미 만든 작업 번호(model_task·rig_task·anim_task)를 주문서에 적어 두면 다시 만들지 않는다.
- 화면 방식(2026-11-16): 가로 전용·전체 화면. 웹은 처음 누를 때 전체 화면과 가로 고정을 청하고(`main.gd`의 `_setup_display`, 설정의 전체 화면 켜기·끄기), 세로로 들면 `scripts/ui/rotate_guard.gd`가 돌려 달라는 안내로 화면을 덮는다.
- 가로 화면(2026-11-15 전환, 1280×720): 로비는 모두의 마블식(왼쪽 세로 메뉴·큰 영웅 카드와 장식 액자 `assets/ui_frames/lobby_frame.png`·배너·게임 시작), 맵은 원작 주사위의 잔영식(통짜 풍경 `assets/art/boards/<지형>.jpg`은 거울 2×2 이어 붙이기, 두꺼운 육각 칸 `assets/hex/<칸 종류>.png`, 가까운 카메라, 파티 3명이 함께 이동, 칸 위 물건 `assets/objects/`). 주사위와 전투는 창을 띄우지 않고 판 위에서 바로 보여 준다. 글·설명 칸은 단색 상자 대신 장식 판(`scripts/ui/ornate_box.gd`, `Kit.plate`/`Kit.panel`)과 리본 제목(`Kit.ribbon`)을 쓴다. 화면마다 판 색이 다르다(`main.gd`의 SCREEN_MOODS → `Kit.panel_tint`). 다른 화면의 아래 메뉴는 `Kit.screen_frame`의 왼쪽 자리(Dock)로 옮겨 가 세로 메뉴가 된다. 가로 배경은 `assets/art/wide/`(`GameData.art`가 WIDE_ART로 먼저 찾음), 입체 로고는 `assets/logos/`(`GameData.logo`). 시험 빌드는 PR 없이 `gh workflow run build.yml --ref <브랜치>`로 돌려 사진만 확인할 수 있다.
- 입체 판과 연출(2026-11-15): 판은 `board_view.gd`에서 비스듬히 누운 블록(TILT, BLOCK_DEPTH)으로 그리고, 말은 꼬마 입체 모형 `assets/standees/<id>.png`(자홍 바탕으로 그려 `tools/import_standees.py`로 바탕 제거, `GameData.standee`)이다. 모형이 없으면 초상화 말로 돌아간다. 이어지지 않은 칸으로 갈 때(패배 복귀·워프)는 한 번에 날아간다. 칸 종류별 효과는 `_draw_tile_fx`. 화면 전체 연출(번쩍임·알갱이·속도선·빛살·튀는 글자)은 `scripts/ui/fx.gd` 한 곳에서 하고 `quiet`이면 건너뛴다. 메뉴 바탕의 떠다니는 빛은 `scripts/ui/ambience.gd`(`Kit.backdrop`이 붙임), 큰 버튼을 훑는 빛은 `scripts/ui/sweep.gd`(`Kit.shimmer`). 적 모형은 `assets/enemy_standees/<적 id>.png`(`GameData.enemy_standee`, 없으면 초상화 메달), 맵 꾸밈 모형은 `assets/props/`(`board_view.gd`의 PROP_NAMES, `tools/import_standees.py <폴더> props`로 넣음). 연출 계획은 프로젝트 문서 `claude/주사위영웅전_연출기획.md`.
- UI 2차 리뉴얼(2026-11-15, 모두의 마블 영상 참고): 기본 글꼴은 주아체(`assets/fonts/Jua-Regular.ttf`, 없는 글자는 노토 산스로 메움·`main.gd`의 `_setup_font`). 버튼 모양은 `scripts/ui/gloss.gd`(버튼 뒤에 붙는 광택 몸통, `Kit.paint`가 붙임)가 그리고 버튼 자체 상자는 비어 있다. 판은 `Kit.panel`+`Kit.sheen`. 그림 아이콘은 `assets/ui_icons`(`Kit.icon(이름)`이 먼저 찾음, 자홍 바탕으로 그려 `tools/import_icons.py`로 바탕 제거), 몸통 없는 바로가기는 `Kit.icon_shortcut`. 큰 초상화는 `assets/portraits_hd`(`Portrait.hd = true`). 로비 영웅 카드 액자는 `assets/ui_frames/hero_frame.png`. 보드는 그린 바탕 `assets/art/boards/<지형>.jpg`(거울 이어 붙이기로 만든 1024px)와 광택 칸 아이콘(`board_view.gd`의 GLOSSY_ICONS), 적은 초상화 메달(`_draw_medal`). 그림이 없으면 예전 도트 그림으로 돌아간다.
- 화면 모양(2026-11 리뉴얼, 밝고 통통한 캐주얼): 하늘색 바탕(`Kit.sky()`), 파란 판에 흰 글자, 주황=가장 중요한 버튼(`Kit.PRIMARY`), 초록=가기·확인(`Kit.ACCENT`), 연파랑=닫기 같은 보조(`Kit.PANEL_LIGHT`), 빨강=나가기. 색과 모양은 `scripts/ui/kit.gd`에서만 정하고 화면에 어두운 남색을 새로 박지 않는다. 로비는 위 띠 → 랭크 카드 → 대표 영웅(양옆 동그란 바로가기) → 모드 타일 4개(`Kit.tile_button`) → 큰 '랭크전 시작' → 아래 메뉴.
- 연출 부품(`scripts/ui/`): `big_dice.gd`(굴러가는 주사위), `versus_overlay.gd`(시작 VS), `turn_banner.gd`(내 차례! START!), `battle_overlay.gd`(공격→방어 굴림, WIN·LOSE), `result_overlay.gd`+`confetti.gd`, `roulette_wheel.gd`.
- 배경음악: `scripts/ui/music.gd`. 수노(Suno, Pro 요금제)에서 만든 연주곡 7개 `assets/audio/bgm_<title·lobby·shop·match·boss·victory·defeat>.ogg`. 화면→곡은 `main.gd`의 SCREEN_MUSIC(없으면 lobby), 관문·수호자 전투 동안은 boss, 결과는 victory/defeat(한 번만). 수노 원본은 사용자가 내려받아 올려 준 mp3를 ffmpeg로 ogg(q1)로 바꾼 것.
- 효과음: `scripts/ui/sfx.gd`. `assets/audio/sfx/이름.ogg`가 있으면 그 파일을, 없으면 코드로 합성한 소리를 쓴다(step·land는 합성). 파일은 주문서 `tools/sfx_prompts.json`을 `claude/gen-audio` 브랜치에 올리면 `.github/workflows/make-sfx.yml`이 ElevenLabs(저장소 비밀 값 ELEVENLABS_API_KEY)로 만들어 산출물로 남긴다. 받아서 앞뒤 무음을 자르고 ogg로 바꿔 넣는다.
- 소리 크기·안내 음성(2026-11-16): 설정에서 효과음·음성·음악 크기를 20%씩 조절한다(`app.volume(kind)`, `app.apply_volumes()`). 음성이 나오면 배경음악이 잠깐 줄어든다(`music.duck`). 안내 음성은 `app.say("announcer", 상황)`(start·turn·battle·gate·double·catchup·last_turn)이고 목소리는 네 가지(`data/voice_extra.json`의 announcers, 파일 `announcer_<id>_<상황>.ogg`) 중 설정의 "안내 음성"에서 고른다(`app.announcer_id()`), 적 음성은 `enemy_gate·enemy_boss·enemy_keeper·enemy_monster`의 appear·win·lose이고 대사는 `data/voice_extra.json`(만들기: `tools/make_batch2.py`). 효과음은 칸 종류별 `tile_<종류>`, 전투 `battle_win/lose`, `gate_open`, `goal`, `banner`, `versus`, `double`, `upgrade`, `reward`, `purchase`, `stamp`, `summon_1~3`, `denied`, `aim`이 더 있고 파일이 없으면 `sfx.gd`의 FALLBACKS 소리로 대신한다.
- 영웅 음성: `scripts/ui/voice.gd`(`app.say(영웅 id, 상황)`, 설정의 '영웅 음성'). 파일은 `assets/audio/voice/<id>_<상황>.ogg`, 상황은 select(도감 클릭)·idle(로비 대표 영웅 누름)·move·attack·defend·skill·win·lose. 대사와 목소리 배정은 `tools/make_voice_lines.py` → `data/voice_lines.json`. 만들 때는 `claude/gen-audio` 브랜치의 `tools/audio_job.txt`에 돌릴 도구 이름(make_voices.py / make_sfx.py / list_voices.py)을 적어 올리면 `make-sfx.yml`이 ElevenLabs로 만들어 산출물 audio로 남긴다. 목소리는 계정의 한국어 역할 목소리(패왕 무신·위엄 도독 등, 사용자가 천하에서 쓰는 것)와 한국어 성우 목소리를 쓴다(2026-11-16 다시 만듦). 만드는 방식은 v3 모델에 연기 지시(tags)를 붙인 것이다(사용자가 A·B 중 B를 고름, `make_voices.py`의 out/b).
- 글꼴은 한글 부분집합이라 없는 기호가 있다(예: ◆). 새 기호를 쓰면 tests의 글꼴 검사(`_test_font_coverage`)가 잡는다.
- 기다림 화면: `scripts/ui/loading_overlay.gd`. 큰 전환(게임 진입, 접속, 대전 준비, 소환)은 `app.go_loading()`·`app.wait_loading()`을 쓰고, 나머지 `app.go()`는 짧게 스르륵 나타난다. 자동 사진 도구는 `app.instant = true`로 모두 건너뛴다.
- 배포 주소(2026-11-16): main에 합쳐지면 GitHub Pages(https://donto333.github.io/dice-heroes/)와 Cloudflare Pages(https://dice-heroes.pages.dev, `build.yml`의 deploy-cloudflare)에 함께 올라간다. Cloudflare는 저장소 비밀값 `CLOUDFLARE_API_TOKEN`(Cloudflare Pages 편집 권한)·`CLOUDFLARE_ACCOUNT_ID`가 있어야 돌고, 없으면 건너뛴다.
- 성능(2026-11-16): 화면은 1초 60번까지(`Engine.max_fps`), 대전 판은 말이 가만히 있으면 1초 30번만 다시 그린다(`board_view.gd`의 IDLE_FRAME_TIME). 저사양 모드(`GameData.low_gfx`, 설정의 '저사양 모드', `app.set_low_gfx`/`apply_gfx`)는 30fps 제한·판 15번·그림자(`_cast_shadow`)·꾸밈 모형(`_draw_props`)·빛 층(`_draw_glow`)·칸 그림자·떠다니는 빛(ambience)·버튼 훑는 빛(sweep)을 끈다. 대전 중 5초 평균이 1초 32번 미만이면 저절로 켜진다(사용자가 설정에서 직접 고른 적이 있으면 안 건드림).
- 저장은 `scripts/save_store.gd`(기기 안 user://). 온라인 서버(Nakama)는 아직 없음.
- 보드 바탕 지형·꾸밈 그림은 `tools/make_terrain.py`로 만든다(assets/terrain, 직접 그린 도트). 키퍼·습격·골 칸 위에 서 있는 적 그림(monsters.png, 7종)도 같은 도구로 만들고, 이름의 낱말로 종류를 고른다(`board_view.gd`의 MONSTER_KINDS). 칸은 두께 있는 육각형으로 그린다(scripts/ui/board_view.gd).
- 화면 확인은 CI의 `tools/capture.gd` 자동 사진(로그에 base64로 남음).
  마지막에 한 판을 끝까지 자동으로 플레이한다(`_play_full_game`, 로그의 `FULLGAME` 줄). 이 단계의 오류는 빌드를 실패시키지 않으므로 로그에서 `SCRIPT ERROR`와 `ERROR:`를 직접 찾아본다.
- 편의·운영: 모험 소탕(`Profile.sweep`, economy.json의 sweep), 오늘 할 일 창(`lobby_screen.gd`의 `open_todo`), 일괄 강화(`Profile.upgrade_all`), 최근 전적·맵별 전적(`profile["history"]`, `profile["map_stats"]`), 초보자 길잡이 과제(`data/guide.json`, `Profile.claim_guide`), 우편·쿠폰·공지·이벤트(`data/mails.json` 등), 시즌 패스·주사위 상점. 결제는 없고 보석 상품·묶음은 '준비 중'으로만 보인다(economy.json의 gem_packs).
- 화면 일러스트: `assets/art/`(ui·chapters·cards)와 적 초상화 `assets/enemies/`. `GameData.art("ui/title_keyart")`, `GameData.enemy_portrait(이름)`(이름→파일은 `data/enemies.json`), 그리는 부품은 `scripts/ui/art_view.gd`, 바탕은 `Kit.backdrop()`, 버튼 그림은 `Kit.button_art()`. 그림 파일이 없으면 예전 모양으로 보인다. 오프닝 영상은 `scripts/ui/opening.gd`(`app.play_opening()`).
- 그림 만들기: PC의 Codex 앱(dice-heroes 프로젝트)에 `codex_work/job.md`를 읽고 그리게 한다. 결과(`codex_work/out`, 저장소에는 안 올림)를 `tools/import_art.py`로 줄여 넣는다.
- 어빌리티 컷인: `scripts/ui/cutin.gd`. 전투 창의 예상 승률은 `Game.win_chance()`(주사위를 굴리지 않고 셈만 함).
- 상점과 미션 화면은 탭으로 나뉜다(상점: 소환·성장·꾸미기·보석, 미션: 오늘·업적). `app.go("shop", {"tab": ...})`. 보석 마일리지는 `Profile.claim_mileage`.
- 더 생긴 것: 수집 앨범(`Profile.claim_album`, economy.json album), 유물(`relics`, 내 파티 시작 보너스·랭크전 상대 강화 `rank_boost`), 홀짝 미니게임(`odd_even`), 주간 리그 보상·훈장(`Profile.settle_league`), 원정 보상(`Profile.claim_idle`, idle), 요일 이벤트(events.json의 weekdays).
- 매일 바뀌는 것(날짜 씨앗): 오늘의 미션 6개(`Profile.active_missions`), 오늘의 특가, 오늘의 도전(상대·맵). 하루 기록은 `profile["daily"]`.

## 게임 요약

- 파티 3자리: ATTACK(이동·공격), DEFENSE(방어), SUPPORT(지력)
- 능력: 이동(주사위 1~2개), 공격·방어(주사위 1~5개), 지력(1~5), 속성, 어빌리티
- 분류 = 속성: 영웅(공격), 위인(지력), 신화(방어), 근현대(이동). 맵 속성과 맞으면 +2
- 등급 ★★★/★★/★ = 소환 포인트 3/2/1. 파티 합계 한도는 플레이어 레벨에 따라 1레벨 5 · 5레벨 6 · 10레벨 7 · 20레벨 8(data/rules.json의 point_limits, `Game.point_limit_at`, `app.point_limit()`). AI 상대도 내 한도로 짠다. 친구 대전은 local_point_limit(6). 한도를 넘는 예전 파티는 불러올 때 `Profile.fit_party`가 맞춘다
- 전투: 이동해 온 쪽이 공격. 양쪽이 주사위를 굴려 합이 큰 쪽이 이김. 지면 직전 거점으로
- 주사위 컨트롤: 굴리기 버튼을 꾹 눌러 낮게·높게를 노리면 35% 확률로 그쪽 눈 비율을 쓴다(`game.roll_move(aim)`, data/rules.json의 dice_control, 화면은 `scripts/ui/aim_bar.gd`). AI는 늘 높게 노린다
- 관문(gate 칸, 강제 전투): 맵마다 큰길 28%·52%·76% 지점에 3개(tools/make_maps.py). 지나가다가도 멈춰 관문지기와 싸운다. 관문지기 주사위는 3·4·4개, 골의 수호자는 5개. 이기면 카드 1장, 그 플레이어는 그 관문을 다시 싸우지 않는다(`game.gates_cleared`). 지면 직전 거점으로 가고 관문지기 주사위가 1개 줄어든다(data/rules.json의 gate_weaken). 골의 수호자도 질 때마다 1개씩 줄되 goal_min_dice(3개)까지
- 시너지: 파티 세 명이 같은 분류면 결속(시작 게이지 +15%), 모두 다른 분류면 조화(부적). data/rules.json의 synergy, `Game.synergy_of`
- 더블: 이동 주사위 2개 이상이 모두 같은 눈이면 어빌리티 게이지 +12%(data/rules.json의 double_gauge)
- 따라잡기: 상대보다 10칸 이상 뒤처진 쪽은 이동 주사위에서 큰 눈이 더 잘 나온다(data/rules.json의 catchup_gap·catchup_move_weights). 전투 주사위는 그대로
- 보드 약 120칸, 맵 9종(유턴형·피라미드형·나선형·직선형·계단형·산맥형·세로 S자형·쌍고리형·성벽형, tools/make_maps.py로 생성), 거점은 10칸 안팎마다, 갈림길(마름모) 3개, 50턴 제한(data/rules.json)
- 규칙 검사(tests)는 칸 번호가 정해진 작은 고정 맵 tests/fixtures/board_small.json으로 한다

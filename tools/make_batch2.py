"""2차 소리 묶음: 새 효과음(ONLY로 고른 것)과 안내·적 음성(data/voice_extra.json)을 만든다."""
import os, runpy
os.environ["ONLY"] = "tile_treasure,tile_prison,tile_curse,tile_luck,tile_forward,tile_trap,tile_fate,gate_open,goal,battle_win,battle_lose,banner,versus,double,card_attack,card_debuff,card_heal,upgrade,reward,purchase,levelup,summon_1,summon_2,summon_3,roulette_tick,stamp,tab,back,popup,denied,step,land,aim"
runpy.run_path("tools/make_sfx.py", run_name="__main__")
os.environ["ONLY"] = ""
os.environ["VOICE_TABLE"] = "data/voice_extra.json"
runpy.run_path("tools/make_voices.py", run_name="__main__")

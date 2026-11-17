import os, runpy
os.environ["PICK"] = "en:announcer_n_lose,vi:amundsen_attack,vi:libai_move,vi:announcer_m_win,vi:announcer_n_lose,en:choichiwon_skill"
runpy.run_path("tools/make_voices_i18n.py")

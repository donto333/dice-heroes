import os, runpy
os.environ["ONLY"] = "libai"
runpy.run_path("tools/make_voices.py")

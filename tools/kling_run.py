"""클링(Kling) API로 주문서 kling/jobs.json의 영웅 동작 영상을 만든다.

- API 키는 환경 변수 KLING_API_KEY(저장소 비밀값)에서만 읽고 화면에 찍지 않는다.
- 영웅마다, 동작마다 그림→영상(image-to-video) 작업을 한 번에 올리고, 끝날 때까지 기다려 mp4를 kling/out/<id>_<동작>.mp4로 받는다.
- 첫 장면(first_frame)과 끝 장면(last_frame)에 같은 그림을 넣어 반복되게 한다.
- 이미 kling/out에 있는 영상은 다시 만들지 않는다(돈이 드니까). 다시 만들려면 파일을 지우거나 주문서에 "redo": true.
- 주문서의 "only": ["gumiho_walk"]처럼 적으면 그것만 만든다.
"""
import base64
import json
import os
import sys
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent.parent
BASE = "https://api-singapore.klingai.com"
OUT = ROOT / "kling" / "out"


def _key() -> str:
	key = os.environ.get("KLING_API_KEY", "").strip()
	if not key:
		print("KLING_API_KEY 비밀값이 없습니다.")
		sys.exit(1)
	return key


def main() -> None:
	order = json.loads((ROOT / "kling" / "jobs.json").read_text(encoding="utf-8"))
	headers = {"Authorization": "Bearer " + _key(), "Content-Type": "application/json"}
	OUT.mkdir(parents=True, exist_ok=True)
	only = set(order.get("only", []))
	tasks = {}
	for job in order["jobs"]:
		image = base64.b64encode((ROOT / job["image"]).read_bytes()).decode()
		for kind, motion in job["kinds"].items():
			name = "%s_%s" % (job["id"], kind)
			if only and name not in only:
				continue
			if (OUT / (name + ".mp4")).exists() and not order.get("redo"):
				print("이미 있음:", name)
				continue
			body = {
				"contents": [
					{"type": "prompt", "text": motion + " " + order["common"]},
					{"type": "first_frame", "url": image},
					{"type": "last_frame", "url": image},
				],
				"settings": {"resolution": order.get("resolution", "720p"), "duration": int(job.get("duration", order.get("duration", 3)))},
				"options": {"watermark_info": {"enabled": False}},
			}
			reply = requests.post("%s/image-to-video/%s" % (BASE, order.get("model", "kling-4.0")), headers=headers, json=body, timeout=120)
			data = reply.json() if reply.headers.get("content-type", "").startswith("application/json") else {}
			print("올림:", name, reply.status_code, json.dumps(data, ensure_ascii=False)[:400])
			task = (data.get("data") or {}).get("id")
			if task:
				tasks[task] = name
	deadline = time.time() + 40 * 60
	while tasks and time.time() < deadline:
		time.sleep(20)
		reply = requests.get("%s/tasks" % BASE, headers=headers, params={"task_ids": ",".join(tasks)}, timeout=60)
		for item in (reply.json().get("data") or []):
			name = tasks.get(item.get("id"))
			status = item.get("status")
			if not name or status not in ("succeeded", "failed"):
				continue
			del tasks[item["id"]]
			if status == "failed":
				print("실패:", name, json.dumps(item, ensure_ascii=False)[:600])
				continue
			videos = [o for o in item.get("outputs", []) if o.get("type") == "video"]
			if not videos:
				print("영상 없음:", name, json.dumps(item, ensure_ascii=False)[:600])
				continue
			url = videos[0]["url"]
			got = requests.get(url, timeout=300)
			if got.status_code != 200:
				got = requests.get(url, headers={"Authorization": headers["Authorization"]}, timeout=300)
			(OUT / (name + ".mp4")).write_bytes(got.content)
			print("받음:", name, got.status_code, len(got.content), "바이트")
		print("남은 작업:", len(tasks))
	if tasks:
		print("시간 안에 끝나지 않은 작업:", tasks)


if __name__ == "__main__":
	main()

"""클링(Kling) API로 주문서 kling/jobs.json의 영웅 동작 영상을 만든다.

- API 키는 환경 변수 KLING_API_KEY(저장소 비밀값)에서만 읽고 화면에 찍지 않는다.
- 영웅마다, 동작마다 그림→영상(image-to-video) 작업을 한 번에 올리고, 끝날 때까지 기다려 mp4를 kling/out/<id>_<동작>.mp4로 받는다.
- 첫 장면(first_frame)에 그림을 넣는다. 끝 장면(last_frame)을 받는 모델(flash가 아닌 것)이면 같은 그림을 끝 장면에도 넣어 반복되게 한다.
- 작업마다 external_task_id(<id>_<동작>_<시각>)를 붙인다. recover: true면 최근 끝난 영상 중 kling/out에 없는 것을 먼저 받는다.
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


def _download(url: str, headers: dict, path: Path) -> None:
	got = requests.get(url, timeout=300)
	if got.status_code != 200:
		got = requests.get(url, headers={"Authorization": headers["Authorization"]}, timeout=300)
	path.write_bytes(got.content)
	print("받음:", path.name, got.status_code, len(got.content), "바이트")


def _recover(headers: dict) -> None:
	"""최근 하루 안에 끝난 영상 작업 중 아직 받지 않은 것을 받는다(앞선 실행이 중간에 멈췄을 때)."""
	now = int(time.time() * 1000)
	reply = requests.post("%s/tasks" % BASE, headers=headers, json={"start_time": now - 86400000, "end_time": now, "limit": 50, "filters": {"status": "succeeded", "product_type": "video"}}, timeout=60)
	items = ((reply.json().get("data") or {}).get("result") or [])
	print("최근 끝난 작업:", len(items))
	for item in items:
		path = OUT / ("recovered_%s.mp4" % item.get("id"))
		if path.exists():
			continue
		for output in item.get("outputs", []):
			if output.get("type") == "video":
				_download(output["url"], headers, path)
				break


def main() -> None:
	order = json.loads((ROOT / "kling" / "jobs.json").read_text(encoding="utf-8"))
	headers = {"Authorization": "Bearer " + _key(), "Content-Type": "application/json"}
	OUT.mkdir(parents=True, exist_ok=True)
	only = set(order.get("only", []))
	if order.get("recover"):
		_recover(headers)
	# 할 일 목록을 만들고, 클링이 한 번에 받는 수(parallel, 기본 4)만큼만 올려 두고 끝나면 다음 것을 올린다.
	queue = []
	for job in order["jobs"]:
		image = base64.b64encode((ROOT / job["image"]).read_bytes()).decode()
		for kind, motion in job["kinds"].items():
			name = "%s_%s" % (job["id"], kind)
			if only and name not in only:
				continue
			if (OUT / (name + ".mp4")).exists() and not order.get("redo"):
				print("이미 있음:", name)
				continue
			contents = [{"type": "prompt", "text": motion + " " + order["common"]}, {"type": "first_frame", "url": image}]
			if "flash" not in order.get("model", ""):
				contents.append({"type": "last_frame", "url": image})
			queue.append((name, contents, int(job.get("duration", order.get("duration", 3)))))
	limit = int(order.get("parallel", 4))
	tasks = {}
	tries = {}
	deadline = time.time() + 50 * 60
	while (queue or tasks) and time.time() < deadline:
		while queue and len(tasks) < limit:
			name, contents, seconds = queue[0]
			body = {
				"contents": contents,
				"settings": dict({"resolution": order.get("resolution", "720p"), "duration": seconds}, **({"sound": order["sound"]} if "sound" in order else {})),
				"options": {"watermark_info": {"enabled": False}, "external_task_id": "%s_%d" % (name, int(time.time()))},
			}
			reply = requests.post("%s/image-to-video/%s" % (BASE, order.get("model", "kling-4.0")), headers=headers, json=body, timeout=120)
			data = reply.json() if reply.headers.get("content-type", "").startswith("application/json") else {}
			task = (data.get("data") or {}).get("id")
			if task:
				queue.pop(0)
				tasks[task] = (name, contents, seconds)
				print("올림:", name)
			elif data.get("code") == 1303:
				break  # 한 번에 받는 수가 찼다. 하나 끝날 때까지 기다린다.
			else:
				queue.pop(0)
				print("올리기 실패:", name, reply.status_code, json.dumps(data, ensure_ascii=False)[:300])
		if not tasks:
			time.sleep(15)
			continue
		time.sleep(15)
		reply = requests.get("%s/tasks" % BASE, headers=headers, params={"task_ids": ",".join(tasks)}, timeout=60)
		for item in (reply.json().get("data") or []):
			entry = tasks.get(item.get("id"))
			status = item.get("status")
			if not entry or status not in ("succeeded", "failed"):
				continue
			del tasks[item["id"]]
			name = entry[0]
			if status == "failed":
				tries[name] = tries.get(name, 0) + 1
				print("실패:", name, str(item.get("message", ""))[:200])
				if tries[name] < 3:
					queue.append(entry)
				continue
			videos = [o for o in item.get("outputs", []) if o.get("type") == "video"]
			if videos:
				_download(videos[0]["url"], headers, OUT / (name + ".mp4"))
		print("남은 작업:", len(queue) + len(tasks))
	if tasks or queue:
		print("시간 안에 끝나지 않은 작업:", [t[0] for t in tasks.values()] + [q[0] for q in queue])


if __name__ == "__main__":
	main()

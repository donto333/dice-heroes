"""트리포(Tripo) API로 그림 한 장에서 3D 모델을 만들고, 뼈대를 넣고, 동작(가만히·걷기·베기)을 입힌다.

GitHub Actions(.github/workflows/tripo.yml)에서만 돈다. API 키는 저장소 비밀값에서 환경 변수로 받는다(화면에 찍지 않는다).
주문서: tripo/jobs.json. 결과: out/tripo/<이름>/model.glb, rigged.glb, anim*.glb, tasks.json(작업 번호).
쓰는 법: python3 tools/tripo_run.py [balance]
"""
import json
import os
import sys
import time
from pathlib import Path

import requests
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
BASE = "https://openapi.tripo3d.com/v3"
OUT = ROOT / "out" / "tripo"
## 비밀값 이름을 모르므로 흔한 이름을 차례로 찾아본다.
KEY_NAMES = ["TRIPO_API_KEY", "TRIPO_KEY", "TRIPO", "TRIPO_API", "TRIPO3D_API_KEY", "TRIPO_TOKEN", "TRIPO_SECRET", "TRIPO_AI_API_KEY"]


def find_key() -> str:
	for name in KEY_NAMES:
		value = os.environ.get(name, "").strip()
		if value:
			print("API 키를 찾음: 비밀값 이름", name, "(길이 %d)" % len(value))
			return value
	print("API 키를 찾지 못함. 저장소 비밀값 이름이 다음 중 하나여야 한다:", ", ".join(KEY_NAMES))
	sys.exit(2)


def call(method: str, path: str, key: str, **kwargs) -> dict:
	headers = {"Authorization": "Bearer " + key}
	for attempt in range(4):
		response = requests.request(method, BASE + path, headers=headers, timeout=120, **kwargs)
		if response.status_code in (429, 500, 502, 503) and attempt < 3:
			time.sleep(5 + attempt * 5)
			continue
		break
	try:
		body = response.json()
	except ValueError:
		body = {"code": -1, "raw": response.text[:400]}
	if response.status_code != 200 or body.get("code") != 0:
		print("요청 실패:", method, path, response.status_code, json.dumps(body, ensure_ascii=False)[:600])
		raise RuntimeError("tripo %s %s" % (method, path))
	return body["data"]


def wait(task_id: str, key: str, label: str) -> dict:
	started = time.time()
	last = -1
	while True:
		data = call("GET", "/tasks/" + task_id, key)
		status = data.get("status")
		progress = data.get("progress", 0)
		if progress != last:
			print("  %s %s %s%%" % (label, status, progress))
			last = progress
		if status == "success":
			print("  끝:", label, "크레딧", data.get("credits_consumed"), "결과 항목", list((data.get("output") or {}).keys()))
			return data
		if status in ("failed", "cancelled", "banned", "expired", "unknown"):
			print("  실패:", json.dumps(data, ensure_ascii=False)[:600])
			raise RuntimeError(label + " " + str(status))
		if time.time() - started > 1500:
			raise RuntimeError(label + " 시간 초과")
		time.sleep(4)


def download(url: str, target: Path) -> None:
	target.parent.mkdir(parents=True, exist_ok=True)
	with requests.get(url, timeout=300, stream=True) as response:
		response.raise_for_status()
		with open(target, "wb") as handle:
			for chunk in response.iter_content(1 << 16):
				handle.write(chunk)
	print("  받음:", target.relative_to(ROOT), "%.1fMB" % (target.stat().st_size / 1e6))


def urls_of(output: dict) -> list:
	"""작업 결과에서 모델 주소들을 꺼낸다(항목 이름이 작업마다 달라서 넓게 찾는다)."""
	found = []
	for name in ("model_url", "pbr_model_url", "base_model_url", "model"):
		value = output.get(name)
		if isinstance(value, str) and value.startswith("http"):
			found.append(value)
			break
	many = output.get("model_urls")
	if isinstance(many, list):
		found += [item if isinstance(item, str) else item.get("url", "") for item in many]
	elif isinstance(many, dict):
		found += [value for value in many.values() if isinstance(value, str)]
	return [url for url in found if url]


def prepare_image(source: Path, target: Path) -> None:
	"""투명 바탕 그림을 흰 바탕 정사각형(1024px)으로 만들어 올린다."""
	image = Image.open(source).convert("RGBA")
	side = int(max(image.size) * 1.12)
	canvas = Image.new("RGBA", (side, side), (255, 255, 255, 255))
	canvas.alpha_composite(image, ((side - image.size[0]) // 2, (side - image.size[1]) // 2))
	target.parent.mkdir(parents=True, exist_ok=True)
	canvas.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(target)


def run_job(job: dict, key: str) -> None:
	name = job["name"]
	folder = OUT / name
	folder.mkdir(parents=True, exist_ok=True)
	tasks = {"model_task": job.get("model_task", ""), "rig_task": job.get("rig_task", ""), "anim_task": job.get("anim_task", "")}
	print("== 주문:", name)
	if not tasks["model_task"]:
		prepared = folder / "input.png"
		prepare_image(ROOT / job["image"], prepared)
		with open(prepared, "rb") as handle:
			token = call("POST", "/files", key, files={"file": ("input.png", handle, "image/png")})["file_token"]
		body = {"input": token, "model": job.get("model", "v3.1-20260211"), "texture": True, "pbr": False,
			"face_limit": int(job.get("face_limit", 30000)), "texture_quality": job.get("texture_quality", "standard")}
		tasks["model_task"] = call("POST", "/generation/image-to-model", key, json=body)["task_id"]
		print("  TASK %s model_task %s" % (name, tasks["model_task"]))
	model = wait(tasks["model_task"], key, name + " 모델")
	for index, url in enumerate(urls_of(model.get("output") or {})[:1]):
		download(url, folder / "model.glb")
	shot = (model.get("output") or {}).get("rendered_image_url") or (model.get("output") or {}).get("rendered_image")
	if isinstance(shot, str) and shot.startswith("http"):
		download(shot, folder / "preview.webp")
	if job.get("rig"):
		if not tasks["rig_task"]:
			check = call("POST", "/animations/rig-check", key, json={"input": tasks["model_task"]})
			print("  뼈대 검사 응답:", json.dumps(check, ensure_ascii=False)[:300])
			if "task_id" in check and "riggable" not in check:
				check = (wait(check["task_id"], key, name + " 뼈대 검사").get("output") or {})
				print("  뼈대 검사 결과:", json.dumps(check, ensure_ascii=False)[:300])
			if check.get("riggable") is False:
				print("  이 모델은 뼈대를 넣을 수 없다고 함. 동작 없이 넘어간다.")
				(folder / "tasks.json").write_text(json.dumps(tasks, indent="\t"))
				return
			body = {"input": tasks["model_task"], "model": "v3.0-20260909", "rig_type": check.get("rig_type", "biped"), "spec": "mixamo"}
			tasks["rig_task"] = call("POST", "/animations/rig", key, json=body)["task_id"]
			print("  TASK %s rig_task %s" % (name, tasks["rig_task"]))
		rig = wait(tasks["rig_task"], key, name + " 뼈대")
		for url in urls_of(rig.get("output") or {})[:1]:
			download(url, folder / "rigged.glb")
		animations = job.get("animations", [])
		if animations:
			if not tasks["anim_task"]:
				body = {"input": tasks["rig_task"], "animations": animations[:5], "out_format": "glb", "animate_in_place": True}
				tasks["anim_task"] = call("POST", "/animations/retarget", key, json=body)["task_id"]
				print("  TASK %s anim_task %s" % (name, tasks["anim_task"]))
			anim = wait(tasks["anim_task"], key, name + " 동작")
			print("  동작 결과:", json.dumps(anim.get("output"), ensure_ascii=False)[:500])
			for index, url in enumerate(urls_of(anim.get("output") or {})):
				download(url, folder / ("anim%d.glb" % index))
	(folder / "tasks.json").write_text(json.dumps(tasks, indent="\t"))


def main() -> None:
	key = find_key()
	balance = call("GET", "/account/balance", key)
	print("남은 크레딧:", balance.get("balance"), "/ 묶인 크레딧:", balance.get("frozen"))
	if len(sys.argv) > 1 and sys.argv[1] == "balance":
		return
	jobs = json.loads((ROOT / "tripo" / "jobs.json").read_text())["jobs"]
	failed = 0
	for job in jobs:
		try:
			run_job(job, key)
		except Exception as error:  # 한 주문이 실패해도 나머지는 계속한다.
			failed += 1
			print("주문 실패:", job.get("name"), error)
	after = call("GET", "/account/balance", key)
	print("끝난 뒤 크레딧:", after.get("balance"), "(이번에 쓴 양 %.1f)" % (float(balance.get("balance", 0)) - float(after.get("balance", 0))))
	if failed:
		sys.exit(1)


if __name__ == "__main__":
	main()

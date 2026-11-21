#!/bin/bash
# 주사위 영웅전 서버 첫 설치. Vultr '시작 스크립트'로 서버가 처음 켜질 때 root로 한 번 돈다.
# 하는 일: Docker 설치 → 저장소 받기 → .env(비밀번호·주소) 만들기 → 서버 켜기 → 5분마다 저장소를 받아 바뀌면 다시 켜기.
set -euxo pipefail

# 'curl ... | bash'로 돌면 스크립트 자체가 표준 입력이라, 중간 명령(apt·docker 설치)이 입력을 읽어 버리면
# 나머지 줄이 사라진다. 그래서 먼저 파일로 받아 그 파일로 다시 시작한다.
SELF=/root/dice-setup.sh
if [ "${DICE_SETUP_FILE:-}" != "1" ]; then
	curl -fsSL https://raw.githubusercontent.com/donto333/dice-heroes/main/server/setup.sh -o "$SELF"
	DICE_SETUP_FILE=1 exec bash "$SELF" < /dev/null
fi

exec > >(tee -a /var/log/dice-setup.log) 2>&1
echo "=== 설치 시작 $(date) ==="

REPO=https://github.com/donto333/dice-heroes.git
DIR=/opt/dice-heroes

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git curl ufw

# 방화벽: SSH·http·https만 연다.
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Docker
if ! command -v docker >/dev/null; then
	curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

# 저장소에서 server 폴더만 받는다(그림·소리는 받지 않음).
if [ ! -d "$DIR/.git" ]; then
	git clone --depth 1 --filter=blob:none --sparse "$REPO" "$DIR"
	git -C "$DIR" sparse-checkout set server
fi

cd "$DIR/server"
mkdir -p nakama/modules

# .env: 처음 한 번만 만든다. 주소는 이 서버의 IP로 만든 무료 주소(sslip.io).
if [ ! -f .env ]; then
	IP=$(curl -fsS https://api.ipify.org || hostname -I | awk '{print $1}')
	SITE="$(echo "$IP" | tr . -).sslip.io"
	cat > .env <<EOF
SITE=$SITE
POSTGRES_PASSWORD=$(openssl rand -hex 24)
CONSOLE_PASSWORD=$(openssl rand -hex 12)
SERVER_KEY=$(grep -o '"server_key": *"[^"]*"' config.json | sed 's/.*"\([^"]*\)"$/\1/')
EOF
	chmod 600 .env
fi

docker compose up -d

# 자동 업데이트: 5분마다 저장소를 받아 server 폴더가 바뀌었으면 다시 켠다.
cat > /usr/local/bin/dice-update <<'EOF'
#!/bin/bash
set -e
cd /opt/dice-heroes
OLD=$(git rev-parse HEAD)
git pull --quiet --depth 1 origin main || exit 0
NEW=$(git rev-parse HEAD)
if [ "$OLD" != "$NEW" ] && ! git diff --quiet "$OLD" "$NEW" -- server; then
	cd server && docker compose pull --quiet && docker compose up -d --remove-orphans
	echo "$(date) 업데이트 $NEW" >> /var/log/dice-update.log
fi
EOF
chmod +x /usr/local/bin/dice-update
cat > /etc/systemd/system/dice-update.service <<'EOF'
[Unit]
Description=주사위 영웅전 서버 업데이트
[Service]
Type=oneshot
ExecStart=/usr/local/bin/dice-update
EOF
cat > /etc/systemd/system/dice-update.timer <<'EOF'
[Unit]
Description=주사위 영웅전 서버 업데이트 5분마다
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now dice-update.timer

echo "설치 끝: https://$(grep ^SITE= .env | cut -d= -f2)/healthcheck"

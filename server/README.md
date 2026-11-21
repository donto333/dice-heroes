# 주사위 영웅전 서버

Vultr 서울 서버(Ubuntu 24.04 LTS, 1 vCPU·2GB) 한 대에 Docker로 세 가지를 켠다.

- **Nakama** 3.22: 게임 서버(계정·저장·나중에 대전).
- **PostgreSQL** 16: 데이터베이스. 바깥에 열지 않는다.
- **Caddy**: `https://<IP를 -로 이은 것>.sslip.io` 무료 주소에 https 인증서를 붙여 Nakama API(7350)로 넘긴다.

## 설치 (처음 한 번)

Vultr에서 서버를 만들 때 **Startup Script**에 아래 내용을 넣는다(Vultr → Orchestration → Scripts → Add Startup Script, 종류 Boot).

```bash
#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/donto333/dice-heroes/main/server/setup.sh | bash
```

처음 켜질 때 `setup.sh`가 Docker 설치 → 이 폴더만 받기 → `.env`(비밀번호·주소, 서버에만 있음) 만들기 → `docker compose up -d`까지 한다. 확인: `https://<주소>/healthcheck`가 `{}`를 돌려주면 성공.

## 업데이트

서버가 5분마다 `main`을 받아서 `server/` 폴더가 바뀌었으면 다시 켠다(`dice-update.timer`). 그래서 이 폴더를 고쳐 PR로 합치면 몇 분 안에 서버에 들어간다. SSH 접속이나 GitHub 비밀값이 필요 없다.

## 주의

- 관리 화면(7351)은 바깥에 열지 않았다. 비밀번호는 서버의 `/opt/dice-heroes/server/.env`에 있다.
- 서버를 새로 만들면 IP가 바뀌어 주소도 바뀐다. 도메인을 사면 `.env`의 `SITE`만 바꾼다.
- 설치 기록: 서버의 `/var/log/dice-setup.log`, 업데이트 기록: `/var/log/dice-update.log`.

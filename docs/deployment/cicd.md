# CI/CD 建置與維運紀錄

從零重建業務中心 dev／prod 自動部署的完整步驟。
repo 內的檔案（workflow、compose、Dockerfile）跟著 git 走；**142 主機上的東西不在 repo**，
這份文件是它們唯一的紀錄，142 上有改要回來更新這裡。

---

## 1. 整體流程

```
push 任一分支
  └─ ci.yml（GitHub 雲端 ubuntu-latest，不在 142）
       ├─ frontend：npm ci → lint → typecheck → build（Node 22）
       └─ api：dotnet restore → build -c Release（.NET 8）

ci 成功 且 分支 = dev
  └─ deploy-dev.yml → 142 的 self-hosted runner
       ├─ checkout dev 到 /runner-data/proril-sales-center/Proril_Sales_Center/Proril_Sales_Center/
       ├─ docker compose -f docker-compose.dev.yml up -d --build --remove-orphans
       │    ├─ build：repo 的 Dockerfile、api/Dockerfile（交給 142 主機 Docker）
       │    └─ env_file：/secrets/dev/docker.env、/secrets/dev/web-server.env
       ├─ logs --tail=50
       └─ docker image prune -f

手動（GitHub → Actions → deploy-prod → Run workflow）
  └─ deploy-prod.yml → 同一個 runner，checkout main，docker-compose.prod.yml
```

- push `main` **只跑 CI，不部署**；prod 一律手動。
- deploy-prod **不檢查 CI 有沒有過**，按之前自己先確認 main 的 ci 是綠的。

---

## 2. repo 內的檔案

| 檔案 | 用途 |
|---|---|
| `.github/workflows/ci.yml` | `on: push`，雲端跑 lint／typecheck／build |
| `.github/workflows/deploy-dev.yml` | `workflow_run`（ci 完成 + 分支 dev），`APP_PORT=50061` |
| `.github/workflows/deploy-prod.yml` | `workflow_dispatch`，`APP_PORT=51061` |
| `Dockerfile` | 前端 Nuxt，node:22-alpine 兩階段，port 3000 |
| `api/Dockerfile` | 後端 .NET 8，sdk build → aspnet runtime，port 8080 |
| `.dockerignore` / `api/.dockerignore` | 排除 env 檔、appsettings.Development/Production、`api/` 等 |
| `docker-compose.dev.yml` | 142 dev，`name: proril_sales_center_dev` |
| `docker-compose.prod.yml` | 142 prod，`name: proril_sales_center_prod` |
| `docker-compose.yml` | 本機單機測試用，CI 不用它 |
| `scripts/pack-docker-images.ps1` | 離線部署：本機 build → `docker save` tar → 傳到主機 `docker load` |
| `.env.example` / `api/docker.env.example` | 兩份 env 檔的範本 |

runner 只認 `runs-on: [self-hosted, docker, proril-sales-center]`，
這三個標籤必須跟 runner 的 `LABELS` 一致。

---

## 3. 142 主機上的配置（不在 repo）

### 3.1 目錄

```
D:\github-runners\
├─ docker-compose.yml            主檔，name: github-runner，include 各專案 runner（見 3.2）
├─ .env                          GH_PAT=ghp_xxx（見 3.3，所有 runner 共用）
├─ proril-sales-center.yml       本專案 runner（見 3.2）
├─ proril-oauth.yml              其他專案的 runner（不歸本專案管）
├─ proril-portal.yml
├─ proril-official-erp-gateway.yml
└─ proril-finance-center.yml

D:\proril-sales-center.proril\
├─ proril-sales-center-dev.proril\     → runner 內 /secrets/dev（唯讀）
│  ├─ docker.env                      前端 env（範本 .env.example）
│  ├─ web-server.env                  後端 env（範本 api/docker.env.example）
│  └─ ProrilWebFiles\                 附件，要與 1.0 共用（見 3.5）
└─ proril-sales-center-prod.proril\    → runner 內 /secrets/prod（唯讀）
   ├─ docker.env
   ├─ web-server.env
   └─ ProrilWebFiles\
```

- `/secrets` **只存在 runner 容器內**，app/api 容器裡沒有；compose 讀完 env 檔後轉成環境變數注入。
- `/secrets` 不會被 git 更新，改設定就是直接改上面的檔案，**改完要重跑 deploy**
  （env_file 只在建容器時讀一次）。
- 整個資料夾掛載而不是單一檔案：單檔掛載在編輯器換檔存檔後，容器可能一直看到舊內容。
- 2026-10 整理時 `/secrets/dev` 下另有 `docker-compose.yml`、`Logs\`，是早期手動部署遺留，
  CI 不會用到。`Logs` 實際寫在 named volume `proril-sales-center-dev-logs`。

### 3.2 runner compose

142 上所有專案的 runner 由同一份主檔 `D:\github-runners\docker-compose.yml` 管理：

```yaml
name: github-runner

include:
  - proril-oauth.yml
  - proril-portal.yml
  - proril-official-erp-gateway.yml
  - proril-finance-center.yml
  - proril-sales-center.yml
```

`.env` 放在主檔旁邊，`${GH_PAT}` 由主檔所在目錄的 `.env` 帶入，所以**五個 runner 共用同一把 PAT**。

本專案的 `D:\github-runners\proril-sales-center.yml`：

```yaml
services:
  proril-sales-center-runner:
    image: myoung34/github-runner:latest
    restart: unless-stopped
    environment:
      #以下勿動
      ACCESS_TOKEN: ${GH_PAT}
      RUNNER_SCOPE: repo
      RUNNER_WORKDIR: /runner-data/proril-sales-center
      #以上勿動

      REPO_URL: https://github.com/mis23255790/Proril_Sales_Center
      RUNNER_NAME: proril-sales-center-runner     # 不可與其他 runner 重複
      LABELS: self-hosted,docker,proril-sales-center  # 與 workflow 的 runs-on 一致
    volumes:
      #以下勿動
      - /var/run/docker.sock:/var/run/docker.sock
      - /runner-data/proril-sales-center:/runner-data/proril-sales-center
      #以上勿動

      #專案相關（不要再重複寫上面兩行，compose 不允許重複項目）
      - D:/proril-sales-center.proril/proril-sales-center-dev.proril:/secrets/dev:ro
      - D:/proril-sales-center.proril/proril-sales-center-prod.proril:/secrets/prod:ro
```

各掛載的用途：

| 掛載 | 說明 |
|---|---|
| `docker.sock` | runner 裡的 `docker compose` 直接操作 142 主機 Docker，app/api 是主機上的兄弟容器 |
| `/runner-data/...`（兩邊同路徑） | runner 工作目錄。Linux 路徑，實際落在 Docker Desktop 的 WSL2 VM 內，D 槽看不到 |
| `/secrets/{dev,prod}:ro` | env 檔，`ro` = 唯讀，防 workflow 改壞機密檔 |

> 2026-10 整理時這份檔案的專案區塊**重複**了 `docker.sock` 與 `runner-data` 兩行，
> 下次重建 runner 前要刪掉，否則 compose 可能報重複項目起不來。

啟動／重建 runner（在 `D:\github-runners`，**一律透過主檔、指定服務名**）：

```bash
docker compose config --quiet
```

```bash
docker compose up -d --force-recreate proril-sales-center-runner
```

第一行只檢查語法（沒輸出 = 通過），會連同其他四個 runner 一起檢查。
第二行只重建本專案的 runner；**不加服務名會把五個 runner 全部重建**。
重建前確認沒有 deploy 在跑。

> 不要用 `docker compose -f proril-sales-center.yml up`：繞過主檔會變成另一個 compose 專案，
> 讀不到主檔旁的 `.env`（GH_PAT 變空），還可能多起一個同 `RUNNER_NAME` 的 runner。

### 3.3 GH_PAT（runner 註冊用的 token）

- 是 GitHub **Personal Access Token**，放在 `D:\github-runners\.env` 的 `GH_PAT=`。
- runner 每次**啟動**時用它向 GitHub 申請一次性註冊 token；平常跑 job 不用它，
  所以 token 失效時現有 runner 不會立刻壞，**要等 runner 重啟才會註冊失敗**。
- 目前用的是 classic token「`.142專用`」，scope `repo`，**沒有到期日**。
  主檔 include 的**五個 runner 全部共用**它，刪掉或過期會讓五個專案的部署一起失效。
- **token 明文只放在 142 的 `.env`**，不要抄進筆記、文件、截圖或聊天。
- 產生者必須對 repo 有 admin：`mis23255790` 是個人帳號時只有擁有者本人有 admin。

重新產生：

1. 用 repo 擁有者帳號登入 → 頭像 → Settings → Developer settings → Personal access tokens。
2. 建議用 **Fine-grained tokens**：Resource owner `mis23255790`、Only select repositories
   勾 `Proril_Sales_Center`（與其他共用的 repo）、Repository permissions →
   **Administration: Read and write**、設 Expiration 並記下到期日。
   （classic：勾 `repo` 即可，但權限涵蓋該帳號所有 repo）
3. 產生後立刻複製（只顯示一次），換掉 `.env` 的 `GH_PAT`。
4. 五個 runner 都要重建：在 `D:\github-runners` 執行 `docker compose up -d --force-recreate`（不帶服務名）。
   fine-grained token 要把五個 repo 都勾進去，少勾的那個 runner 會註冊失敗。
5. GitHub repo → Settings → Actions → Runners 確認都是 Idle，最後才刪舊 token。

反查 `.env` 裡的 token 屬於誰、何時到期（PowerShell，不會印出 token）：

```powershell
$pat = (Get-Content D:\github-runners\.env | Where-Object { $_ -like 'GH_PAT=*' }) -replace '^GH_PAT=',''; $r = Invoke-WebRequest -Uri https://api.github.com/user -Headers @{ Authorization = "Bearer $pat" } -UseBasicParsing; ($r.Content | ConvertFrom-Json).login; $r.Headers['github-authentication-token-expiration']
```

回 401 = token 已失效。

### 3.4 external network

compose 宣告為 `external: true`，**要先存在**，compose 不會建：

| 環境 | network |
|---|---|
| dev | `dev-mssql-2022-network`、`nginx-proxy` |
| prod | `prod-mssql-2022-network`、`nginx-proxy` |

```bash
docker network ls
```

這些是 DB 與 nginx 那邊的 compose 建的，不屬於本專案。

### 3.5 附件 volume（ProrilWebFiles）

附件必須與 1.0 指向同一個 host 目錄。compose 在 Linux 的 runner 容器裡解析不了 Windows 路徑，
所以改用「先綁好 host 路徑的 external named volume」。在 142 用**原生 Windows Docker CLI** 建：

```bash
docker volume create --driver local --opt type=none --opt o=bind --opt device="D:\proril-sales-center.proril\proril-sales-center-dev.proril\ProrilWebFiles" proril-sales-center-dev-prorilwebfiles
```

```bash
docker volume create --driver local --opt type=none --opt o=bind --opt device="D:\proril-sales-center.proril\proril-sales-center-prod.proril\ProrilWebFiles" proril-sales-center-prod-prorilwebfiles
```

device 目錄要先存在。確認：`docker volume inspect proril-sales-center-dev-prorilwebfiles`。

Log volume（`proril-sales-center-{dev,prod}-logs`）不是 external，compose 會自己建。

### 3.6 nginx 反向代理

142 的 `nginx_proxy` 容器用**容器名稱**轉發：

| 環境 | 設定檔 | proxy_pass |
|---|---|---|
| dev | `/etc/nginx/conf.d/proril-sales-center-dev.conf` | `http://proril_sales_center_dev_app:3000` |
| prod | `/etc/nginx/conf.d/proril-sales-center.conf` | `http://proril_sales_center_prod_app:3000` |

所以 compose 的 `container_name` 寫死，**不要拿掉**，否則新容器接不上 nginx、畫面一直是舊的。
`NUXT_PUBLIC_API_BASE` 也用容器名稱（`http://proril_sales_center_{env}_api:8080`），
避免在共用的 `nginx-proxy` 網路上與別的專案的 `api` 服務撞名。

---

## 4. env 檔內容

### web-server.env（api）

範本 `api/docker.env.example`，巢狀設定用 `__` 取代 `:`：

| 變數 | 說明 |
|---|---|
| `ConnectionStrings__SalesCenter` | 唯一的 DB 連線（`Proril_Sales_Center`），沒填 api 起不來 |
| `JwtSettings__SignKey` | **必須與 1.0 相同**，不同 → 全部 401 |
| `Security__AesKey` | **必須與 1.0 相同**，不同 → 密碼永遠錯 |
| `Storage__ShareRoot` | 固定 `/app/ProrilWebFiles` |
| `Sso__InternalSecret` | 與前端 `NUXT_SSO_INTERNAL_SECRET` 同值 |
| `Cors__AllowedOrigins__0` | 走 Nuxt proxy 同源時留空 |

`ASPNETCORE_ENVIRONMENT` 寫在 compose（dev=`Development`、prod=`Production`），不用放 env 檔。

### docker.env（app）

範本 `.env.example`。`NUXT_PUBLIC_API_BASE` 已寫在 compose，不用放。重點：

- dev：`NUXT_PUBLIC_BLOCK_ROBOTS=true`、`NUXT_PUBLIC_SHOW_WATERMARK=true`、`NUXT_PUBLIC_FAVICON=/favicon-test.jpg`
- prod：上面三個留空／false
- OAuth：`NUXT_PUBLIC_OAUTH_CLIENT_ID`、`NUXT_PUBLIC_OAUTH_REDIRECT_URI`（與通行證登記的一字不差）、`NUXT_OAUTH_CLIENT_SECRET`
- `NUXT_SSO_INTERNAL_SECRET`（與 api 同值）、`NUXT_MFG_HANDOFF_SECRET`

---

## 5. 從零重建檢查清單

1. 142 有 Docker Desktop，`docker network ls` 看得到 3.4 的 network。
2. 建 `D:\proril-sales-center.proril\proril-sales-center-{dev,prod}.proril\`，
   放好 `docker.env`、`web-server.env`、`ProrilWebFiles\`。
3. 建兩個附件 external volume（3.5）。
4. 產生 GH_PAT 放 `D:\github-runners\.env`（3.3）。
5. 寫 `D:\github-runners\proril-sales-center.yml`，並加進主檔 `docker-compose.yml` 的 `include`（3.2），
   `docker compose config --quiet` 後 `docker compose up -d proril-sales-center-runner`。
6. GitHub → Settings → Actions → Runners 看到 runner 是 Idle、標籤正確。
7. 若 142 上有手動建的同名舊容器，先刪：
   `docker rm -f proril_sales_center_dev_app proril_sales_center_dev_api`
8. nginx 設定檔（3.6）就位。
9. push 到 dev → Actions 看 ci 綠 → deploy-dev 綠 → 開網頁驗證。
10. prod：Actions → deploy-prod → Run workflow。

---

## 6. 日常維運

| 要做的事 | 怎麼做 |
|---|---|
| 部署 dev | push 到 `dev` |
| 部署 prod | GitHub Actions → deploy-prod → Run workflow |
| 改 env | 改 142 上的 env 檔 → 重跑對應 deploy（Actions 裡 Re-run） |
| 看執行紀錄 | https://github.com/mis23255790/Proril_Sales_Center/actions |
| 看容器 log | `docker logs --tail=100 proril_sales_center_dev_api` |
| 確認 env 有注入 | `docker exec proril_sales_center_dev_api printenv ConnectionStrings__SalesCenter` |
| 確認 runner 看得到 secrets | `docker exec proril-sales-center-runner ls /secrets/dev` |
| 看磁碟用量 | `docker system df` |
| 清 build cache（workflow 沒清，會累積） | `docker builder prune -f --filter until=168h` |

checkout 目錄會被下次 checkout 重用（`git clean` + 切 commit），不會累積；
舊 image 由 deploy 最後的 `docker image prune -f` 清掉。

---

## 7. 常見問題

| 症狀 | 原因 |
|---|---|
| deploy 一直 Waiting for a runner | runner 掛了或註冊失敗（GH_PAT 失效）、標籤不一致 |
| deploy 報找不到 `/secrets/dev/web-server.env` | 檔案不存在，或 runner 的 `/secrets` 掛載沒設好 |
| api 容器一直重啟 | `web-server.env` 缺 `ConnectionStrings__SalesCenter` |
| 全部 401 | `JwtSettings__SignKey` 與 1.0 不同 |
| 讀不到附件 | ProrilWebFiles volume 綁錯目錄 |
| 部署成功但畫面還是舊的 | `container_name` 被改掉，nginx 接不到新容器 |
| 新端點全部 404 | app 沒拿到 `NUXT_PUBLIC_API_BASE`，退回 1.0 站台 |
| 改了 env 沒生效 | 沒重跑 deploy，env_file 只在建容器時讀 |
| `network ... not found` | external network 不存在（3.4） |

---

## 8. 已知待改

- [ ] runner yml 專案區塊重複的兩行 volumes（3.2）
- [ ] 確認 `/secrets/dev` 有 `web-server.env`；清掉遺留的 `docker-compose.yml`、`Logs\`
- [ ] GH_PAT 改 fine-grained + 設到期日（3.3）
- [ ] deploy-prod 加 CI 通過的關卡
- [ ] CI 加 docker build 驗證（目前 Dockerfile 壞了要到部署才知道）
- [ ] `docker-compose.prod.yml` 開頭註解誤寫成 dev-mssql-2022-network 主機
- [ ] `scripts/pack-docker-images.ps1` 的 prod 目錄 `D:\proril-sales-center-prod.proril\`
      與實際 `D:\proril-sales-center.proril\proril-sales-center-prod.proril\` 不一致；
      且 prod compose 的 env_file 是 runner 內路徑，離線包在主機直接 `up` 會找不到
- [ ] image 沒有版本 tag，無法退版，只能 revert commit 重部署

# 專案名稱：PRORIL Official 2.0

## 1. 專案架構 (Architecture)
本專案採用單一倉庫 (Monorepo) 進行 1.0 到 2.0 的重構遷移：
- `/web`: 2.0 全端專案（Nuxt 4 + Nitro 引擎）。前後端邏輯、API 與網頁皆在此資料夾內。
- `/legacy_1.0`: 1.0 官網的 .NET 原始碼（唯讀，重構時供 AI 參考業務邏輯與資料來源）。
- 資料庫定義：位於 `/web/prisma/schema.prisma` (MySQL)，使用 Prisma ORM 管理。

## 2. 技術棧 (Tech Stack)
- 核心框架：Nuxt 4 (Stable)
- 包管理器：Yarn
- 樣式系統：Tailwind CSS v4 (全面改用原生 CSS 巢狀語法)
- UI 元件庫：Nuxt UI v4 (基於 Tailwind v4 生態)
- 資料庫 ORM：Prisma (搭配 MySQL)
- 程式語言：TypeScript
- 語系管理：@nuxtjs/i18n (支援 `zh-TW` 與 `en`)
- 爬蟲管理：@nuxtjs/robots

## 3. 常用開發指令 (Crucial Commands)
- 安裝套件: `cd web && yarn add <package>` 或 `yarn add -D <package>`
- 啟動全端本地開發伺服器: `cd web && yarn dev`
- 專案打包建置: `cd web && yarn build`
- Prisma 建立/套用資料庫異動 (開發環境，會產生 migration 檔案): `cd web && npx prisma migrate dev --name <變更描述>`
- Prisma 套用既有 migration (其他電腦/正式環境，不產生新檔案): `cd web && npx prisma migrate deploy`
- 開啟 Prisma 視覺化後台: `cd web && npx prisma studio`

> 注意：`prisma/migrations` 資料夾必須進 git 版控。多台電腦或多人開發時，異動 schema 一律用 `migrate dev` 產生 migration 檔案並 commit，換電腦後執行 `migrate deploy` 套用，禁止直接對正式或共用資料庫用 `db push`。

## 4. 全端開發規範與風格 (Guidelines)

### AI 回應風格與 Token 優化 (CRITICAL for Saving Tokens)
- **一律使用繁體中文回應**：無論我用什麼語言下指令，一律以繁體中文回覆，不得使用英文或其他語言回應。
- **禁止盲猜與主動確認**：若我的指令不完整、缺乏實作細節、或可能引發架構衝突，請暫停執行。直接提出精簡的關鍵提問與我確認，對齊需求後再動手寫 code。
- **嚴格禁止廢話**：拒絕任何開場白、結語、社交客套話（例如：「好的，我來幫你...」、「希望這個回答對你有幫助」）。
- **嚴格禁用表情符號**：整段對話中嚴禁出現任何 Emojis。
- **直奔主題**：直接給出修改後的程式碼區塊、檔案變更或需要執行的指令。


### 程式碼與語法規範：
- **語法風格**：前端全面使用 Vue 3 Composition API (`<script setup>`)。
- **函式宣告**：優先且嚴格使用**箭頭函式 (Arrow Functions)**。
- **型別規範**：盡可能落實 TypeScript 型別定義，開發效率優先時**允許彈性使用 `any`**。

### 核心設計原則：
- **絕對嚴格的多國語系 (i18n)**：
  - 所有硬編碼文本絕對不允許直接寫在 Template 內，必須抽離至語系檔（如 `zh-TW.json`, `en.json`）。
  - 畫面上統一使用 `$t('path.to.key')` 進行調用。

- **行動優先與 RWD 響應式設計**：
  - 必須嚴格遵循 Tailwind CSS 的 Mobile-First 規範。
  - 預設樣式為手機版，並善用 `md:` (768px+) 與 `lg:` (1024px+) 的斷點。

- **搜尋引擎最佳化 (SEO) & 爬蟲控制**：
  - 全站全域 SEO 由 `app.vue` 透過 `useLocaleHead` 自動生成 `canonical` 與 `hreflang`。
  - 建立任何新頁面時，必須主動加入帶有 i18n 綁定的 `useSeoMeta` 結構。
  - **環境隔離防呆**：非正式環境（如 Staging/測試站）必須透過環境變數 `NUXT_PUBLIC_BLOCK_ROBOTS=true` 封鎖 Google 爬蟲索引。

- **品牌色彩系統**（取自 LOGO 實際取樣）：
  - 深海軍藍 `#002237`（LOGO 文字色）→ Tailwind token `navy-50 ~ navy-950`（900 = 原色）
  - 品牌橘 `#e26a23`（LOGO 斜紋色）→ Tailwind token `brand-50 ~ brand-900`（500 = 原色）
  - 定義位置：`web/app/assets/css/main.css` 的 `@theme` 區塊

- **後端 API 規範**：
  - **禁止建立 `tailwind.config.js`**。本專案使用 Tailwind v4，任何主題或斷點自訂必須嚴格寫在 CSS 的 `@theme` 區塊中。
  - 後端 API 回傳格式需保持一致，統一採用以下 JSON 結構：
    `{ success: boolean, data: any, error: { message: string, code?: number } | null }`

- **檔案上傳 / 私有檔案存取權限**：
  - `File.visibility`（`PUBLIC` / `PRIVATE`）決定檔案能不能被直接用網址存取，任何「只有登入使用者才能看」的檔案（客戶文件、BOM圖…）一律要標記 `PRIVATE`，禁止沿用舊的固定 `/uploads/<key>` 網址。
  - 私有檔案下載一律透過 `issueFileDownloadUrl()` 現簽短效期網址，且授權判斷必須對「業務實體」做（例如經銷商是否有權限看這筆 `CustomerDocument`），不能只檢查「使用者有登入」。
  - 完整設計決策、現況與待辦見 [`docs/file-access-control-architecture.md`](./docs/file-access-control-architecture.md)，開發前務必先讀，避免重工或做出跟既有規則衝突的設計。

- **Git 提交規範**：
  - 執行 commit 時，必須遵循 Conventional Commits 規範（例如：`feat:`, `fix:`, `docs:`, `style:`, `refactor:`）。

## 5. 部署規範 (Deployment)
- 本專案使用 Docker 進行單一容器化打包（前後端打包在同一個 Image 中）。
- 部署目標平台為 **GCP Cloud Run**。
- 撰寫 Dockerfile 時，必須確保容器監聽隨機分配的 `$PORT` 環境變數。
- 所有環境差異（API 金鑰、資料庫連線字串、是否封鎖爬蟲）一律透過 runtime 環境變數注入。
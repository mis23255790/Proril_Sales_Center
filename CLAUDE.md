# 專案名稱：PRORIL 業務中心 (Sales Center) 2.0

## 1. 專案架構 (Architecture)
本專案是 PRORIL 1.0 (.NET MVC) 業務模組往 2.0 遷移的目的地，**前後端都在這裡**：
- `app/`: Nuxt 4 前端（頁面、元件、composables、型別、utils）。
- `api/`: .NET 8 後端（`Proril.SalesIssue.Api`，EF Core 8 + SQL Server）。
  端點名稱與回傳信封與 1.0 一字不差，前端切換只要改 `NUXT_PUBLIC_API_BASE` 一行。
  **搬了什麼、沒搬什麼、與 1.0 的行為差異一律看 [`api/README.md`](./api/README.md)。**
- `server/api/proxy/[...path].ts`: 轉發層，把 `/api/proxy/**` 轉到 `NUXT_PUBLIC_API_BASE`
  （可以是 `api/`，也可以是 1.0 站台，搬移期間兩者都能用）。
- `server/api/download.get.ts`: 附件下載中繼，把後端根目錄下的 `/ShareRoot/**` 拉回同源。
- `database/`: schema 版控（DACPAC）與資料正確性檢查。
- 1.0 原始碼在 `D:\Projects\Source\Proril\PRORIL`（唯讀參考）。已搬過來的模組請改 `api/`，
  還沒搬的才回 1.0 改。

> `api/` 與 1.0 打**同一個** `PRORIL_WEB`，可以並存。
> `api/appsettings` 的 `JwtSettings` / `Security:AesKey` / `Storage:ShareRoot`
> **必須與 1.0 相同**，分別對應 token 互通、密碼驗證、讀得到既有附件。
> 三者任一不同的症狀都不會直說原因（全 401 / 密碼永遠錯 / 附件讀不到）。

> **不要動資料庫**，包含 View / StoredProcedure。
>
> 例外：`database/` 是業務議題資料表的 **schema 版控**（DACPAC），
> 只管結構、不碰任何資料列，也不納管 View / StoredProcedure。
> 它管的是 1.0 `PRORIL_WEB` 的表；執行時前端仍然只走 API，不直連 DB。
> **main branch 的 `database/Tables/*.sql` == 正式區 schema**，未上線欄位放 feature branch。
> 詳見 `database/README.md`。

## 2. 技術棧 (Tech Stack)
- 核心框架：Nuxt 4 (Stable)
- 包管理器：npm
- 樣式系統：Tailwind CSS v4 (全面改用原生 CSS 巢狀語法)
- UI 元件庫：Nuxt UI v4 (基於 Tailwind v4 生態)
- 程式語言：TypeScript（前端）／C# 12（後端）
- 爬蟲管理：@nuxtjs/robots
- 後端：ASP.NET Core 8 + EF Core 8（database-first，**不要用 EF Migrations**，schema 走 `database/` 的 DACPAC）

## 3. 常用開發指令 (Crucial Commands)

前端：
- 安裝套件: `npm install <package>` 或 `npm install -D <package>`
- 啟動本地開發伺服器: `npm run dev`
- 專案打包建置: `npm run build`
- 型別檢查: `npm run typecheck`
- 程式碼檢查: `npm run lint`

後端（`api/`）：
- 啟動: `dotnet run --project api/Proril.SalesIssue.Api.csproj --urls http://localhost:5211`
- 建置: `dotnet build api/Proril.SalesIssue.Api.csproj`
- 設定: `cp api/appsettings.Development.json.example api/appsettings.Development.json` 後填連線字串

> 注意：工具鏈需要 **Node.js 22 以上**（`nuxt build` 會用到 `Set.prototype.difference`，
> eslint flat config 會用到 `Object.groupBy`）。Node 20 只跑得動 `npm run typecheck`。

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
- **Try/Catch**： 盡可能有Try/catch包住每一段程式，在catch把原因顯示在Console與log到實體檔案
- **`api/Controllers` 禁止放一堆檔案在同一層**：新增 Controller 一律依模組/用途分子目錄，
  不要直接丟在 `api/Controllers/` 底下。目前的分法：
  - `api/Controllers/{模組名}/`：只給該模組用的 Controller（例如 `SalesIssue/` 底下的
    `WorkProcessApiController` 系列）。namespace 對齊資料夾，寫成
    `Proril.SalesIssue.Api.Controllers.{模組名}`。
  - `api/Controllers/Shared/`：跨模組共用的 Controller（登入、客戶查詢、檔案上傳等），
    namespace 是 `Proril.SalesIssue.Api.Controllers.Shared`。
  之後每加一個新模組（例如銷貨檢索的後端），比照 `SalesIssue/` 這樣開新子目錄，
  不要把新 Controller 加進既有模組的資料夾，也不要全部塞回 `Controllers/` 根目錄。
- **`app/components` 同樣禁止全部放同一層**，依用途分子目錄：
  - `app/components/common/`：跨模組共用元件（`AppLogo`、`ConfirmDialog`、
    `FullPageLoading`、`TablePaginationBar`、`NavCard`…）。
  - `app/components/{模組名}/`：只給該模組用的元件（例如 `sales-issue/` 底下的
    `IssueContentView`、`RichTextEditor`）。
  - `nuxt.config.ts` 已設 `components: [{ path: '~/components', pathPrefix: false }]`，
    元件標籤名只看檔名、不會因為資料夾改變（`common/AppLogo.vue` 還是 `<AppLogo>`，
    不會變成 `<CommonAppLogo>`），新增元件時不用管路徑會不會改到呼叫端的標籤名。
  - 只有單一模組在用的元件才歸進該模組資料夾；哪天第二個模組也要用，再搬進 `common/`。

### 核心設計原則：
- **語系**：本專案是**內部後台，只有繁體中文**，目前沒有裝 `@nuxtjs/i18n`，
  文字直接寫在 template 即可。若哪天要支援多語，再整批抽語系檔。
  （官網專案 PRORIL Official 才需要嚴格 i18n，兩邊規範不同。）

- **各功能詳細邏輯**：
  - `docs/modules/` 下面是各功能的詳細邏輯，**動到哪個模組就先讀它的文件**。
    - `SalesIssue/logic.md` — 業務議題：資料表關聯、關鍵字三串對齊規則、
      客戶別的兩個來源、附件 zip 流程、哪些查詢條件其實沒送到後端
    - `SalesIssue/update.md` — 業務議題更新紀錄
  - 改完邏輯請順手更新對應的 md。

- **後端字串常帶尾端空白**：ERP／舊系統同步進來的字串常帶**尾端空白**，
  前端做比對（客戶編號、SNo…）一定要兩邊都 `trim()`。這是反覆出現的 bug 來源。

- **行動優先與 RWD 響應式設計**：
  - 必須嚴格遵循 Tailwind CSS 的 Mobile-First 規範。
  - 預設樣式為手機版，並善用 `md:` (768px+) 與 `lg:` (1024px+) 的斷點。

- **爬蟲控制**：
  - 這是內部系統，不需要做 SEO；`useSeoMeta` 只用來設瀏覽器分頁標題。
  - **環境隔離防呆**：非正式環境（如 Staging/測試站）必須透過環境變數 `NUXT_PUBLIC_BLOCK_ROBOTS=true` 封鎖 Google 爬蟲索引。

- **品牌色彩系統**（取自 LOGO 實際取樣）：
  - 深海軍藍 `#002237`（LOGO 文字色）→ Tailwind token `navy-50 ~ navy-950`（900 = 原色）
  - 品牌橘 `#e26a23`（LOGO 斜紋色）→ Tailwind token `brand-50 ~ brand-900`（500 = 原色）
  - 定義位置：`app/assets/css/main.css` 的 `@theme` 區塊；
    Nuxt UI 的語意色在 `app/app.config.ts`（`primary: brand` / `neutral: navy`）。
  - **禁止建立 `tailwind.config.js`**。本專案使用 Tailwind v4，任何主題或斷點自訂必須嚴格寫在 CSS 的 `@theme` 區塊中。

- **API 回傳格式（沿用 1.0，不要改）**：
  - 所有 API 都是 1.0 .NET 的 `CustomApiViewModel` 信封：
    `{ isSuccess: boolean, message: string | null, body: any, body2: any }`
    （型別在 `app/types/api.ts`）。
  - **`isSuccess: false` 不一定是錯誤**：查無資料時後端也回 false + 說明訊息，
    這種情況要當成空清單處理，不要跳 error toast。

- **檔案上傳 / 下載**：
  - 上傳走 1.0 的 `UploadApi/SaveByFileName`（單檔）或 `UploadApi/SaveZipFile`（打包）。
  - 下載不要直接連 .NET 站台（跨網域），一律經 `server/api/download.get.ts`，
    它只接受 `/ShareRoot/` 開頭的路徑，避免變成開放轉址。

- **Git 提交規範**：
  - 執行 commit 時，必須遵循 Conventional Commits 規範（例如：`feat:`, `fix:`, `docs:`, `style:`, `refactor:`）。

## 5. 部署規範 (Deployment)
- 本專案使用 Docker 進行單一容器化打包。
- 撰寫 Dockerfile 時，必須確保容器監聽隨機分配的 `$PORT` 環境變數。
- 所有環境差異（後端 API 位址、是否封鎖爬蟲）一律透過 runtime 環境變數注入：
  `NUXT_PUBLIC_API_BASE`、`NUXT_PUBLIC_BLOCK_ROBOTS`、`NUXT_PUBLIC_DEV_TOKEN`（僅開發用）。

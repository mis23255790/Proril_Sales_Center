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
- 1.0 原始碼在 `D:\Projects\Source\Proril\PRORIL`。已搬過來的模組請改 `api/`；
  還沒搬的模組，一律先把邏輯從 1.0 搬過來 `Proril_Sales_Center`（`api/` 對應模組資料夾）
  再繼續開發，不要留在 1.0 那邊直接改。

> `api/` 與 1.0 打**同一個** `PRORIL_WEB`，可以並存。
> `api/appsettings` 的 `JwtSettings` / `Security:AesKey` / `Storage:ShareRoot`
> **必須與 1.0 相同**，分別對應 token 互通、密碼驗證、讀得到既有附件。
> 三者任一不同的症狀都不會直說原因（全 401 / 密碼永遠錯 / 附件讀不到）。

> **不要動 1.0 的資料庫**，包含 View / StoredProcedure。
>
> 例外：`database/` 是業務議題資料表的 **schema 版控**（DACPAC），
> 只管結構、不碰任何資料列，也不納管 View / StoredProcedure。
> 它管的是 1.0 `PRORIL_WEB` 的表；執行時前端仍然只走 API，不直連 DB。
> **main branch 的 `database/Tables/*.sql` == 正式區 schema**，未上線欄位放 feature branch。
> 詳見 `database/README.md`。

> **獨立資料庫 `Proril_Sales_Center`：業務議題本體 + `CRM_Customer` + `H_FileLink` + 權限控管已切連線，其餘仍是快照**：
> `database/PortingNotes.md` 記錄了把 18 張表（業務議題白名單 8 張 + `M_User` /
> `M_Permission` / `H_FileLink` / `COP_CheckRule` / `COP_DepData` 5 張 + 訂單資料檢核
> SP 寫入目標 5 張）從 `PRORIL_WEB` **一次性複製**到獨立資料庫 `Proril_Sales_Center`。
> `api/` 同時注入 `ProrilWebDbContext`（連 `ConnectionStrings:ProrilWeb`）與
> `SalesCenterDbContext`（連 `ConnectionStrings:SalesCenter`），兩者都在
> `BaseApiController` 注入，子類別直接用 `db` / `scDb`：
> `WorkProcessApiController`（含 `.Attach.cs`/`.Permission.cs`）、
> `CustomQueryApiController.SaveCustom`、`UploadApiController.AddFileLog`、
> `MainApiController`（含 `.User.cs`/`.SystemSetting.cs`）、`CommonApiController`
> 已改讀寫 `SalesCenterDbContext`，這幾張表**已經是真的切連線，不再只是快照**；
> 其餘表（`COP_*`、`M_PermissionLinkType`、`M_Department`）維持只在 `PRORIL_WEB` 有效，
> 兩邊之後不會自動同步。
>
> **下列表在 1.0 有業務議題／訂單資料檢核以外的其他功能在寫，不能只切連線就當作遷移完成**
> （已用 grep 逐一核對 1.0 全部 Controller，非只查已知模組）：
> - `M_Department`（部門／群組主檔）—— `Controllers/System/OrgApiController.cs`
>   （組織維護）在寫。
>
> 它在 `api/` 維持**唯讀**（打 `ProrilWebDbContext`），**新增功能一律不要對它加寫入邏輯**。
> （`M_PermissionLinkType` 原本也在這一類——1.0 `FileQueryApiController` 會 `Add`——
> 但 `FunctionNo` 改格式之後跨庫對不起來，2026-09-14 已被迫一起搬進新庫，
> 代價是 1.0 之後新增的細項不會自動同步，見 `database/PortingNotes.md`。）

> **`FunctionNo` 是 `varchar(8)` 的 `AAABBCC` 格式**（AAA=SystemNo、BB=GroupNo、
> CC=序號，各自補零），例如議題維護是 `0070102`、銷貨檢索是 `0320101`。
> **只有 `Proril_Sales_Center` 是這個格式，`PRORIL_WEB`（1.0 在用）仍是 int 流水號，
> 兩邊永久分岔** —— `publish.ps1` / `drift.ps1` 對快照庫一定會報
> `M_Function`／`M_Permission`／`M_PermissionGroup`／`M_PermissionLinkType`／
> `H_FileLink` 這幾個欄位的差異，**那是預期的，不要套用回去**。
> 常數在 `api/Models/Enums.cs` 的 `FunctionIds` 與 `useAppNavigation.ts` 的 `NAV_MODULES`，
> 新增功能時**兩邊都要加**，再改 `PermissionMasterSeed.sql` 的對照表。
> 完整對照與腳本見 `database/FunctionNoFormatMigration.sql`。

> **2.0 的登入只走 SSO**，`Proril_Sales_Center.M_User.Password` 已全部清成 `NULL`
> （2026-09-14，備份在 `M_User_bak_Password`）。`LoginSso` 不看密碼，
> `MainApi/Login`（帳密登入）端點還在但前端沒有任何地方呼叫。
> 但 `AddUser` / `ResetPassword` 仍會寫 `AES(帳號)` 當密碼——**這個不一致還沒處理**，
> 新建的帳號會是唯一有密碼的那個。
>
> `M_System`／`M_Function`（功能主檔）已切到 `SalesCenterDbContext`，但 `api/` 仍**只讀不寫**
> （應用層本來就沒有寫入路徑，直接維護在 DB）。關鍵是新庫**只保留 2.0 真的有頁面的
> 3 個系統別 + 8 個功能**，不是整份複製——否則權限樹會長出一堆點下去 404 的功能。
> 資料由 `database/PermissionMasterSeed.sql` 維護（`copy-snapshot-data.ps1` 會跳過這兩張，
> 也不要靠 `publish.ps1` 建表）。
> （原本這裡還有一條「DACPAC 的 `M_Function` 是 `varchar`、中文會變 `?`」——
> 2026-09-14 把資料庫定序對齊成 `Chinese_Taiwan_Stroke_BIN` 之後，`varchar` 存得下中文，
> 這個限制已經不存在。）
> **要讓新功能出現在權限樹，得先在 `NAV_MODULES` 加路由，再改那支腳本的 `@FunctionNos`。**
>
> **權限控管已完成搬遷（2026-09-14）**：`M_User`／`M_Permission`／`M_PermissionGroup`
> 已連同 1.0 的人員管理（`MainApiController`）與權限管理
> （`MainApiController_SystemSetting`）邏輯一起搬進
> `api/Controllers/Shared/MainApiController.User.cs` / `.SystemSetting.cs` /
> `CommonApiController.cs`，改打 `SalesCenterDbContext` 讀寫。
> **代價是 1.0 的人員管理／權限管理必須停用**——兩邊各改各的一定分岔。
> 還沒搬的是「登入失敗自動鎖定」（要連 `H_Logins` 一起搬，屬登入流程），
> 所以 1.0 鎖的是舊庫、2.0 讀的是新庫，鎖定狀態不互通；2.0 補了
> `MainApi/UnlockUser` 讓人員管理解得開鎖。
> 資料庫端還有人工步驟沒跑（`publish.ps1` 建 `M_PermissionGroup`、
> `copy-snapshot-data.ps1` 重灌帳號權限資料），見 `database/PortingNotes.md`
> 「權限控管搬遷（第二輪）」與 `docs/modules/SystemSetting/logic.md`。
>
> 已核對「單一擁有者、之後可以放心切」且**已完成切連線**的表：業務議題 7 張（不含
> `CRM_Customer`，只有 `WorkProcessApiController.cs`）、`CRM_Customer`（只有
> `CustomQueryApiController.SaveCustom`；`WorkProcessApiController` 讀它組客戶顯示欄位，
> 一併改讀 `SalesCenterDbContext`）、`H_FileLink`（只有 `UploadApiController` 內的
> `AddFileLog`）、權限控管 3 張（`M_User`／`M_Permission`／`M_PermissionGroup`）。
> `COP_PoCheck`/`COP_PoDetailCheck`/`COP_PassCheck`/
> `COP_AvailableAmt`/`COP_ProductCheck` 應用層完全沒有直寫，只有預存程序
> （`prc_COPOrderChk`/`prc_COPPassCheck`/`prc_ProductChk`）在寫，但呼叫入口分散在
> `ErpImportApiController.cs`／`BomQueryApiController.cs`／`OrderInfoVerifyApiController.cs`
> 三支 controller，之後切連線要三支都一併確認能連到新 DB 執行對應 SP，**這幾張還沒切**。
> 資料庫物件本身（7 View / 5 SP / 1 函式 / 5 表）**2026-09-14 已在測試區的
> `Proril_Sales_Center` 建好**（`database/OrderCheckObjectsMigration.sql`，
> 7 個 View 的筆數與舊庫一致，代表 ERP linked server 在新庫可用）；
> **但 `api/` 還沒切**，`OrderInfoVerifyApiController` 仍打 `ProrilWebDbContext`。
> `COP_CheckRule`/`COP_DepData` 應用層目前完全查不到任何寫入路徑（含維護畫面），
> 可能是直接維護在 DB，遷移時沒有既有 CRUD 邏輯可搬，**同樣還沒切**。
> `COP_SalesOrder`（銷貨檢索的 ERP 銷貨單快取）是 2026-09-14 新收進 DACPAC 的第 21 張，
> 寫入者只有預存程序 `prc_ImportSalesOrder`（由 `prc_QuerySalesOrder(_1)` 呼叫，
> 所以**銷貨檢索的「查詢」其實會寫資料**），但 `V_SalesTotal` 也在讀它、
> 而那支 View 對應的 `MixSalesShipApi/GetSalesTotal` 還沒搬，**不算單一擁有者，還沒切**。
> 表 + 3 支 SP 的搬移腳本是 `database/SalesShippingObjectsMigration.sql`，
> **測試區已執行完成**（走 `database/scripts/run-objects-migration.ps1`），正式區還沒建庫。

> **`Proril_Sales_Center` 的定序必須是 `Chinese_Taiwan_Stroke_BIN`**（與 `PRORIL_WEB` 相同）。
> 測試區那份原本是建庫時沿用 instance 預設的 `SQL_Latin1_General_CP1_CI_AS`，
> 2026-09-14 已用 `database/scripts/fix-collation.ps1` 對齊（142 個欄位）。
> 不一致的後果不只是「中文變問號」，**排序與比對語意會變**——實際踩到的是銷貨檢索的
> 預存程序在兩個庫回傳不同的分群統計筆數。**之後在正式區建這個資料庫時，
> `CREATE DATABASE` 就要直接指定定序**，不要事後再修。詳見
> `database/PortingNotes.md`「定序已對齊」與 `database/README.md`「定序（collation）」。

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
- 啟動: `dotnet run --project api/Proril.SalesIssue.Api.csproj`
- 開發時建議改用 watch，存檔自動重建重啟：
  `dotnet watch run --project api/Proril.SalesIssue.Api.csproj --no-hot-reload`
- 建置: `dotnet build api/Proril.SalesIssue.Api.csproj`
- 設定: `cp api/appsettings.Development.json.example api/appsettings.Development.json` 後填連線字串

> 環境與 port 由 `api/Properties/launchSettings.json` 帶（`ASPNETCORE_ENVIRONMENT=Development`
> + `http://localhost:5211`），所以上面的指令**不用**再自己加 `--urls` 或設環境變數。
> 少了它會踩到：`api/appsettings.json` 的連線字串是空的（實際值在
> `appsettings.Development.json`，那份沒進版控），非 Development 啟動會被 `Program.cs`
> 的設定檢查直接擋下來、根本起不來。
>
> **`--no-hot-reload` 不是可有可無**：改 EF 對映／`DbContext`／`Program.cs`／新增 Controller
> 這幾類變更 Hot Reload 套不上去，`dotnet watch` 只會停下來問要不要重啟，很容易按過去
> 卻以為已經生效。實際踩過：`M_System`/`M_Function` 換 DbContext 之後後端沒重啟，
> 畫面一直讀到舊庫的資料，查了一輪才發現是進程沒換。
>
> 同理，**`npm run dev` 只重載 Nuxt 前端，不會重啟 `api/`**，兩者是不同的進程。

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
- **Try/Catch（後端 API Action 不用再手寫）**：`api/` 的例外處理與進入點 log 已經是全域機制，
  新增/修改 Controller Action **不用**自己包 try/catch，也不用手動印 log：
  - 例外：`api/Filters/ApiExceptionFilter.cs`（在 `Program.cs` 註冊為全域 MVC filter），
    未捕捉的例外會統一被攔截、寫 log，並轉成該 Action 宣告的回傳型別
    （`CustomApiViewModel` 或 `LoginModel` 皆可，靠 reflection 塞 `Message` 屬性），
    前端拿到的錯誤回傳格式不變。
  - Log：`api/Middleware/RequestLoggingMiddleware.cs`（掛在 `UseRouting()` 之前），
    每個進來的 request 自動記錄方法/路徑/狀態碼，不用在 Action 裡加任何呼叫碼。
  - 例外情況（這兩支不算「boilerplate」，仍保留各自的 try/catch，不要拿掉）：
    - `BaseApiController` 的 `GetAccountByToken` / `GetUserNameByToken` / `IsAdmin`：
      token 解析失敗時刻意當「匿名／非管理員」處理並繼續往下走，不是單純記錄後 rethrow。
    - `UploadApiController.AddFileLog`：檔案已經存檔成功，只是記錄 `H_FileLink` 失敗，
      要讓呼叫端知道「上傳成功但記錄失敗」這種部分失敗語意，不能被全域 filter 蓋掉。
  - 前端（Nuxt/Vue）目前沒有對應機制，該包還是要包，這條只適用後端 `api/`。
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
    - `SystemSetting/logic.md` — 權限控管（人員管理／權限管理）：權限的資料模型、
      權限樹規則、群組預設功能、側欄如何依權限過濾、哪幾張表在哪個庫
    - `SystemSetting/update.md` — 權限控管更新紀錄
  - 改完邏輯請順手更新對應的 md。

- **表格整列可點擊（有編輯／明細畫面的 table 一律照做）**：
  只要 `UTable` 對應得到編輯（或明細）畫面，就必須：
  1. `:ui="{ tr: clickableRowTr, ... }"`（`app/utils/table.ts`，Nuxt 自動 import），
     hover 時整列變色、**列內文字加底線**、游標變手指；
  2. `@select="(_e: Event, row: any) => openXxx(row.original)"`，點列上任一處就進編輯畫面；
  3. `actions` 欄的按鈕包一層 `<div @click.stop>`，避免點按鈕時觸發兩次。
  只有「純檢視、沒有編輯畫面」的 table 才不掛。

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

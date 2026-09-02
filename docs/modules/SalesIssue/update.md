<details>
  <summary>版號2026.09.02.1700</summary>

##### refactor: 每一層都有自己的頁面，改成逐層下鑽（比照 1.0）
      原本 /sales-center 是把所有功能攤平列出來（議題維護、類別維護、銷貨檢索三張卡），
      跟 1.0 的層級不一致。改成：
          /sales-center            只列模組：業務議題、業務檢索
          /sales-center/{module}   列該模組底下的功能，依群組分段
          /sales-center/{module}/{func}   實際作業畫面

      新增：
        app/pages/sales-center/[module]/index.vue  模組首頁，**一支動態頁共用**
        app/components/NavCard.vue                 導覽卡片，首頁與模組首頁共用外觀
      調整：
        app/pages/sales-center/index.vue  改列模組（含 labelEn 與功能數量）
        useAppNavigation: 加 findModuleBySlug() / countItems() / breadcrumbForModule()
        功能頁麵包屑的「模組」那一層現在會連到模組首頁，可以退一層
        側欄的模組名稱也可以點（進模組首頁），展開仍然看得到底下功能

      新增模組只要在 NAV_MODULES 加一筆設定，不用開新頁面檔。
      某個模組要客製首頁就在 app/pages/sales-center/<模組>/index.vue 放靜態頁，
      Nuxt 靜態路由優先會自動蓋過動態頁。

      驗證：typecheck 通過；/sales-center/sales-issue 與 /sales-center/sales-search
            都 200、不存在的模組 404；瀏覽器實地走完
            首頁 → 業務議題(2 項) → 議題維護、首頁 → 業務檢索(1 項) → 銷貨檢索，
            麵包屑三層皆正確且中間層 href = /sales-center/sales-search。

##### refactor: 網址多一層，改成 業務中心/模組/功能
      比照 1.0 的層級，所有頁面前面加一段 /sales-center：
          /sales-center                                   業務中心首頁
          /sales-center/sales-issue/issues                議題維護
          /sales-center/sales-issue/issues/new            新增議題
          /sales-center/sales-issue/issues/{wpno}         議題編輯
          /sales-center/sales-issue/kind-maintain         類別維護
          /sales-center/sales-search/shipping-inquiry     銷貨檢索
      /  改成 redirect 到 /sales-center，直接開站台根目錄不會 404。

      作法：頁面檔案整批移到 app/pages/sales-center/ 底下，
      再把根層級抽成 useAppNavigation.ts 的 APP_BASE 常數。
      **功能表只存相對路徑**（'sales-issue/issues'），完整路徑一律由
      appPath() / itemPath() / modulePath() 組出來 ——
      這樣以後要再改根路徑只需要動一個地方，不用全域搜尋替換。

      唯一寫死的例外是 app/pages/index.vue 的 redirect：
      definePageMeta 是編譯期巨集，讀不到 APP_BASE 的值。已在該檔與 logic.md 註明。

      連帶調整：
        - layouts/default.vue 的 activeModuleSlug 從 split('/')[1] 改成 [2]
          （第 1 段現在固定是 sales-center）
        - 麵包屑第一層從「首頁 → /」改成「業務中心 → /sales-center」
        - app/pages/[module]/[func].vue 佔位頁一起移到 sales-center/ 底下

      舊網址（/sales-issue/...）**沒有做轉址**，直接 404。
      這批網址只上線一天，判斷不值得為它留轉址規則；如果有人已經加了書籤再補。

      驗證：typecheck 通過；6 條網址實測（/ 與 /sales-center 都 200、
            三個功能頁 200、舊網址 404）；瀏覽器實地確認麵包屑、側欄、
            首頁卡片連結、列表點擊進入編輯頁的網址都是新結構。
</details>

<details>
  <summary>版號2026.09.02.1600</summary>

##### feat(api): 後端搬到 api/ — Proril.SalesIssue.Api (.NET 8)
      決策(三個都由使用者確認):
        1. DbContext 只搬 10 張表, 不整包搬 1.0 的 13,782 行 / 347 個 DbSet。
           邊界對齊 database/TABLES.txt 白名單, 另加 H_FileLink(上傳 log)
           與 V_ERPCustomer(唯讀 View, 客戶清單要 join ERP 名稱), 共 12 個。
        2. 專案放在 Proril_Sales_Center/api/(同 repo), 不另開 repo。
           前端型別、schema 版控、後端在同一次 commit 對得起來。
        3. 周邊 API 一起搬(UploadApi/CustomQueryApi/MainApi), 新站不再依賴 1.0。

      端點名稱、參數大小寫、回傳信封都與 1.0 一字不差, 前端把
      NUXT_PUBLIC_API_BASE 指過來就能跑, 不必改任何一行。

      新增: api/{Proril.SalesIssue.Api.csproj, Program.cs, appsettings*.json, README.md}
            api/Data/{Entities.cs, SalesIssueDbContext.cs}
            api/Models/{ApiModels.cs, Enums.cs}
            api/Helpers/{JwtHelper.cs, AesHelper.cs, StoragePaths.cs}
            api/Controllers/{BaseApiController, WorkProcessApiController(+.Attach/.Permission),
                             MainApiController, UploadApiController, CustomQueryApiController}.cs
      設定: connection string 在 appsettings(ConnectionStrings:ProrilWeb)。
            appsettings.Development.json 已進 .gitignore, 另附 .example。
            JwtSettings / Security:AesKey / Storage:ShareRoot **必須與 1.0 相同** ——
            分別對應 token 互通、密碼驗證、讀得到既有附件。

      與 1.0 的行為差異(刻意修的, 不是漏搬, 完整清單見 api/README.md):
      a. **議題不再無故從列表消失**。1.0 getSOPList() 對 M_User 用兩個 inner join
         (Creator, 以及「最新一則進度的 Modifier」), 只要接不到整張議題就無聲消失。
         最嚴重的是「一則進度都沒有」的議題 —— FirstOrDefault() 是 null, 配不到任何帳號,
         也就是**剛建好還沒寫進度的議題根本看不到**。改成左外接。
         實測(同一份資料, 63 筆議題): 1.0 回 52 筆, 2.0 回 58 筆,
         多出來的 6 筆 lastModiTime 全是 null, 完全符合預測。
      b. 附件目錄中間層統一用 wpNo 算(1.0 有一半用 sNo)。
      c. SetWPOrderPhrase / SetWPOrderCustom 接受空清單 = 清空
         (1.0 空字串直接回錯, 所以把客戶改回「未指定」是存不進去的)。
      d. GetEditorText 會幫 SNo 補零(1.0 這支沒補)。
      e. 加了路徑穿越防護、關閉 /ShareRoot 目錄瀏覽、重壓 zip 失敗保留舊檔、
         登入不再區分「帳號不存在」與「密碼錯誤」。

##### fix: 前端兩個在移植過程中發現的 bug
      a. **grantAllUsersEdit 送錯格式**。後端 strAccountList 是用
         JsonConvert.DeserializeObject<List<string>> 解的, 必須送 JSON 陣列字串。
         前端送 '000000' 會在後端丟例外回 isSuccess:false, 而前端不看這個結果 ——
         症狀是「存檔成功但列表看不到」(權限列沒寫進去)。已改 JSON.stringify(['000000'])。
      b. **prepareTemp 的 extSubPath 傳空字串**。它決定 zip 解到
         Doc_SOP/{dcu}/{extSubPath}, 但 EnumTempUploadAttach / ZipAttachFileList /
         UpdateDBAttachFile 都去 Doc_SOP/{dcu}/{sNo} 找。傳空字串的話既有附件解到上一層,
         重壓時後端回「原始檔案不存在」—— 編輯一則有附件的進度再加新檔, 舊附件全部消失。
         已改成傳 sNo(與 1.0 的 unzipAttachFileList_Edit 一致)。

##### chore: JwtHelper 的 claim map
      1.0 是在 Program.cs 清全域 JwtSecurityTokenHandler.DefaultInboundClaimTypeMap。
      漏了這步的話 sub 會被映射成 ClaimTypes.NameIdentifier, 找不到名為 "sub" 的 claim,
      GetAccountByToken 一路回空字串 —— API 全部會通, 但 Creator/Modifier 全存成空的。
      這裡改成只清該 handler 的 InboundClaimTypeMap, 不動全域狀態, 並加 NameIdentifier fallback。

      驗證: dotnet build 0 警告 0 錯誤; 前端 typecheck 通過;
            /health 200; 未帶 token 401; **帶 1.0 簽發的 token 直接通過**(證明 JwtSettings 相容);
            對真實資料庫(唯讀)實測 9 支端點, GetSOPOrder/GetSOPDetail/GetEditorText/
            GetKindList/GetWPOrderPhrase/GetWPOrderCustom/GetCustom/GetCurrentUser/
            GetSOPListAll 全部回正確筆數。
      未驗證: 所有寫入端點(SaveOrder/SaveDetail/附件 zip 流程)沒有實際執行過 ——
            不在唯讀範圍內, 需要人工在測試區跑一輪。
</details>

<details>
  <summary>版號2026.09.02.1500</summary>

##### chore(db): 新增 database/checks/ — 資料正確性檢查 (SQL 斷言 + runner)
      定位: database/ 原本只管 schema(結構), 這組管「結構對了但資料是壞的」。
      純讀取, 不寫任何東西。刻意不引 dbt / Great Expectations / tSQLt ——
      檢查全部是單純 SQL, 那些工具要多養一套環境, 而且 tSQLt 強項是測 SP 行為,
      跟「不動 SP」的規範衝突。

      新增檔案:
          database/checks/01_format.sql       WPNo/SNo 補零、尾端空白、aStatus 值域
          database/checks/02_referential.sql  孤兒列、指到失效資料的參照、重複鍵
          database/checks/03_consistency.sql  資料合法但畫面會出錯的情況
          database/checks/README.md           契約、基線流程、T-SQL 陷阱
          database/scripts/check.ps1          runner, 沿用 _common.ps1

      契約: 每個 .sql 回一個 result set, 固定四欄 chk/severity/ident/detail,
            回 0 列代表通過。(chk, ident) 是基線比對的 key。

      03_consistency 是價值最高的一組, 它把一個**既有的隱性 bug**變成可檢測:
      `getSOPList()` 對 M_User 用了兩個 **inner join**(沒有 DefaultIfEmpty):
          join user        in musers_list on wp.Creator equals user.Account
          join modify_user in musers_list on wpdetails?.FirstOrDefault()?.Modifier
                                            equals modify_user.Account
      所以下面任一條成立, 整張議題就會從列表無聲消失:
          a. Creator 不在 M_User (離職刪帳號 / Creator 帶尾端空白)
          b. 最新一筆進度的 Modifier 不在 M_User
          c. **這張議題一筆有效進度都沒有** —— FirstOrDefault() 回 null,
             null 配不到任何 Account
      (c) 影響「新增議題」流程: 剛存好還沒寫第一則進度的議題就是這個狀態。
      而且這些 join 在 .ToList() 之後做(LINQ to Objects), `equals` 不像 SQL
      會忽略尾端空白 —— 這也是 01_format 要抓空白的原因。

      使用流程(老系統一定有歷史髒資料, 順序不能顛倒):
          1. check.ps1 -Environment prod -Sample 20   先看過內容
          2. check.ps1 -Environment prod -UpdateBaseline  現況寫進 baseline.tsv
          3. baseline.tsv 進版控 -> 有人讓它變長會在 code review 看到
          4. 之後 -FailOnError 只對「不在基線裡的 ERROR」失敗, 可掛 CI
      沒有基線就直接看幾百筆違規, 結果一定是放棄看它。

      T-SQL 陷阱(寫在 checks/README.md, 這次踩到的):
          `=` / `<>` 會忽略尾端空白 —— 'abc ' = 'abc' 是 TRUE。
          所以 `col <> LTRIM(RTRIM(col))` **永遠抓不到**尾端空白,
          要用 DATALENGTH 比長度。
          .sql 必須存成 UTF-8 **不帶 BOM**(runner 用 sqlcmd -f 65001 讀);
          .ps1 反過來必須 UTF-8 **with BOM**, 否則 PowerShell 5.1 用 CP950 讀成亂碼。

      下一步(還沒做): 跑到 0 違規後, 用 FOREIGN KEY ... WITH NOCHECK 把規則固化,
      只擋新寫入、不驗既有資料。先決條件: D_WorkProcess 的 PK 是 ID 不是 WPNo,
      要先在 WPNo 加 UNIQUE 才建得了 FK。這步會動 schema, 要走 DACPAC 流程。

      待辦: 尚未實際對資料庫執行(需要 DB 憑證)。
            語法已驗(PSParser 964 tokens 無誤), 無 .env 時會有清楚的錯誤訊息。
</details>

<details>
  <summary>版號2026.09.02.1400</summary>

##### fix: 議題列表長標題溢出, 蓋掉右邊的欄位
      現象: 主題較長的議題(例如「Paul - Mighty Pumps詢價Stormy Pro 6370/8370+
      著托+SHD屏蔽電纜...」)整行不換行地衝出去, 把客戶別/類別整欄蓋掉。
      原因: Nuxt UI 的 UTable 預設在 `td` 掛 `whitespace-nowrap`。
      我原本只在儲存格「內層 div」加 max-w, 對 td 完全沒有約束力。
      作法(**兩件事要一起做, 少一件都沒用**):
          1. UTable `:ui.td` 覆寫成 `whitespace-normal`, 讓它可以換行
          2. 每欄用 `meta.class.td/th` 給 max-w —— 否則 table-layout: auto
             會讓內容自己決定寬度, 就算允許換行也不會換
      內層再配 line-clamp (主題 2 行 / 最新進度 3 行) + break-words + title 屬性,
      避免某一列高到誇張, 滑鼠移上去仍看得到完整文字。
      驗證: 該列 td 260px、<p> scrollWidth == clientWidth (無溢出)、
            表格總寬 985px 落在容器內。
</details>

<details>
  <summary>版號2026.09.02.1300</summary>

##### fix: 編輯進度時內容顯示 [object Object]
      現象: 進度時間軸上內文正常, 但按編輯進去, 編輯器裡只有 "[object Object]"。
      原因: `GetEditorText` 名字叫 Text, 回的卻是**整個 DWorkProcessDetail 物件**
      (`ca.Body = qry[0]`), 不是內文字串。我把它當字串直接餵進編輯器。
      作法: `getDetailContent()` 的回傳型別改成 ApiResponse<SalesIssueDetail>,
      呼叫端取 `body.processContent`; 取不到才退回列表帶進來的 processContent。
      順手修: `GetEditorText` 是少數**沒有幫 SNo 補零**的 API
      (`o.Sno == SNo` 直接比), 其他像 GetSOPDetailWSNo / SaveDetail / DeleteSno
      內部都會 `$"{nSno:0000}"`。SNo 是 varchar(4), 呼叫端沒補到 4 碼就會
      「查無資料」。已在 getDetailContent 內補 padStart(4, '0') 並 trim。
</details>

<details>
  <summary>版號2026.09.02.1200</summary>

##### fix: 舊內文 line-height: 0.3 造成行與行疊在一起
      現象: 接上真實資料後, 進度時間軸的內文每一行疊在前一行上面, 完全看不懂。
      原因: **資料本身**帶著壞掉的行高, 不是 CSS 寫錯。從 Outlook/Word 貼進舊
      Summernote 的內容, 每個 <p> 與 <span> 都掛 style="line-height: 0.3"
      —— 16px 的字配 4.8px 行高。1.0 的 control-summer-note.css 有寫
      `.note-editable p { line-height: 1.2 }` 想蓋掉, 但 inline style 優先權比
      class selector 高, 蓋不動 (release-note 上好幾筆行高相關修正都在打這個)。
      作法: 新增 `fixLegacyLineHeight()` (app/utils/salesIssue.ts), 在渲染前把
      **明顯壞掉**的 line-height 宣告移除, 讓 .issue-content / .issue-editor-body
      的預設行高生效。判定: 無單位倍率 < 1, 或 px 值 < 12px。
      使用者用舊編輯器刻意設的 1.0 ~ 1.6 保留不動。
      套用在兩處 (兩邊必須一致, 否則編輯時看到的跟存完看到的不一樣):
          IssueContentView 的消毒流程
          RichTextEditor.setContent()
      副作用: 編輯器載入時也會清, 所以**開啟舊進度並重新儲存, 那一則的壞行高
      會被永久修正掉**。只影響有被編輯的那一則, 不會整批改寫。

##### feat: 進度收合時加漸層 + 「展開全文」
      原本 max-h-40 overflow-hidden 是硬切, 看不出來下面還有沒有內容。
      改成底部漸層遮罩 + 可點的「展開全文」, 跟標題列的展開鈕同一個 state。

##### chore: 後端位址設定
      新增 .env (已被 .gitignore 擋掉) 指向 https://intranet-dev.proril.com。
      nuxt.config.ts 的 fallback 從 'https://localhost:7000/api' 改成同一個位址:
      舊值是從製造中心複製過來的, 對 PRORIL 後端兩點都錯 ——
      host 不存在, 而且多了 /api (Program.cs 的路由是 {controller}/{action}/{id?},
      沒有 api 前綴)。
      驗證: proxy 從 502 Bad Gateway 變成 401, 帶 token 後 200 / 52 筆議題。
</details>

<details>
  <summary>版號2026.09.02.1100</summary>

##### chore(db): 新增 database/ — 業務議題資料表的 schema 版控 (DACPAC)
      解決的問題: 測試區 (,50002) 與正式區 (,51002) 都叫 PRORIL_WEB, 測試區長期領先,
      未上線欄位散在 DB 裡靠人工記憶同步; 從測試區 scaffold 會把別人做到一半的欄位一起吃進來。

      做法: 把白名單資料表的「結構」納入 git, 讓未上線欄位跟著 feature branch 走。
            main branch 的 database/Tables/*.sql == 正式區 schema。
            未上線 != 不進版控, 未上線 = 進版控但還沒 merge。

      納管範圍 (database/TABLES.txt, 只有結構不含資料列):
          D_WorkProcess / D_WorkProcessDetail / D_WorkProcessSearch
          D_WorkProcessCustomer / D_WorkProcessPermission
          M_WorkProcessPhrase / M_WorkProcessType / CRM_Customer
      不納管: View、StoredProcedure、白名單以外的 400+ 張表 (含鼎新 ERP)。

      新增檔案:
          database/Proril.SalesIssue.Database.sqlproj  Microsoft.Build.Sql 2.2.0 (SDK 樣式)
          database/TABLES.txt                          納管白名單, 各 script 共用
          database/scripts/_common.ps1                 .env 載入、連線字串解析、工具檢查
          database/scripts/extract.ps1                 從指定環境擷取 schema 進 Tables/
          database/scripts/drift.ps1                   比對測試區 vs 正式區, 列出未上線欄位
          database/scripts/deploy-report.ps1           部署預覽, 不修改任何東西
          database/scripts/publish.ps1                 實際部署, 預設 dry-run
          database/README.md, database/Tables/README.md, database/.env.example
          .gitignore 追加 database/{bin,obj,.tmp} 與 *.dacpac

      安全設定 (publish/deploy-report 固定帶, 不要拿掉):
          BlockOnPossibleDataLoss=true   會造成資料遺失的變更直接中止
          DropObjectsNotInSource=false   目標多出來的欄位不會被砍掉
          後者特別重要: 測試區長期領先 main, 設成 true 會清掉所有未上線欄位。
      publish 對 prod 另外要求互動輸入資料庫名稱確認。

      踩到的兩個雷:
          1. Microsoft.Build.Sql 1.0.0 與 .NET SDK 10 不相容 (import 的
             NuGet.Build.Tasks.Pack.targets 已移除), 必須用 2.2.0。
          2. .ps1 含中文必須存成 UTF-8 with BOM, 否則 Windows PowerShell 5.1
             會用 CP950 讀, 中文註解變亂碼直接打壞 parser。

      待辦: 尚未執行初始擷取 (需要 DB 憑證, 由人工帶憑證跑)。
            先 cp database/.env.example database/.env 填連線, 再跑
            scripts/extract.ps1 -Environment prod 建立基線。
            擷取後請核對 .sqlproj 的 <ModelCollation> 與 script 回報的實際定序是否一致。
</details>

<details>
  <summary>版號2026.09.02.1000</summary>

##### feat: 業務議題自 PRORIL 1.0 (WorkProcess) 搬到 2.0 業務中心, 並重做 UI/UX
      範圍: 只搬前端。後端沿用 1.0 的 WorkProcessApi, 不新增 API、不動資料庫
      (含 View / StoredProcedure), 經 Nitro 的 /api/proxy 轉發。

      新增頁面:
          /sales-issue/issues          議題維護 (原 WorkProcess/SOPMaintain)
          /sales-issue/issues/new      新增議題
          /sales-issue/issues/{wpno}   議題編輯 (原 WorkProcess/SOPDetailEditor)
          /sales-issue/kind-maintain   類別維護 (原 WorkProcess/KindMaintain)

      UI/UX 調整 (與舊畫面的差異):
      1. **進度改成時間軸卡片**, 不再是 bootstrap-table 的一列。
         一則進度本來就是「日期 + 內文 + 附件」, 用表格呈現會把內文壓成一行,
         舊畫面得靠一個藏起來的 checkbox 展開內文列才看得到內容。
         現在每則進度是一張卡: 標題列放日期/修改人/修改時間 + 展開、編輯、刪除,
         內容直接渲染, 附件變成可點的 chip。
      2. **列表頁的頁籤帶計數** (進行中 / 結案 / 全部)。
         舊版三個頁籤各自綁一張獨立的 bootstrap-table, 同一份資料塞三次;
         現在同一份資料前端切分, 換頁籤自動回第一頁。
      3. **查詢區重排**, 並標示「哪些條件會重新查詢、哪些只篩選目前結果」。
         另加「快速搜尋」在目前結果內找編號/主題/進度/人員, 以及一鍵清除條件。
      4. **議題編輯改成左右分欄**: 左邊基本資料 (主題/客戶別/類別/最新進度/公開/結案),
         右邊進度時間軸; 底部固定存檔列, 捲到哪裡都能存。
         舊畫面的存檔鈕在最上面, 進度多了就得捲回去。
      5. **類別改成可複選的 USelectMenu**, 取代舊版「開一個 modal → 選 radio →
         在表格裡逐筆按啟用 → 關 modal」那一連串。
      6. **客戶別改成可搜尋的下拉**, 取代舊版另開一個全螢幕 modal 選客戶。
      7. 新增議題改用 /issues/new 這個路徑, 存檔後 replace 成真正的編號,
         重新整理或把連結貼給別人都還在同一筆。舊版是 `?wpNo=-1&newSop=1`。
      8. 表格空狀態、載入中、確認刪除都換成 Nuxt UI 的元件, 不再用 window.alert/confirm。

      技術決策:
      - **編輯器不引第三方套件**。舊系統用 Summernote (jQuery 外掛), 2.0 沒有 jQuery。
        改寫 `RichTextEditor.vue`: contenteditable + document.execCommand。
        理由是 DB 既有的內文就是一堆帶 inline style 的 HTML, execCommand 產出的結構
        跟舊資料同一種, 新舊內容混在一起不會走樣; 換成 TipTap 那種有自己 schema 的
        編輯器, 舊內容會在載入時被正規化掉。
        代價: execCommand 已標記 deprecated (但主流瀏覽器都還支援)。
      - `RichTextEditor` 的內文 CSS 與 `IssueContentView` 必須保持同一組規則,
        否則編輯時看到的排版跟存完在時間軸上看到的不一樣。
      - 顯示端一律消毒 (拔 script / on* / javascript:)。內文有不少是從 Outlook、Word
        貼進來的, v-html 不會幫你擋。
      - 登入帳號改從 JWT 的 `sub` claim 解出來 (`useAuthAccount`), 取代舊版的
        `$.session.get('account')`。附件的 temp 路徑需要它。

      順手修的 bug:
      a. **附件中間層目錄用錯來源**。後端 EnumTempUploadAttach / UpdateDBAttachFile
         都是用 `floor(wpNo * 2 / 1000)` 組 temp 路徑, 但舊 JS `onClickAddAttach()`
         是用「目前附件筆數」算的。wpNo < 500 時兩邊剛好都是 00000 所以看不出來,
         **wpNo 到 500 以上上傳的檔案會落在後端找不到的層級, 存檔後附件憑空消失**。
         2.0 的 `dcuMiddleLayer()` 統一改用 wpNo。
      b. **編輯期間的日期條件送了等於沒送**。GetSOPList_Edit 收 startDate/endDate,
         但後端那段過濾在 2026-06-08 改 order by 客戶別時整段被註解掉了。
         舊畫面照樣顯示「編輯期間」欄位, 使用者以為有篩到。
         2.0 改成前端對「最後修改時間」過濾, 行為才跟欄位名稱一致。
         哪天後端補回來, 把這段移回去即可。
      c. 附件沒異動時不再重壓 zip。舊流程每次存檔都重壓, 而重壓會重編 RenameFile。

      沒搬的部分 (需要時再補, 清單見 logic.md):
          WorkProcess/Index 功能按鈕首頁、SOPList/SOPDetail 唯讀瀏覽視角、
          逐議題的編輯/檢視人員權限設定、版本進版與各版本備註、調整進度順序、
          執行說明 ProcessCaption2。

      異動 (Proril_Sales_Center):
          app/types/{api,salesIssue}.ts
          app/utils/salesIssue.ts
          app/composables/{useSalesIssueApi,useIssueAttachments,useAuthAccount,useAppNavigation}.ts
          app/components/{RichTextEditor,IssueContentView,IssueProgressModal}.vue
          app/pages/sales-issue/issues/{index,[wpno]}.vue
          app/pages/sales-issue/kind-maintain.vue
          app/pages/index.vue, app/app.vue, app/layouts/default.vue
          server/api/download.get.ts
          docs/modules/SalesIssue/{logic,update}.md
</details>

<details>
  <summary>版號2026.09.02.0900</summary>

##### chore: 清空 Proril_Sales_Center, 只留 Nuxt 空殼與 UI/UX 設定
      這個 repo 原本是從 Proril_Manufacturing_Center 複製過來的, 帶著製造中心的功能。
      移除: app/pages/test/、app/pages/q-exception/、app/components/test/、
            app/composables/{useTestEnums,useMemo}.ts、app/types/{test,qexception}.ts
      保留: Nuxt 4 + Nuxt UI v4 + Tailwind v4 的空殼、CLAUDE.md、
            品牌色票 (app/assets/css/main.css 的 @theme)、app.config.ts 的 ui.colors、
            版面 (layouts/default.vue)、共用元件 (AppLogo / ConfirmDialog /
            FullPageLoading / TablePaginationBar)、useApi / useTablePagination
      還原: public/ (logo) 與 server/api/proxy/ —— 這兩個目錄在工作區被誤刪了, 從 git 取回。
      改名: package.json name、側欄與 navbar 標題改成「業務中心」。
</details>

<details>
  <summary>版號2026.10.05.1600</summary>

##### feat: 訂單資料檢核拿掉整頁遮罩，表格等 API 回來才更新
      比照銷貨檢索：不再顯示 FullPageLoading，查詢條件與頁籤一開始就可操作；
      表格只在 UTable 上顯示 loading，GetPOCheckView 回來才換資料。
      load() 加序號，連按查詢／快速翻頁時晚回來的舊回應直接丟掉。

      載入中整頁顯示 wait cursor（cursor: progress，仍可操作），共用 app/composables/useWaitCursor.ts，
      樣式在 app/assets/css/main.css 的 html.is-waiting。

      app/pages/sales-center/sales-search/order-info-verify.vue
</details>

<details>
  <summary>版號2026.10.05</summary>

##### perf: GetPOCheckView 查詢加速
      實測瓶頸（測試區 50002）：
        - V_PODetailList 是四段式名稱的跨 linked server 多表 JOIN，「編譯」查詢計畫就要
          ~500 ms，執行只要 ~70 ms。原本用 EF.Constant 把單號翻成常值 IN (N'...')，
          每一頁的 SQL 文字都不同，每次都重新編譯。
        - V_UpFileData（replace 過的 KeyValues）與 V_Product_English_All（TOP ... ORDER BY）
          的條件推不到 ERP 主機，加不加 IN 條件都是整份拉回來（約 0.2~0.3 s），而且是排在
          V_POList、V_PODetailList 後面依序執行。
        - 明細 modal（pageSize=0）原本 V_PODetailList 不加單號條件，只查一張訂單也整份讀（約 1 s）。

      修正：
        - V_PODetailList 改 FromSqlRaw + 固定個數的 nvarchar(20) 參數（1/20/50/100 四檔，
          不足的重複填第一個單號），SQL 文字固定、計畫快取得到。依「本頁訂單數」決定，
          不再看 pageSize，所以明細 modal 也走參數化；超過 100 張（「全部」、匯出）
          維持只用 COP_Source 過濾整份讀。
        - V_UpFileData／V_Product_English_All 改成不加條件整份讀，各自開一個 DbContext
          跟 V_POList 同時開跑，join 照舊在記憶體做。
        - GetPOCheckView、ExportXls 改 async。

      新舊版同時起在本機、打同一組請求比對（回傳 JSON 逐字相同）：
        未確認第 1 頁     1034 → 601 ms
        已確認第 1/2/8 頁 1082~1180（沒看過的頁約 1.6~2.7 s）→ 617~702 ms
        已確認 50 筆      1219 → 726 ms
        明細 modal        1415~1587 → 415~461 ms
        全部（18638 列）  4995 → 4498 ms（大部分是 JSON 序列化與傳輸）
      剩下的固定成本主要是 V_POList（OPENQUERY，約 430 ms）。

      api/Controllers/SalesSearch/OrderInfoVerifyApiController(.Xls).cs

</details>

<details>
  <summary>版號2026.09.30</summary>

##### perf: V_POList 改用 OPENQUERY
      原本四段式名稱 [192.168.1.200].PRORIL.dbo.xxx 的跨主機 JOIN，改成國內、國外各一個
      OPENQUERY，整段在 ERP 主機執行後只傳回結果；未確認／已確認兩段併成一段
      （TC027 = TD021 且為 N 或 Y），ConfirmFlag 改由 TC027 推出。
      中文別名與常值放在外層（OPENQUERY 字串不能加 N 前綴）。
      定義在 database/OrderCheckObjectsMigration.sql 與
      database/prod-migration-2026-09-21/02-create-views.sql（兩份內容相同）。

##### fix: 國外未確認訂單被歸到已確認
      搬移 V_POList 時「國外訂單 未確認」那段的 ConfirmFlag 誤抄成 'Y'
      （1.0 PRORIL_WEB 原本是 'N'），國外未確認訂單全部跑到已確認頁籤。
      隨上面的改寫一起修正。

      測試區（50002）比對新舊定義：總筆數一致（芳晟 2638、浦瑞 2365），
      除 ConfirmFlag 外其餘欄位 EXCEPT 雙向 0 筆；差異只有浦瑞 9 張單 Y → N。
      單次查詢 1134 ms → 440 ms。

</details>

<details>
  <summary>版號2026.09.29</summary>

##### fix: 已確認訂單頁（與匯出）整頁空白
      症狀：頁籤筆數正常（已確認 5006），列表卻顯示「沒有符合條件的訂單」；未確認頁正常。

      原因：GetOrderInfoList 撈 V_PODetailList 用 orderNos.Contains(d.單號.Trim())，
      單號在 EF 對映是 nchar(11)（IsFixedLength），EF 8 把清單參數翻成
      OPENJSON(...) WITH ([value] nchar(11))。這個寫法對 V_PODetailList（跨 linked server
      的 View）只要清單超過 1 個值就一筆都比對不到（已在 DB 實測：1 個值 2 筆、2 個值 0 筆；
      改 nvarchar 或常值 IN 都正常）。品號明細是 inner join，撈不到就整張訂單消失。
      未確認頁剛好只有 1 張單，所以看不出來；匯出已確認同樣是空的。

      修正：分頁時改用 EF.Constant(orderNos)（翻成 IN (N'...') 常值，最多一頁的單號數）；
      不分頁（匯出）不加單號條件，只用 COP_Source 過濾，最後的 join 一樣會對齊。
      實測已確認第 1 頁 20 張單／64 筆明細、匯出全部 5003 張單正常。

</details>

<details>
  <summary>版號2026.09.18.1200</summary>

##### feat: 訂單資料檢核列表改後端分頁
      GetPOCheckView 原本是後端一次撈全部（V_POList join 品號明細後攤平），前端拿到全量
      資料用 UTable 的 getPaginationRowModel() 自己切頁；兩個頁籤（未確認/已確認）也是
      前端對全量 groups 用 confirmFlag 分兩組，沒有送到後端。已確認訂單這邊資料量上看
      五千筆，每次查詢都要整包傳到瀏覽器，跟畫面實際顯示 20 筆完全脫鉤。

      改成後端做 Skip/Take，但**分頁的單位是「訂單」，不是攤平後的品號明細列**——
      GetPOCheckView 回傳的資料形狀不變（一個品號一列，同一張訂單重複表頭），
      但 Skip/Take 是對 V_POList（一列一張訂單）在 join 品號明細**之前**做，不然同一張
      訂單的品號會被切頁切散到不同頁。獨立出 GetFilteredOrders() 做訂單層級的篩選
      （copSource/orderType/orderNo/customerNo/日期區間），GetPOCheckView 與
      GetOrderInfoList（ExportXls 共用的查詢核心）共用這份「篩選後、切頁籤前」的訂單清單，
      不用各自重撈一次 V_POList（這支查詢因為走 ERP linked server，實測要價 3~4 秒）。
        - GetPOCheckView 新增 tab（notChecked|checked）/ pageIndex / pageSize；
          不傳（明細 modal 的用法）就不篩、不分頁，回傳該訂單全部品號列，明細 modal
          （OrderCheckDetailModal）完全不用改，行為不受影響。
        - 新增 OrderInfoVerifySummary（body2）：兩個頁籤的訂單數是「篩選後、切頁籤前」
          算出來的，不會因為目前選哪個頁籤而變動；totalCount 才是目前頁籤篩選後的訂單數，
          前端拿來算分頁列的頁數，順便在頁籤按鈕上加了筆數徽章（原本沒有）。
        - 前端 groupOrderInfoVerifyRows() 完全不用改——後端已經把資料範圍縮小到當頁的
          訂單，前端照舊把攤平列 group 成一列一張訂單即可，不需要跟著大改。
        - ExportXls／GetOrderInfoList 的既有呼叫（不分頁、匯出全部）不受影響，
          pageIndex/pageSize/preFilteredOrders 都是新增的可選參數，預設值等於原本行為。
        - 前端 UTable 改成 manualPagination + rowCount，比照業務議題列表
          （見 SalesIssue/update.md 同一天的條目）沿用同一組 TablePaginationBar
          （every-page 筆數選單 20/50/全部）與 onPaginationUpdate 寫法。

      api/Models/ApiModels.cs
      api/Controllers/SalesSearch/OrderInfoVerifyApiController.cs
      app/types/orderInfoVerify.ts
      app/composables/useOrderInfoVerifyApi.ts
      app/pages/sales-center/sales-search/order-info-verify.vue

      驗證：瀏覽器手動測試（頁籤切換、換頁、明細 modal 重新查詢）皆確認後端回傳的
      分頁與統計數字正確，未確認/已確認訂單數與畫面徽章一致，明細 modal 打的
      GetPOCheckView 請求 tab/pageSize 皆為空／0，資料未被截斷。

</details>

<details>
  <summary>版號2026.09.14.2100</summary>

##### feat(app): 表格整列可點擊進編輯畫面

      新增全站共用樣式 app/utils/table.ts 的 clickableRowTr:
      hover 時整列變色 + 列內文字加底線 + 游標變手指，
      列內的 button / a 不跟著加底線。

      訂單資料檢核 (order-info-verify) 兩個分頁的表格改成整列可點，
      點任一格即開「檢核結果」明細 Modal；原本的 actions 按鈕保留，
      外面包 <div @click.stop> 避免觸發兩次。

      同時把既有已支援整列點擊的表格換成同一組樣式 (原本只有 cursor-pointer、
      沒有底線): 議題清單、議題類別維護、客戶資料維護 (內網 / ERP 兩張)。

      規範已寫進 CLAUDE.md「核心設計原則」: 之後只要 table 有對應的編輯畫面，
      一律掛 clickableRowTr + @select。

      異動:
          app/utils/table.ts (新增)
          app/pages/sales-center/sales-search/{order-info-verify,customer}.vue
          app/pages/sales-center/sales-issue/issues/index.vue
          app/pages/sales-center/sales-issue/kind-maintain.vue
          CLAUDE.md

</details>

<details>
  <summary>版號2026.09.14.1800</summary>

##### chore(db): 訂單資料檢核的資料庫物件已搬進 Proril_Sales_Center (測試區)
      跑了 database/OrderCheckObjectsMigration.sql (走 scripts/run-objects-migration.ps1)，
      18 個物件全部建立: 7 View + 5 SP + 1 函式 + 5 表。

      驗證:
          5 張表筆數與 PRORIL_WEB 逐一相同
              COP_PoCheck 446 / COP_PoDetailCheck 1256 / COP_PassCheck 47 /
              COP_AvailableAmt 2790 / COP_ProductCheck 23135
          7 個 View 在新庫查得到資料且筆數與舊庫一致
              196 / 4974 / 18688 / 9984 / 7078 / 3 / 22
              → instance 層級的 linked server [192.168.1.200] 在新庫同樣可用

      還沒驗: prc_COPOrderChk / prc_COPPassCheck / prc_COPGetCredit /
      prc_ProductChk_COP 四支都會寫資料，沒有「只查不寫」的跑法，要驗得挑一張
      可以拿來試的訂單。

      **api/ 還沒切連線**: OrderInfoVerifyApiController 仍打 ProrilWebDbContext，
      SP 也還是在 PRORIL_WEB 執行。切連線要三支呼叫入口 (ErpImportApi /
      BomQueryApi / OrderInfoVerifyApi) 一併確認，見 CLAUDE.md。

      同時間整個 Proril_Sales_Center 的定序已對齊成 Chinese_Taiwan_Stroke_BIN，
      詳見 database/PortingNotes.md「定序已對齊」。

</details>

<details>
  <summary>版號2026.09.10.1200</summary>

##### fix: 客戶下拉選單渲染失敗
      USelectMenu 的 placeholder 選項用 value:'' 跟 Reka UI Combobox 保留的「清空選取」值
      衝突，mount 就丟例外，選單看起來像空的。改用哨兵字串 + writable computed 轉換。
      同一個模式在其他模組的客戶/類別篩選也有，一併修掉，詳見
      `docs/modules/SalesIssue/update.md` 對應那筆的完整說明。

</details>

<details>
  <summary>版號2026.09.03.1200</summary>

##### feat: 訂單資料檢核自 PRORIL 1.0 (業務檢索/OrderInfoVerify) 搬到 2.0 業務中心
      範圍: 前後端都搬。這個功能含寫入操作 (執行檢核 prc_COPOrderChk、特規Pass
      prc_COPPassCheck 都會寫回 COP_PoCheck/COP_PoDetailCheck/COP_PassCheck)，
      跟只搬前端的銷貨檢索/未完成訂單檢索不同，後端整支搬進 Proril.SalesIssue.Api。

      新增頁面:
          /sales-center/sales-search/order-info-verify   訂單資料檢核 (原 Mix/OrderInfoVerify)
              2 個頁籤: 未確認訂單/已確認訂單
              1 個檢核 modal: 表頭唯讀欄位 + 執行檢核 + 特規Pass(訂單金額/信用額度) + 品號卡片
              1 個檢核條件說明 modal
              Excel 匯出

      後端新增:
          api/Data/OrderInfoVerifyEntities.cs   V_POList/V_PODetailList/COP_PoCheck/
              COP_PoDetailCheck/COP_CheckRule/COP_PassCheck/V_Product_English_All/
              COP_DepData/V_UpFileData 對映 + prc_COPGetCredit(_CRM) 查詢結果形狀
          api/Models/OrderInfoVerifyModels.cs   CopPoCheckExRule/CopPoDetailCheckExRule
              (掛檢核規則說明文字)、VPoListDetailViewModel
          api/Controllers/SalesSearch/OrderInfoVerifyApiController(.Xls).cs
          api/Controllers/Shared/MainApiController.cs   加 CheckUserPermissionLinkType
              (裸 bool，跟其他模組共用同一支金額欄位權限檢查)

      技術決策:
      - **跟業務議題共用同一個 SalesIssueDbContext**，不是每個模組各開一個
        DbContext——這批表跟業務議題的表無關，但 database-first 的 EF Core 專案
        本來就是「一個 DbContext 對一個資料庫」，開新 DbContext 反而要重複一份
        連線設定。
      - **Excel 匯出不移植 1.0 的 CMN_XlsFileFormat 資料庫驅動格式引擎**
        (XlsFormatterApis_Cmn)，改在 C# 寫死欄位配置。那套引擎是給多個「還沒搬」
        的模組共用的排版基礎設施，只為這一個匯出去搬不成比例，見 logic.md。
      - **主表格不做巢狀展開列**，品號明細只在檢核 modal 呈現，見 logic.md。

      順手修的 bug (跟舊版的刻意差異，詳見 logic.md):
      a. **GetPOCheckView 不再雙重 JSON 編碼**。1.0 用 JsonConvert.SerializeObject
         把結果轉成字串塞進 Body，前端還要再 JSON.parse 一次；2.0 直接放物件。
      b. **SP_GetCredit(_CRM) 改參數化 SQL**，1.0 直接字串插值組 SQL 有注入風險。
      c. **prc_COPGetCredit(_CRM) 回傳欄位型別改宣告 decimal**。1.0 model 宣告
         float，但 SP 實際回傳 SQL decimal/numeric，EF Core 8 對不上型別會直接
         丟 InvalidCastException（本機實測撈信用額度會直接 500，1.0 用舊版 EF
         Core 型別轉換比較寬鬆才沒事）。
      d. **只顯示NG 改用品號自己的 FinFlag**。1.0 比對
         `copPoCheck.FinChk.toLowerCase() == 'Y'`，大小寫比對邏輯本身就不可能為
         真，這個 checkbox 在 1.0 形同虛設；而且比對的是訂單層級欄位，就算修好
         判斷式也濾不出「哪個品號有問題」。2.0 改用品號自己的 vPoDetail.finFlag。
      e. **CheckUserPermissionLinkType 用 .Any() 不用 .First()**，帳號不存在時
         不會丟例外。
      f. **匯出金額欄位權限統一用 FunctionId.OrderInfoVerify(425)**，1.0 查權限
         用的是 410 (MixSalesShipping)，跟查詢 Excel 格式用的 425 對不上號。

      沒搬的部分 (需要時再補，清單見 logic.md):
          SP_GetCreditCRM 前端沒有呼叫（比照 1.0 本來就沒用到）、頁面級功能權限
          檢查、訂單單別動態下拉（改純文字輸入）。

      異動 (Proril_Sales_Center):
          api/Data/{SalesIssueDbContext,OrderInfoVerifyEntities}.cs
          api/Models/{Enums,OrderInfoVerifyModels}.cs
          api/Controllers/Shared/MainApiController.cs
          api/Controllers/SalesSearch/OrderInfoVerifyApiController(.Xls).cs
          api/Helpers/StoragePaths.cs
          api/Proril.SalesIssue.Api.csproj（加 ClosedXML 套件）
          api/README.md
          app/types/orderInfoVerify.ts
          app/composables/{useOrderInfoVerifyApi,useAppNavigation}.ts
          app/utils/orderInfoVerify.ts
          app/components/sales-search/{OrderCheckDetailModal,OrderCheckProductCard,OrderCheckConditionModal}.vue
          app/pages/sales-center/sales-search/order-info-verify.vue
          docs/modules/OrderInfoVerify/{logic,update}.md
</details>

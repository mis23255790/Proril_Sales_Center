<details>
  <summary>版號2026.09.14.1700</summary>

##### feat: 銷貨檢索後端自 1.0 搬到 api/，並產出資料庫物件遷移腳本
      後端 (api/Controllers/SalesSearch/):
          MixSalesShipApiController.cs      GetSalesOrder / GetSalesOrder_1
          MixSalesShipApiController.Xls.cs  ExportXls (四個分頁, 金額欄位權限 410/100)
          api/Data/SalesShippingEntities.cs CopSalesOrder, 對映在 ProrilWebDbContext

      端點名稱/參數大小寫/回傳信封與 1.0 一字不差, 前端 useSalesShippingApi.ts 不用改,
      NUXT_PUBLIC_API_BASE 指 api/ 或 1.0 站台都能跑。

      刻意的差異:
          SQL 改 FromSqlInterpolated 參數化 (1.0 是直接串字串, 有 injection 風險)
          匯出版面不再讀 PUR_XlsFileFormat 動態組, 改寫死在 C# (表頭與數字格式照抄
              那張表的 FunctionNo=410 設定), 欄寬改 AdjustToContents()
          不搬 COP_MDL_SalesOrder_1 (0 筆空殼表, 無人參照), 匯出改用 CopSalesOrder

      資料庫 (測試區已執行完成):
          database/SalesShippingObjectsMigration.sql
              COP_SalesOrder 1 張表 + prc_QuerySalesOrder / prc_QuerySalesOrder_1 /
              prc_ImportSalesOrder 3 支預存程序, 0 個 View。
              唯一改過的邏輯: prc_ImportSalesOrder 兩處寫死的
              PRORIL_WEB.dbo.COP_SalesOrder 改成 dbo.COP_SalesOrder。
              PRORIL_WEB.dbo.NPS_D_Order 的參照刻意保留 (那張表屬於別的模組)。
          database/Tables/COP_SalesOrder.sql + TABLES.txt  收進 DACPAC schema 版控
          database/scripts/run-objects-migration.ps1
              新增: 執行 *ObjectsMigration.sql 的共用執行器 (訂單資料檢核那支也適用)。
              預設 dry-run: 目標庫與腳本 USE 對帳 / linked server [192.168.1.200] 檢查 /
              物件現況列表 / SET PARSEONLY ON 驗語法; 加 -Execute 才真的跑。
              一律用 sqlcmd -f 65001 讀 (腳本是 UTF-8 無 BOM 且含中文字串常值)。

      注意: prc_QuerySalesOrder(_1) 進來第一行就 EXEC prc_ImportSalesOrder,
      所以「查詢」其實會對 COP_SalesOrder 做 INSERT/DELETE, 不是唯讀。
      詳見 database/PortingNotes.md「銷貨檢索相關的表 / 預存程序」。

##### fix(db): Proril_Sales_Center 定序對齊 PRORIL_WEB
      執行上面那支遷移腳本時發現的: 同一份資料、同一組查詢條件,
      prc_QuerySalesOrder_1 在兩個庫回傳的分群統計筆數不一樣 (200/24/33 vs 194/23/32)。
      原因是 Proril_Sales_Center 建庫時沿用 instance 預設的
      SQL_Latin1_General_CP1_CI_AS, 與 PRORIL_WEB 的 Chinese_Taiwan_Stroke_BIN 不同,
      SP 的 ORDER BY 在兩種定序下順序有 13 列不同, 而它的分群是用游標比對相鄰列做的。

      已用新增的 database/scripts/fix-collation.ps1 把整個庫對齊
      (142 個字元欄位 / 15 張表 / 1 個索引重建), 改完兩支 SP 在兩庫的結果完全一致。
      這不只影響銷貨檢索 —— 業務議題與權限控管那幾張表的字串比對原本也是
      「不分大小寫」, 現在回到 1.0 的 BIN 語意。詳見
      database/PortingNotes.md「定序已對齊」與 database/README.md「定序 (collation)」。

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
  <summary>版號2026.09.02.1600</summary>

##### feat: 銷貨檢索自 PRORIL 1.0 (業務檢索/MixSalesShip) 搬到 2.0 業務中心
      範圍: 只搬前端。後端沿用 1.0 的 MixSalesShipApi, 不新增 API、不動資料庫
      (含 View / 預存程序 prc_QuerySalesOrder(_1)), 經 Nitro 的 /api/proxy 轉發。

      新增頁面:
          /sales-search/shipping-inquiry   銷貨檢索 (原 Mix/SalesShipping)
              4 個頁籤: 品號細項/品號統計/銷貨單細項/銷貨單統計
              2 個明細 modal: 單一品號明細/單一銷貨單明細
              Excel 匯出

      新增基礎設施:
          app/composables/usePermission.ts   通用的 M_Permission LinkType 權限檢查,
              打 MainApi/CheckUserPermissionLinkType (裸 bool, 非 ApiResponse 信封)。
              這是全站第一個權限判斷 composable, 之後其他模組要做欄位級權限可以共用。
          app/types/api.ts、useAppNavigation.ts 新增「業務檢索」導覽模組

      技術決策:
      - **FooterFlag 過濾邏輯照搬 SQL 的既有行為**: 細項 tab = 非 Y (N+S+T),
        統計 tab = 非 N (S+Y+T), 兩邊都吃得到 T (總計列)。這樣寫是為了跟舊畫面
        bootstrap-table 的資料完全一致, 不是好懂的設計, 細節記在 logic.md。
      - **金額欄位權限即時查、不快取**, 對照舊版行為 (每次進頁面打一次
        CheckUserPermissionLinkType(410, 100)), 沒權限時整欄不渲染。
      - **兩支查詢 API 同時打** (Promise.all), 對照舊版 onClickConditionQuery
        的 Promise.all([GetSalesOrder, GetSalesOrder_1]) —— 拿兩份幾乎重複的
        資料分別餵給品號/銷貨單兩組頁籤, 效能上有優化空間但先照搬行為。
      - 表格用 UTable + columns 陣列 (h() 函式做金額置右/千分位), 沒有另外
        引 bootstrap-table 或 resizableColumns 這類擴充。

      順手修的 bug (跟舊版的刻意差異):
      a. **明細 modal 金額權限漏洞**。舊版兩個明細 modal
         (#modalProductDetail / #modalSoDetail) 的欄位沒有掛 per-amount class,
         不管有沒有權限點進明細都看得到金額。2.0 統一用同一個 showAmount 旗標
         控制外層頁籤跟兩個 modal。
      b. **訂單單號欄位對應修正**。舊版 UI 上「訂單單號」(#inputOrderNo) 實際送的
         是 poNo 參數, 跟只有明細 modal 才用的 orderType/orderNo 是兩回事,
         2.0 的查詢條件表單同樣對應到 poNo, 避免搬遷時看名字誤接錯參數。

      沒搬的部分 (需要時再補, 清單見 logic.md):
          MixSalesShipApi/GetCOPOrder (早期/未用的全表查詢)、
          頁面級功能權限檢查 checkPermission (MainApi/CheckUserPermission)、
          業務檢索系統下其他功能 (報價/應收帳款/未完工訂單等)。

      異動 (Proril_Sales_Center):
          app/types/salesShipping.ts
          app/utils/salesShipping.ts
          app/composables/{useSalesShippingApi,usePermission,useAppNavigation}.ts
          app/components/SalesOrderDetailModal.vue
          app/pages/sales-search/shipping-inquiry.vue
          docs/modules/SalesShipping/{logic,update}.md
</details>

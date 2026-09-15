<details>
  <summary>版號2026.09.15.1500</summary>

##### feat: prc_QueryUnfinOrder(_1) + V_UnfinOrder 搬進 Proril_Sales_Center
      背景: 上一版把 SalesOrderUnFinishApi 的 Controller 搬進 api/ 時，資料庫物件
      沒有一起搬（repo 內找不到對應 .sql，沒人分析過依賴，先求能動）。這次把兩支 SP
      跟它們唯一依賴的 V_UnfinOrder View 一起搬過去，理由跟銷貨檢索/訂單資料檢核
      的物件搬移一致：讓查詢真的走獨立資料庫，而不是靠 api/ 反過來打 PRORIL_WEB。

      新增:
          database/SalesOrderUnfinishObjectsMigration.sql
              CREATE OR ALTER VIEW V_UnfinOrder + CREATE OR ALTER PROCEDURE
              prc_QueryUnfinOrder / prc_QueryUnfinOrder_1，可重複執行，用
              database/scripts/run-objects-migration.ps1 執行（比照銷貨檢索/
              訂單資料檢核）。定義是 2026-09-15 用 OBJECT_DEFINITION 直接從
              PRORIL_WEB 撈出來，除了 CREATE -> CREATE OR ALTER 之外一字不差。

      異動:
          database/scripts/run-objects-migration.ps1
              ValidateSet 加 SalesOrderUnfinishObjectsMigration.sql。
          api/Controllers/SalesSearch/SalesOrderUnFinishApiController.cs
              CallQueryUnfinOrder / CallQueryUnfinOrder1 改打 scDb
              （SalesCenterDbContext），不再是 db（ProrilWebDbContext）；
              另外兩支都加了 BuildDebugSql 除錯用的 WriteStepLog，把可以直接貼
              SSMS 執行的 EXEC 字串印出來，方便比對兩個資料庫的查詢結果。

      技術決策:
      - **不用複製任何表的資料**：V_UnfinOrder 不像銷貨檢索的 COP_SalesOrder 有本地
        快取表，它每次查都直接打 ERP linked server（浦瑞 TWPR、芳晟 PRORIL 兩套
        COPTC/COPTD/CMSMQ）+ PRORIL_WEB.dbo.NPS_D_Order（銘版序號來源）。NPS_D_Order
        這次不搬，處理方式跟 SalesShippingObjectsMigration.sql 對同一張表的做法一致：
        3 段式跨庫查詢，兩個資料庫在同一個 SQL Server instance。
      - **不需要 COLLATE DATABASE_DEFAULT**：跟 SalesShippingObjectsMigration.sql
        當時踩到的定序衝突不同，那支是本地快取表（用目標資料庫定序）去 JOIN ERP
        欄位；這裡沒有本地快取表，加上 Proril_Sales_Center 現在定序已經對齊
        Chinese_Taiwan_Stroke_BIN（見 database/PortingNotes.md「定序已對齊」），
        兩側欄位本來就同定序，不用特別處理。
      - **執行前先跑 dry-run**：`run-objects-migration.ps1` 不加 -Execute 已確認
        linked server 存在、三個物件在目標庫都是 ABSENT（首次搬移）、語法檢查通過；
        真正對測試區資料庫執行 -Execute 前跟使用者確認過。

</details>

<details>
  <summary>版號2026.09.14.1800</summary>

##### feat: 未完成訂單檢索後端搬進 2.0（api/），不再沿用 1.0
      背景: 本機 .env 的 NUXT_PUBLIC_API_BASE 指向 api/（新後端）測試時，這個模組
      因為後端還留在 1.0 而打不到路由，前端跳「無法連接後端 API」。順勢把
      SalesOrderUnFinishApi 整支搬進來，不用再切 .env 才能測。

      新增:
          api/Data/SalesOrderUnfinishEntities.cs
              UnfinOrder（對映 1.0 SalesOrderViewModel，keyless，FromSql 專用）。
          api/Controllers/SalesSearch/SalesOrderUnFinishApiController.cs
              GetUnfinOrder（依品號 TD004 分群）/ QueryUnfinOrder_1（依訂單 TC001+TC002 分群）。
          api/Controllers/SalesSearch/SalesOrderUnFinishApiController.Xls.cs
              ExportXls，欄位配置寫死在 C#，比照 MixSalesShipApiController.Xls.cs 的做法。

      異動:
          api/Data/ProrilWebDbContext.cs
              加 DbSet<UnfinOrder> + HasNoKey() 註冊。
          app/composables/useSalesOrderUnfinishApi.ts
              更新頂端註解，反映後端已搬（前端呼叫路徑不變）。

      技術決策:
      - **資料庫物件不動、不搬連線**：prc_QueryUnfinOrder(_1) repo 內沒有對應 .sql，
        只存在資料庫端，跟 1.0 一樣直接 EXEC，對映的表仍在 PRORIL_WEB，走 api/ 的
        ProrilWebDbContext（不是 Proril_Sales_Center）。
      - **SQL 改參數化**：1.0 是拼字串 FromSql，這裡改 FromSqlInterpolated，
        跟銷貨檢索/訂單資料檢核搬移時的做法一致，堵掉 SQL injection 風險。
      - **UnfinOrder.CopSource 改名**：1.0 是 COPSource（全大寫前綴），camelCase 化後
        會變成 cOPSource；這裡改成一般 PascalCase 的 CopSource，跟銷貨檢索的
        CopSalesOrder.CopSource 一致，camelCase 化是 copSource（前端型別本來就是這樣定的）。
      - **Excel 欄位配置寫死在 C#**：1.0 讀 PUR_XlsFileFormat（FunctionNo=420）動態組，
        那套通用格式引擎是給多個還沒搬的模組共用的基礎設施，這裡直接寫死，
        欄位順序跟頁面上四個頁籤的表格（unfinished-orders.vue 的 *_COLS）逐欄對齊，
        欄寬改 AdjustToContents()，是與 1.0 已知的唯一外觀差異。
      - FunctionIds.QueryUnFinish("0320102")、NAV_MODULES、PermissionMasterSeed.sql
        這三處在前端搬移那次（見下面「版號2026.09.02.1700」）就已經備好，這次不用再改。

      沒動: 前端頁面/composable 呼叫路徑、查詢條件、頁籤/明細 modal 邏輯全部不變，
      詳見 logic.md「架構：前後端都搬了」。
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
  <summary>版號2026.09.02.1700</summary>

##### feat: 未完成訂單檢索自 PRORIL 1.0 (業務檢索/QueryUnFinish) 搬到 2.0 業務中心
      範圍: 只搬前端。後端沿用 1.0 的 SalesOrderUnFinishApi, 不新增 API、不動資料庫
      (含預存程序 prc_QueryUnfinOrder(_1), repo 內沒有對應 .sql, 只存在資料庫端)。

      新增頁面:
          /sales-center/sales-search/unfinished-orders   未完成訂單檢索 (原 Mix/QueryUnFinish)
              4 個頁籤: 品號細項/品號統計/訂單細項/訂單統計
              2 個明細 modal: 單一品號明細/單一訂單明細
              Excel 匯出

      共用/共用化的基礎設施:
          app/components/common/QueryDetailModal.vue（原 sales-search/SalesOrderDetailModal.vue）
              泛型化 (script setup generic="T") 讓銷貨檢索與未完成訂單共用同一個
              「表頭唯讀欄位 + 總金額 + 細項表」modal 元件，改名反映用途已跨模組。
          app/composables/usePermission.ts   沿用銷貨檢索建的 LinkType 權限 composable,
              只是 functionNo 換成 420。

      技術決策:
      - **跟銷貨檢索是不同資料表/不同 ViewModel**（訂單 SalesOrderViewModel vs
        銷貨單 CopSalesOrder），型別/工具函式/常數刻意各自獨立
        (`app/types/salesOrderUnfinish.ts`、`app/utils/salesOrderUnfinish.ts`)，
        不共用銷貨檢索那組，避免兩個模組互相牽動。
      - **orderType 用後端 LINQ 二次過濾，不像銷貨檢索直接讓 SP 篩**：
        prc_QueryUnfinOrder(_1) 沒有 orderType 參數，篩單一訂單要靠 poNo 帶
        "{單別}-{單號}" 組合字串（對照舊版 onClickShowSoDetail），不是
        orderType/orderNo 分開傳，這點跟銷貨檢索的兩個明細 modal 用法不同。
      - 訂單細項 tab 比品號細項多一欄「贈品量」(td024)，對照舊版 cshtml 的欄位差異照搬。

      順手修的 bug (跟舊版的刻意差異):
      a. **明細 modal 金額權限漏洞**。跟銷貨檢索原本的問題一樣，舊版兩個明細
         modal 沒有掛 per-amount class，2.0 統一用 showAmount 旗標控制。
      b. **匯出參數對位錯誤**。舊版 onExportCopXls() 呼叫 API_ExportXls 時位置參數
         對錯（inPlanNumber 落到 orderType 的參數槽），2.0 改用具名參數的
         UnfinOrderQuery 物件呼叫，不會有這個問題（後端 ExportXls 本來就自己組
         品號/訂單兩份資料，這個修正對匯出結果沒有實質影響，只是呼叫端程式碼正確）。
      c. **明細 modal 總金額計算簡化**。舊版從查詢結果裡挑 footerFlag=='Y' 的
         小計列取 ntd；2.0 直接用外層列（本來就是分群小計）自帶的 row.ntd，
         結果等價但少一層轉換。

      沒搬的部分 (需要時再補, 清單見 logic.md):
          頁面級功能權限檢查 checkPermission、VUnfinOrder/VUnfinOrderSum 相關的
          舊 view model（目前查詢路徑沒用到）。

      異動 (Proril_Sales_Center):
          app/types/salesOrderUnfinish.ts
          app/utils/salesOrderUnfinish.ts
          app/composables/{useSalesOrderUnfinishApi,useAppNavigation}.ts
          app/components/common/QueryDetailModal.vue（重新命名 + 泛型化，
              原 app/components/sales-search/SalesOrderDetailModal.vue）
          app/pages/sales-center/sales-search/{shipping-inquiry,unfinished-orders}.vue
          docs/modules/SalesOrderUnfinish/{logic,update}.md
</details>

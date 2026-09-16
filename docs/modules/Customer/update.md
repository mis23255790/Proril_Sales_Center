<details>
  <summary>版號2026.09.16.1400</summary>

##### feat: 客戶相關資訊自 PRORIL 1.0 (Mix/CustomerRelated, FunctionNo 441) 搬到 2.0
      範圍: 前後端 + 資料庫都搬。1.0 的六個頁籤（基本資料/情報/訂單/銷售/信用額度/議題）
      一次搬齊，端點名稱與 1.0 一字不差（散在三支 controller，路由由 class 名稱決定）。

      新增頁面:
          /sales-center/sales-search/customer-related?customer=&erpCustomerNo=
              不進側欄、不進權限樹，比照 1.0（441 在 M_Function 的用途是權限掛載點，
              enum 註解就寫「No entry from UI, click button」）。入口是客戶檢索的整列點擊。

      客戶檢索的異動:
          整列點擊從「開編輯 modal」改成「跳客戶相關資訊」，編輯移到功能欄按鈕。
          內網客戶頁籤帶 (customerNo, erpcustomerNo)，ERP 客戶頁籤帶 (customerNo, ma001)。
          功能欄按鈕從「編輯」改名成「編輯基本資料」（ERP 頁籤未建內網客戶時是
          「建立內網客戶」），modal 標題改成「客戶基本資料」——同一列上有兩個不同去向，
          光寫「編輯」看不出來編的是哪一份資料。

      後端異動 (api/):
          Controllers/Shared/CustomQueryApiController.Memo.cs        新增 (GetCustomMemo /
                                                                     SetCustomMemo / DeleteCustomMemo)
          Controllers/Shared/CustomQueryApiController.cs             改成 partial
          Controllers/SalesSearch/MixSalesShipApiController.CustomerRelated.cs
                                                                     新增 (GetSalesTotal /
                                                                     GetCustomerUnfinOrder)
          Controllers/SalesIssue/WorkProcessApiController.cs         新增 GetWPOrderForCustom
          Data/SalesCenter/CrmCustomerMemo.cs                        新增實體
          Data/CustomerRelatedEntities.cs                            新增 VSalesTotal / VUnfinOrder
          Data/SalesCenter/SalesCenterDbContext.cs                   三者的對映
          Models/ApiModels.cs                                        新增 CrmCustomerMemoViewModel
      「信用額度」頁籤的 GetCustomerCreditCRM 之前就搬好了（MixSalesShipApiController.
      CustomerCredit.cs），這次只是終於有畫面在呼叫它。

      資料庫異動 (測試區已執行，正式區還沒建庫):
          database/CustomerRelatedObjectsMigration.sql   新增。建 V_SalesTotal View
                                                        + CRM_CustomerMemo 表 + 複製 23 筆情報
          database/Tables/CRM_CustomerMemo.sql          新增（schema 版控）
          database/TABLES.txt                           收進白名單
      V_SalesTotal 一併從 PRORIL_WEB 搬過來，順手結掉 PortingNotes.md 第 5 點
      「COP_SalesOrder 不算單一擁有者」——2.0 這側最後一個讀舊庫的路徑沒了。

      順手修的 bug (跟舊版的刻意差異):
      a. **從 ERP 客戶清單點進來時，情報與議題永遠是空的**。1.0 拿網址上的 Customer
         去查，那條路徑只有 ErpCustomerNo，查不到東西（GetCustomMemo 甚至在只有
         erpCustomerNo 時刻意清空）。2.0 改成先用 GetCustom 以 ERP 客編反查內網客戶，
         再用查回來的內網客編去查情報與議題，兩個入口看到的內容一致。
      b. **訂單頁籤的金額可能算成 NaN**。1.0 只在群組第一筆是 5 或 x 開頭時才初始化
         數量金額欄位，都不是的話整列是 undefined。2.0 一律從 0 起算。
      c. **情報建了就刪不掉**。1.0 沒有刪除端點也沒有按鈕，打錯字沒救。
         2.0 補 DeleteCustomMemo（軟刪除，aStatus 改 N）。
      d. **SetCustomMemo 的反射整包覆蓋**。1.0 用 DataHelper.combineModel 把非 null
         欄位全部蓋過去，加欄位時很容易連不該改的一起改掉。2.0 只更新畫面編得到的
         MemoType / MemoDesc。
      e. **dacpac 建不起來**（既有問題，跟這次功能無關但擋住 publish.ps1）。
         sqlproj 會把 checks/ 與各支一次性搬移腳本當成 schema 解析，噴 63 個
         SQL70001/SQL71006。加 <Build Remove> 排除掉，dotnet build 恢復 0 錯。

      刻意不搬的部分:
      - GetCustomerOrderTotal：1.0 的過濾條件寫反（erpCustomerNo.Length > 0 時清空），
        永遠回空清單，前端接收端也整段註解掉，是完整的死碼。
      - GetCustomerCredit（舊版信用額度）：1.0 畫面實際呼叫的是 CRM 版本。
      - CustomerRelated.cshtml 的 #modalEditCustom 與 customer-related.js 的
        window.operateEvents：從 custom-query.js 複製殘留，參照的 DOM 在本頁不存在。
      - 六個頁籤的細項權限（M_Permission 的 PermissionLinkTypeId 10~60）：
        1.0 那段實際是壞的（CommonApiController.GetPermission 的 where 整段被註解，
        回傳整張 M_Permission，等於誰都看得到全部）。2.0 先全開，跟其他業務檢索頁一致。

      沒搬的部分 (需要時再補, 清單見 logic.md):
          訂單金額 → 未完成訂單檢索、銷售月份 → 銷貨檢索這兩個下鑽連結
          （那兩頁目前不吃 query 參數，接了也不會帶條件）。

      異動 (Proril_Sales_Center):
          api/Controllers/Shared/CustomQueryApiController.{cs,Memo.cs}
          api/Controllers/SalesSearch/MixSalesShipApiController.CustomerRelated.cs
          api/Controllers/SalesIssue/WorkProcessApiController.cs
          api/Data/CustomerRelatedEntities.cs
          api/Data/SalesCenter/{CrmCustomerMemo.cs,SalesCenterDbContext.cs}
          api/Models/ApiModels.cs
          app/types/customerRelated.ts
          app/utils/customerRelated.ts
          app/composables/useCustomerRelatedApi.ts
          app/pages/sales-center/sales-search/{customer-related.vue,customer.vue}
          database/{CustomerRelatedObjectsMigration.sql,TABLES.txt,Proril.SalesIssue.Database.sqlproj}
          database/Tables/CRM_CustomerMemo.sql
          database/scripts/run-objects-migration.ps1
          database/PortingNotes.md
          docs/modules/Customer/{logic,update}.md

</details>

<details>
  <summary>版號2026.09.10.1200</summary>

##### fix: 內網客戶/ERP客戶下拉選單渲染失敗
      USelectMenu 的 placeholder 選項用 value:'' 跟 Reka UI Combobox 保留的「清空選取」值
      衝突，mount 就丟例外，選單看起來像空的。改用哨兵字串 + writable computed 轉換。
      同一個模式在其他模組的客戶/類別篩選也有，一併修掉，詳見
      `docs/modules/SalesIssue/update.md` 對應那筆的完整說明。

</details>

<details>
  <summary>版號2026.09.03.1200</summary>

##### feat: 客戶維護自 PRORIL 1.0 (業務檢索/Mix/CustomQuery) 搬到 2.0 業務中心
      範圍: 前後端都搬。後端擴充既有的 api/Controllers/Shared/CustomQueryApiController
      （既有 GetCustom 不動，新增 GetERPCustom / SaveCustom），不新開 controller
      （路由是 [controller]/[action] 慣例，class 名稱決定 URL，不能重複/改名）。
      不動資料庫 schema，只多讀 V_ERPCustomer 既有欄位（MA005~MA009/MA019/MA023/MA024/
      ERPHeadCustomer）。

      新增頁面:
          /sales-center/sales-search/customer   客戶維護 (原 Mix/CustomQuery)
              2 個頁籤: 內網客戶/ERP客戶
              新增/編輯客戶 modal (含 ERP 客戶對應、業務負責人指派、潛在客戶標記)

      後端異動 (api/):
          Controllers/Shared/CustomQueryApiController.cs  新增 GetERPCustom / SaveCustom
          Data/Entities.cs                                VErpcustomer 補齊 UI 用得到的欄位
          Data/SalesIssueDbContext.cs                     對應的 EF 欄位對照
          Models/ApiModels.cs                              新增 VErpcustomerViewModel

      刻意不搬的部分 (1.0 本來就是死碼，沒有可參考的畫面):
      - 客戶備註 CrmCustomerMemo / GetCustomMemo / SetCustomMemo：1.0 的
        custom-query-apis.js / custom-query.js 有對應函式，但 Views/Mix/CustomQuery.cshtml
        完全沒有 #table-customer-memo / .memo-editor 這些 DOM，畫面上叫不到。
      - 「全部客戶」頁籤：1.0 View 裡整段註解掉，沒有實際使用。

      順手修的 bug (跟舊版的刻意差異):
      a. **SaveCustom 漏送欄位**。1.0 的 API_SaveCustom() 呼叫時 ContactTel2/ContactFax/
         Addr1/Addr2 四個參數整行被註解掉，畫面上填了這幾欄也不會存進去；後端本來就支援
         這四個欄位，2.0 前端補上正常送出。

      沒搬的部分 (需要時再補, 清單見 logic.md):
          頁面級功能權限檢查 checkPermission、客戶備註功能（需要重新設計畫面，不是照搬）。

      異動 (Proril_Sales_Center):
          api/Controllers/Shared/CustomQueryApiController.cs
          api/Data/{Entities,SalesIssueDbContext}.cs
          api/Models/ApiModels.cs
          app/types/customer.ts
          app/composables/{useCustomerApi,useAppNavigation}.ts
          app/pages/sales-center/sales-search/customer.vue
          docs/modules/Customer/{logic,update}.md
</details>

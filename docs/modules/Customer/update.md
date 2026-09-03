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

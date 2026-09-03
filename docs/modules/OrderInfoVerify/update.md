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

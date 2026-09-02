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

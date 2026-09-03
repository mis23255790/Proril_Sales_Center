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

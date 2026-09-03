<details>
  <summary>程式邏輯</summary>

###### 對應舊系統
     PRORIL (.NET MVC) 的「業務檢索」系統下的「未完成訂單檢索」
       Controllers/MixSalesShip/MixSalesShipController.cs   MVC 入口 `QueryUnFinish()`（回空 View）
       Views/Mix/QueryUnFinish.cshtml
       wwwroot/js/mix/{query-unfinish, query-unfinish-apis}.js
       Controllers/MixSalesShip/SalesOrderUnFinishApiController.cs        ← **後端沒搬，繼續用**
       Controllers/MixSalesShip/SalesOrderUnFinishApiController_XlsOut.cs ← ExportXls
       SystemId.MixSales = 32 / FunctionId.QueryUnFinish = 420

     enum 註解寫「尚未出貨訂單」，但畫面 top-title 顯示的是**「未完成訂單檢索」**，
     2.0 沿用畫面上實際看到的字樣。

###### 相關資料表 / 預存程序
     SalesOrderViewModel（FromSql 查詢結果，非 EF 對應的實體表）
     prc_QueryUnfinOrder      依品號(TD004)分群，GetUnfinOrder 呼叫
     prc_QueryUnfinOrder_1    依訂單(TC001+TC002)分群，QueryUnfinOrder_1 呼叫
                              也是「單一訂單明細」modal 在用（poNo 帶 "單別-單號" 組合字串篩單一訂單）
     M_Permission / M_PermissionLinkType   金額欄位權限（FunctionNo=420, LinkType=100）

     這兩支 SP **repo 內找不到對應 .sql 檔**（`database/` 只管業務議題的表，
     這個功能是 1.0 唯讀，不動資料庫），只存在資料庫端，需要改邏輯要直接查資料庫。
</details>

# 架構：只搬前端

跟 [業務議題](../SalesIssue/logic.md)、[銷貨檢索](../SalesShipping/logic.md) 一樣，只搬 Nuxt 前端，
後端沿用 1.0 的 `SalesOrderUnFinishApi`。

```
Nuxt 頁面 ──▶ useSalesOrderUnfinishApi() ──▶ /api/proxy/... ──▶ server/api/proxy/[...path].ts
                                                                   └─▶ NUXT_PUBLIC_API_BASE (.NET) /SalesOrderUnFinishApi/...
```

- **沒有新後端、沒有動資料庫**。
- 跟銷貨檢索是**不同資料表/不同 ViewModel**（訂單 vs 銷貨單），欄位命名也不同
  （銷貨檢索是 `th0xx`/`tg0xx`，這裡是 `tc0xx`/`td0xx`），刻意不共用型別或常數
  （`app/types/salesOrderUnfinish.ts` 自成一組），避免兩個模組互相牽動。

# 兩支查詢 API，同時打，餵給不同分頁

`load()` 用 `Promise.all` 同時打兩支：

| API | groupName | 分群鍵 | 餵給哪個頁籤 |
|---|---|---|---|
| `GetUnfinOrder` | `TD004` | 品號 | 品號細項 / 品號統計 |
| `QueryUnfinOrder_1` | `TC001` | 訂單單別+單號 | 訂單細項 / 訂單統計 |

過濾參數比銷貨檢索多兩組：**訂單日期起訖**（`startDate`/`endDate`）與
**預交日期起訖**（`deliveryStartDate`/`deliveryEndDate`，各自獨立、預設不套用）。

# orderType 只做後端二次過濾，SP 不支援

`prc_QueryUnfinOrder(_1)` **沒有 `orderType` 參數**（跟銷貨檢索的 `prc_QuerySalesOrder_1`
不同，那支直接支援 `orderType`/`orderNo`）。後端收到 `orderType` 非空時，用 LINQ
對已查出的結果再過濾一次：

```csharp
if (!string.IsNullOrWhiteSpace(orderType))
    list = list.Where(x => x.FooterFlag == "Y" || x.Tc001 == orderType).ToList();
```

（`SalesOrderUnFinishApiController.cs:55-59`，`Y` 小計列一律保留，只濾明細/總計列）

`orderNo` 參數則完全沒用到（SP 不吃、C# 也不比對），舊畫面永遠送空字串，
2.0 的 `useSalesOrderUnfinishApi.ts` 的 `toParams()` 同樣固定送 `''`。

**篩單一訂單靠 `poNo` 帶組合字串**：「單一訂單明細」modal 呼叫
`QueryUnfinOrder_1` 時，`poNo` 送 `` `${tc001}-${tc002}` ``（對照舊版
`onClickShowSoDetail` 的 `` `${row.tc001}-${row.tc002}` ``），不是傳
`orderType`/`orderNo`。這是這個模組跟銷貨檢索最大的行為差異，改邏輯時別套錯模式。

# FooterFlag：跟銷貨檢索語意相同，各自獨立實作

```
細項 tab = FooterFlag != 'Y'   (N + S + T)
統計 tab = FooterFlag != 'N'   (S + Y + T)
```

跟銷貨檢索一樣兩邊都吃得到 `T`（總計列），是既有行為。`showIndex`（斑馬紋）
邏輯也相同：品號 tab 用 `td004` 當群組鍵，訂單 tab 用 `tc001+tc002`。

# 訂單細項比品號細項多一欄「贈品量」

`SO_DETAIL_COLS`（訂單細項）比 `PRODUCT_DETAIL_COLS`（品號細項）多一欄
`td024`（贈品量），對照舊版 cshtml 的 `table-so-detail` 比 `table-product-detail`
多一個 `data-field="td024"`。品號統計/訂單統計兩個 tab 都沒有這欄。

# 明細 modal：兩個 tab 打的是不同 API

跟銷貨檢索不一樣 —— 銷貨檢索兩個明細 modal 都打同一支 `getSalesOrder1`；
未完成訂單的兩個明細 modal 打的是**不同**的 API：

| Modal | 打哪支 API | 篩選方式 | 對照舊版函式 |
|---|---|---|---|
| 單一品號明細 | `GetUnfinOrder`（groupName=TD004） | `productNo = row.td004` + 目前查詢條件 | `onClickShowProductDetail` |
| 單一訂單明細 | `QueryUnfinOrder_1`（groupName=TC001） | `poNo = "{tc001}-{tc002}"` | `onClickShowSoDetail` |

> **與舊版的差異（刻意簡化 + 修正）**：
> 1. 舊版兩個 modal 的「總金額」是從查詢結果裡 `footerFlag=='Y'` 的小計列取
>    `item.ntd`，邏輯繞了一圈；2.0 直接用外層列（品號統計/訂單統計那一列）
>    自帶的 `row.ntd`（那一列本來就是分群小計），結果等價但少一層轉換。
> 2. 舊版兩個明細 modal 的表格欄位**沒有掛 `per-amount` class**，不管有沒有
>    金額權限都看得到金額 —— 跟銷貨檢索原本的漏洞一樣。2.0 統一用 `showAmount`
>    旗標控制外層四個頁籤與兩個 modal，明細 modal 也會照樣隱藏金額欄位。

# 金額欄位權限

`FunctionId.QueryUnFinish(420)` 底下 `LinkType=100` 控制金額欄位（原幣單價/金額、
幣別、匯率、台幣金額、付款條件、課稅別）。跟銷貨檢索共用同一個 `usePermission()`
composable，只是 functionNo 換成 420：

```
usePermission().checkLinkTypePermission(420, 100)
```

`LinkType=100` 這個數字跟銷貨檢索相同，但 `M_Permission` 是
`(帳號, FunctionNo, LinkType)` 組合鍵，兩個功能各自獨立判斷，互不影響
（比對某帳號在銷貨檢索有沒有權限，不代表在未完成訂單也有）。

# 查詢條件：哪些真的送到後端

| 條件 | 誰處理 |
|---|---|
| 客戶別／品號種類／品號／品名／規格／序號／訂單單號(poNo)／計畫批號／訂單日期／預交日期 | 後端（SP 直接吃） |
| 訂單單別(orderType) | 後端 LINQ 二次過濾（SP 不支援），保留 `Y` 小計列 |
| 期間格式 | 前端轉成 `YYYYMMDD`（`toCompactDate()`） |

預設訂單日期是 90 天（`UI_InitQueryDate(..., 90)`），**預交日期預設不設定**，
兩組日期各自有「清除」按鈕（對照舊版 `onClickClearSalesOrderDate` /
`onClickClearDeliveryDate`）。查無資料時後端回 `isSuccess: false` + 說明訊息，
不是錯誤，當空清單處理。

# 匯出 Excel

`ExportXls` 回傳的 `body` 是相對於 **.NET 站台根目錄**的路徑，前端補
`/ShareRoot/` 前綴後走 `server/api/download.get.ts` 中繼下載，跟銷貨檢索作法一致。

> **與舊版的差異**：舊版 `onExportCopXls()` 呼叫 `API_ExportXls` 時**參數位置對錯**
> （`inPlanNumber` 的值落到 `orderType` 的參數槽，導致 `orderType`/`orderNo`/
> `groupName`/`groupDesc` 全部錯位或遺漏），是原始碼裡的既有 bug。2.0 改用具名
> 參數的 `UnfinOrderQuery` 物件呼叫，不會有這個問題；`groupName` 固定送 `TC001`
> （比照銷貨檢索匯出的慣例），後端 `ExportXls` 本來就是自己組品號/訂單兩份資料，
> 不太理會前端傳的 `groupName`，所以這個修正對匯出結果沒有實質影響，只是讓
> 呼叫端的程式碼正確、好維護。

# 頁面

| 路徑 | 對應舊畫面 | 說明 |
|---|---|---|
| `/sales-center/sales-search/unfinished-orders` | `Mix/QueryUnFinish` | 未完成訂單檢索：4 個頁籤 + 2 個明細 modal + Excel 匯出 |

# 尚未搬移

- 頁面級功能權限檢查 `checkPermission(functionId)`（`MainApi/CheckUserPermission`）——
  跟銷貨檢索一樣，2.0 目前假設能進到路由就有權限
- `SalesOrderViewModel` 底下 `VUnfinOrder` / `VUnfinOrderSum`（1.0 程式碼裡存在但
  目前沒被這個功能實際查詢路徑使用的舊 view model），沒有對應的畫面需求，不搬
</details>

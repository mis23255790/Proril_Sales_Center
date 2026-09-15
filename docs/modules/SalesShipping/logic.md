<details>
  <summary>程式邏輯</summary>

###### 對應舊系統
     PRORIL (.NET MVC) 的「業務檢索」系統下的「銷貨檢索」
       Controllers/MixSalesShip/MixSalesShipController.cs   MVC 入口（回空 View）
       Views/Mix/SalesShipping.cshtml
       wwwroot/js/mix/{sales-shipping, sales-shipping-apis}.js
       Controllers/MixSalesShip/MixSalesShipApiController.cs        ← 已搬（見下）
       Controllers/MixSalesShip/MixSalesShipApiController_XlsOut.cs ← ExportXls，已搬
       SystemId.MixSales = 32 / FunctionId.MixSalesShipping = 410

###### 對應 2.0 後端
       api/Controllers/SalesSearch/MixSalesShipApiController.cs      GetSalesOrder / GetSalesOrder_1
       api/Controllers/SalesSearch/MixSalesShipApiController.Xls.cs  ExportXls
       api/Data/SalesShippingEntities.cs                             CopSalesOrder

###### 相關資料表 / 預存程序
     COP_SalesOrder（EF: CopSalesOrder）  ERP 銷貨單明細快取，也是兩支查詢 SP 的結果集形狀
     prc_ImportSalesOrder     從鼎新 ERP（linked server [192.168.1.200]）增量補 COP_SalesOrder
                              兩支查詢 SP 進來第一行就叫它 → **查詢其實會寫資料**
     prc_QuerySalesOrder      依品號(TH004)分群，GetSalesOrder 呼叫
     prc_QuerySalesOrder_1    依銷貨單(TH001+TH002)分群，GetSalesOrder_1 呼叫
                              也是兩個明細 modal 在用（帶 orderType/orderNo 篩單一銷貨單）
     M_Permission / M_PermissionLinkType   金額欄位權限（FunctionNo=410, LinkType=100）
</details>

# 架構：前後端都在 2.0

```
Nuxt 頁面 ──▶ useSalesShippingApi() ──▶ /api/proxy/... ──▶ server/api/proxy/[...path].ts
                                                              └─▶ NUXT_PUBLIC_API_BASE /MixSalesShipApi/...
```

`NUXT_PUBLIC_API_BASE` 指到 `api/` 或 1.0 站台都能跑——端點名稱、參數大小寫與回傳信封
一字不差（`GetSalesOrder_1` 的 `OrderType`/`OrderNo` 是大寫開頭，其餘小寫開頭，別順手改）。

- 查詢邏輯在預存程序裡，要改回 `database/SalesShippingObjectsMigration.sql`
  （那份是從 `PRORIL_WEB` 原樣抄出來的，1.0 repo 的 `DB/prc_QuerySalesOrder_1.sql`
  是舊版本，不要拿它當準）；欄位與匯出版面要改，回
  `api/Controllers/SalesSearch/MixSalesShipApiController*.cs`。
- **資料庫物件目前還在 `PRORIL_WEB`**：`api/` 的 `CopSalesOrder` 對映在
  `ProrilWebDbContext`，`EXEC prc_QuerySalesOrder(_1)` 也還是在舊庫執行。
  搬到 `Proril_Sales_Center` 的腳本已經產好但**尚未執行**，細節與注意事項見
  `database/PortingNotes.md`「銷貨檢索相關的表 / 預存程序」。

## 與 1.0 後端的差異（刻意的）

| 項目 | 1.0 | 2.0 |
|---|---|---|
| SQL 參數 | 把使用者輸入串進 `EXEC` 字串 | `FromSqlInterpolated` 交給 EF 參數化 |
| 匯出版面 | 讀 `PUR_XlsFileFormat`（FunctionNo=410）動態組表頭/欄寬/數字格式 | 寫死在 C#（表頭與數字格式照抄那張表），欄寬改用 `AdjustToContents()` |
| 匯出用的 EF 型別 | 另一個空殼型別 `CopMdlSalesOrder1`（對映 0 筆的 `COP_MDL_SalesOrder_1`） | 與查詢共用 `CopSalesOrder`，那張表不搬 |
| try/catch | 每個 action 自己包 | 全域 `ApiExceptionFilter`，見 CLAUDE.md |

# 兩支查詢 API，同時打，餵給不同分頁

`load()` 用 `Promise.all` 同時打兩支：

| API | groupName | 分群鍵 | 餵給哪個頁籤 |
|---|---|---|---|
| `GetSalesOrder` | `TH004` | 品號 | 品號細項 / 品號統計 |
| `GetSalesOrder_1` | `TH001` | 銷貨單別+單號 | 銷貨單細項 / 銷貨單統計 |

兩支的過濾參數幾乎一樣（客戶／期間／品號／品名／規格／序號／訂單單號／計畫批號），
只有 `groupName` 不同。`GetSalesOrder_1` 多帶 `orderType` / `orderNo`，
但只有「單一銷貨單明細」modal 才會填值，一般查詢兩者都送空字串。

> 舊畫面「訂單單號」欄位（`#inputOrderNo`）實際送的是 `poNo` 參數，
> 不要跟 `orderType`/`orderNo` 搞混 —— 那兩個只有明細 modal 篩單一筆時才用。

# FooterFlag：細項/統計怎麼分

`prc_QuerySalesOrder_1.sql` 逐筆處理時會依群組筆數插入額外列：

| Flag | 意思 | 產生時機 |
|---|---|---|
| `N` | 逐筆明細列 | 每一筆原始資料都會產生一列 |
| `Y` | 群組小計 | 同一個群組（TH001+TH002 或 TH004）筆數 > 1 才產生 |
| `S` | 單筆升格 | 群組剛好只有 1 筆時，那筆明細直接變成小計（不另外產生 Y 列） |
| `T` | 總計 | 整批查詢結果的最後一列 |

畫面顯示規則（`app/utils/salesShipping.ts` 的 `isDetailRow` / `isSummaryRow`）：

```
細項 tab = FooterFlag != 'Y'   (N + S + T)
統計 tab = FooterFlag != 'N'   (S + Y + T)
```

**兩邊都吃得到 `T`（總計列）**，這是舊系統的既有行為，照搬，不是 bug。

`showIndex`（斑馬紋交錯用）是前端自己補的：同一個群組鍵（品號 tab 用 `th004`，
銷貨單 tab 用 `th001+th002`）相鄰列共用一個號碼，換群組才 +1（`assignShowIndex()`）。

# 品號種類勾選框

`getProductType(show5x, showX)`：

| show5x | showX | 送給後端的 productType |
|---|---|---|
| 否 | 否 | `A`（含 9 開頭等其他品號，不篩） |
| 是 | 是 | `a` |
| 是 | 否 | `5` |
| 否 | 是 | `x` |

「全部」按鈕會把兩個勾選都取消（送 `A`）並把日期展開到 20 年；
「重設」則兩個都勾回去，日期退回預設區間。

# 金額欄位權限

`FunctionId.MixSalesShipping(410)` 底下 `LinkType=100` 專門控制金額欄位
（單價／小計／幣別／匯率／台幣未稅／稅額／總額）。

```
usePermission().checkLinkTypePermission(410, 100)
  ──▶ GET /MainApi/CheckUserPermissionLinkType?functionNo=410&linkType=100
  ──▶ 回裸 bool（這支 API 例外，不是 ApiResponse 信封）
```

每次進頁面即時查一次，**不快取進 token**（舊系統也是這樣，見
`MainApiController_SystemSetting.CheckUserPermissionLinkType`：`IsAdmin` 帳號直接
放行，否則查 `M_Permission` 有沒有 `(帳號, FunctionNo=410, LinkType=100)` 這一列）。

`LinkType` 沒有跨功能通用的常數表 —— 100 只在 FunctionId=410 底下有這個意思，
其他功能的 LinkType 各自定義，不要拿去共用。

沒有權限時，四個頁籤與兩個明細 modal 的金額欄位**整欄不渲染**（不是模糊或唯讀），
對照舊版 `bootstrapTableHideColumn(..., 'per-amount')`。

> **與舊版的差異（刻意修正）**：舊版兩個明細 modal（`#modalProductDetail` /
> `#modalSoDetail`）的表格欄位**沒有掛 `per-amount` class**，等於不管有沒有權限，
> 點進明細永遠看得到金額 —— 這是舊畫面的權限漏洞。2.0 統一用同一個 `showAmount`
> 旗標控制外層四個頁籤與兩個 modal，明細 modal 也會照樣隱藏金額欄位。

# 查詢條件：哪些真的送到後端

| 條件 | 誰處理 |
|---|---|
| 客戶別／期間／品號種類／品號／品名／規格／序號／訂單單號(poNo)／計畫批號 | 後端（GetSalesOrder / GetSalesOrder_1） |
| 期間格式 | 前端轉成 `YYYYMMDD`（`toCompactDate()`），對照舊版 `getDateStringCompact()` |

預設期間是 90 天（對照舊版 `UI_InitQueryDate(..., 90)` 的行為）。
查無資料時後端回 `isSuccess: false` + 說明訊息，**不是錯誤**，當空清單處理。

# 匯出 Excel

`ExportXls` 回傳的 `body` 是相對於 **.NET 站台根目錄**的路徑（不含開頭 `/ShareRoot/`），
前端要自己補這個前綴，並走 `server/api/download.get.ts` 中繼下載（同源 + 強制附件），
不能像舊版 `window.open('/ShareRoot/'+body)` 直接開（跨網域）。

匯出送的 `groupName` 固定是 `TH001`（銷貨單分群），對照舊版 `onExportCopXls()`。

# 頁面

| 路徑 | 對應舊畫面 | 說明 |
|---|---|---|
| `/sales-search/shipping-inquiry` | `Mix/SalesShipping` | 銷貨檢索：4 個頁籤 + 2 個明細 modal + Excel 匯出 |

# 尚未搬移

搬過來的是銷貨檢索這一支查詢頁的前端與它用到的三支後端端點
（`GetSalesOrder` / `GetSalesOrder_1` / `ExportXls`）。以下舊功能**還沒做**，需要時再補：

- 1.0 同一支 `MixSalesShipApiController` 底下的其他端點，它們屬於別的模組、
  2.0 前端目前也沒有呼叫：`GetCOPOrder`（早期/未用的全表查詢，畫面上沒有入口）、
  `GetFinalQuotation` / `ExportCustomerPrice`（報價）、`GetSalesTotal` /
  `GetCustomerOrderTotal` / `GetCustomerUnfinOrder`（客戶相關頁籤）。
  其中 `GetSalesTotal` 走的 `V_SalesTotal` 也讀 `COP_SalesOrder`，
  搬它的時候要一併處理那張表的歸屬。
  `GetCustomerCredit` / `GetCustomerCreditCRM`（同樣是客戶相關頁籤）後端已搬進
  `MixSalesShipApiController.CustomerCredit.cs`（依賴的 `prc_COPGetCredit(_CRM)`
  跟訂單資料檢核共用），但 2.0 前端還沒有頁面呼叫，見 `../../../api/README.md`
  「客戶信用額度」。
- 頁面級功能權限檢查 `checkPermission(functionId)`（`MainApi/CheckUserPermission`）——
  2.0 目前假設能進到路由就有權限，之後若要做選單/路由層級的權限守衛再補
- `業務檢索`系統底下其他功能（報價、應收帳款、未完工訂單等，`MixSalesShip` 目錄下
  其餘 controller），本次只搬「銷貨檢索」一項
</details>

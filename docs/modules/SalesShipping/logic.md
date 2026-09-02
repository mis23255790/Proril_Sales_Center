<details>
  <summary>程式邏輯</summary>

###### 對應舊系統
     PRORIL (.NET MVC) 的「業務檢索」系統下的「銷貨檢索」
       Controllers/MixSalesShip/MixSalesShipController.cs   MVC 入口（回空 View）
       Views/Mix/SalesShipping.cshtml
       wwwroot/js/mix/{sales-shipping, sales-shipping-apis}.js
       Controllers/MixSalesShip/MixSalesShipApiController.cs        ← **後端沒搬，繼續用**
       Controllers/MixSalesShip/MixSalesShipApiController_XlsOut.cs ← ExportXls
       SystemId.MixSales = 32 / FunctionId.MixSalesShipping = 410

###### 相關資料表 / 預存程序
     COP_SalesOrder（EF: CopSalesOrder）  查詢結果暫存表，兩支 API 都 FromSql 這張
     prc_QuerySalesOrder      依品號(TH004)分群，GetSalesOrder 呼叫
     prc_QuerySalesOrder_1    依銷貨單(TH001+TH002)分群，GetSalesOrder_1 呼叫
                              也是兩個明細 modal 在用（帶 orderType/orderNo 篩單一銷貨單）
     M_Permission / M_PermissionLinkType   金額欄位權限（FunctionNo=410, LinkType=100）
</details>

# 架構：只搬前端

跟 `docs/modules/SalesIssue/logic.md`（業務議題）一樣，只搬 Nuxt 前端，後端沿用 1.0 的 `MixSalesShipApi`。

```
Nuxt 頁面 ──▶ useSalesShippingApi() ──▶ /api/proxy/... ──▶ server/api/proxy/[...path].ts
                                                              └─▶ NUXT_PUBLIC_API_BASE (.NET) /MixSalesShipApi/...
```

- **沒有新後端、沒有動資料庫**（含 View / StoredProcedure）。
- 任何查詢邏輯要改，回 `PRORIL/DB/prc_QuerySalesOrder(_1).sql`；欄位要改，回
  `MixSalesShipApiController.cs`。

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

搬過來的是銷貨檢索這一支查詢頁。以下舊功能**還沒做**，需要時再補：

- `MixSalesShipApi/GetCOPOrder`（早期/未用的全表查詢，畫面上沒有入口）
- 頁面級功能權限檢查 `checkPermission(functionId)`（`MainApi/CheckUserPermission`）——
  2.0 目前假設能進到路由就有權限，之後若要做選單/路由層級的權限守衛再補
- `業務檢索`系統底下其他功能（報價、應收帳款、未完工訂單等，`MixSalesShip` 目錄下
  其餘 controller），本次只搬「銷貨檢索」一項
</details>

<details>
  <summary>程式邏輯</summary>

###### 對應舊系統
     PRORIL (.NET MVC) 的「業務檢索」系統下的「客戶查詢」與「客戶相關訊息」
       Controllers/MixSalesShip/CustomQueryApiController.cs
       Controllers/MixSalesShip/MixSalesShipApiController.cs（客戶相關的四支端點）
       Controllers/WorkProcess/WorkProcessApiController.cs（GetWPOrderForCustom）
       Views/Mix/{CustomQuery, CustomerRelated}.cshtml
       wwwroot/js/mix/{custom-query, custom-query-apis, customer-related, customer-related-apis}.js
       SystemId.MixSales = 32 / FunctionId.CustomQuery = 440（1.0 畫面 top-title 顯示「客戶檢索」）
                         / FunctionId.CustomerRelated = 441（「客戶相關訊息」）

###### 相關資料表 / View / SP
     CRM_Customer      內網客戶主檔（客戶檢索唯一會寫入的表）
     CRM_CustomerMemo  客戶情報（客戶相關資訊「情報」頁籤唯一會寫入的表）
     V_ERPCustomer     ERP 客戶唯讀 View，同一個 MA001 可能重複匯入多筆
     V_SalesTotal      年／月銷售統計，只 GROUP BY COP_SalesOrder
     V_UnfinOrder      未完成訂單明細（每次查都直接打 ERP linked server）
     prc_COPGetCredit_CRM  信用額度，跟訂單資料檢核共用
     D_WorkProcess / D_WorkProcessCustomer  議題頁籤
     M_User            業務負責人下拉、情報與議題的作者姓名
</details>

# 架構：後端擴充既有的 Shared/CustomQueryApiController

跟其他模組不同，這個功能**不是**新開一支後端，而是在既有的
`api/Controllers/Shared/CustomQueryApiController.cs` 上加方法：

```
Nuxt 頁面 ──▶ useCustomerApi() ──▶ /api/proxy/CustomQueryApi/{GetCustom,GetERPCustom,SaveCustom}
                                       └─▶ api/ 的 CustomQueryApiController（Shared）
```

`GetCustom` 是**既有**端點（業務議題編輯頁的「客戶別」下拉、銷貨檢索/未完成訂單檢索的
客戶篩選都在用），這次只加 `GetERPCustom`（ERP 客戶清單）跟 `SaveCustom`（新增/更新客戶）。

**為什麼不獨立開 `SalesSearch/` 資料夾**：`BaseApiController` 用
`[Route("[controller]/[action]")]`，路由是從 controller **class 名稱**產生的
（`CustomQueryApiController` → `CustomQueryApi/*`）。1.0 前端跟這次的 Nuxt 前端
都打這個固定 URL，class 名稱不能改也不能重複，所以新方法只能加在同一個既有 class 上，
維持在 `Shared/`（本來就是給多模組共用的客戶查詢邏輯）。

# 客戶備註（CustomerMemo）：在客戶檢索是死碼，在客戶相關資訊才是活的

1.0 的 `custom-query-apis.js` 有 `API_GetCustomMemo` / `API_SetCustomMemo`，
`custom-query.js` 也有對應的 `onClickAddNewMemo` / `reload_custom_memo` /
`operateEventsMemoEdit` 等函式，但**對照 `Views/Mix/CustomQuery.cshtml`，
畫面上完全沒有 `#table-customer-memo` / `.memo-editor` 這些 DOM 元素**——
在客戶檢索這一頁是死碼。

真正在用這組 API 的是 `Views/Mix/CustomerRelated.cshtml` 的「情報」頁籤
（那裡才有 `#table-customer-memo` 與 `.memo-editor`）。2.0 把它連同整個
客戶相關資訊一起搬過來了，見下面「客戶相關資訊」那節。

1.0 畫面另外規劃過「內網客戶／ERP客戶／**全部**」三個頁籤，但「全部」那個
`<input type="radio" id="tab-all">` 在 View 裡整段被註解掉，只有前兩個頁籤
真的在用，2.0 只做這兩個。

# GetERPCustom：ERP 客戶去重 + 左併內網客戶代碼

`V_ERPCustomer` 是唯讀 View，同一個 `MA001`（ERP 客戶代碼）可能因為匯入時機不同
被寫入多筆，所以先用 Trim 後的 `Ma001` 分組取每組第一筆（對齊 1.0
`DistinctBy(x => x.Ma001)`），再左併 `CRM_Customer.ErpcustomerNo`（同樣 Trim 後比對——
ERP 同步進來的字串常帶尾端空白，這是專案裡反覆出現的 bug 來源，兩邊都要 Trim）
補上目前掛勾的內網客戶代碼，查無對應客戶時是空字串，前端用它判斷「這個 ERP
客戶有沒有建過內網客戶」（ERP 客戶頁籤的「內網客戶代碼」欄 + 功能欄按鈕文字）。

`customNo` 參數保留但沒真的拿來過濾（對齊 1.0：那段 filter 邏輯本來就整段被註解掉），
只有 `erpCustomNo` 是真的有效的過濾條件。

# SaveCustom：新增走年份流水號，更新用 CustomerNo 比對

```
customerNo 空白／查無資料 → 新增：CustomerNo = "{兩位數年份}{3 位數流水號}"
                              流水號 = 同年度、且流水號 <= 100 的既有客戶裡最大的 +1
customerNo 有對到既有客戶 → 更新該筆
```

流水號上限 `<= 100` 這個怪條件是照搬 1.0 原始邏輯（`Int64.Parse(...) <= 100`），
沒去查為什麼是 100，維持原樣以免改動既有客戶編碼規則。

**ERP 客戶代碼衝突檢查**：儲存前檢查是否已有「另一個」內網客戶掛同一個
ERP 客戶代碼（`ErpcustomerNo` 相同、`CustomerNo` 不同），有的話直接擋掉、
回錯誤訊息「已有內網客戶代碼關連到ERP客戶代碼{xxx}」，不寫入。

> **與 1.0 的差異（修正遺漏）**：1.0 的 `custom-query-apis.js` 的
> `API_SaveCustom` 呼叫時，`ContactTel2` / `ContactFax` / `Addr1` / `Addr2`
> 四個參數整行被註解掉（`//ContactTel2: contactTel2,` 這種寫法），代表
> 1.0 畫面上這幾個欄位輸入了也不會存進去，是前端的既有漏洞。後端
> `SaveCustom` 本身（含這次搬過來的版本）一直都支援這四個欄位，2.0 前端
> 補上正常送出，讓這些欄位真的能存檔。

# 客戶清單畫面：兩個頁籤各自打不同 API，資料互不相依

`load()` 用 `Promise.all` 同時打 `GetCustom`（內網客戶頁籤）跟 `GetERPCustom`
（ERP 客戶頁籤），互不依賴、各自的查詢框（內網客戶代碼 / ERP客戶代碼）都會
同時當作兩支 API 的篩選條件送出去（對齊 1.0 `showCustomList()` 的行為）。

# 編輯 Modal：從兩個頁籤都能開，資料來源不同

- **內網客戶頁籤「編輯」**：直接把該列資料（`CustomerWithErp`）灌進表單。
- **ERP 客戶頁籤「編輯／建立客戶」**：
  - 該 ERP 客戶已經有對到的內網客戶（`row.customerNo` 非空）→ 從已載入的
    內網客戶清單裡找出那筆，灌進表單（等於「編輯」）。
  - 還沒有對到的客戶 → 表單清空，只預填 `erpcustomerNo`/`shortName`/
    `longName`/`contactName`/`contactTel1`（來自 ERP 資料，當新增的起始值），
    使用者存檔後才會真的產生一筆新的 `CRM_Customer`。

Modal 裡另外有一塊「ERP 資料參考（唯讀）」，依表單目前選到的 `erpcustomerNo`
從已載入的 ERP 客戶清單找對應資料顯示，純參考用，不會覆寫使用者已經編輯過的
內網欄位——這點跟 1.0 一樣：ERP 端資料跟內網客戶資料是兩份獨立欄位，
不會自動同步。

# 業務負責人下拉

沿用既有的 `MainApi/GetUserList`（`M_User.IsEnable = true`，帳號+姓名），
跟業務議題指派負責人用同一支端點，這次沒有新增後端。

# 客戶相關資訊（原 `Mix/CustomerRelated`，FunctionNo 441）

同一個客戶的六個面向攤成六個頁籤。**它沒有自己的查詢列**，客戶是從網址參數帶進來的
（1.0 的查詢列在 View 裡整塊 `hidden`，對應的 JS 函式也沒定義，本來就不能單獨使用）。

## 入口：從客戶檢索整列點擊進來，不進側欄

1.0 的 `EnumFunctionIds.cs` 就寫了 `// No entry from UI, click button`——441 登記在
`M_Function` 的用途是**當權限掛載點**，不是選單項目。2.0 照這個語意做：
`NAV_MODULES` 沒有它、`PermissionMasterSeed.sql` 的 `@FunctionNos` 也沒有它，
麵包屑用 `breadcrumbFor(appPath('sales-search/customer'), '客戶相關資訊')`
掛在客戶檢索底下。

客戶檢索**兩個頁籤的整列點擊都是進這一頁**（符合「表格整列可點擊」規範），
編輯客戶移到功能欄按鈕。兩個頁籤帶的參數不同：
內網客戶頁籤帶 `(customerNo, erpcustomerNo)`，ERP 客戶頁籤帶 `(customerNo, ma001)`。

功能欄的按鈕叫**「編輯基本資料」**（ERP 客戶頁籤在還沒建內網客戶時顯示「建立內網客戶」），
不是只叫「編輯」——整列點擊改成跳客戶相關資訊之後，同一列上有兩個不同去向，
光寫「編輯」看不出來編的是 `CRM_Customer` 那幾個欄位。開出來的 modal 標題同樣是
「客戶基本資料」。這顆按鈕跟客戶相關資訊「基本資料」頁籤看到的是同一份資料，
差別只在那邊唯讀、這邊可編輯。

## 內網客編與 ERP 客編是兩把不同的鑰匙，不能混用

這是整頁最容易寫錯的地方：

| 頁籤 | 用哪個客編 | 資料來源 |
|---|---|---|
| 基本資料 | 兩個都用 | `CRM_Customer` + `V_ERPCustomer` |
| 情報 | **內網**客編 | `CRM_CustomerMemo.CustomerNo` |
| 議題 | **內網**客編 | `D_WorkProcessCustomer.CustomerNo` |
| 訂單 | **ERP** 客編 | `V_UnfinOrder.TC004` |
| 銷售 | **ERP** 客編 | `V_SalesTotal.CustomerNo`（**欄名騙人，存的是 ERP 客編**） |
| 信用額度 | **ERP** 客編 | `prc_COPGetCredit_CRM` 的參數 |

> **與 1.0 的差異（修正遺漏）**：1.0 是直接拿網址上的 `Customer` 去查情報與議題。
> 從 ERP 客戶清單點進來時那個值是空的（`GetCustomMemo` 在只有 `erpCustomerNo` 時
> 還會刻意把結果清空、`GetWPOrderForCustom` 的簽章連 `erpCustomerNo` 都沒收），
> 所以那條路徑進來的人永遠看到兩個空頁籤。2.0 改成**先用 `GetCustom` 以 ERP 客編
> 反查內網客戶**（那支本來就支援用 ERP 客編過濾），再拿查回來的內網客編去查情報與議題，
> 兩個入口看到的內容一致。頁面上的 `effectiveCustomerNo` / `effectiveErpCustomerNo`
> 就是在做這件事，所以基本資料一定要先載完才能載其他四個頁籤，不能六支全部併發。

## 訂單與銷售的彙總在前端做

後端刻意回原始明細（端點形狀與 1.0 一字不差），彙總邏輯搬到
`app/utils/customerRelated.ts`：

- **`toUnfinOrderSummary`**：`V_UnfinOrder` 是逐筆品項，依「單別+單號」彙總成一列。
  品號開頭 `5` 算成品、`x` 算零件，分兩組統計數量與金額（金額 = 原幣金額 `TD012`
  × 匯率 `TC009`），其餘品號不計入金額但那張訂單仍會列出。單別 `2700`（詢問單）整批濾掉。
  `x` 只比對小寫，跟 1.0 以及 `V_SalesTotal` 的 `in ('5','x')` 一致（DB 定序是 BIN）。
- **`toSalesYearRows`**：`V_SalesTotal` 同一支查詢混著兩種列——`YM` 長度 4 是年度總計、
  長度 6 是該年某月。轉成每年一列（12 個月 + 年度合計），沒有資料也一定保留
  今年／去年／前年三列，最後加一列 Total。**Total 只加總各月、不加年度總計列**，
  否則同一筆金額會被算兩次。

`V_SalesTotal` 的 `YM` 是從**銷貨單號 `TH002`** 推出來的（前 3 碼民國年 +1911、
第 4~5 碼月份），不是銷貨日期 `TG003`。看起來取巧但那是 1.0 的既有語意，
改用 `TG003` 會讓歷史數字整批位移。那支 View 兩段 `UNION` 都有 `TOP 10000` 卻沒有
`ORDER BY`，資料量超過上限時會靜默漏資料——同樣是既有寫法，搬移時照抄不動。

## 六個頁籤的權限：先全開

1.0 用 `M_Permission.PermissionLinkTypeId` 10/20/30/40/50/60 對應六個頁籤，
但那段檢查**實際上是壞的**：`CommonApiController.GetPermission` 的 `where` 整段被註解，
直接回傳整張 `M_Permission`，只要全系統任一筆權限的 `PermissionLinkTypeId` 落在
10~60 就會開該頁籤，等於誰都看得到全部。`customer-related.js` 的
`checkPermission(functionId)` 也被註解掉，任何登入者打 URL 都進得來。

2.0 這次維持六個頁籤全開，跟其他業務檢索頁一致（那幾頁也都沒做頁面級權限檢查）。
真的要管控時要連 `M_PermissionLinkType` 的六筆、權限管理畫面的細項一起做。

# 頁面

| 路徑 | 對應舊畫面 | 說明 |
|---|---|---|
| `/sales-center/sales-search/customer` | `Mix/CustomQuery` | 客戶檢索：2 個頁籤（內網客戶／ERP客戶）+ 新增/編輯客戶 modal |
| `/sales-center/sales-search/customer-related` | `Mix/CustomerRelated` | 客戶相關資訊：6 個頁籤 + 情報新增/編輯/刪除 modal。靠 `?customer=&erpCustomerNo=` 帶客戶 |

# 尚未搬移

- 「全部客戶」頁籤——1.0 View 裡整段註解掉，沒有實際使用。
- 頁面級功能權限檢查 `checkPermission(functionId)` 與六個頁籤的細項權限——
  跟其他業務檢索頁面一樣，2.0 目前假設能進到路由就有權限，見上面那節。
- **客戶相關資訊的兩個下鑽連結**：1.0 點訂單金額會開
  `/Mix/QueryUnFinish?erpCustomerNo=&orderType=&orderNo=`、點銷售月份會開
  `/Mix/SalesShipping?erpCustomerNo=&start_date=&end_date=`。2.0 那兩頁
  （`unfinished-orders` / `shipping-inquiry`）目前都不讀 query 參數，接了連結也不會
  帶進篩選條件，所以這次沒接。要補的話得先讓那兩頁支援初始篩選條件；
  日期區間的換算 `salesMonthRange()` 已經先寫在 `app/utils/customerRelated.ts` 裡。
  （議題那個下鑽有接：點議題列會進 `/sales-center/sales-issue/issues/{wpno}`。）
- `GetCustomerOrderTotal` / `GetCustomerCredit`（舊版信用額度）——前者條件寫反、
  永遠回空清單且前端已註解，後者 1.0 畫面實際用的是 CRM 版本。兩支都是死碼，不搬。
</details>

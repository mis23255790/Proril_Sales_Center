<details>
  <summary>程式邏輯</summary>

###### 對應舊系統
     PRORIL (.NET MVC) 的「業務檢索」系統下的「客戶查詢」
       Controllers/MixSalesShip/CustomQueryApiController.cs
       Views/Mix/CustomQuery.cshtml
       wwwroot/js/mix/{custom-query, custom-query-apis}.js
       SystemId.MixSales = 32 / FunctionId.CustomQuery（1.0 畫面 top-title 顯示「客戶檢索」）

###### 相關資料表 / View
     CRM_Customer      內網客戶主檔（唯一會寫入的表）
     V_ERPCustomer     ERP 客戶唯讀 View，同一個 MA001 可能重複匯入多筆
     M_User            業務負責人下拉（MainApi/GetUserList，既有端點）
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

# 沒有搬的部分：客戶備註（CustomerMemo）

1.0 的 `custom-query-apis.js` 有 `API_GetCustomMemo` / `API_SetCustomMemo`，
`custom-query.js` 也有對應的 `onClickAddNewMemo` / `reload_custom_memo` /
`operateEventsMemoEdit` 等函式，但**對照 `Views/Mix/CustomQuery.cshtml`，
畫面上完全沒有 `#table-customer-memo` / `.memo-editor` 這些 DOM 元素**——
這組 API 跟 JS 函式在 1.0 實際頁面上叫不到，是死碼。2.0 不搬這塊，
也沒有新增 `CrmCustomerMemo` 的 EF 實體/API。

同理，1.0 畫面規劃過「內網客戶／ERP客戶／**全部**」三個頁籤，但「全部」那個
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

# 頁面

| 路徑 | 對應舊畫面 | 說明 |
|---|---|---|
| `/sales-center/sales-search/customer` | `Mix/CustomQuery` | 客戶維護：2 個頁籤（內網客戶／ERP客戶）+ 新增/編輯客戶 modal |

# 尚未搬移

- 客戶備註（`CrmCustomerMemo` / `GetCustomMemo` / `SetCustomMemo`）——1.0 畫面沒有
  對應 UI，是死碼，需要時再依實際需求重新設計（不是照搬，因為原本就沒有可參考的畫面）。
- 「全部客戶」頁籤——1.0 View 裡整段註解掉，沒有實際使用。
- 頁面級功能權限檢查 `checkPermission(functionId)`——跟其他業務檢索頁面一樣，
  2.0 目前假設能進到路由就有權限。
</details>

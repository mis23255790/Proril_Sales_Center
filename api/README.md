# Proril.SalesIssue.Api

業務議題的後端，從 1.0 `PRORIL`（.NET MVC）搬過來的。net8.0 + EF Core 8 + SQL Server。

前端把 `NUXT_PUBLIC_API_BASE` 指到這支就會直接跑 —— 端點名稱、參數大小寫、
回傳信封（`{ isSuccess, message, body, body2 }`）都與 1.0 一字不差。

## 設定

```bash
cd api
cp appsettings.Development.json.example appsettings.Development.json
# 填 ConnectionStrings:ProrilWeb（其餘的範例檔已帶好）
dotnet run
```

`appsettings.Development.json` 已被 `.gitignore` 擋掉，不會進版控。
部署環境改用環境變數（`:` 換成 `__`）：

| 設定 | 環境變數 | 說明 |
|---|---|---|
| `ConnectionStrings:ProrilWeb` | `ConnectionStrings__ProrilWeb` | PRORIL_WEB 連線字串 |
| `JwtSettings:Issuer` / `SignKey` | `JwtSettings__SignKey` | **必須與 1.0 相同**，否則 token 不互通 |
| `Security:AesKey` | `Security__AesKey` | **必須與 1.0 相同**，否則登入驗不過密碼 |
| `Storage:ShareRoot` | `Storage__ShareRoot` | 附件共享根目錄，**必須與 1.0 指向同一處** |
| `Cors:AllowedOrigins` | — | 只有瀏覽器直接打 API 才需要 |

三個「必須與 1.0 相同」不是建議：
- SignKey 不同 → 使用者在 1.0 登入的 token 打這支一律 401
- AesKey 不同 → `M_User.Password` 是用 1.0 的金鑰加密的，永遠比對不過
- ShareRoot 不同 → 讀不到既有附件的 zip

## 搬了什麼、沒搬什麼

**搬了**（前端實際會呼叫的）：

| Controller | 端點 |
|---|---|
| `WorkProcessApi` | GetSOPList_Edit / GetSOPListAll / GetSOPOrder / SaveOrder / DisableOrder / GetSOPDetail / GetSOPDetailWSNo / GetEditorText / SaveDetail / DeleteSno / GetKindList / SaveKindData / GetWPOrderPhrase / SetWPOrderPhrase / GetWPOrderCustom / SetWPOrderCustom |
| `WorkProcessApi`（附件） | ClearSOPTempPath / UnzipAttachFileList / ZipAttachFileList / UpdateDBAttachFile / EnumTempUploadAttach / DelDetailAttach / GetDownloadUrl |
| `WorkProcessApi`（權限） | SetWPNoPermissionEdit / SetWPNoPermissionView / AddWPNoPermissionEdit / GetWPNoPermission |
| `MainApi` | Login / GetCurrentUser / GetUserInfo / GetUserList |
| `UploadApi` | SaveByFileName |
| `CustomQueryApi` | GetCustom / GetERPCustom / SaveCustom |
| `OrderInfoVerifyApi` | GetPOCheckView / GetConditionList / CheckCOPOrderInfo / COPOrderInfoPassCheck / SP_GetCredit / SP_GetCreditCRM / ExportXls |
| `MainApi`（權限） | CheckUserPermissionLinkType |
| `MainApi`（人員管理） | GetUserSetting / AddUser / UpdateUser / DeleteUser / ResetPassword / UnlockUser / GetAllUserList |
| `MainApi`（權限管理） | GetMSystem / GetMFunction / GetMPermissionLinkType / GetPermissionLinkType / SetPermissionTree / SaveDepFunction / GetDepartmentList / GetUserFunctions |
| `MixSalesShipApi` | GetSalesOrder / GetSalesOrder_1 / ExportXls |
| `SalesOrderUnFinishApi` | GetUnfinOrder / QueryUnfinOrder_1 / ExportXls |
| `CommonApi` | GetDepFunction |

**沒搬**：
- 1.0 `ProrilWebContext` 的另外 335 個 DbSet。這裡只留業務議題碰得到的 12 個
  （10 張表 + `H_FileLink` 上傳 log + `V_ERPCustomer` 唯讀 View）、訂單資料檢核碰得到的
  11 個（見下方「訂單資料檢核」小節），以及銷貨檢索的 1 個（`COP_SalesOrder`）。
- `PRORILContext`（dsWorkFlowContext）——另一個資料庫，用不到。
- 版本進版 / 各版本備註 / 調整進度順序 / OrderReview —— 1.0 UI 早已隱藏。
- reCAPTCHA、首登強制改密碼 —— 登入流程的一部分，2.0 沒有對應畫面。
- 登入失敗鎖定（`M_User.PwdWrongTime`/`IsLocked` + `H_Logins`）—— 要連 `H_Logins`
  一起搬，屬於登入流程不是人員管理。2.0 補了 `MainApi/UnlockUser` 讓人員管理解得開鎖，
  但「登入失敗自動鎖定」這件事本身仍然只在 1.0 發生，見
  `../database/PortingNotes.md`「權限控管搬遷（第二輪）」。
- 1.0 權限相關的其他舊端點（SetPermission / SetPermissionLinkType / GetPermissionTree /
  GetFunctionPermissions / GetPermissionList / SaveDepFunction_Tree …）—— 1.0 畫面
  本身已經不呼叫它們了，只搬畫面實際打的那幾支。
- 組織管理（`OrgApiController`）—— `M_Department` 的維護畫面還在 1.0，2.0 只唯讀它。
- `UploadApi` 的 SaveZipFile / SaveByPath —— 其他模組在用，搬到那些模組時再補。
- `OrderInfoVerifyApi.SP_GetCreditCRM` 後端搬了，但前端目前沒有呼叫（比照 1.0，
  該功能在 1.0 前端本來就沒被實際用到）。
- 1.0 `MixSalesShipApiController` 底下不屬於銷貨檢索的端點：`GetCOPOrder`（沒有畫面入口）、
  `GetFinalQuotation`/`ExportCustomerPrice`（報價）、`GetSalesTotal`/`GetCustomerCredit`/
  `GetCustomerCreditCRM`/`GetCustomerOrderTotal`/`GetCustomerUnfinOrder`（客戶相關頁籤）。
  它們屬於別的模組，搬那些模組時再處理。
- 未完成訂單檢索頁面級功能權限檢查 `checkPermission(functionId)`（`MainApi/CheckUserPermission`）——
  跟銷貨檢索一樣，2.0 目前假設能進到路由就有權限，見
  `../docs/modules/SalesOrderUnfinish/logic.md`「尚未搬移」。

## 與 1.0 的行為差異

搬移過程中修掉的東西。**這些是刻意的**，不是漏搬：

1. **議題不會再無故從列表消失**（最重要）
   1.0 的 `getSOPList()` 對 `M_User` 用了兩個 inner join（`Creator`，以及
   「最新一則進度的 `Modifier`」）。只要 Creator 不在 `M_User`、最新進度的
   Modifier 不在 `M_User`、或**這張議題一則進度都還沒有**（`FirstOrDefault()`
   是 null，配不到任何帳號），整張議題就會從列表無聲消失。
   最後那一項代表「剛建好還沒寫進度的議題」根本看不到。
   這裡改成左外接，接不到就顯示空字串，議題照樣列出來。

2. **附件目錄的中間層統一用 wpNo 算**
   1.0 在這裡不一致：`ZipAttachFileList` / `UpdateDBAttachFile` /
   `EnumTempUploadAttach` 用 wpNo，`UnzipAttachFileList` / `UnzipAttachFile` 用 sNo。
   兩者在 wpNo 與 sNo 都小於 500 時剛好都是 0，現有資料看不出來；
   一旦超過就會「壓在 A 目錄、去 B 目錄找」，附件憑空消失。

3. **`SetWPOrderPhrase` / `SetWPOrderCustom` 接受空清單**
   1.0 空字串直接回錯，所以在畫面上把客戶改回「未指定」、或取消最後一個類別，
   是存不進去的。現在空清單就是「清空」。

4. **`GetEditorText` 會幫 SNo 補零**
   1.0 這支是少數沒補零的（`o.Sno == SNo` 直接比），傳 `1` 而不是 `0001` 就查無資料。

5. **加了路徑穿越防護**
   `UploadApi.SaveByFileName` 會確認解出來的路徑仍在 ShareRoot 內；
   附件相關端點的檔名一律只取 `Path.GetFileName`。1.0 沒有這些檢查。

6. **`/ShareRoot` 關閉目錄瀏覽**
   1.0 開著 `EnableDirectoryBrowsing`，等於任何人都能列出整個共享目錄。

7. **`ZipAttachFileList` 重壓失敗時保留舊 zip**
   先改名成 `.bak`，壓成功才刪。1.0 是先刪再壓，中途失敗就沒了。

8. **登入不再區分「帳號不存在」與「密碼錯誤」**，避免被用來列舉帳號。

## 訂單資料檢核（`OrderInfoVerifyApi`）

跟業務議題不同，這個模組的資料表不在 `database/` 的 DACPAC 版控範圍內（那批表本來就是
1.0 唯讀在用的既有表，不是這次搬移新增的），純粹是把 1.0 `OrderInfoVerifyApiController`
的邏輯搬進來，資料表結構完全比照 1.0 現況。

跟 1.0 的行為差異：

1. **`GetPOCheckView` 不再用 JSON 字串包兩層**
   1.0 把 `List<VPolistDetailViewModel>` 用 `JsonConvert.SerializeObject` 轉成字串塞進
   `Body`，前端還要再 `JSON.parse` 一次——那是 1.0 繞路的寫法。這裡 `Body` 直接放物件，
   前端 `$fetch` 拿到的就是陣列。
2. **`SP_GetCredit` / `SP_GetCreditCRM` 改參數化 SQL**
   1.0 直接把 `customNo` 字串插值進 SQL 字串執行，有 SQL injection 風險；這裡改用
   `FromSqlInterpolated`，讓 EF Core 自己把值轉成參數。
3. **`CheckUserPermissionLinkType` 用 `.Any()` 不用 `.First()`**
   1.0 對不存在的帳號會直接丟例外，這裡改成查不到就當非 admin 處理。
4. **`prc_COPGetCredit`/`prc_COPGetCredit_CRM` 的回傳欄位型別改宣告 `decimal`**
   1.0 的 model 這裡宣告 `float`，但 SP 實際回傳的欄位是 SQL `decimal`/`numeric`，
   EF Core 8 對不上型別會直接丟 `InvalidCastException`（本機實測打
   `SP_GetCredit` 會直接 500；1.0 用的是舊版 EF Core，型別轉換比較寬鬆才沒事）。
5. **Excel 匯出改寫死格式，不吃 `CMN_XlsFileFormat`**
   1.0 用資料庫驅動的通用格式引擎（`XlsFormatterApis_Cmn`）決定欄寬/表頭/樣式，那套引擎
   是給多個「還沒搬」的模組共用的排版基礎設施，這裡直接在 C# 寫死欄位配置，
   輸出的分頁、欄位、上色規則與 1.0 一致。
6. **匯出金額欄位權限統一用 `FunctionId.OrderInfoVerify`(425)**
   1.0 匯出時查的是 `FunctionId.MixSalesShipping`(410) 的權限，但查詢 Excel 格式用的
   卻是 425——兩個 FunctionId 對不上號，找不到明顯理由，這裡統一用 425。

## 銷貨檢索（`MixSalesShipApi`）

只搬銷貨檢索頁實際會打的三支：`GetSalesOrder`（依品號 TH004 分群）、
`GetSalesOrder_1`（依銷貨單 TH001+TH002 分群）、`ExportXls`（四個分頁的 Excel）。

查詢本身全在預存程序裡，Controller 只負責傳參數與回結果集。要注意的幾點：

1. **「查詢」會寫資料。** `prc_QuerySalesOrder(_1)` 進來第一行就
   `EXEC prc_ImportSalesOrder`，從鼎新 ERP（linked server `[192.168.1.200]`）
   增量補 `COP_SalesOrder`，再對它做去重 DELETE。所以這兩支端點不是唯讀的。
2. **SP 逾時要放寬。** 匯入會打 linked server，預設 30 秒不夠，沿用 1.0 的
   `SetCommandTimeout(120)`。
3. **參數大小寫照抄 1.0。** `GetSalesOrder_1` 的 `OrderType`/`OrderNo` 是大寫開頭，
   其餘小寫開頭。前端 query string 是照這個拼的，不要順手改成 camelCase。
4. **SQL 改成參數化。** 1.0 是把使用者輸入串進 `EXEC` 字串，這裡用
   `FromSqlInterpolated`。SP 內部仍會把值再組成動態 SQL，那是 SP 自己的事（不改資料庫）。
5. **匯出版面寫死在 C#。** 理由與訂單資料檢核那支相同（1.0 讀 `PUR_XlsFileFormat`
   動態組）。表頭文字與數字格式是直接抄那張表 `FunctionNo=410` 的設定，
   欄寬改成 `AdjustToContents()`——這是與 1.0 已知的唯一外觀差異。
   金額欄位權限照 1.0 用 `(410, LinkType=100)`。
6. **資料庫物件還在 `PRORIL_WEB`。** `CopSalesOrder` 對映在 `ProrilWebDbContext`，
   SP 也還在舊庫執行。搬到 `Proril_Sales_Center` 的腳本
   （`../database/SalesShippingObjectsMigration.sql`）已經產好但尚未執行，
   注意事項見 `../database/PortingNotes.md`「銷貨檢索相關的表 / 預存程序」。

## 未完成訂單檢索（`SalesOrderUnFinishApi`）

只搬未完成訂單檢索頁實際會打的三支：`GetUnfinOrder`（依品號 TD004 分群）、
`QueryUnfinOrder_1`（依訂單 TC001+TC002 分群）、`ExportXls`（四個分頁的 Excel）。

跟銷貨檢索是不同資料表/不同 ViewModel（訂單 `SalesOrderViewModel` vs 銷貨單
`COP_SalesOrder`），型別（`UnfinOrder`）、Controller 都各自獨立，不共用銷貨檢索那組。

1. **查詢是純讀，不像銷貨檢索的 SP 會順便寫資料。** `prc_QueryUnfinOrder(_1)` 不會像
   `prc_QuerySalesOrder(_1)` 先 `EXEC prc_ImportSalesOrder` 匯入 ERP，所以不用放寬
   `SetCommandTimeout`，也沒有「查詢會寫資料」的顧慮。
   **這兩支 SP 連同它們依賴的 `V_UnfinOrder` View 已於 2026-09-15 搬進
   `Proril_Sales_Center`**（見 `database/SalesOrderUnfinishObjectsMigration.sql`），
   `CallQueryUnfinOrder` / `CallQueryUnfinOrder1` 改打 `scDb`
   （`SalesCenterDbContext`），不再是 `db`（`ProrilWebDbContext`）。沒有落地任何快取表——
   `V_UnfinOrder` 每次查都直接打 ERP linked server + `PRORIL_WEB.dbo.NPS_D_Order`
   （3 段式跨庫查詢，兩個資料庫在同一個 SQL Server instance）。
2. **`orderType` 沒有對應的 SP 參數。** `prc_QueryUnfinOrder(_1)` 不支援按訂單單別篩選，
   收到 `orderType` 非空時對已查出的結果用 LINQ 再過濾一次（小計/總計列 `FooterFlag=Y`
   一律保留）。篩單一訂單靠 `poNo` 帶 `"{訂單單別}-{訂單單號}"` 組合字串
   （`QueryUnfinOrder_1` 的「單一訂單明細」modal 用法），不是走 `orderType`/`orderNo`——
   這點跟銷貨檢索的兩個明細 modal 不同，改邏輯時別套錯模式。
3. **SQL 改成參數化。** 1.0 是把使用者輸入串進 `EXEC` 字串再 `FromSql`，這裡用
   `FromSqlInterpolated`。SP 內部仍會把值再組成動態 SQL，那是 SP 自己的事（不改資料庫）。
4. **匯出版面寫死在 C#。** 理由與銷貨檢索、訂單資料檢核相同（1.0 讀 `PUR_XlsFileFormat`
   動態組，那套引擎是給多個還沒搬的模組共用的基礎設施）。欄位順序跟頁面上四個頁籤的
   表格逐欄對齊，欄寬改成 `AdjustToContents()`——這是與 1.0 已知的唯一外觀差異。
   金額欄位權限用 `(FunctionIds.QueryUnFinish=0320102, LinkType=100)`。
5. **資料庫物件還在 `PRORIL_WEB`。** `UnfinOrder` 是 keyless 型別，只給
   `FromSqlInterpolated` 用，對映在 `ProrilWebDbContext`；SP 也還在舊庫執行，
   repo 內找不到對應 .sql，只存在資料庫端。
6. **`UnfinOrder.CopSource` 改名自 1.0 的 `COPSource`。** camelCase 化後前者是
   `copSource`（跟銷貨檢索的 `CopSalesOrder.CopSource` 一致），後者會是 `cOPSource`，
   跟前端 `app/types/salesOrderUnfinish.ts` 定的欄位名對不起來，故意改掉。

## 與 1.0 並存

兩邊打同一個資料庫，可以同時運作，token 也互通（前提是 JwtSettings 相同）。

> **例外：權限控管不能並存。** `M_User`/`M_Permission`/`M_PermissionGroup` 已經切到
> `Proril_Sales_Center`，1.0 讀寫的還是 `PRORIL_WEB`，兩邊各改各的一定分岔。
> 上線時要把 1.0 的「系統設定 / 人員管理」「系統設定 / 權限管理」關掉。
>
> 功能主檔 `M_System`/`M_Function` 也切過去了，而且新庫**只保留 2.0 真的有頁面的
> 3 個系統別 + 8 個功能**（`database/PermissionMasterSeed.sql`）——所以 2.0 的權限樹
> 只長得出 2.0 管得到的功能，勾不到 1.0 還沒搬的模組。

切換期間要注意的是：1.0 的議題畫面仍然有上面第 1 點的 inner join 問題，
所以**同一批資料在兩邊看到的筆數可能不一樣**——2.0 會多出那些 1.0 藏起來的。
這是預期的，不是 2.0 撈錯。

## 相關文件

- `../docs/modules/SalesIssue/logic.md` — 業務邏輯、欄位語意、附件流程
- `../docs/modules/SalesIssue/update.md` — 更新紀錄
- `../docs/modules/OrderInfoVerify/logic.md` — 訂單資料檢核的業務邏輯、檢核欄位語意
- `../docs/modules/SalesShipping/logic.md` — 銷貨檢索的業務邏輯、四個頁籤與金額權限
- `../docs/modules/SalesOrderUnfinish/logic.md` — 未完成訂單檢索的業務邏輯、四個頁籤與金額權限
- `../docs/modules/SystemSetting/logic.md` — 權限控管（人員管理 / 權限管理）的邏輯與資料表歸屬
- `../database/README.md` — schema 版控（DACPAC）
- `../database/checks/README.md` — 資料正確性檢查

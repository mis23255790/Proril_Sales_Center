<details>
  <summary>程式邏輯</summary>

###### 對應舊系統
     PRORIL (.NET MVC) 的 WorkProcess 模組
       Views/WorkProcess/{SOPMaintain, SOPDetailEditor, SOPList, SOPDetail, KindMaintain}.cshtml
       wwwroot/js/workProcess/*.js
       Controllers/WorkProcess/WorkProcessApiController.cs        ← **後端沒搬，繼續用**
       SystemId.WorkProcess = 7 / FunctionId.ProcessMaintain = 17

###### 相關資料表
     D_WorkProcess           議題表頭
     D_WorkProcessDetail     議題進度（一則一列）
     D_WorkProcessSearch     議題 ←→ 關鍵字
     D_WorkProcessCustomer   議題 ←→ 客戶
     D_WorkProcessPermission 議題 ←→ 可編輯／可檢視帳號
     M_WorkProcessPhrase     關鍵字主檔
     M_WorkProcessType       關鍵字分類主檔（01/02/03/04）
     CRM_Customer            客戶主檔
</details>

# 架構

前端 Nuxt 4 + 後端 .NET 8，兩邊都在這個 repo 裡。

```
Nuxt 頁面 ──▶ useSalesIssueApi() ──▶ /api/proxy/... ──▶ server/api/proxy/[...path].ts
                                                          └─▶ NUXT_PUBLIC_API_BASE
                                                                ├─ api/  (2.0 自己的 .NET API)
                                                                └─ 或 1.0 PRORIL 站台（搬移期間）
```

- **後端已經搬過來了**：`api/`（`Proril.SalesIssue.Api`，net8.0 + EF Core 8）。
  端點名稱與回傳信封與 1.0 一字不差，切換只要改 `NUXT_PUBLIC_API_BASE` 一行。
- **資料庫沒有動**（含 View / StoredProcedure），兩套後端打同一個 `PRORIL_WEB`，可以並存。
- Nitro 只有兩支：`/api/proxy/**`（轉發）與 `/api/download`（附件下載中繼）。
- 後端細節（搬了什麼、沒搬什麼、與 1.0 的行為差異）見 [`api/README.md`](../../../api/README.md)。

> 下面描述的邏輯**兩套後端共通**，除非特別註明「1.0 才有的問題」。

# 編號與補零

| 欄位 | 型別 | 規則 |
|---|---|---|
| `D_WorkProcess.WPNo` | varchar | **6 碼左補零**字串，`"000123"`。後端 `transferWpNoToPadding()` 會幫忙補，但送進去前自己補比較保險 |
| `D_WorkProcessDetail.SNo` | varchar(4) | **4 碼左補零**，`"0003"` |

前端一律用 `padWpno()`（`app/utils/salesIssue.ts`）處理。

> ERP／舊資料常帶**尾端空白**。所有比對（客戶編號、SNo）在前端都要先 `trim()`，
> 這是整個 PRORIL 系統反覆出現的 bug 來源。

# aStatus

`aStatus = 'N'` 代表「這筆已失效／已不在集合裡」，**不是**「已完成」。

- 刪除議題 = `DisableOrder` 把表頭寫成 `'N'`，資料仍在 DB。
- 「結案」是另一個獨立欄位 `FinFlag`，跟 `aStatus` 無關。

# 關鍵字：三串字串靠「位置」對齊

`GetSOPOrder` / `GetSOPList_Edit` 回來的是三個分號字串：

```
phraseTypeList = "02;02;03"
phraseCodeList = "01;05;03"
phraseNameList = "客訴;價格議題;業務二課"
```

**它們是靠索引對應的，不是 key-value。** 任何一串被 filter 或排序，對應關係就整個錯開。
`parsePhraseTriples()` 只做 `split`，配對完才 filter —— 不要在配對前先過濾空值。

寫回去用 `SetWPOrderPhrase`，同樣要送三串同順序的字串。

`phraseType` 對照（`M_WorkProcessType.TypeCode`）：

| code | 名稱 | 畫面上叫 |
|---|---|---|
| 01 | 搜尋片語 | （目前未用） |
| 02 | 流程類別 | **類別** |
| 03 | 職能主題 | 舊版的「客戶別」 |

後端沒有回傳 `M_WorkProcessType` 的 API（舊畫面是 Razor 直接讀 DB），
所以 `pages/sales-issue/kind-maintain.vue` 的 `PHRASE_TYPES` 是寫死的。
DB 新增分類時記得回來補這張表。

# 客戶別有兩個來源，兩個都要看

2025-04 改版前，客戶是用「職能主題」關鍵字（phraseType 03）記的；
改成客戶導向後才有 `D_WorkProcessCustomer` + `CRM_Customer`。
**兩種資料至今並存**，只看一邊會有議題顯示不出客戶。

`toIssueRow()` 因此把兩邊合併：

```
customers = phraseType == '03' 的 phraseName  ∪  {issue.customerName}
```

另外 `GetSOPOrder` 回的 `customerNo` 對早期資料常常是空的，
編輯頁在空值時會再打一次 `GetWPOrderCustom` 補，否則存檔會把客戶洗掉。

# 進度的標題就是日期

`D_WorkProcessDetail.ProcessCaption` 是自由文字，但**慣例上放日期**，
後端 `GetSOPDetail` 也就直接 `OrderBy(ProcessCaption)` 升冪當時序。

- 前端顯示要「最新在上」，所以在 `sortedDetails` 反轉，標題相同時再用 `SNo` 分先後。
- 新增進度時預設帶入今天的日期，維持這個慣例。

# 內文：哪支 API 有 ProcessContent

| API | 有沒有 `processContent` |
|---|---|
| `GetSOPList_Edit`（議題列表） | **沒有** —— 後端 select 時就刻意跳過，內文太大 |
| `GetSOPDetail`（進度列表） | 有，回完整 entity |
| `GetEditorText`（單筆進度） | 有 |

編輯視窗開啟時仍然打一次 `GetEditorText`，拿最新的內容當權威值；
失敗才退回列表帶回來的 `processContent`。

`GetEditorText` 有兩個坑：

1. **名字叫 Text，回的卻是整個 `DWorkProcessDetail` 物件**（`ca.Body = qry[0]`），
   不是內文字串。要自己取 `.processContent`，直接當字串用會變 `[object Object]`。
2. **它不幫 `SNo` 補零**（`o.Sno == SNo` 直接比）。其他同類 API
   （`GetSOPDetailWSNo` / `SaveDetail` / `DeleteSno`）內部都有 `$"{nSno:0000}"`，
   只有這支沒有。`SNo` 是 varchar(4)，呼叫端沒補到 4 碼就會回「查無資料」。
   `getDetailContent()` 已經在裡面 `trim()` + `padStart(4, '0')`。

內文是**帶 inline style 的 HTML**（`<table>`、`<span style="font-family:Times New Roman">`…），
由舊 Summernote 產生。2.0 用 `RichTextEditor.vue`（contenteditable + `execCommand`）取代，
刻意不引第三方編輯器 —— 產出的結構要跟既有資料同一種，新舊內容混排才不會走樣。
`RichTextEditor` 與 `IssueContentView` 的 CSS 必須保持同一組規則，否則編輯時看到的排版
跟存完在時間軸上看到的不一樣。

顯示端一律過 `IssueContentView` 消毒（拔 `<script>`、`on*`、`javascript:`）——
這些 HTML 有不少是從 Outlook / Word 貼進來的，`v-html` 不會幫你擋。

## 舊內文的行高是壞的

從 Outlook / Word 貼進舊 Summernote 的內容，幾乎每個 `<p>` 與 `<span>` 都掛著
`style="line-height: 0.3"` —— 16px 的字配 4.8px 行高，**行與行會直接疊在一起**。

1.0 的 `control-summer-note.css` 寫了 `.note-editable p { line-height: 1.2 }` 想蓋掉，
但 inline style 的優先權高於 class selector，**蓋不動**（release-note 上好幾筆行高
相關的修正都在打這個問題）。

`fixLegacyLineHeight()`（`app/utils/salesIssue.ts`）在渲染前把**明顯壞掉**的
line-height 宣告移除：無單位倍率 `< 1`，或 px 值 `< 12px`。
使用者用舊編輯器刻意設的 1.0 ~ 1.6 保留不動。

- 套用在 `IssueContentView`（顯示）與 `RichTextEditor.setContent()`（編輯）**兩處**。
  兩邊必須一致，否則編輯時看到的排版跟存完看到的不一樣。
- **副作用**：編輯器載入時也會清，所以開啟舊進度並重新儲存，那一則的壞行高會被
  永久修正掉。只影響被編輯過的那一則，不會整批改寫。

# 議題存檔是四支 API，缺一項就會怪

```
1. SaveOrder              寫 D_WorkProcess（主題／最新進度／公開／結案／客戶編號）
2. SetWPNoPermissionEdit  把 '000000'（全體使用者保留帳號）加進可編輯清單
3. SetWPOrderPhrase       覆寫 D_WorkProcessSearch
4. SetWPOrderCustom       覆寫 D_WorkProcessCustomer
```

- 少第 2 步 → 新建的議題**只有建立者看得到**（`GetSOPList_Edit` 會做權限過濾）。
- 少第 3、4 步 → 存了但列表上沒有類別／客戶別。

新議題的編號是 `GetSOPListAll` 撈全部再取 `max(wpno) + 1`。
這是 read-modify-write，**兩人同時新增有機會撞號** —— 舊系統本來就這樣，沿用未改。

# 附件：解壓 → 改 → 壓回去

一則進度的所有附件壓成**一個 zip** 存在 share root，畫面要編輯就得先解出來。
`useIssueAttachments()` 固定跑這個順序：

```
1. ClearSOPTempPath     清掉自己的 temp 目錄
2. UnzipAttachFileList  zip 解到 temp（檔名還原成原始檔名）
3. SaveByFileName       新選的檔案上傳到同一個 temp 目錄
4. UpdateDBAttachFile   最終檔名清單寫回 D_WorkProcessDetail
5. ZipAttachFileList    temp 目錄重新壓成 zip
```

- 4 與 5 的順序看這則進度存不存在：
  - 既有進度（`detailId > 0`）→ **先 Zip 再寫 DB**，zip 檔名 `{wpNo}.{detailId}` 已經知道了。
  - 新進度 → **先寫 DB 拿回 id**，才組得出 zip 檔名。
- 兩條路都必須「Zip 與寫 DB 用**同一份、同順序**的檔名清單」——
  `RenameFile` 是後端依序重編的（`1.pdf`、`2.docx`…），順序一亂就對不回原始檔名。
- **附件沒異動就不要重壓**。重壓會重編 `RenameFile`。

## 中間層目錄一定要用 wpNo 算

```
/temp/{account}/Doc_SOP/{floor(wpNo * 2 / 1000):00000}/{sNo}/
```

後端 `EnumTempUploadAttach` 與 `UpdateDBAttachFile` **都是用 wpNo** 去組這個路徑。
舊 JS 的 `onClickAddAttach()` 卻是用「目前附件筆數」算的 ——
`wpNo < 500` 時兩邊剛好都是 `00000` 所以看不出來，**wpNo 到 500 以上就會壞**
（檔案落在後端找不到的層級，存檔後附件憑空消失）。
2.0 的 `dcuMiddleLayer()` 統一改用 wpNo，這是一個 bug fix，不是行為變更。

## 下載

`GetDownloadUrl` 回的是 `/ShareRoot/Temp/...`，相對於 **.NET 站台根目錄**（不在 `/api` 底下）。
直接開會跨網域，所以走 `server/api/download.get.ts` 轉一手，順便補 `Content-Disposition`
讓瀏覽器真的存檔而不是內嵌預覽。這支只接受 `/ShareRoot/` 開頭的路徑，避免變成開放轉址。

# 查詢條件：哪些真的送到後端

| 條件 | 誰處理 |
|---|---|
| 類別 / 客戶別 / 標題關鍵字 / 內文關鍵字 | 後端 `GetSOPList_Edit` |
| 最後修改起訖日 | **前端** |
| 快速搜尋 | 前端（在目前結果內找） |

`GetSOPList_Edit` 的簽章雖然收 `startDate` / `endDate`，
但後端那段過濾邏輯**整段被註解掉了**（2026-06-08 改成 order by 客戶別時停用），
傳上去等於沒作用。所以 2.0 改在前端對「最後修改時間」過濾，
使用者看到的行為才跟欄位名稱一致。哪天後端補回來，把這段移回去即可。

另外：查無資料時後端回的是 `isSuccess: false` + 說明訊息，**這不是錯誤**，
不要跳 error toast，當成空清單處理。

# 頁面

網址是三層：`業務中心 / 模組 / 功能`（比照 1.0），而且**每一層都有自己的頁面**，
可以逐層下鑽也可以用麵包屑往回退：

| 路徑 | 畫面 |
|---|---|
| `/sales-center` | 列**模組**（業務議題、業務檢索） |
| `/sales-center/{module}` | 列該模組底下的**功能**，依群組分段 |
| `/sales-center/{module}/{func}` | 實際的作業畫面 |

模組首頁是 `app/pages/sales-center/[module]/index.vue` **一支動態頁**共用的，
資料來自 `useAppNavigation` 的 `NAV_MODULES` —— 新增模組只要加一筆設定，不用開新頁面。
某個模組要客製首頁（例如放儀表板）就在 `app/pages/sales-center/<模組>/index.vue`
放靜態頁，Nuxt 靜態路由優先，會自動蓋過動態頁。

| 路徑 | 對應舊畫面 | 說明 |
|---|---|---|
| `/sales-center/sales-issue/issues` | `WorkProcess/SOPMaintain` | 議題列表，進行中／結案／全部三個頁籤 |
| `/sales-center/sales-issue/issues/new` | `SOPDetailEditor?newSop=1` | 新增議題 |
| `/sales-center/sales-issue/issues/{wpno}` | `SOPDetailEditor?wpNo=` | 議題編輯 + 進度時間軸 |
| `/sales-center/sales-issue/kind-maintain` | `WorkProcess/KindMaintain` | 關鍵字（類別）維護 |

**不要在頁面裡寫死路徑。** 根層級定義在 `useAppNavigation.ts` 的 `APP_BASE`，
功能表只存相對路徑（`sales-issue/issues`），要完整路徑就用 `appPath()` / `itemPath()`。
唯一的例外是 `app/pages/index.vue` 的 redirect —— `definePageMeta` 是編譯期巨集，
讀不到 `APP_BASE`，改根路徑時要跟著手動改那一行。

# 尚未搬移

搬過來的是「議題維護」這條主線。以下舊功能**還沒做**，需要時再補：

- `WorkProcess/Index`（依關鍵字分群的功能按鈕首頁）
- `WorkProcess/SOPList` / `SOPDetail`（唯讀瀏覽視角，`GetSOPList_View`）
- 逐議題的編輯／檢視人員權限設定（`GetUserListEditor` / `SetWPNoPermissionView`）——
  2.0 沿用舊系統後來的做法：存檔時一律開放給 `'000000'` 全體使用者
- 版本進版（`VerNo`）與各版本備註（`MemoApi`）—— 舊系統早已固定 `1.0`、UI 也隱藏了
- 調整進度順序（`SetWPDetailNewSno`）
- 執行說明 `ProcessCaption2`（舊畫面同樣是 hidden）

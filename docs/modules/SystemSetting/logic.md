# 系統管理 / 權限控管

對應 1.0 的「系統設定」系統（`SystemId.Setting = 0`）底下的兩支畫面，外加 2.0 自己拆出來的一支：

| 2.0 | 1.0 | FunctionNo |
|---|---|---|
| `/sales-center/system/user-manager` | `Views/System/UserManager.cshtml` | `0000102`（舊 8） |
| `/sales-center/system/permission-manager` | `Views/System/PermissionManager.cshtml` | `0000101`（舊 1） |
| `/sales-center/system/group-permission` | （1.0 是權限管理頁裡的「群組預設功能編輯」彈窗） | `0000103`（2.0 新增） |

## 相關資料表

| 表 | 用途 | `api/` 連哪個庫 |
|---|---|---|
| `M_User` | 帳號主檔 | `Proril_Sales_Center`（讀寫） |
| `M_Permission` | 個人權限：誰有哪個功能／細項 | `Proril_Sales_Center`（讀寫） |
| `M_PermissionGroup` | 群組（部門）預設功能範本 | `Proril_Sales_Center`（讀寫） |
| `M_System` | 系統別，權限樹第一層 | `Proril_Sales_Center`（唯讀，**只有 3 列**） |
| `M_Function` | 功能，權限樹第二層 | `Proril_Sales_Center`（唯讀，**只有 9 列**） |
| `M_PermissionDef` | 字串權限主檔（`module.function.action`），權限樹的功能節點與細項節點都從這裡長 | `Proril_Sales_Center`（唯讀，**2.0 新表**，14 列） |
| `M_PermissionLinkType` | 1.0 的細項主檔，2.0 已不拿來組樹，只剩 `M_PermissionDef.PermissionLinkTypeID` 對回它 | `Proril_Sales_Center`（唯讀，4 列） |
| `M_Department` | 部門／群組下拉來源 | `PRORIL_WEB`（唯讀） |

**為什麼分兩個庫**：只有「唯一應用層寫入者已經搬到 2.0」的表才切連線。
`M_Department` 在 1.0 還被 `OrgApiController`（組織維護）寫，留在舊庫唯讀。
`M_PermissionLinkType` 原本也是同樣理由留在舊庫（1.0 的 `FileQueryApiController` 會 Add），
但 `FunctionNo` 改成 AAABBCC 之後跨庫對不起來了，只能一起搬——代價是 1.0 之後在舊庫
新增的細項不會自動同步過來。完整理由與核對過程見
`database/PortingNotes.md`「權限控管搬遷（第二輪）」與「FunctionNo 改成 AAABBCC 格式」。

**`M_System` / `M_Function` 在新庫只有部分資料列**：`PRORIL_WEB.M_Function` 有 90+ 個
功能，絕大多數是 2.0 還沒搬的模組，整份複製的話權限樹會長出一堆點下去 404 的功能。
新庫只收 2.0 真的有頁面的 3 個系統別（0 系統設定 / 7 業務議題 / 32 業務檢索）
與 8 個功能（1 / 8 / 16 / 17 / 410 / 420 / 425 / 440），外加 2.0 專屬的 `0000103` 群組權限
（PRORIL_WEB 沒有，seed 腳本另外直接寫值）。
資料由 `database/PermissionMasterSeed.sql` 維護——**不要用 `copy-snapshot-data.ps1`**
（它會整批覆蓋，已在該腳本把這兩張排除），也**不要靠 `publish.ps1` 建表**。
（原本不能用 publish 的理由是「DACPAC 的 `M_Function` 是 `varchar`、中文會變 `?`」——
2026-09-14 資料庫定序已對齊成 `Chinese_Taiwan_Stroke_BIN`，`varchar` 存得下中文了，
那個理由不再成立；不用 publish 純粹是因為這兩張的**資料**要由 seed 腳本控管。）
要加功能請先確認 `NAV_MODULES` 有對應路由，再改那支腳本的 `@FunctionNos`。

實作上的後果：**權限樹那幾支 API 的併表一律先各自 `ToList()` 再用 LINQ to Objects 併**，
不能寫成單一 SQL——EF 組不出跨資料庫的查詢。

> 原本的既有問題（1.0 就有）：`OrderInfoVerifyApiController` 會檢查
> `(functionNo 425, linkType 100)` 的欄位級權限，但 `M_PermissionLinkType` 沒有這一列，
> 權限樹上勾不到。2026-09-23 改成字串權限時在 `M_PermissionDef` 補上了
> `salesSearch.orderInfoVerify.viewAmount`，**現在勾得到了**。

## 權限的資料模型

### 字串權限（PermissionKey）

2026-09-23 起，權限一律用 Google IAM 式的三段字串 `module.function.action` 認：

| PermissionKey | FunctionNo | LinkType | 名稱 |
|---|---|---|---|
| `system.permissionManager.view` | `0000101` | 1 | 權限管理 |
| `system.userManager.view` | `0000102` | 1 | 人員管理 |
| `system.groupPermission.view` | `0000103` | 1 | 群組權限 |
| `salesIssue.kindMaintain.view` | `0070101` | 1 | 類別維護 |
| `salesIssue.processMaintain.view` | `0070102` | 1 | 議題維護 |
| `salesIssue.processMaintain.createSop` | `0070102` | 10 | SOP-新增 |
| `salesIssue.processMaintain.publishSop` | `0070102` | 20 | SOP-公開 |
| `salesSearch.mixSalesShipping.view` | `0320101` | 1 | 銷貨檢索 |
| `salesSearch.mixSalesShipping.viewAmount` | `0320101` | 100 | 顯示金額欄位 |
| `salesSearch.queryUnFinish.view` | `0320102` | 1 | 未完成訂單 |
| `salesSearch.queryUnFinish.viewAmount` | `0320102` | 100 | 顯示金額欄位 |
| `salesSearch.customQuery.view` | `0320103` | 1 | 客戶檢索 |
| `salesSearch.orderInfoVerify.view` | `0320201` | 1 | 訂單資料檢核 |
| `salesSearch.orderInfoVerify.viewAmount` | `0320201` | 100 | 顯示金額欄位 |

規則：

- `.view` = 進得去這個功能（等於舊的 `LinkType = 1`），其餘是細項。
  **有細項一定連帶 `.view`**，前端 `collectSelection` 與後端 `ResolvePermissionKeys` 都會補。
- Action 只收**目前真的有在檢查**的動作，不預先捏造 view/create/edit/delete 全套。
  SOP-新增／SOP-公開 2.0 目前沒有任何地方在檢查，只是從 1.0 帶過來保留。
- 主檔在 `M_PermissionDef`（`database/PermissionDefObjectsMigration.sql`），
  常數在後端 `api/Models/Enums.cs` 的 `PermissionKeys`、前端 `app/utils/permissionKeys.ts`，
  **三邊要一起改**。
- 後端檢查一律 `BaseApiController.HasPermission(key)`，前端 `usePermission().checkPermission(key)`
  （打 `MainApi/CheckPermission`，回裸 bool）。

### M_Permission / M_PermissionGroup 的欄位

`M_Permission` 一列代表「某人有某個東西」：

| 欄位 | 意思 |
|---|---|
| `LinkNumber` | 帳號。保留值 `000000` 代表**全體使用者** |
| `PermissionKey` | **權限判斷以這欄為準**，對照 `M_PermissionDef.PermissionKey` |
| `FunctionNo` | 功能代碼（`varchar(8)`）。過渡期照樣寫，**側欄（`GetUserFunctions`）還靠它** |
| `LinkType` | 過渡期照樣寫：`1` = 功能本身；`> 1` = 細項 |
| `PermissionLinkTypeID` | 過渡期照樣寫，對照 `M_PermissionLinkType.ID` |

`M_PermissionGroup` 同樣多了 `PermissionKey`，其餘欄位照舊（沒有 `PermissionLinkTypeID`）。

既有資料由 migration 以 `(FunctionNo, LinkType)` 回填 `PermissionKey`。回填不到的列
（`PermissionKey IS NULL`）是 FunctionNo 改格式時**刻意保留**的 1.0 功能（FunctionNo 還是舊數字，
測試區有 `M_Permission` 501 列、`M_PermissionGroup` 29 列）：樹上不會出現、權限檢查也不認，
但 `SetPermissionKeys` / `SaveDepPermissionKeys` **只動有 PermissionKey 的列，這些原封不動**。
（1.0 版的 `SetPermissionTree` 存檔時會把它們一起刪掉，改成字串權限時順便修正。）
migration 的驗證查詢只把「7 碼 AAABBCC 卻回填不到」當問題，那個應為 0 筆。

### FunctionNo 的格式

`AAABBCC` —— SystemNo 補零 3 位 + GroupNo 補零 2 位 + 序號補零 2 位，`varchar(8)`。
定長所以字串排序等於「系統別 → 群組 → 序號」的正確順序。

| FunctionNo | 功能 | 2.0 路由 |
|---|---|---|
| `0000101` | 權限管理 | `system/permission-manager` |
| `0000102` | 人員管理 | `system/user-manager` |
| `0000103` | 群組權限 | `system/group-permission` |
| `0070101` | 類別維護 | `sales-issue/kind-maintain` |
| `0070102` | 議題維護 | `sales-issue/issues` |
| `0320101` | 銷貨檢索 | `sales-search/shipping-inquiry` |
| `0320102` | 未完成訂單 | `sales-search/unfinished-orders` |
| `0320103` | 客戶檢索 | `sales-search/customer` |
| `0320201` | 訂單資料檢核 | `sales-search/order-info-verify` |

**只有 `Proril_Sales_Center` 是這個格式**，`PRORIL_WEB`（1.0 在用）仍是 int 流水號，
兩邊永久分岔。常數在 `api/Models/Enums.cs` 的 `FunctionIds` 與
`app/composables/useAppNavigation.ts` 的 `NAV_MODULES`，改號的來龍去脈見
`database/FunctionNoFormatMigration.sql`。

判斷順序一律是：`M_User.IsAdmin` 為真就全放行，否則查 `M_Permission`
（`LinkNumber` = 自己 或 `000000`，`PermissionKey` = 要檢查的 key）。

### PermissionKey 的命名規則

**PermissionKey 是權限的識別碼，不是 C# namespace、資料夾或路由的投影。**
第一段 `salesSearch` 剛好跟 `Controllers/SalesSearch/` 同名，容易讓人以為要照程式結構推導，
其實同一個功能在各處本來就叫不同名字，以銷貨檢索為例：

| 地方 | 名稱 |
|---|---|
| PermissionKey | `salesSearch.mixSalesShipping.view` |
| C# namespace／Controller | `Controllers.SalesSearch` / `MixSalesShipApiController` |
| 前端路由 | `sales-search/shipping-inquiry` |
| 文件資料夾 | `docs/modules/SalesShipping/` |
| M_Function | `0320101` 銷貨檢索 |

規則：

- **三段各自的意思**：`module` = 業務模組、`function` = 使用者可被授權的一個業務功能、
  `action` = 在該功能裡被檢查的動作。三段都用 lowerCamelCase 英文。
- **命名以使用者看到的業務功能為準**，不以任何一層程式碼的名稱為準。
  程式搬資料夾、改 Controller 名、改路由，**都不改 key**。
- **key 一旦寫進 `M_Permission` 就不改名。** 改名等於兩個環境的 `M_Permission` /
  `M_PermissionGroup` 全部要回填，正是 FunctionNo 把位置編進號碼、搬一次就要全庫改號的老問題。
  既有的 key（`mixSalesShipping`、`queryUnFinish`、`customQuery`… 大多沿用 1.0 的名稱）
  就算跟上表其他地方對不上也維持原樣，**命名規則只套用在新功能**。
- **不要用 FunctionNo 當識別。** FunctionNo（`AAABBCC`）把系統別／群組／序號編進號碼，
  功能換群組就得改號；它只負責排序與權限樹分組。`032.01.01` 這類點分寫法是同一件事換個格式，
  問題一樣，而且 9 個字元放不進 `varchar(8)`，不採用。

> **尚未實作的方向**：`M_Function` 加 `FunctionKey`（= PermissionKey 的前兩段，例如
> `salesSearch.mixSalesShipping`，`.view` 由它加 `.view` 組成），`GetUserFunctions` 回傳它、
> `NAV_MODULES` 改用它對照，前端就不必再知道 FunctionNo。目前側欄仍靠 FunctionNo。
> 名稱不用 `ResourceKey`（IAM 的說法）是因為本專案的 DB 與畫面都叫「功能」。

### 新增一個功能要改哪裡

1. `NAV_MODULES`（`app/composables/useAppNavigation.ts`）加路由與 `functionNo`
2. `api/Models/Enums.cs` 的 `FunctionIds` 加號碼
3. `database/PermissionMasterSeed.sql` 加 `M_Function` 那列（1.0 有的加 `@FunctionNos`，2.0 專屬的加在「2.0 專屬功能」段）
4. `database/PermissionDefObjectsMigration.sql` 的 MERGE 加 `.view`（有細項也一起加），
   key 的取名照上面「PermissionKey 的命名規則」
5. `PermissionKeys`（後端）與 `PERMISSION_KEYS`（前端 `app/utils/permissionKeys.ts`）加常數

## 人員管理

流程跟 1.0 一樣：輸入／選一個工號按查詢 → 查到是編輯模式、查不到是新增模式。

- 新增帳號與密碼重置的**初始密碼都等於帳號本身**（AES 加密後存 `M_User.Password`），
  同時把 `IsFirstLogin` 設為 true。這是 1.0 的規則，沒有改。

> **但 2.0 的登入只走 SSO**，`M_User.Password` 在 `Proril_Sales_Center` 已經全部清成
> `NULL`（2026-09-14，備份在 `M_User_bak_Password`）。`LoginSso` 不看密碼，
> 所以清空不影響登入；`MainApi/Login`（帳密登入）端點還在但前端沒有任何地方呼叫。
> **這留下一個不一致**：`AddUser` / `ResetPassword` 仍會寫 `AES(帳號)`，
> 新建的帳號會變成唯一有密碼的那個。要嘛拿掉那兩段，要嘛連 `Login` 一起下架。
- 「帳號啟用」= `IsEnable`，「管理人員」= `IsAdmin`。

與 1.0 的差異（都是刻意的）：

1. API 回傳從裸 `bool` 改成 `CustomApiViewModel` 信封。1.0 失敗時只回 `false`，
   畫面永遠只能說「帳號新增失敗」，看不到原因。
2. 後端補上功能權限檢查。1.0 這些端點只掛 `[Authorize]`，擋在前端的
   `checkPermission()`——等於任何登入者直接打 API 就能建管理員帳號。
3. 刪除帳號時連同他的 `M_Permission` 一起刪。1.0 只刪 `M_User`，權限列變孤兒，
   之後同工號重建帳號會直接繼承到舊權限。
4. 多一支「解除鎖定」。`IsLocked` 在 1.0 只有登入失敗會設成 true，畫面上解不開。
5. 不能刪自己的帳號。

## 權限管理

### 權限樹

三層（外加一層純分類）：

```
M_System.TypeName（行政／現場／…，不可勾）
  └ M_System.SystemName（系統設定／業務議題／…，不可勾）
      └ M_Function.FunctionName（可勾，代表該功能的 .view）
          └ M_PermissionDef.ActionName（LinkType > 1 的細項，可勾，可依 ParentPermissionKey 再往下巢狀）
```

節點 key 是 `p-{PermissionKey}`（純分類節點是 `t-`/`s-`）；主檔裡沒有 `.view` 的功能
照樣長出來但不能勾，免得存出後端認不得的 key。

勾選**互相獨立、不做父子連動**（對應 1.0 fancytree 的 `selectMode: 2`）。
「勾了細項就自動開啟所屬功能」是**存檔時**才補的——存檔前會把每個勾到的節點往上找
parent，把沿路的 PermissionKey 一併加進去，否則細項有權限但功能沒開，等於進不去那個畫面。
後端 `ResolvePermissionKeys` 也會再補一次，不只靠前端。

組樹、取值與差異計算的邏輯集中在 `app/utils/permissionTree.ts`，權限管理與群組權限兩頁共用。

> **與 1.0 的一個差異**：1.0 的 `v2AddFunctionEx` 把所有 `M_PermissionLinkType`
> 一律掛在功能底下，完全沒用 `ParentLinkTypeID`，巢狀的細項會被攤平成兄弟節點。
> 2.0 照父節點掛，樹形才跟資料一致。

### 存檔

`MainApi/SetPermissionKeys(account, str_permission_keys)`：`str_permission_keys` 是
PermissionKey 陣列的 **JSON 字串**（照 1.0 的習慣，不是物件），後端用 `JsonConvert.DeserializeObject` 解。

- 主檔找不到的 key 一律回錯，不默默略過。
- 做法是算出目標集合後做差集，既有列的 `Creator`/`CreateTime` 保留不動。
- 新增的列同時寫 `PermissionKey` 與過渡期的 `FunctionNo`/`LinkType`/`PermissionLinkTypeID`。

1.0 的 `SetPermissionTree`（兩個 JSON 字串：functionNos + linkTypes）**已移除**——
它不會寫 `PermissionKey`，留著會存出權限檢查認不得的列。

### 群組預設功能

2026-09-23 起拆成兩支畫面：

- **群組權限**（`system/group-permission`，`0000103`）→ 選群組、勾樹、儲存，寫 `M_PermissionGroup`（群組範本），
  **不會改到任何人目前的權限**。存檔端點 `MainApi/SaveDepPermissionKeys`，權限要
  `system.groupPermission.view`——拆出來就是為了能跟權限管理分開授權。
- **權限管理 → 群組預設功能套用** → 讀出該群組的範本（可再微調），下方即時列出**差異清單**：
  - 將新增：群組有、這個人目前沒有
  - 已有：兩邊都有
  - 本人原有、群組沒有（保留不動）：套用是聯集，這些不會被取消
  按「套用」後把勾勾點進**目前這個人**的樹裡，**還要再按「儲存」才會寫進 `M_Permission`**。
  差異的計算兩邊都先補祖先（`diffSelection`），跟實際存檔結果一致。

讀範本的 `CommonApi/GetDepFunction` 兩頁都在用，所以只要登入、不擋功能權限。
`GroupType` 固定是 10（1.0 的 `_default_group_type`）。

## 側欄選單改成讀 DB

在這一輪之前，2.0 側欄（`app/composables/useAppNavigation.ts` 的 `NAV_MODULES`）
是**寫死的常數**，跟 `M_Permission` 完全無關——權限管理勾了什麼不影響任何人看到的選單。

現在改成：

- **路由、icon、分組、說明文字**仍然在 `NAV_MODULES`。`M_Function.Href` 存的是
  1.0 的網址，對不上 2.0 的路由，所以路由不能從 DB 來。
  （新庫的 `M_Function` 雖然已經只剩 2.0 有頁面的 8 列，路由仍然要本地對照表。）
- **可見性與顯示名稱**來自 `MainApi/GetUserFunctions`（`M_Function` ∩ `M_Permission`，
  admin 全開）。每個 `NAV_MODULES` 項目都帶 `functionNo`，對不到權限的就不顯示，
  對得到的用 DB 的 `FunctionName` 蓋掉本地 label。
- 整個模組底下一項都看不到時，模組本身也不顯示。

`GetUserFunctions` 打失敗（API 掛了、token 過期）時**不過濾**，退回顯示全部項目：
寧可多顯示，也不要讓人一進站看到空選單以為系統壞了。真正的把關在後端，每支 API 自己會擋。

**載入中則不顯示任何功能**，側欄放 skeleton 佔位（`isLoadingUserFunctions`）。
原本載入中跟失敗一樣走「顯示全部」，結果沒權限的項目會先出現、API 回來後又消失
（2026-09-23 群組權限就是這樣被發現沒授權的）。

## 上線注意事項

`M_User`/`M_Permission`/`M_PermissionGroup` 已切到 `Proril_Sales_Center`，
**1.0 的人員管理／權限管理必須停用**，否則兩邊帳號權限狀態一定分岔。
另外「登入失敗自動鎖定」還留在 1.0（要連 `H_Logins` 一起搬），
所以 1.0 鎖的是舊庫、2.0 讀的是新庫，鎖定狀態不互通。
資料庫端還有三件人工步驟（見 `database/PortingNotes.md`）：

1. `publish.ps1 -Environment snapshot -Execute` 建 `M_PermissionGroup`
2. `copy-snapshot-data.ps1` 重灌 `M_User`/`M_Permission`（新庫那份還停在 2026-09-03 快照）
3. **`PermissionMasterSeed.sql`** 建 `M_System`/`M_Function` 並灌那 12 列（含 `0000103`）
4. **`PermissionDefObjectsMigration.sql`** 建 `M_PermissionDef`、加 `PermissionKey` 欄位並回填

第 3 步沒跑之前 2.0 是壞的：`api/` 已經改讀新庫的功能主檔，表還不存在的話側欄會空、
topbar 環境圖示不見、權限樹長不出來。
第 4 步沒跑之前也是壞的：權限樹與所有權限檢查都讀 `M_PermissionDef` / `PermissionKey`，
非 admin 帳號會變成什麼權限都沒有。

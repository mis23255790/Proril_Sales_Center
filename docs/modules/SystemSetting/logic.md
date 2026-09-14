# 系統管理 / 權限控管

對應 1.0 的「系統設定」系統（`SystemId.Setting = 0`）底下的兩支畫面：

| 2.0 | 1.0 | FunctionNo |
|---|---|---|
| `/sales-center/system/user-manager` | `Views/System/UserManager.cshtml` | 8 |
| `/sales-center/system/permission-manager` | `Views/System/PermissionManager.cshtml` | 1 |

## 相關資料表

| 表 | 用途 | `api/` 連哪個庫 |
|---|---|---|
| `M_User` | 帳號主檔 | `Proril_Sales_Center`（讀寫） |
| `M_Permission` | 個人權限：誰有哪個功能／細項 | `Proril_Sales_Center`（讀寫） |
| `M_PermissionGroup` | 群組（部門）預設功能範本 | `Proril_Sales_Center`（讀寫） |
| `M_System` | 系統別，權限樹第一層 | `Proril_Sales_Center`（唯讀，**只有 3 列**） |
| `M_Function` | 功能，權限樹第二層 | `Proril_Sales_Center`（唯讀，**只有 8 列**） |
| `M_PermissionLinkType` | 功能底下的細項，權限樹第三層以後 | `Proril_Sales_Center`（唯讀，**只有 4 列**） |
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
與 8 個功能（1 / 8 / 16 / 17 / 410 / 420 / 425 / 440）。
資料由 `database/PermissionMasterSeed.sql` 維護——**不要用 `copy-snapshot-data.ps1`**
（它會整批覆蓋，已在該腳本把這兩張排除），也**不要靠 `publish.ps1` 建表**。
（原本不能用 publish 的理由是「DACPAC 的 `M_Function` 是 `varchar`、中文會變 `?`」——
2026-09-14 資料庫定序已對齊成 `Chinese_Taiwan_Stroke_BIN`，`varchar` 存得下中文了，
那個理由不再成立；不用 publish 純粹是因為這兩張的**資料**要由 seed 腳本控管。）
要加功能請先確認 `NAV_MODULES` 有對應路由，再改那支腳本的 `@FunctionNos`。

實作上的後果：**權限樹那幾支 API 的併表一律先各自 `ToList()` 再用 LINQ to Objects 併**，
不能寫成單一 SQL——EF 組不出跨資料庫的查詢。

`M_PermissionLinkType` 在新庫只有 4 列：`0070102` 的 SOP-新增／SOP-公開、
`0320101` 與 `0320102` 的顯示金額欄位。組樹時掛不到功能節點的會被
`buildPermissionTree` 自動忽略，所以多餘的列不會造成問題。

> 既有問題，不是這次搬壞的：`OrderInfoVerifyApiController` 會檢查
> `(functionNo 425, linkType 100)` 的欄位級權限，但 `M_PermissionLinkType` 沒有這一列，
> 權限樹上根本勾不到，只能靠 admin 或直接寫 DB。1.0 也是同樣狀況。

## 權限的資料模型

`M_Permission` 一列代表「某人有某個東西」，靠三個欄位分辨是哪一種：

| 欄位 | 意思 |
|---|---|
| `LinkNumber` | 帳號。保留值 `000000` 代表**全體使用者** |
| `FunctionNo` | 功能代碼（`varchar(8)`），對照 `M_Function.FunctionNo` |
| `LinkType` | `1` = 這列是「功能本身」；`> 1` = 功能底下的細項 |
| `PermissionLinkTypeID` | 細項時對照 `M_PermissionLinkType.ID`，功能本身時是 null |

### FunctionNo 的格式

`AAABBCC` —— SystemNo 補零 3 位 + GroupNo 補零 2 位 + 序號補零 2 位，`varchar(8)`。
定長所以字串排序等於「系統別 → 群組 → 序號」的正確順序。

| FunctionNo | 功能 | 2.0 路由 |
|---|---|---|
| `0000101` | 權限管理 | `system/permission-manager` |
| `0000102` | 人員管理 | `system/user-manager` |
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

`LinkType` **沒有跨功能通用的值域**，每個 `FunctionNo` 底下各自定義
（例如訂單資料檢核的「顯示金額欄位」是 100）。要判斷細項權限請帶自己模組定義好的
functionNo + linkType，見 `app/composables/usePermission.ts`。

判斷順序一律是：`M_User.IsAdmin` 為真就全放行，否則查 `M_Permission`
（`LinkNumber` = 自己 或 `000000`）。

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
      └ M_Function.FunctionName（可勾）
          └ M_PermissionLinkType.LinkTypeName（可勾，可依 ParentLinkTypeID 再往下巢狀）
```

勾選**互相獨立、不做父子連動**（對應 1.0 fancytree 的 `selectMode: 2`）。
「勾了細項就自動開啟所屬功能」是**存檔時**才補的——存檔前會把每個勾到的節點往上找
parent，把沿路的 `FunctionNo` 一併加進去，否則細項有權限但功能沒開，等於進不去那個畫面。

組樹與取值的邏輯集中在 `app/utils/permissionTree.ts`，個人權限與群組範本兩棵樹共用。

> **與 1.0 的一個差異**：1.0 的 `v2AddFunctionEx` 把所有 `M_PermissionLinkType`
> 一律掛在功能底下，完全沒用 `ParentLinkTypeID`，巢狀的細項會被攤平成兄弟節點。
> 2.0 照 `ParentLinkTypeID` 掛，樹形才跟資料一致。

### 存檔

`MainApi/SetPermissionTree` 的參數形狀沿用 1.0：兩個 **JSON 字串**
（`str_permission_functionNos` 是 int 陣列、`str_permission_linkTypes` 是
`{FunctionNo, LinkType, PermissionLinkTypeID}` 陣列），不是物件，後端用
`JsonConvert.DeserializeObject` 解。

後端的做法跟 1.0 不同但結果相同：1.0 是「先刪不在清單裡的、再補沒有的」，
分四段條件寫、條件有重疊也有漏；2.0 改成算出目標集合後做差集，既有列的
`Creator`/`CreateTime` 一樣保留不動。

### 群組預設功能

兩顆按鈕做的是不同的事，很容易搞混：

- **群組預設功能編輯** → 開一棵獨立的樹，存的是 `M_PermissionGroup`（群組範本），
  **不會改到任何人目前的權限**。
- **群組預設功能套用** → 讀出該群組的範本，勾選後把勾勾點進**目前這個人**的樹裡。
  是聯集不是覆蓋（不會取消他原本就有的），而且**還要再按「儲存」才會寫進 `M_Permission`**。

`M_PermissionGroup` 沒有 `PermissionLinkTypeID` 欄位，細項只靠
`(FunctionNo, LinkType)` 認人，跟 `M_Permission` 不同。
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

## 上線注意事項

`M_User`/`M_Permission`/`M_PermissionGroup` 已切到 `Proril_Sales_Center`，
**1.0 的人員管理／權限管理必須停用**，否則兩邊帳號權限狀態一定分岔。
另外「登入失敗自動鎖定」還留在 1.0（要連 `H_Logins` 一起搬），
所以 1.0 鎖的是舊庫、2.0 讀的是新庫，鎖定狀態不互通。
資料庫端還有三件人工步驟（見 `database/PortingNotes.md`）：

1. `publish.ps1 -Environment snapshot -Execute` 建 `M_PermissionGroup`
2. `copy-snapshot-data.ps1` 重灌 `M_User`/`M_Permission`（新庫那份還停在 2026-09-03 快照）
3. **`PermissionMasterSeed.sql`** 建 `M_System`/`M_Function` 並灌那 11 列

第 3 步沒跑之前 2.0 是壞的：`api/` 已經改讀新庫的功能主檔，表還不存在的話側欄會空、
topbar 環境圖示不見、權限樹長不出來。

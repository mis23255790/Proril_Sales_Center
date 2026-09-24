# 系統管理 / 權限控管

對應 1.0 的「系統設定」系統（`SystemId.Setting = 0`）底下的兩支畫面：

| 2.0 | 1.0 | FunctionNo |
|---|---|---|
| `/sales-center/system/user-manager` | `Views/System/UserManager.cshtml` | `0000102`（舊 8） |
| `/sales-center/system/permission-manager` | `Views/System/PermissionManager.cshtml` | `0000101`（舊 1） |
| ~~`/sales-center/system/group-permission`~~ | （1.0 是權限管理頁裡的「群組預設功能編輯」彈窗） | ~~`0000103`~~ **2026-09-23 已移除** |

> **2026-09-23 起權限改成角色制（RBAC）**：不再逐人勾權限，改成「角色綁一組 PermissionKey、
> 帳號掛多個角色」。1.0 的個人權限（`M_Permission`）與部門範本（`M_PermissionGroup`）
> 都已停用，改由 `RBAC_Role` / `RBAC_RolePermission` / `RBAC_RoleUser` 取代。
> 群組權限頁（`0000103`）跟著拿掉——部門範本在角色制底下沒有意義，一個角色本身就是範本。
> 資料庫腳本是 `database/RbacObjectsMigration.sql`，搬移紀錄見
> `database/PortingNotes.md`「角色制 RBAC」。

> **2026-09-24 起權限樹與側欄都由 `RBAC_Permission` 一張表驅動**：原本是
> `M_System`（系統）→ `M_Function`（功能，位置編在 `FunctionNo`）→ `RBAC_Permission`（細項）
> 三張表拼起來，路由／icon 還寫死在前端 `NAV_MODULES`。現在 `RBAC_Permission` 是單一表自我參照
> （`NodeType` = MODULE / GROUP / PAGE / ACTION，`ParentKey` 指父節點），側欄的模組、分組、頁面、
> 路由、icon、說明與順序都從它來，`NAV_MODULES` 已刪除。頁面 key 拿掉 `.view`
> （`salesSearch.mixSalesShipping.view` → `salesSearch.mixSalesShipping`）。
> 上表的 `FunctionNo` 只剩歷史對照，權限與側欄都不再用它。

## 相關資料表

| 表 | 用途 | `api/` 連哪個庫 |
|---|---|---|
| `M_User` | 帳號主檔。`IsEnable` / `IsLocked` 會直接影響權限（見下方）；`IsAdmin` **已不再被讀** | `Proril_Sales_Center`（讀寫） |
| `RBAC_Permission` | 權限樹（單一表自我參照）：模組／分組／頁面／細項節點都在這裡，**側欄也由它驅動**，角色只能從這裡挑 key。**原名 `M_PermissionDef`**，改名時一併拿掉過渡期的 `PermissionLinkTypeID`；2026-09-24 再拿掉 `FunctionNo` / `LinkType`（見下方「權限樹的資料（`RBAC_Permission`）」） | `Proril_Sales_Center`（`api/` 唯讀，節點資料直接在 DB 維護，**2.0 新表**，23 列：3 模組 + 6 分組 + 9 頁面（含已停用的 `system.groupPermission`）+ 5 細項） |
| `RBAC_Role` | 角色：代碼、名稱、說明、`IsSystem` / `IsSuperAdmin` / `IsDefault` 旗標 | `Proril_Sales_Center`（讀寫，2.0 新表） |
| `RBAC_RolePermission` | 角色有哪些 PermissionKey，唯一鍵 `(RoleID, PermissionKey)`，FK 到 `RBAC_Role` 與 `RBAC_Permission` | `Proril_Sales_Center`（讀寫，2.0 新表） |
| `RBAC_RoleUser` | 帳號掛哪些角色，唯一鍵 `(Account, RoleID)` | `Proril_Sales_Center`（讀寫，2.0 新表） |
| `M_System` | 系統別。**2026-09-24 起不再組權限樹與側欄**，只剩 topbar 環境圖示（`GetMSystemWNo`）在讀 | `Proril_Sales_Center`（唯讀，**只有 3 列**） |
| `M_Function` | 功能。**2026-09-24 起權限樹與側欄都不再讀它**，`api/` 已拿掉對映（`SalesCenterDbContext` 沒有 `MFunctions`，`scaffold-sales-center.ps1` 也排除它與 `M_Function_bak_FunctionNo`）。**2.0 新增功能不用寫它** | `Proril_Sales_Center`（不再使用，**只有 9 列**，`0000103` 已設 `aStatus = 'N'`） |
| `M_Permission` | 1.0 的個人權限。**只剩備份用途，`api/` 不讀不寫** | `Proril_Sales_Center`（備份） |
| `M_PermissionGroup` | 1.0 的部門預設功能範本。**只剩備份用途，`api/` 不讀不寫** | `Proril_Sales_Center`（備份） |
| `M_PermissionLinkType` | 1.0 的細項主檔。**權限樹已不再用它**，`RBAC_Permission` 也不再對回它 | `Proril_Sales_Center`（不再使用） |
| `M_Department` | 1.0 的部門／群組主檔。**權限已不再用它**（原本是群組範本的下拉來源） | `PRORIL_WEB`（權限相關無讀取） |

四張 `RBAC_` 開頭的表都是 2.0 新表，`PRORIL_WEB` 沒有，所以不在 `TABLES.txt` /
`Tables/*.sql`（`copy-snapshot-data.ps1` 不歸它管），建表一律走 `RbacObjectsMigration.sql`。

> 下面這段是 2026-09-24 以前 `M_System` / `M_Function` 還在組權限樹時的背景，資料列照舊保留。
> **現在要讓新功能出現在權限樹與側欄，是加 `RBAC_Permission` 的節點**（見「新增一個功能要改哪裡」），
> 不必再動 `PermissionMasterSeed.sql`。

**`M_System` / `M_Function` 在新庫只有部分資料列**：`PRORIL_WEB.M_Function` 有 90+ 個
功能，絕大多數是 2.0 還沒搬的模組，整份複製的話權限樹會長出一堆點下去 404 的功能。
新庫只收 2.0 真的有頁面的 3 個系統別（0 系統設定 / 7 業務議題 / 32 業務檢索）
與 8 個功能（1 / 8 / 16 / 17 / 410 / 420 / 425 / 440），外加 2.0 專屬的 `0000103` 群組權限
（PRORIL_WEB 沒有，seed 腳本另外直接寫值；角色制之後已停用，列保留）。
資料由 `database/PermissionMasterSeed.sql` 維護——**不要用 `copy-snapshot-data.ps1`**
（它會整批覆蓋，已在該腳本把這兩張排除），也**不要靠 `publish.ps1` 建表**。
（原本不能用 publish 的理由是「DACPAC 的 `M_Function` 是 `varchar`、中文會變 `?`」——
2026-09-14 資料庫定序已對齊成 `Chinese_Taiwan_Stroke_BIN`，`varchar` 存得下中文了，
那個理由不再成立；不用 publish 純粹是因為這兩張的**資料**要由 seed 腳本控管。）

角色制之後權限相關的表**全部在 `Proril_Sales_Center`**，不再有跨庫併表的問題
（原本群組下拉要讀 `PRORIL_WEB.M_Department`，那段已經拿掉）。

> 原本的既有問題（1.0 就有）：`OrderInfoVerifyApiController` 會檢查
> `(functionNo 425, linkType 100)` 的欄位級權限，但 `M_PermissionLinkType` 沒有這一列，
> 權限樹上勾不到。2026-09-23 改成字串權限時補上了
> `salesSearch.orderInfoVerify.viewAmount`，**現在勾得到了**。

## 權限的資料模型

### 有效權限怎麼算

```
有效權限(帳號) = ⋃ 帳號自己掛的角色（RBAC_RoleUser）的 PermissionKey
               ∪ IsDefault 角色（everyone）的 PermissionKey
```

解析集中在 `api/Services/PermissionService.cs`（Scoped，同一個 request 內同一帳號只查一次 DB），
`BaseApiController.HasPermission` / `IsAdmin` 與 `RequirePermissionAttribute` 共用。規則：

- **不做個人例外授權**。要給某人多一個權限，就是讓他多掛一個角色（或新開一個角色）。
- **系統角色兩個**（`IsSystem = 1`，不可刪、不可改代碼）：

  | RoleCode | 名稱 | 旗標 | 意思 |
  |---|---|---|---|
  | `superAdmin` | 系統管理員 | `IsSuperAdmin = 1` | **全放行**，不看任何 PermissionKey。取代 1.0 的 `M_User.IsAdmin` |
  | `everyone` | 全體使用者 | `IsDefault = 1` | 所有帳號自動擁有，**不需要也不能設成員**。取代 1.0 的 `LinkNumber = '000000'` |

- **帳號停用（`IsEnable = false`）或鎖定（`IsLocked = true`）一律沒有任何權限**，
  連 everyone 也不給——即使手上的 token 還有效。token 是 24 小時有效、裡面不帶權限，
  不在這裡擋的話，停用帳號手上的舊 token 還能繼續用。帳號不存在也一樣當成沒有權限。
- **`aStatus`**：`RBAC_Role` / `RBAC_RolePermission` / `RBAC_RoleUser` 都有 `aStatus`，
  預設 `'Y'`。**手動在 DB 把某一列改成 `'N'` 就是讓那一列失效**——
  整個角色失效、角色的某個權限失效、某人的某個角色失效，`api/` 一律只認 `'Y'`。
  `RBAC_Permission.aStatus = 'N'` 的 key 也一樣不算（`system.groupPermission` 就是這樣停掉的），
  **而且連同它底下整棵子樹一起不算**（見「權限樹的資料」）。
- **畫面上取消勾選／移除成員是直接刪列（hard delete）**，不是改成 `'N'`。
  反過來，畫面上勾回一個原本是 `'N'` 的列時，是**把那一列改回 `'Y'`**（寫 `Modifier`/`ModiTime`），
  不是另外新增——兩張關聯表都有唯一鍵（`(RoleID, PermissionKey)`、`(Account, RoleID)`），
  新增會撞鍵。所以 `'N'` 是「DB 端手動停用」專用的狀態，畫面不會產生它。

`BaseApiController.IsAdmin(account)` 現在的意思是「有沒有掛 `IsSuperAdmin` 的角色」，
**`M_User.IsAdmin` 欄位角色制之後不再被讀**（`AddUser` 一律寫 `false`）。
`IsAdmin` 仍保留自己的 try/catch：解析失敗當成非管理員繼續往下走。

### 字串權限（PermissionKey）

2026-09-23 起，權限一律用 Google IAM 式的字串認，主檔是 `RBAC_Permission`。
2026-09-24 起它同時是**權限樹與側欄的唯一來源**（見下一節），key 依節點類型分成四種：

| NodeType | key 形式 | 例子 | 意思 |
|---|---|---|---|
| `MODULE` | `module` | `salesSearch` | 模組，側欄第一層，`Path` = 模組首頁 |
| `GROUP` | `module.grpXxx` | `salesSearch.grpOrder` | 模組內的分組標題，不是頁面、沒有 `Path` |
| `PAGE` | `module.function` | `salesSearch.mixSalesShipping` | 頁面，**勾了 = 進得去**，`Path` = 前端路由 |
| `ACTION` | `module.function.action` | `salesSearch.mixSalesShipping.viewAmount` | 頁面內被檢查的細項 |

目前的頁面與細項（測試區）：

| PermissionKey | NodeType | 名稱 | 路由（`Path`） |
|---|---|---|---|
| `system.permissionManager` | PAGE | 權限管理 | `system/permission-manager` |
| `system.userManager` | PAGE | 人員管理 | `system/user-manager` |
| ~~`system.groupPermission`~~ | PAGE | 群組權限（**已停用**，`aStatus = 'N'`，掛在 `system.grpAccess` 底下） | （頁面已刪） |
| `salesIssue.kindMaintain` | PAGE | 類別維護 | `sales-issue/kind-maintain` |
| `salesIssue.processMaintain` | PAGE | 議題維護 | `sales-issue/issues` |
| `salesIssue.processMaintain.createSop` | ACTION | SOP-新增 | |
| `salesIssue.processMaintain.publishSop` | ACTION | SOP-公開 | |
| `salesSearch.mixSalesShipping` | PAGE | 銷貨檢索 | `sales-search/shipping-inquiry` |
| `salesSearch.mixSalesShipping.viewAmount` | ACTION | 顯示金額欄位 | |
| `salesSearch.queryUnFinish` | PAGE | 未完成訂單 | `sales-search/unfinished-orders` |
| `salesSearch.queryUnFinish.viewAmount` | ACTION | 顯示金額欄位 | |
| `salesSearch.customQuery` | PAGE | 客戶檢索 | `sales-search/customer` |
| `salesSearch.orderInfoVerify` | PAGE | 訂單資料檢核 | `sales-search/order-info-verify` |
| `salesSearch.orderInfoVerify.viewAmount` | ACTION | 顯示金額欄位 | |

模組與分組：`salesIssue`（`salesIssue.grpIssue` 議題管理／`salesIssue.grpBasic` 基本資料）、
`salesSearch`（`salesSearch.grpCustomer` 客戶／`salesSearch.grpSales` 銷貨／`salesSearch.grpOrder` 訂單）、
`system`（`system.grpAccess` 權限控管）。

規則：

- **頁面 key 就是 `module.function`，沒有 `.view`**（2026-09-24 以前是 `module.function.view`，
  見下方「key 一旦寫進資料就不改名」的例外說明）。
- **勾細項一定連帶所有祖先**（頁面、分組、模組）：細項有權限但頁面沒開等於進不去，
  側欄也要有模組／分組才長得出上層。前端 `collectSelection` 與後端 `ResolvePermissionKeys`
  都會沿 `ParentKey` 往上補，不只靠前端。
- 權限判斷本身只看 key；`FunctionNo` / `LinkType` 兩欄**已從 `RBAC_Permission` 拿掉**。
- Action 只收**目前真的有在檢查**的動作，不預先捏造 view/create/edit/delete 全套。
  SOP-新增／SOP-公開 2.0 目前沒有任何地方在檢查，只是從 1.0 帶過來保留。
- 常數在後端 `api/Models/Enums.cs` 的 `PermissionKeys`（例如 `PermissionKeys.SalesSearch.MixSalesShipping`、
  `PermissionKeys.SalesSearch.MixSalesShippingViewAmount`；權限控管那組叫 `PermissionKeys.SystemSetting`，
  免得蓋掉 `System` 命名空間）、前端 `app/utils/permissionKeys.ts` 的 `PERMISSION_KEYS`
  （例如 `PERMISSION_KEYS.system.permissionManager`），**與主檔三邊要一起改**。
  常數只收 PAGE / ACTION，模組與分組沒有程式在檢查，不另開常數。
  節點類型的常數是後端的 `PermissionNodeType`（`Module` / `Group` / `Page` / `Action`）。
- 後端檢查：整支 Controller／單一 Action 用 `[RequirePermission(頁面 key...)]`（見「後端功能把關」），
  Action 內的細項判斷用 `BaseApiController.HasPermission(key)`。
  前端用 `usePermission().can(key)` / `checkPermission(key)`（見「前端 usePermission」）。

### 權限樹的資料（`RBAC_Permission`）

| 欄位 | 說明 |
|---|---|
| `ID` | 流水號 |
| `PermissionKey` | 節點識別碼（唯一），規則見上一節 |
| `NodeType` | `MODULE` / `GROUP` / `PAGE` / `ACTION`，`NOT NULL`，有 CHECK 約束 `CK_RBAC_Permission_NodeType` |
| `ParentKey` | 父節點的 `PermissionKey`，`NULL` = 最上層。自我參照外鍵 `FK_RBAC_Permission_Parent`。原名 `ParentPermissionKey` |
| `Label` | 中文名稱（側欄、權限樹顯示）。原名 `ActionName` |
| `LabelEn` | 英文名稱（目前只有模組有填，業務中心首頁的模組卡片用） |
| `Path` | 前端路由，**不含 `/sales-center`**（例如 `sales-search/shipping-inquiry`）。只有 MODULE 與 PAGE 有 |
| `Icon` | Iconify 名稱（例如 `i-lucide-truck`） |
| `Description` | 說明文字（模組首頁卡片） |
| `Sort` | 同一層內的順序 |
| `aStatus` | `'Y'` / `'N'`，見下方 |
| `Creator` / `CreateTime` / `Modifier` / `ModiTime` | 異動紀錄 |

2026-09-24 拿掉的：`FunctionNo`、`LinkType` 兩欄與唯一鍵 `UQ_RBAC_Permission_FunctionNo_LinkType`。

**維護方式：直接在 DB 改。** 節點資料由 `RbacObjectsMigration.sql` 第 4b.4 段**只灌一次**
（條件是「還沒有任何 MODULE 節點」），之後的位置、名稱、icon、順序都直接改表：

- **搬位置**：改 `ParentKey`（例如把頁面移到另一個分組）。
- **換順序**：改 `Sort`。
- **改名稱／icon／說明**：改 `Label` / `Icon` / `Description`，前端不用改程式、不用重新部署。
- 重跑腳本**不會**把手動調整蓋回去。反過來說，改腳本裡的 seed 清單對既有的庫也不會生效。

**`aStatus = 'N'` 連同底下整棵子樹一起失效**：`PermissionService.ActiveNodes` 只收
「自己與往上每一層祖先都是 `'Y'`，而且祖先鏈接得到最上層」的節點——`ParentKey` 指到不存在的節點
或形成迴圈的也一律不算。所以把一個模組設成 `'N'`，底下的分組、頁面、細項在權限判斷與側欄
一起消失；角色手上即使還有那些 key 也不算數。

**權限管理的樹例外（2026-09-24 起）**：停用節點照樣列出、顯示成 disabled（標「停用」、checkbox 不能動），
角色原本勾過的照樣顯示成已勾。存檔時前端不送停用節點，後端 `SaveRole` 也**不刪**停用節點的
`RBAC_RolePermission` 列——所以節點改回 `'Y'` 時，原本有勾的角色權限直接恢復。
角色清單的「權限」數只算有效的 PAGE / ACTION（自動補的 MODULE / GROUP 祖先與停用節點都不算）。
（`PermissionService.TreeNodes` 回全部掛得上樹的節點 + `IsActive`；`ActiveNodes` 是其中 `IsActive` 的那些。
祖先鏈斷掉或有迴圈的節點放不進樹，兩者都不收。）

**`RBAC_RolePermission` 的外鍵 `FK_RBAC_RolePermission_RBAC_Permission` 是 `ON UPDATE CASCADE`**：
改 `RBAC_Permission.PermissionKey` 時角色權限列跟著改。拿掉 `.view` 那次就是靠它讓角色跟著換 key。

### FunctionNo 的格式

`AAABBCC` —— SystemNo 補零 3 位 + GroupNo 補零 2 位 + 序號補零 2 位，`varchar(8)`。
定長所以字串排序等於「系統別 → 群組 → 序號」的正確順序。

> **2026-09-24 起權限樹、側欄、權限判斷都不再用 `FunctionNo`**，這一節只剩歷史對照。
> `api/Models/Enums.cs` 的 `FunctionIds` 常數留著，只給 `H_FileLink` 上傳紀錄
> （`LinkFunctionNo` 存的仍是 FunctionNo）對照用；`NAV_MODULES` 已刪除。

| FunctionNo | 功能 | 2.0 路由 |
|---|---|---|
| `0000101` | 權限管理 | `system/permission-manager` |
| `0000102` | 人員管理 | `system/user-manager` |
| ~~`0000103`~~ | ~~群組權限~~（已停用） | ~~`system/group-permission`~~（頁面已刪） |
| `0070101` | 類別維護 | `sales-issue/kind-maintain` |
| `0070102` | 議題維護 | `sales-issue/issues` |
| `0320101` | 銷貨檢索 | `sales-search/shipping-inquiry` |
| `0320102` | 未完成訂單 | `sales-search/unfinished-orders` |
| `0320103` | 客戶檢索 | `sales-search/customer` |
| `0320201` | 訂單資料檢核 | `sales-search/order-info-verify` |

**只有 `Proril_Sales_Center` 是這個格式**，`PRORIL_WEB`（1.0 在用）仍是 int 流水號，
兩邊永久分岔。改號的來龍去脈見 `database/FunctionNoFormatMigration.sql`。

### PermissionKey 的命名規則

**PermissionKey 是權限的識別碼，不是 C# namespace、資料夾或路由的投影。**
第一段 `salesSearch` 剛好跟 `Controllers/SalesSearch/` 同名，容易讓人以為要照程式結構推導，
其實同一個功能在各處本來就叫不同名字，以銷貨檢索為例：

| 地方 | 名稱 |
|---|---|
| PermissionKey | `salesSearch.mixSalesShipping` |
| C# namespace／Controller | `Controllers.SalesSearch` / `MixSalesShipApiController` |
| 前端路由（`RBAC_Permission.Path`） | `sales-search/shipping-inquiry` |
| 文件資料夾 | `docs/modules/SalesShipping/` |
| M_Function（歷史對照） | `0320101` 銷貨檢索 |

規則：

- **各段的意思**：`module` = 業務模組、`function` = 使用者可被授權的一個業務功能（= 一個頁面）、
  `action` = 在該功能裡被檢查的動作。頁面是 `module.function`，細項是 `module.function.action`，
  分組是 `module.grpXxx`（`grp` 開頭，一看就知道不是頁面）。全部用 lowerCamelCase 英文。
- **命名以使用者看到的業務功能為準**，不以任何一層程式碼的名稱為準。
  程式搬資料夾、改 Controller 名、改路由，**都不改 key**——路由改 `Path`、位置改 `ParentKey`，
  key 本身不動。
- **key 一旦寫進資料就不改名。** 改名等於兩個環境的 `RBAC_RolePermission`
  全部要回填，正是 FunctionNo 把位置編進號碼、搬一次就要全庫改號的老問題。
  既有的 key（`mixSalesShipping`、`queryUnFinish`、`customQuery`… 大多沿用 1.0 的名稱）
  就算跟上表其他地方對不上也維持原樣，**命名規則只套用在新功能**。
  不用的 key 也不刪，改 `aStatus = 'N'`（`system.groupPermission` 就是這樣處理）。
  > **唯一的例外**：2026-09-24 頁面 key 拿掉 `.view`。當時只有測試區有資料、正式區還沒建庫，
  > 又有 `ON UPDATE CASCADE` 讓角色權限列跟著改，才一次做掉。之後不要再比照。
- **位置不編進 key。** 頁面換分組、換模組只改 `ParentKey`，key 不動——所以分組 key 雖然帶模組前綴，
  頁面 key **不帶分組**（是 `salesSearch.mixSalesShipping`，不是 `salesSearch.grpSales.mixSalesShipping`）。
- **不要用 FunctionNo 當識別。** FunctionNo（`AAABBCC`）把系統別／群組／序號編進號碼，
  功能換群組就得改號。`032.01.01` 這類點分寫法是同一件事換個格式，
  問題一樣，而且 9 個字元放不進 `varchar(8)`，不採用。

### 新增一個功能要改哪裡

1. `app/pages/sales-center/` 底下加頁面檔（例如 `sales-search/xxx.vue`）。
2. `RBAC_Permission` 加 PAGE 節點（有細項也一起加 ACTION 節點），填 `NodeType` / `ParentKey`
   （掛在哪個分組或模組底下）/ `Label` / `Path`（第 1 步的路由，不含 `/sales-center`）/ `Icon` /
   `Description` / `Sort`，key 的取名照上面「PermissionKey 的命名規則」。
   `RbacObjectsMigration.sql` 第 4b.4 段的 seed **只在還沒有 MODULE 節點時跑**，對既有的庫不會生效——
   **既有的庫請直接 INSERT，或另外寫一支 `*ObjectsMigration.sql`**；
   同時把節點補進 4b.4 的清單，全新環境建庫時才長得出來。
   新模組就先加 MODULE 節點（`Path` = 網址第 2 段），模組首頁由 `[module]/index.vue` 共用，不用開頁面檔。
3. `PermissionKeys`（後端 `api/Models/Enums.cs`）與 `PERMISSION_KEYS`（前端 `app/utils/permissionKeys.ts`）加常數。
4. 新功能的 Controller 掛 `[RequirePermission(PermissionKeys.Xxx.Yyy)]`（class 層級，頁面 key）；
   跨功能共用的 Action 在 Action 上把用得到的頁面 key 都列上去。
5. 在權限管理把新 key 勾進需要的角色（superAdmin 不用勾；勾頁面或細項會自動帶上分組與模組）。

**不用再改**：`NAV_MODULES`（已刪除）、`FunctionIds`、`PermissionMasterSeed.sql` 的 `M_Function`——
側欄與權限樹都不再讀它們。

## 人員管理

- 列表：一進畫面就列出全部帳號（`GetAllUserList`，前端分頁），可用工號／姓名關鍵字與
  狀態（啟用／停用／鎖定）篩選；點一列在右邊編輯（`GetUserSetting`）。
- 新增：按「新增人員」另外開表單，工號填在表單裡；存檔前會先比對人員清單，已存在就擋下來。
  新增成功後自動切到該帳號的編輯模式。
  （1.0 是先輸入工號查詢、查不到直接變新增模式，打錯工號很容易順手建出錯的帳號，
  2026-09-24 拆開。）

- 新增帳號與密碼重置的**初始密碼都等於帳號本身**（AES 加密後存 `M_User.Password`），
  同時把 `IsFirstLogin` 設為 true。這是 1.0 的規則，沒有改。

> **但 2.0 的登入只走 SSO**，`M_User.Password` 在 `Proril_Sales_Center` 已經全部清成
> `NULL`（2026-09-14，備份在 `M_User_bak_Password`）。`LoginSso` 不看密碼，
> 所以清空不影響登入；`MainApi/Login`（帳密登入）端點還在但前端沒有任何地方呼叫。
> **這留下一個不一致**：`AddUser` / `ResetPassword` 仍會寫 `AES(帳號)`，
> 新建的帳號會變成唯一有密碼的那個。要嘛拿掉那兩段，要嘛連 `Login` 一起下架。

- 「帳號啟用」= `IsEnable`。**停用的帳號沒有任何權限**（見「有效權限怎麼算」）。
- **「管理人員」開關（`IsAdmin`）已拿掉，改成角色多選**：
  - 下拉來源是 `GetRoleList`，不列 everyone（所有人自動擁有）。
  - superAdmin 顯示成「系統管理員（全放行）」，**只有 superAdmin 自己能勾／取消**，
    其他人看得到但選項是 disabled（後端 `SetUserRoles` 也擋）。superAdmin 不能把自己移出。
  - 存檔順序：先 `AddUser` / `UpdateUser` 存帳號本身，成功後**角色有變才**打
    `SetUserRoles`（整批取代）。角色沒改就不打，免得非 superAdmin 編輯 superAdmin 帳號時
    撞到 superAdmin 的檢查。帳號存成功、角色失敗時訊息是「帳號已儲存，但角色設定失敗」。
  - 存完重載自己的權限與側欄（改到的可能是自己）。
- `AddUser` / `UpdateUser` **不再收 `isAdmin` 參數**，只收 `account` / `name` / `isEnable`。
  `AddUser` 的 `M_User.IsAdmin` 一律寫 `false`。
- `GetUserSetting` 多回 `roleIds`（有效的角色 ID），`isAdmin` 欄位仍在但改成由 superAdmin 角色推導；
  `GetAllUserList` 的 `isAdmin` 同樣改由 superAdmin 角色推導，欄位名不變。

與 1.0 的差異（都是刻意的）：

1. API 回傳從裸 `bool` 改成 `CustomApiViewModel` 信封。1.0 失敗時只回 `false`，
   畫面永遠只能說「帳號新增失敗」，看不到原因。
2. 後端補上功能權限檢查（`system.userManager`）。1.0 這些端點只掛 `[Authorize]`，擋在前端的
   `checkPermission()`——等於任何登入者直接打 API 就能建管理員帳號。
3. 刪除帳號時**同一個交易**連同他的 `RBAC_RoleUser` 一起刪。1.0 只刪 `M_User`，權限列變孤兒，
   之後同工號重建帳號會直接繼承到舊權限。
4. 多一支「解除鎖定」。`IsLocked` 在 1.0 只有登入失敗會設成 true，畫面上解不開。
5. 不能刪自己的帳號；**非 superAdmin 不能刪 superAdmin 的帳號**。
6. 管理員從「任何能進人員管理的人都能把自己或別人設成管理員」改成「只有 superAdmin 能指派 superAdmin」。

## 權限管理（角色管理）

2026-09-23 起權限管理頁就是**角色管理**，不再選人勾樹。

### 畫面

- **左邊：角色清單**（`GetRoleList`），欄位是角色名稱（下方小字角色代碼）／權限數／成員數。
  superAdmin 標「全放行」、權限數顯示「全部」；everyone 標「所有人」、成員數顯示「全部」。
  整列可點擊進編輯；上方「新增角色」。
- **右邊：編輯區**（`GetRole` 一次拿回基本資料 + 權限 key + 成員），由上而下是基本資料、成員、權限
  - **基本資料**：代碼（英文字母開頭，英數字／底線／連字號，最多 50 字，唯一）、名稱（必填，最多 50 字）、
    說明（最多 200 字）。系統角色標「系統角色」，**代碼不能改**，名稱與說明可以改。
  - **成員**：從全部帳號（含停用，停用會標 `[停用]`）挑成員。everyone 不顯示成員選單
    （說明「所有啟用中的帳號都自動擁有」），後端 `SetRoleMembers` 也擋。
    **superAdmin 的成員只有 superAdmin 能改**，其他人看得到但唯讀；superAdmin 不能把自己移出。
  - **權限**：權限樹勾這個角色的 key（見下方「權限樹」）。superAdmin 不顯示樹，
    只說明「全部功能放行」，存檔時也不送 key（後端也會忽略）。
- **存檔**：先 `SaveRole`（基本資料 + 權限，一個交易），成功後**成員有變才**打 `SetRoleMembers`
  （整批取代）。角色存成功、成員失敗時提示「角色已儲存，但成員設定失敗」並重新載入該角色。
  存完呼叫 `loadPermissions(true)` 與 `loadUserFunctions(true)`——改到的可能是自己所屬的角色。
- **刪除**：`DeleteRole`，系統角色沒有刪除按鈕、後端也擋。同一個交易刪掉該角色的
  `RBAC_RoleUser` / `RBAC_RolePermission` / `RBAC_Role`，成員會立刻失去這個角色給的權限。

後端讀取一律只認 `aStatus = 'Y'` 的列；存檔時畫面上沒勾的有效列直接刪，
勾回來的 `'N'` 列改回 `'Y'`（見「有效權限怎麼算」）。

### 權限樹

2026-09-24 起整棵樹只來自 `RBAC_Permission`（`GetRBACPermission`），依 `ParentKey` 組、同層依 `Sort` 排：

```
MODULE（業務議題／業務檢索／系統管理，不可勾）
  └ GROUP（議題管理／客戶／訂單／權限控管…，不可勾）
      └ PAGE（議題維護／銷貨檢索…，可勾 = 進得去）
          └ ACTION（SOP-新增／顯示金額欄位…，可勾，可依 ParentKey 再往下巢狀）
```

PAGE 也可以直接掛在 MODULE 底下（沒有分組）。原本最上層的 `M_System.TypeName`（行政／現場／…）
那一層純分類跟著 `M_System` 一起拿掉了。

權限管理用 `GetRBACPermission?includeDisabled=true` 拿樹，**停用節點照樣出現、顯示成 disabled**
（例如 `system.groupPermission`）；停用一個分組或模組，底下整棵子樹都是 disabled，
「停用」標籤只標在最上面那一層。規則見上方「`aStatus = 'N'` 連同底下整棵子樹一起失效」。

節點 key 是 `p-{PermissionKey}`。**MODULE / GROUP 節點不能勾**，只有 PAGE / ACTION 能勾。

勾選**互相獨立、不做父子連動**（對應 1.0 fancytree 的 `selectMode: 2`）。
「勾了細項就自動開啟所屬頁面、分組、模組」是**存檔時**才補的——存檔前 `collectSelection` 會把每個勾到的節點
沿 `ParentKey` 往上找，把沿路**所有祖先**的 PermissionKey 一併加進去：細項有權限但頁面沒開等於進不去，
角色也要擁有模組／分組節點，側欄才長得出上層。
後端 `ResolvePermissionKeys` 也會再補一次，不只靠前端；主檔找不到（或已停用）的 key 一律回錯，不默默略過。
所以 `RBAC_RolePermission` 裡除了頁面與細項，也會有 MODULE / GROUP 的 key（權限數會比勾的多）。

組樹與取值的邏輯集中在 `app/utils/permissionTree.ts`。

> **與 1.0 的一個差異**：1.0 的 `v2AddFunctionEx` 把所有 `M_PermissionLinkType`
> 一律掛在功能底下，完全沒用 `ParentLinkTypeID`，巢狀的細項會被攤平成兄弟節點。
> 2.0 照父節點掛，樹形才跟資料一致。

### 已移除：逐人權限與群組預設功能

以下 2026-09-23 上午（字串權限那一版）才做的東西，當天下午改成角色制時**整段拿掉**：

- `SetPermissionKeys`（逐人存權限到 `M_Permission`）。
- 群組權限頁 `system/group-permission.vue`（`0000103`）與它的 `SaveDepPermissionKeys`
  （存部門範本到 `M_PermissionGroup`）。功能與 key 改 `aStatus = 'N'` 停用，不刪。
- 權限管理的「群組預設功能套用」彈窗與「套用後差異」清單（`diffSelection`）。
- 讀部門範本的 `CommonApi/GetDepFunction`——`CommonApiController` 整支刪除。
- 群組下拉的 `GetDepartmentList`，以及已經不組樹的 `GetPermissionLinkType` / `GetMPermissionLinkType`。

部門範本在角色制底下沒有對應概念：一個角色本身就是一組可重複套用的權限。
`M_PermissionGroup` 的資料**沒有轉成角色**（見「資料轉換」），留在表裡當備份。

## 後端功能把關（`RequirePermissionAttribute`）

`api/Filters/RequirePermissionAttribute.cs`：掛在 class 上代表整支 Controller 都要那個頁面的
key（`module.function`）；列多個 key 時**任一個**有就放行；Action 上的比 Controller 上的優先（取最靠近 Action 的那個）；
`[AllowAnonymous]` 的端點不擋。

權限不足時回 **HTTP 403** + `CustomApiViewModel { isSuccess: false, message: "沒有此功能的權限" }`。
用 403 而不是 200 + `isSuccess = false`，是因為前端把 `isSuccess = false` 當「查無資料」處理，
權限不足會被默默吞成空清單。前端 `useApi` 攔到 403 會跳 warning toast「沒有權限」
（description 帶後端訊息），不當成連線錯誤。

1.0 只掛 `[Authorize]`，進不進得去畫面完全靠前端擋；2.0 補在後端。目前掛的位置：

| Controller / Action | 需要的 key（任一） |
|---|---|
| `WorkProcessApiController`（class，含 `.Attach.cs` / `.Permission.cs`） | `salesIssue.processMaintain` |
| └ `GetKindList` | `salesIssue.processMaintain` / `salesIssue.kindMaintain` |
| └ `SaveKindData` | `salesIssue.kindMaintain` |
| └ `GetWPOrderForCustom`（客戶相關資訊也在查） | `salesIssue.processMaintain` / `salesSearch.customQuery` |
| `CustomQueryApiController`（class，議題維護的客戶欄位也會查客戶） | `salesSearch.customQuery` / `salesIssue.processMaintain` |
| └ `SaveCustom`、`.Memo.cs` 的 `GetCustomMemo` / `SetCustomMemo` / `DeleteCustomMemo` | `salesSearch.customQuery` |
| `MixSalesShipApiController`（class） | `salesSearch.mixSalesShipping` |
| └ `GetCustomerCredit` / `GetCustomerCreditCRM` / `GetSalesTotal` / `GetCustomerUnfinOrder`（客戶相關資訊在用） | `salesSearch.mixSalesShipping` / `salesSearch.customQuery` |
| `SalesOrderUnFinishApiController`（class） | `salesSearch.queryUnFinish` |
| `OrderInfoVerifyApiController`（class） | `salesSearch.orderInfoVerify` |

**刻意沒掛的**：

- `MainApiController`：登入、目前使用者、`GetMyPermissions` / `GetRBACPermission` / `CheckPermission`
  所有登入者都要打；人員管理／權限管理那幾支在 Action 內自己檢查
  （`DenyIfNoUserManagerPermission` / `DenyIfNoPermissionManagerPermission`，回 200 + `isSuccess = false`），
  `GetRoleList` 是 `permissionManager` 或 `userManager` 任一即可（人員管理的角色下拉也在用）。
- 跨模組共用的 `CustomerApiController`、`UploadApiController`、`ManufacturingApiController`：
  好幾個功能都在用，只掛 `[Authorize]`，不綁特定功能。

## 金額欄位後端遮蔽

沒有 `viewAmount` 時，**後端直接把金額相關欄位清成 `null`**，不只靠前端藏欄位——
直接打 API 一樣看不到。清的欄位與各自匯出 Excel 在沒有權限時拿掉的那組一致：

| 端點 | 權限 | 清掉的欄位 |
|---|---|---|
| `MixSalesShipApi/GetSalesOrder`、`GetSalesOrder_1` | `salesSearch.mixSalesShipping.viewAmount` | `Th012` 單價、`Th013` 數量*單價、`Tg011` 幣別、`Tg012` 匯率、`Th037` 台幣未稅、`Th038` 台幣稅額、`SumAmt` 台幣總額 |
| `SalesOrderUnFinishApi/GetUnfinOrder`、`QueryUnfinOrder_1` | `salesSearch.queryUnFinish.viewAmount` | `Td011` 原幣單價、`Td012` 原幣金額、`Tc008` 幣別、`Tc009` 匯率、`Ntd` 台幣金額、`Tc014` 付款條件、`Tc016` 課稅別 |
| `OrderInfoVerifyApi/GetPOCheckView` | `salesSearch.orderInfoVerify.viewAmount` | 表頭：`訂單金額`、`交易條件`（null）、`交易條件名稱`（清成空字串）；明細 `VPoDetail`：`幣別`、`匯率`、`外幣單價`、`外幣金額`、`台幣金額` |

`交易條件名稱` 是非 nullable 字串，清成空字串——前端明細 modal 是直接字串插值，清成 null 會顯示成 `"null"`。

> **訂單資料檢核的明細視窗也會一起被遮**：列表與明細 modal 打的是同一支 `GetPOCheckView`，
> 所以沒有 viewAmount 的人在明細視窗裡也看不到「訂單金額」與「交易條件」。
> 這是**決定過的**，不是漏掉——交易條件跟金額一樣屬於商務條件，照匯出的規則一起遮。

## 側欄選單

2026-09-24 起**整份功能表都從 DB 來**（`RBAC_Permission`），前端寫死的 `NAV_MODULES` 已刪除。
邏輯在 `app/composables/useAppNavigation.ts`：

- `loadUserFunctions()` **平行**打 `MainApi/GetRBACPermission`（節點）與 `usePermission().loadPermissions()`
  （目前登入者的有效權限），側欄、業務中心首頁卡片、模組首頁、麵包屑共用同一份（`useState('app-nav-nodes')`）。
- 節點排成三層：**MODULE → GROUP（分組標題）→ PAGE（功能）**。
  名稱用 `Label`、路由用 `Path`（前面接 `/sales-center`）、icon 用 `Icon`、卡片說明用 `Description`，順序照 `Sort`。
  - PAGE 直接掛在 MODULE 底下（沒有分組）也可以，會放進一個沒有標題的分組，排在有標題的分組前面。
  - **ACTION 不出現在側欄**（權限管理的樹照樣看得到）；沒有 `Path` 的 PAGE 也不出現。
- 可見性：每個 PAGE 用 `canAccess(permissionKey)` 判斷，也就是 `usePermission().can(頁面 key)`
  （superAdmin 全開）。分組底下一項都看不到就不顯示分組，模組底下一個分組都沒有就不顯示模組。
  `canAccess` 的參數**改成 PermissionKey**（原本是 FunctionNo）。
- 停用（`aStatus = 'N'`）的節點與它底下的子樹後端就不會回（側欄呼叫 `GetRBACPermission`
  不帶 `includeDisabled`），前端不用另外判斷。

失敗時的處理分兩種：

- **權限沒載到**（`GetMyPermissions` 失敗：API 掛了、token 過期）：**不過濾**，顯示全部頁面——
  寧可多顯示，也不要讓人一進站看到空選單以為系統壞了。真正的把關在後端（`RequirePermission`）。
- **節點沒載到**（`GetRBACPermission` 失敗）：沒有別的來源能長側欄，只能是空的，
  顯示「沒有可用功能」的提示（`hasNoAccessibleModule`）。
  「權限載到但一個都沒有」同樣過濾成空並顯示這個提示。

**載入中則不顯示任何功能**，側欄放 skeleton 佔位（`isLoadingUserFunctions`）。
原本載入中跟失敗一樣走「顯示全部」，結果沒權限的項目會先出現、API 回來後又消失。

**模組首頁（`app/pages/sales-center/[module]/index.vue`）**：模組是否存在看**未過濾**的完整表
（`allModules`，`Path` 對網址第 2 段），權限只影響列出哪幾張卡片。因為功能表改成非同步從 DB 載，
404 判斷**要等載完**（`isLoadingUserFunctions` 變 false）才做，用 `showError` 丟 404——
原本同步判斷的寫法會讓每個模組在載入前都先被當成 404。新增模組只要加 MODULE 節點，不用開頁面檔。

## 前端 `usePermission`

`app/composables/usePermission.ts`：

- 登入後打一次 `MainApi/GetMyPermissions`（回 `{ isSuperAdmin, keys }`，superAdmin 的 keys 是空陣列），
  存在 `useState('app-my-permissions')`，之後每個 key 都查這份，不用逐個打後端。
  同一輪好幾個地方同時要時共用同一個請求。
- `can(key)`：同步判斷，要先載入；沒載到一律當沒有權限。
- `checkPermission(key)`：非同步，先確保已載入再判斷。頁面 `onMounted` 用這個最省事。
- `isSuperAdmin`：computed，人員管理／權限管理用來決定 superAdmin 相關選項能不能動。
- `loadPermissions(true)`：強制重載。權限管理存角色／刪角色、人員管理改角色之後都會呼叫
  （連同 `loadUserFunctions(true)`），改到自己的角色才會馬上反映。

**這只決定畫面顯示**，真正的把關在後端，前端判斷錯了也拿不到資料。
`MainApi/CheckPermission`（回裸 bool）仍保留給單點查詢，前端一般不再用。

## 端點

| 端點 | 用途 | 權限 |
|---|---|---|
| `MainApi/GetRoleList` | 角色清單（含權限數／成員數） | `permissionManager` 或 `userManager` |
| `MainApi/GetRole(roleId)` | 單一角色：基本資料 + 權限 key + 成員 | `permissionManager` |
| `MainApi/SaveRole(roleId, roleCode, roleName, description, str_permission_keys)` | 新增（`roleId = 0`）／修改角色與權限；`str_permission_keys` 是 key 陣列的 **JSON 字串**。回 `Body` = 角色 ID | `permissionManager` |
| `MainApi/DeleteRole(roleId)` | 刪除角色（連同權限與成員），系統角色不能刪 | `permissionManager` |
| `MainApi/SetRoleMembers(roleId, str_accounts)` | 角色成員整批取代（帳號陣列的 JSON 字串） | `permissionManager`；superAdmin 成員限 superAdmin |
| `MainApi/SetUserRoles(account, str_role_ids)` | 某帳號的角色整批取代（角色 ID 陣列的 JSON 字串），everyone 傳進來會略過 | `userManager`；superAdmin 增減限 superAdmin |
| `MainApi/GetMyPermissions` | 目前登入者的有效權限 | 登入即可 |
| `MainApi/GetRBACPermission` | 權限樹的全部有效節點（自己與祖先都是 `'Y'`，依 `Sort` 排），回 `permissionKey` / `nodeType` / `parentKey` / `label` / `labelEn` / `path` / `icon` / `description` / `sort`。**側欄、首頁卡片、模組首頁、麵包屑與權限管理的樹都用這一份** | 登入即可 |
| `MainApi/CheckPermission(permissionKey)` | 單點檢查（裸 bool），保留 | 登入即可 |
| `MainApi/GetUserSetting` / `AddUser` / `UpdateUser` / `DeleteUser` / `ResetPassword` / `UnlockUser` | 人員管理 | `userManager` |
| `MainApi/GetAllUserList` | 全部帳號（含停用），工號與成員下拉 | 登入即可 |

**已移除**：`SetPermissionKeys`、`SaveDepPermissionKeys`、`GetPermissionLinkType`、
`GetMPermissionLinkType`、`GetDepartmentList`、`CommonApi/GetDepFunction`
（`CommonApiController` 整支刪除）；`GetMPermissionDef` 改名成 `GetRBACPermission`。
2026-09-24 權限樹改成單一表時再移除：`GetMSystem`、`GetMFunction`、`GetUserFunctions`
（連同 `UserFunctionViewModel`）——權限樹與側欄都改讀 `GetRBACPermission` + `GetMyPermissions`。
`GetMSystemWNo`（topbar 環境圖示）不受影響，仍讀 `M_System`。
更早移除的 1.0 端點：`SetPermissionTree` / `SaveDepFunction` / `CheckUserPermissionLinkType`。

## 資料轉換（`RbacObjectsMigration.sql`）

既有的個人權限在建表時一次轉成角色，**只在 `RBAC_RoleUser` 還是空的時候做**，重跑不會重複建角色：

1. **everyone 的權限** = `M_Permission` 裡 `LinkNumber = '000000'` 的 key（只收仍啟用的 key）。
2. **`M_User.IsAdmin = 1` 的帳號 → 指派 superAdmin**。個人 key 不另外轉（全放行，轉了也沒意義）。
3. **其餘帳號**：個人 key 先扣掉 everyone 已有的（有效權限本來就是聯集，扣掉不失真），
   把剩下的 key 排序後串成「簽章」，**簽章相同的人歸成同一個角色**：
   角色代碼 `migratedNN`、名稱「移轉角色-NN」、說明「由舊個人權限依權限組合自動產生，請改名或合併」。
   編號依簽章裡字典序最小的成員帳號排序，重跑結果穩定、好對照。扣完是空集合的人不建角色
   （他只有 everyone 的權限）。
4. **不轉的**：`PermissionKey IS NULL` 的 1.0 遺留列（FunctionNo 改格式時刻意保留的舊功能）、
   `M_PermissionGroup` 的部門範本、`M_User` 裡已經不存在的帳號的孤兒權限列。

移轉角色只是「把現況原樣搬過來」，**上線後請在權限管理改成有意義的名稱或合併**。

**驗證**（腳本最後自己跑）：

- 每個非管理員帳號「轉換前有效權限（本人 ∪ `000000`）」與「轉換後有效權限（所屬角色 ∪ IsDefault 角色）」
  的對稱差，應為 0 筆。
- `M_User.IsAdmin = 1` 與 superAdmin 成員的對稱差，應為 0 筆。

**測試區 2026-09-23 執行結果**：兩組對稱差都是 0 筆；建出 12 個角色（2 個系統角色 + 10 個移轉角色）、
36 筆角色權限、25 筆角色成員。
2026-09-24 權限樹改成單一表（第 4b 段）時，角色補上祖先節點（模組、分組），
角色權限從 36 筆變成 72 筆；驗證改成把舊的 `xxx.view` 換算成新 key、只比 PAGE / ACTION 節點，
對稱差仍是 0 筆。

`M_Permission` / `M_PermissionGroup` **不刪、不改**，留作備份，`api/` 之後不再讀寫它們。

## 上線注意事項

資料庫腳本在 `Proril_Sales_Center` 上**依序**跑：

1. `database/PermissionMasterSeed.sql` —— `M_System` / `M_Function`（含 `0000103`）
2. `database/PermissionDefObjectsMigration.sql` —— 建 `M_PermissionDef`、`M_Permission.PermissionKey` 回填
   （`RBAC_Permission` 已存在的庫會自動整支略過）
3. `database/RbacObjectsMigration.sql` —— 改名 `RBAC_Permission`、建三張角色表、停用群組權限、轉換資料，
   以及第 4b 段的權限樹改造（加欄位、頁面 key 拿掉 `.view`、拿掉 `FunctionNo` / `LinkType`、灌節點、角色補祖先）

後兩支走 `database/scripts/run-objects-migration.ps1`：

```powershell
.\scripts\run-objects-migration.ps1 -Script RbacObjectsMigration.sql -Environment snapshot
.\scripts\run-objects-migration.ps1 -Script RbacObjectsMigration.sql -Environment snapshot -Execute
```

- **測試區 2026-09-23 已執行完成（第 4b 段 2026-09-24 已執行）；正式區還沒建庫。**
- 第 4b 段會拿掉 `FunctionNo` / `LinkType`、把頁面 key 改名，**跑完之後 2026-09-23 版的 `api/` 與前端就不能用了**
  （舊版讀 `LinkType` 組側欄、檢查的是 `xxx.view`）。腳本跑完要緊接著部署新版。
- 順序反過來或第 3 步沒跑：新版 `api/` 讀的是 `RBAC_*`，表不存在的話非 superAdmin 什麼權限都沒有，
  連 superAdmin 也不存在（沒有人是管理員）。所以**先跑腳本、再部署 `api/` 與前端**。
- `copy-snapshot-data.ps1` 之後若重灌 `M_Permission` / `M_PermissionGroup`，**已經不影響權限**——
  那兩張只剩備份。但重灌之後再跑 `RbacObjectsMigration.sql` 也**不會**重新轉換
  （`RBAC_RoleUser` 已有資料就略過），要重轉得先清空三張角色表。
- **資料庫定序是 `Chinese_Taiwan_Stroke_BIN`，物件名稱區分大小寫**：是 `RBAC_Role` 不是 `rbac_role`，
  手寫查詢時打錯大小寫會直接「無效的物件名稱」。表名改過好幾輪（見 `database/PortingNotes.md`），
  腳本會把任何一個舊名原地改成現在的名字。

`M_User` 已切到 `Proril_Sales_Center`，**1.0 的人員管理／權限管理必須停用**，否則兩邊帳號狀態一定分岔。
另外「登入失敗自動鎖定」還留在 1.0（要連 `H_Logins` 一起搬），
所以 1.0 鎖的是舊庫、2.0 讀的是新庫，鎖定狀態不互通。

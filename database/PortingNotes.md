# 搬遷紀錄：業務議題 + 訂單資料檢核的本地表複製到 Proril_Sales_Center

**2026-09-03**：把以下 13 張**真正本地**的表（結構 + 資料）從 `192.168.1.142,50002`
的 `PRORIL_WEB` 複製一份到同一台主機、同一個 port 底下的獨立資料庫 `Proril_Sales_Center`。

- `TABLES.txt` 白名單的 8 張（業務議題）：
  `D_WorkProcess`/`D_WorkProcessDetail`/`D_WorkProcessSearch`/`D_WorkProcessCustomer`/
  `D_WorkProcessPermission`/`M_WorkProcessPhrase`/`M_WorkProcessType`/`CRM_Customer`
- 另外 5 張（帳號權限 + 訂單資料檢核的本地參照表）：
  `M_User`/`M_Permission`/`H_FileLink`/`COP_CheckRule`/`COP_DepData`

> 這是**一次性快照**，不是同步機制。複製之後兩邊資料不會自動保持一致——
> `PRORIL_WEB` 之後新增/修改的資料不會自動進到 `Proril_Sales_Center`，反之亦然。
> `api/appsettings*.json` 的 `ConnectionStrings:ProrilWeb` **仍然指向 `PRORIL_WEB`**，
> 沒有因為這次複製而改接 `Proril_Sales_Center`（詳見下面「為什麼不能整個切過去」）。

## 訂單資料檢核相關的 View / 預存程序 / 函式（第二階段，另一支腳本）

一開始以為 `V_POList`/`V_PODetailList`/`V_Product_English_All`/`V_UpFileData`/
`V_ERPCustomer` 這幾個 View 是查 `PRORIL_WEB` 本地表，複製資料等於凍結成今天的快照，
會讓訂單資料檢核失去即時性，所以第一輪只複製了上面這 13 張真正本地的表。

後來確認 `Proril_Sales_Center` 跟 `PRORIL_WEB` **在同一台 SQL Server instance**
（`192.168.1.142,50002`），而這些 View 透過的是 **instance 層級的 linked server**
（`[192.168.1.200]`，鼎新 ERP 主機），不是資料庫層級設定——同一個 instance 底下、
不同資料庫都能用同一個 linked server。實測 `Proril_Sales_Center` 底下執行
`SELECT TOP 1 * FROM PRORIL_WEB.dbo.CRM_Customer` 沒問題，代表 View 定義原封不動搬過去，
查到的還是即時 ERP 資料，不是快照。

順著這幾個 View 追依賴關係（`sys.sql_expression_dependencies` 遞迴查兩輪確認無遺漏），
實際範圍比一開始以為的大：

- **7 個 View**：`V_ERPCustomer`、`V_POList`、`V_PODetailList`、`V_Product_English_All`、
  `V_UpFileData`、`V_COPMOQ`（分量計價，`prc_COPOrderChk` 內部用）、`V_COPNoChk`（純靜態
  對照表，無資料表依賴）。全部用四段式命名 `[192.168.1.200].{DB}.dbo.{table}` 查 ERP，
  沒有寫死本地資料庫名稱。
- **5 個預存程序**：`prc_COPOrderChk`（745 行，訂單主檔+明細完整檢核）、`prc_COPPassCheck`、
  `prc_COPGetCredit`、`prc_COPGetCredit_CRM`、`prc_ProductChk_COP`（767 行，
  `prc_COPOrderChk` 內部呼叫，品號中英文品名規格比對）。讀寫的本地表都是 unqualified
  表名（`COP_PoCheck` 等），沒有寫死 `PRORIL_WEB`，搬過去後自動讀寫 `Proril_Sales_Center`
  自己的表。
- **1 個函式**：`fu_RemoveParentheses`，純運算無依賴。
- **5 張表**（SP 的寫入目標，第一輪沒複製）：`COP_PoCheck`/`COP_PoDetailCheck`/
  `COP_PassCheck`（訂單/明細/特規Pass 檢核結果）+ `COP_AvailableAmt`（信用額度計算紀錄，
  2790 筆）/`COP_ProductCheck`（品號檢核紀錄，23135 筆，`prc_ProductChk_COP` 的寫入目標）。

這批物件的完整腳本在 **`database/OrderCheckObjectsMigration.sql`**（結構、資料複製、
View/函式/預存程序，一支腳本包完，可重複執行）。**這支腳本尚未執行**——因為它會重新
建立業務邏輯複雜的預存程序（`prc_COPOrderChk`/`prc_ProductChk_COP` 各 700+ 行），
改用「產出腳本交給人工在 SSMS 審閱後自己執行」的方式，不是這次對話直接連線跑掉。

執行前那支腳本裡也寫了同樣的提醒：`V_Product_English_All` 這個 View 的儲存文字裡
CREATE VIEW 開頭寫的是舊名字 `V_Produce_English_All`（`sp_rename` 只改物件名稱、
不會更新已儲存的定義文字，SQL Server 已知行為），腳本裡已經手動修正成正確名稱，
不是謄寫錯誤，這點不要在之後「校對」時誤改回去。

腳本執行完之後，`ProrilWebDbContext` 用到的全部物件（業務議題 13 張表 + 訂單資料檢核
7 View/5 SP/1 函式/5 表）在 `Proril_Sales_Center` 就會齊全。`api/` 現在已經拆成
`ProrilWebDbContext`（連 `ConnectionStrings:ProrilWeb`）與 `SalesCenterDbContext`
（連 `ConnectionStrings:SalesCenter`，見 `Program.cs`）兩個 DbContext；哪個表真的確定
可以安全切連線，才把對應 Entity 從前者搬過去，不要整批搬（見下面「已切連線」段落）。

## 已切連線：業務議題本體 + CRM_Customer + H_FileLink（2026-09-10）

`WorkProcessApiController`（含 `.Attach.cs`/`.Permission.cs`）、
`CustomQueryApiController.SaveCustom`、`UploadApiController.AddFileLog` 已改注入
`SalesCenterDbContext`，實際讀寫 `Proril_Sales_Center`（不再只是快照）：

- `D_WorkProcess`/`D_WorkProcessDetail`/`D_WorkProcessSearch`/`D_WorkProcessCustomer`/
  `D_WorkProcessPermission`/`M_WorkProcessPhrase`/`M_WorkProcessType`（業務議題 7 張，
  唯一寫入者是 `WorkProcessApiController`）
- `CRM_Customer`（唯一寫入者是 `CustomQueryApiController.SaveCustom`；
  `WorkProcessApiController` 也會讀它組客戶顯示欄位，同樣改讀 `_scDb`）
- `H_FileLink`（唯一寫入者是 `UploadApiController.AddFileLog`）

對應的實體改用 `api/Data/SalesCenter/`（`dotnet ef dbcontext scaffold` 產生，
不要手改欄位對映，要改就跑 `database/scripts/scaffold-sales-center.ps1` 重新產生）；
`api/Data/Entities.cs`、`ProrilWebDbContext` 裡這幾張表原本手寫的對映已一併移除，
避免兩套 DbContext 同時對映同一張表、之後有人手滑寫錯庫。`ApiModels.cs` 裡
`DWorkProcessesEx`/`DWorkProcessDetailViewModel`/`DWorkProcessSearchEx`/
`DWorkProcessCustomerEx`/`CrmCustomerViewModel` 的基底型別也跟著換成
`Data.SalesCenter` 命名空間的實體。

`M_User`/`M_Permission`（1.0 還在寫，維持唯讀）、`V_ERPCustomer`（ERP 唯讀 view）、
`COP_*`（無應用層 CRUD 可搬）維持不動，繼續留在 `ProrilWebDbContext` 打 `PRORIL_WEB`。

## 為什麼有 7 個欄位型別跟來源不一樣

兩個資料庫的 collation（定序）不同：

| 資料庫 | Collation |
|---|---|
| `PRORIL_WEB`（來源） | `Chinese_Taiwan_Stroke_BIN`（支援繁體中文的 code page） |
| `Proril_Sales_Center`（目標） | `SQL_Latin1_General_CP1_CI_AS`（西歐語系 code page，**不支援中文**） |

這 13 張表裡有幾個 `varchar`（非 Unicode）欄位實際存了繁體中文（關鍵字名稱、附件原始檔名、
使用者姓名）。若照原型別直接建表，資料從 `PRORIL_WEB` 複製過去時會經過 code page 轉換，
中文字會變成 `?`（不可逆的資料損毀）。已抽查證實以下欄位確實有中文內容，因此**建表時改成
`nvarchar`**，其餘欄位型別、長度、可為空、預設值、PK/索引名稱都跟 `PRORIL_WEB` 現況逐欄
核對後 1:1 複製：

| 表 | 欄位 | 來源型別 | `Proril_Sales_Center` 型別 |
|---|---|---|---|
| `M_WorkProcessPhrase` | `PhraseName` | `varchar(40)` | `nvarchar(40)` |
| `M_WorkProcessPhrase` | `Directions` | `varchar(MAX)` | `nvarchar(MAX)` |
| `M_WorkProcessType` | `TypeName` | `varchar(40)` | `nvarchar(40)` |
| `M_WorkProcessType` | `Descript` | `varchar(MAX)` | `nvarchar(MAX)` |
| `D_WorkProcessDetail` | `UploadFile` | `varchar(200)` | `nvarchar(200)` |
| `D_WorkProcessDetail` | `RenameFile` | `varchar(200)` | `nvarchar(200)` |
| `M_User` | `UserName` | `varchar(40)` | `nvarchar(40)` |

（`COP_CheckRule`/`COP_DepData` 的中文欄位如 `ChkRule`/`DepName` 在來源本來就已經是
`nvarchar`，不用覆寫。）

複製完成後已在資料庫端逐筆比對這些中文欄位（`CAST ... COLLATE Chinese_Taiwan_Stroke_BIN`
比對來源與目標），0 筆不一致；13 張表的資料列數也與來源一致
（業務議題 8 張：44/63/187/109/72/117/36/4；另外 5 張：
`COP_CheckRule` 31、`COP_DepData` 19、`H_FileLink` 1799、`M_Permission` 574、`M_User` 45）。

`api/Data/Entities.cs`／`api/Data/OrderInfoVerifyEntities.cs` 的 EF Core 對映不受影響——
這些欄位在 C# 端本來就宣告 `string`，ORM 層不區分 `varchar`/`nvarchar`，型別差異只存在於
資料庫端的實體 DDL。

## 之後更新這批 schema 時要注意

- 若之後要重新從 `PRORIL_WEB` 對 `Proril_Sales_Center` 做 DACPAC extract/publish、
  或用 `database/scripts/*.ps1` 重新產生 `Proril_Sales_Center` 的建表腳本，
  **記得把上面這 7 個欄位重新改回 `nvarchar`**——直接照抄 `PRORIL_WEB` 的 `varchar` 定義
  會重新踩到同一個 collation 問題。
- `database/` 目前的 DACPAC 版控（`Tables/*.sql`、`scripts/*.ps1`、`TABLES.txt`）納管的
  是業務議題 8 張 + 訂單資料檢核 5 張 + `H_FileLink` + 權限控管 2 張，共 16 張
  （見 `README.md`）。`M_User`/`M_Permission` 從「刻意排除在外」改成「2026 進行中的
  完整搬遷」，見下面「權限控管搬遷」小節——**schema 已收編，但 `api/` 的讀寫仍指向
  `PRORIL_WEB`，資料還沒重新整批複製**，兩件事分開看，見下一節。
- 訂單資料檢核相關的 7 View/5 SP/1 函式/5 表不在這一段（13 張表）的複製範圍內，
  腳本另外放在 `database/OrderCheckObjectsMigration.sql`，見上面「訂單資料檢核相關的
  View / 預存程序 / 函式」小節。
- 複製用的 SQL 是即席產生（比對 `sys.columns`/`sys.indexes` 逐欄核對），沒有存成
  repo 裡的腳本檔——若要重跑，流程是：查詢 `PRORIL_WEB` 對應表的 `sys.columns`/
  `sys.indexes` 組出 `CREATE TABLE`（欄位型別套用上表覆寫），
  `SET IDENTITY_INSERT ON` 後 `INSERT INTO ... SELECT ... FROM PRORIL_WEB.dbo.表名`。

## 權限控管搬遷（2026 進行中，先做資料庫這半）

目標是把 `M_User`/`M_Permission` 從「唯讀留在 `PRORIL_WEB`」改成「2.0 完整接手寫入」——
CLAUDE.md 講得很白：這兩張表**要嘛連同 1.0 對應的兩支 Controller 一起搬過來寫新 DB，
要嘛維持唯讀**，不能只切一半。這次先做資料庫這一半，Controller 邏輯
（`MainApiController.cs` 的帳號鎖定/建帳號/改密碼/刪帳號、
`MainApiController_SystemSetting.cs` 的權限維護）留到下一輪。

### 這次做了什麼

- `TABLES.txt` 加入 `M_User`/`M_Permission`，DACPAC schema 版控從 14 張變 16 張。
- `Tables/M_User.sql`／`Tables/M_Permission.sql` **手動撰寫**，不是 `extract.ps1` 產出——
  沙盒環境的唯讀分類器擋掉了直連正式區 `PRORIL_WEB` 做 schema extract 的動作
  （`sqlcmd`/`sqlpackage` 對外連線一律被擋），改成照抄 1.0
  `Models/ProrilWebContext.cs` 裡 `MUser`/`MPermission` 的 EF fluent mapping
  （欄位型別、長度、PK 約束名稱 `PK__M_User__3214EC27F2F69166` /
  `PK__M_Permis__3214EC274A3FED69` 都是從那邊照抄，不是憑空編的）。
  **這兩個檔案還沒被 `extract.ps1` 驗證過**，正式排進 DACPAC 部署流程前，
  請找能連正式區的人跑一次 `.\scripts\extract.ps1 -Environment prod` 蓋掉重新產生，
  `git diff` 應該要是空的（沒有差異）才代表手動謄寫沒抄錯。
- `README.md`（本目錄）與本檔前面幾節的敘述一併更新為 16 張表、拿掉「刻意排除」的舊字句。

### 還沒做、需要人工執行（都需要能連正式區/測試區的帳密，這裡的沙盒連不過去）

1. `extract.ps1 -Environment prod` —— 驗證上面手寫的兩個 `Tables/*.sql`（唯讀）。
2. `.\scripts\publish.ps1 -Environment snapshot -Execute` —— 在 `Proril_Sales_Center`
   建出 `M_User`/`M_Permission` 的表結構。**這兩張表的 `UserName`/`Modifier` 等欄位
   有中文內容，比照上面「為什麼有 7 個欄位型別跟來源不一樣」那節的做法，
   `Tables/*.sql` 裡維持 `PRORIL_WEB` 的 `varchar`，但 publish 到 `snapshot` 前
   要先確認 DACPAC 是否會把這兩張表的 `UserName` varchar 開下去** ——
   若會，得照抄同一招先在 `Proril_Sales_Center` 手動建成 `nvarchar(40)`，
   不能直接信任 `publish.ps1` 的預設輸出，否則中文使用者名稱會變成 `?`。
3. `.\scripts\copy-snapshot-data.ps1 -Environment test`（dry-run 看列數對照）→
   確認無誤後 `-Execute`，把 `PRORIL_WEB` 最新的 `M_User`/`M_Permission` 資料
   整批覆蓋進 `Proril_Sales_Center`（這一輪 2026-09-03 複製過的那份已經舊了，
   之後 1.0 新增的帳號/權限都沒進去，見上面「已核對」段落）。
4. `drift.ps1 -From snapshot -To prod` 收尾確認兩邊长一樣。

### 之後（下一輪，不是這次的範圍）

- `api/Data/SalesCenter/` 加上 `MUser`/`MPermission` 的 EF scaffold 對映
  （`database/scripts/scaffold-sales-center.ps1`）。
- 把 1.0 `Controllers/MainApiController.cs`（帳號鎖定/建帳號/改密碼/刪帳號）與
  `Controllers/System/MainApiController_SystemSetting.cs`（權限維護）的邏輯
  搬進 `api/Controllers/`，`db.MUsers`/`db.MPermissions` 才能從 `ProrilWebDbContext`
  換成 `SalesCenterDbContext`——邏輯沒搬完前，即使資料庫這半做完了，
  `api/` 也不能提前切連線，否則 1.0 那邊的登入鎖定/建帳號/權限異動會讀不到
  `Proril_Sales_Center` 的最新狀態，兩邊帳號權限狀態分岔。

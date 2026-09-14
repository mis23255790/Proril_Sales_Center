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
View/函式/預存程序，一支腳本包完，可重複執行），走
`scripts/run-objects-migration.ps1`（`-Script OrderCheckObjectsMigration.sql`）執行，
不加 `-Execute` 只做檢查，見 `README.md`「View / 預存程序的搬移」。

**2026-09-14 已對測試區的 `Proril_Sales_Center` 執行完成**，驗證結果：

- 18 個物件全部建立（7 View / 5 SP / 1 函式 / 5 表）。
- 5 張表的筆數與 `PRORIL_WEB` 逐一相同：`COP_PoCheck` 446、`COP_PoDetailCheck` 1256、
  `COP_PassCheck` 47、`COP_AvailableAmt` 2790、`COP_ProductCheck` 23135。
- **7 個 View 在新庫查得到資料，筆數與舊庫完全一致**（196 / 4974 / 18688 / 9984 /
  7078 / 3 / 22）——這證明 instance 層級的 linked server `[192.168.1.200]` 在新庫下
  同樣可用，不是搬過去就查不到 ERP。
- 定序仍然全對齊（0 個欄位未對齊），這批表沒有破壞上面那節的成果。

**還沒驗的**：`prc_COPOrderChk` / `prc_COPPassCheck` / `prc_COPGetCredit` /
`prc_ProductChk_COP` 這四支**會寫資料**（寫回 `COP_PoCheck`/`COP_PoDetailCheck`/
`COP_PassCheck`/`COP_AvailableAmt`/`COP_ProductCheck`），沒有「只查不寫」的跑法，
所以沒有實跑驗證——要驗的話得挑一張可以拿來試的訂單，跑完那張訂單的檢核紀錄就會留在
新庫裡。正式區還沒建庫，那邊也還沒跑。

正式區的 `Proril_Sales_Center@51002` 還沒建。

執行前那支腳本裡也寫了同樣的提醒：`V_Product_English_All` 這個 View 的儲存文字裡
CREATE VIEW 開頭寫的是舊名字 `V_Produce_English_All`（`sp_rename` 只改物件名稱、
不會更新已儲存的定義文字，SQL Server 已知行為），腳本裡已經手動修正成正確名稱，
不是謄寫錯誤，這點不要在之後「校對」時誤改回去。

腳本執行完之後，`ProrilWebDbContext` 用到的全部物件（業務議題 13 張表 + 訂單資料檢核
7 View/5 SP/1 函式/5 表）在 `Proril_Sales_Center` 就會齊全。`api/` 現在已經拆成
`ProrilWebDbContext`（連 `ConnectionStrings:ProrilWeb`）與 `SalesCenterDbContext`
（連 `ConnectionStrings:SalesCenter`，見 `Program.cs`）兩個 DbContext；哪個表真的確定
可以安全切連線，才把對應 Entity 從前者搬過去，不要整批搬（見下面「已切連線」段落）。

## 銷貨檢索相關的表 / 預存程序（第三階段，另一支腳本，2026-09-14）

銷貨檢索的後端這次從 1.0 搬進 `api/Controllers/SalesSearch/MixSalesShipApiController.cs`
（見 `docs/modules/SalesShipping/logic.md`），連帶要把它吃的資料庫物件搬過來。
範圍比訂單資料檢核小得多：

- **1 張表**：`COP_SalesOrder`（10794 筆）。它是 ERP 銷貨單明細的**快取表**，
  不是使用者維護的主檔——`prc_ImportSalesOrder` 從鼎新 ERP 增量塞資料進去，
  兩支查詢 SP 再從它撈。同時也是兩支查詢 SP 結果集的形狀（SP 回傳的是同欄位的暫存表）。
- **3 個預存程序**：`prc_QuerySalesOrder`（依品號 TH004 分群）、
  `prc_QuerySalesOrder_1`（依銷貨單 TH001+TH002 分群）、
  `prc_ImportSalesOrder`（ERP 增量匯入，前兩支進來第一行就叫它）。
- **0 個 View、0 個函式**。

腳本在 **`database/SalesShippingObjectsMigration.sql`**，**2026-09-14 已對測試區的
`Proril_Sales_Center` 執行完成**（表 10841 筆、3 支 SP 都在，兩庫跑同一組查詢結果一致）。
正式區的 `Proril_Sales_Center@51002` 還沒建，那邊還沒跑。執行方式：

```powershell
.\scripts\run-objects-migration.ps1 -Script SalesShippingObjectsMigration.sql -Environment snapshot
.\scripts\run-objects-migration.ps1 -Script SalesShippingObjectsMigration.sql -Environment snapshot -Execute
```

不加 `-Execute` 只做檢查（目標庫與 `USE` 對帳、linked server 在不在、物件現況、
`SET PARSEONLY ON` 驗語法），不會動任何東西。細節見 `README.md`
「View / 預存程序的搬移」。

幾個執行前一定要知道的點（腳本檔頭也寫了同一份）：

1. **`prc_ImportSalesOrder` 有兩處寫死 `PRORIL_WEB.dbo.COP_SalesOrder`**，是那個判斷
   「這筆 ERP 銷貨單匯入過沒有」的 `LEFT JOIN ... CSO.TH001 IS NULL`。腳本已經改成
   不帶資料庫名稱的 `dbo.COP_SalesOrder`。**這是整支腳本唯一動到的邏輯**，沒改的話
   搬過去會拿新庫的空表跟舊庫比對，變成整批重複匯入。
2. **`PRORIL_WEB.dbo.NPS_D_Order` 的參照刻意保留**（銘版序號 `SerialNosJson` 的來源）。
   那張表屬於別的模組（1.0 的 `sp_ImportPurchaseOrder`/`sp_UpdatePurchaseOrder`/
   `prc_ReImportTestOrder` 在寫、`V_UnfinOrder` 在讀），這次不搬；兩個資料庫在同一個
   instance，三段式跨庫查詢可行。哪天 `NPS_D_Order` 也搬過來，記得回頭拿掉前綴。
3. **「查詢」其實會寫資料**。`prc_QuerySalesOrder(_1)` 進來就 `EXEC prc_ImportSalesOrder`，
   對 `COP_SalesOrder` 做 INSERT + 去重 DELETE。切連線之後兩邊的快取表各自成長，
   內容都是從同一份 ERP 拉的，不影響正確性，但**不會互相同步**。
4. **`prc_ImportSalesOrder` 的兩處 `LEFT JOIN dbo.COP_SalesOrder CSO` 加了
   `COLLATE DATABASE_DEFAULT`**。這是執行當下才發現的：linked server `[192.168.1.200]` 的
   `collation compatible` 是 off、沒指定 collation name，ERP 欄位沿用遠端的
   `Chinese_Taiwan_Stroke_BIN`，跟當時還是 Latin1 的本地 `COP_SalesOrder` 一比就
   **在 `CREATE PROCEDURE` 當場**噴 Msg 468（參照的物件都存在，沒有延後解析可言）。
   後來整個庫的定序已經對齊（見「定序已對齊」那節），這個 `COLLATE DATABASE_DEFAULT`
   變成沒有作用，但**刻意留著**：它讓這支腳本在任何定序的目標庫都跑得起來。
5. **`COP_SalesOrder` 在 `PRORIL_WEB` 還有另一個讀者：`V_SalesTotal`**
   （1.0 `MixSalesShipApi/GetSalesTotal` 的客戶頁籤，2.0 還沒搬那支）。它留在舊庫讀舊庫，
   不受影響；等那支也搬過來時要一併處理。因此 `COP_SalesOrder`**不算單一擁有者**，
   切連線的前置條件比業務議題那批嚴格一點。

`TABLES.txt` 已把 `COP_SalesOrder` 收進 DACPAC schema 版控（`Tables/COP_SalesOrder.sql`），
一樣是**收 schema 不等於切連線**：**測試區的物件雖然都到位了，`api/` 仍把 `CopSalesOrder`
對映在 `ProrilWebDbContext`，SP 也還是在 `PRORIL_WEB` 執行。** 要切連線還缺兩件事：
正式區的 `Proril_Sales_Center@51002` 還沒建、上面第 5 點的 `V_SalesTotal` 歸屬還沒解決。

1.0 另外還有一張 `COP_MDL_SalesOrder_1`（匯出時當 SP 結果形狀用的空殼表）：DB 裡 0 筆、
沒有任何 View/SP 參照，2.0 匯出改用同一個 `CopSalesOrder` 型別，**這張表不搬**。

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

## 定序已對齊（2026-09-14）

> **這一節是下一節的前提，先讀這節。** `Proril_Sales_Center` 的定序原本與來源不同，
> 2026-09-14 已經改成與 `PRORIL_WEB` 相同的 `Chinese_Taiwan_Stroke_BIN`。

| 資料庫 | 原本 | 現在 |
|---|---|---|
| `PRORIL_WEB`（來源） | `Chinese_Taiwan_Stroke_BIN` | 不變 |
| `Proril_Sales_Center` | `SQL_Latin1_General_CP1_CI_AS`（建庫時沿用 instance 預設） | `Chinese_Taiwan_Stroke_BIN` |

### 為什麼非改不可

下一節（varchar → nvarchar）只處理了定序問題的一半：「非 Unicode 欄位存中文會變 `?`」。
另一半是**比對與排序語意**，一直到搬銷貨檢索時才踩到：

同一份資料、同一組查詢條件，`prc_QuerySalesOrder_1` 在兩個庫回傳的分群統計筆數不一樣
（明細/單筆/小計 = `200/24/33` vs `194/23/32`）。原因是 SP 的
`ORDER BY TG003,COP_Source,TH001,TH002,TH003` 在兩種定序下**順序有 13 列不同**
（`COP_Source` 是中文，筆畫序 vs Latin1 序差很多），而 SP 的分群是用游標比對相鄰列做的，
順序一變，分群就跟著變。

同樣的語意差也存在於已經切連線的業務議題／權限控管那幾張表：字串比對從 1.0 的
BIN（區分大小寫、區分全半形）變成 CI_AS（不分大小寫）。所以這不是銷貨檢索一個模組的問題，
是整個獨立資料庫的地基問題。

### 怎麼改的

`database/scripts/fix-collation.ps1`（預設 dry-run，`-Execute` 才真的跑）：

1. `SET SINGLE_USER` → `ALTER DATABASE ... COLLATE Chinese_Taiwan_Stroke_BIN`
   （**只影響之後新建的物件**，既有欄位不會跟著變，所以才需要第 3 步）
2. DROP 含字元欄位的索引（`ALTER COLUMN` 動不了索引鍵欄位）
3. 逐欄 `ALTER TABLE ... ALTER COLUMN ... COLLATE`，型別/長度/可為空原樣保留
4. 重建索引 → `SET MULTI_USER` → 驗證還有幾個欄位沒對齊

實際規模：**142 個字元欄位、15 張表、1 個索引**（`D_WorkProcessDetail` 的
`NonClusteredIndex-20231221-145816`）。沒有任何 FK / CHECK / 計算欄位 / schema-bound
物件擋路。

### 為什麼不會毀資料

- `varchar`/`char` 換定序等於換 code page（CP1252 → CP950），內容只要全是 ASCII 就是 no-op。
  執行前掃過全部 `varchar`/`char` 欄位，**沒有任何一筆含非 ASCII 內容**（中文都在 `nvarchar`
  裡，就是下一節那批覆寫的功勞）。這個掃描已經做進 `fix-collation.ps1` 的前置檢查，
  一旦有非 ASCII 就直接中止。
- BIN 是區分大小寫的，改完之後原本「只差大小寫」的值會變成兩筆不同值。執行前查過
  `M_User.Account`／`CRM_Customer.CustomerNo`／`M_WorkProcessPhrase.PhraseName`，
  **0 組只差大小寫**。

### 驗證結果

改完之後兩個庫跑同一組查詢，`prc_QuerySalesOrder`（品號分群）與 `prc_QuerySalesOrder_1`
（銷貨單分群）的筆數與金額**完全一致**；中文欄位抽查正常；15 張表列數不變。

### 對其他東西的影響

- **DACPAC 不用改**：`Tables/*.sql` 沒有 `COLLATE` 子句，publish 時欄位沿用資料庫預設，
  所以改完之後產出的新欄位自動就是對的。
- **`api/` 不用改**：EF Core 不管定序。但**字串比對語意變嚴格了**（回到 1.0 的行為），
  帳號、關鍵字、客戶編號的比對從此區分大小寫。
- **正式區還沒做**：`Proril_Sales_Center@51002` 建好之後，**建庫當下就直接指定
  `Chinese_Taiwan_Stroke_BIN`**，不要再重演一次事後修。真的忘了，就跑
  `fix-collation.ps1 -Environment snapshot-prod`。

## 為什麼有 9 個欄位型別跟來源不一樣

這一節講的是上一節之前的歷史：定序還沒對齊時，為了不讓中文變 `?` 所做的型別覆寫。
**定序已經對齊，這些覆寫現在不再是必要的**，但保留不改——`nvarchar` 一定安全，
而且改回 `varchar` 要動資料。之後看到型別跟 `PRORIL_WEB` 不一樣，是這個原因，不是錯。

當時兩個資料庫的 collation（定序）不同：

| 資料庫 | Collation |
|---|---|
| `PRORIL_WEB`（來源） | `Chinese_Taiwan_Stroke_BIN`（支援繁體中文的 code page） |
| `Proril_Sales_Center`（目標，當時） | `SQL_Latin1_General_CP1_CI_AS`（西歐語系 code page，**不支援中文**） |

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
| `M_Function` | `FunctionName` | `varchar(20)` | `nvarchar(20)` |
| `M_Function` | `GroupName` | `varchar(20)` | `nvarchar(20)` |

（最後兩列是 2026-09-14 功能主檔搬過去時加的，見最後一節。
`M_System` 的 `SystemName`/`TypeName` 在來源本來就是 `nvarchar`，不用覆寫。）

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
  **記得把上面這 9 個欄位重新改回 `nvarchar`**——直接照抄 `PRORIL_WEB` 的 `varchar` 定義
  會重新踩到同一個 collation 問題。
- `database/` 目前的 DACPAC 版控（`Tables/*.sql`、`scripts/*.ps1`、`TABLES.txt`）納管的
  是業務議題 8 張 + 訂單資料檢核 5 張 + 銷貨檢索 1 張 + `H_FileLink` + 權限控管 6 張，
  共 21 張（**以 `README.md` 為準**，這個數字每加一個模組就會變）。`M_User`/`M_Permission` 從「刻意排除在外」改成「2026 進行中的
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

### 下一輪已完成（2026-09-14）：Controller 邏輯搬完、`api/` 已切連線

見下面「權限控管搬遷（第二輪）」。

## 權限控管搬遷（第二輪，2026-09-14）：畫面與 Controller 都搬完，`api/` 已切連線

把 1.0 的**人員管理**（`Views/System/UserManager.cshtml` + `Controllers/MainApiController.cs`）
與**權限管理**（`Views/System/PermissionManager.cshtml` +
`Controllers/System/MainApiController_SystemSetting.cs`）搬進 2.0，
`M_User` / `M_Permission` / `M_PermissionGroup` 從「唯讀留在 `PRORIL_WEB`」改成
「`api/` 打 `SalesCenterDbContext` 讀寫」。

### 表的歸屬（這次定案）

| 表 | `api/` 連哪個庫 | 為什麼 |
|---|---|---|
| `M_User` | `Proril_Sales_Center`（讀寫） | 唯一應用層寫入者是 1.0 `MainApiController`，已搬過來 |
| `M_Permission` | `Proril_Sales_Center`（讀寫） | 唯一應用層寫入者是 1.0 `MainApiController_SystemSetting`，已搬過來 |
| `M_PermissionGroup` | `Proril_Sales_Center`（讀寫） | 同上（群組預設功能） |
| `M_System` | `PRORIL_WEB`（唯讀） | 應用層完全沒有寫入路徑，直接維護在 DB，沒有 CRUD 可搬 |
| `M_Function` | `PRORIL_WEB`（唯讀） | 同上 |
| `M_PermissionLinkType` | `PRORIL_WEB`（唯讀） | 1.0 `Controllers/Query/FileQueryApiController.cs:356` 會 `Add`，不是單一擁有者 |
| `M_Department` | `PRORIL_WEB`（唯讀） | 1.0 `Controllers/System/OrgApiController.cs`（組織維護）在寫 |

上面這張表是逐一 grep 1.0 全部 Controller 核對出來的，不是只看已知模組。
因為讀寫分兩個庫，權限樹那幾支 API 的併表一律先各自 `ToList()` 再用 LINQ to Objects 併，
**不能寫成單一 SQL**（跨資料庫的 EF 查詢組不出來）。

### ⚠️ 上線前必須做的事：1.0 的人員管理／權限管理要停用

`M_Permission` 已經切到新庫，代表：

- 在 2.0 改權限**不會**反映到 1.0 站台（1.0 讀 `PRORIL_WEB.M_Permission`）
- 在 1.0 改權限**不會**反映到 2.0

兩邊都還開著就一定分岔。上線時要把 1.0 的「系統設定 / 人員管理」「系統設定 / 權限管理」
關掉（拿掉選單或直接擋掉 functionNo 1 / 8），統一在 2.0 操作。

### 還沒搬的一塊：登入失敗鎖定

1.0 `MainApiController.Login` 會寫 `M_User.PwdWrongTime` / `IsLocked`，還會寫 `H_Logins`
（登入記錄表，不在白名單、2.0 沒有對映）。2.0 的 `Login` 本來就沒搬這段，這次也沒補——
補它要連 `H_Logins` 一起搬，屬於「登入流程」而不是「這兩個畫面」。

現況是：**1.0 登入失敗會鎖 `PRORIL_WEB.M_User`，2.0 讀的是 `Proril_Sales_Center.M_User`，
鎖定狀態不會互通。** 2.0 這邊補了 `MainApi/UnlockUser` 讓人員管理畫面可以解鎖
（1.0 連解鎖的畫面都沒有，只能進 DB 改）。

### 需要人工執行的資料庫步驟（沙盒連不到正式區，這次沒跑）

1. `.\scripts\extract.ps1 -Environment prod` —— 驗證手寫的 `Tables/*.sql`。
   這次新增的 `M_Function` / `M_PermissionLinkType` / `M_PermissionGroup` /
   `M_Department` 四個檔案**同樣是照 1.0 `Models/ProrilWebContext.cs` 的 EF fluent
   mapping 手寫的**，跟上一輪的 `M_User`/`M_Permission` 一樣還沒被 extract 驗證過。
   `git diff` 要是空的才代表沒抄錯。

   兩個沒有 `HasName` 可抄、是照 EF 慣例推出來的 PK 名稱，extract 時要特別看：
   `PK_M_PermissionGroup`、`PK_M_PermissionLinkType`。

2. `.\scripts\publish.ps1 -Environment snapshot -Execute` —— 在 `Proril_Sales_Center`
   建出新表結構。**這次真正需要的只有 `M_PermissionGroup`**（`M_User`/`M_Permission`
   在 2026-09-03 那批已經建好了）。

   `M_PermissionGroup` 的 `TypeDesc`/`GroupDesc` 在來源就是 `nvarchar`，
   不用套「為什麼有 7 個欄位型別跟來源不一樣」那節的覆寫。
   但 publish 會順便把 `M_Function`/`M_PermissionLinkType`/`M_Department` 也建進去
   （它們現在在白名單裡），這三張的 `FunctionName`/`LinkTypeName`/`DepName` 是
   **存了中文的 `varchar`**。原本這裡要提醒「灌資料前先改成 `nvarchar`，否則中文會變 `?`」，
   2026-09-14 定序對齊成 `Chinese_Taiwan_Stroke_BIN` 之後不用了（見「定序已對齊」）。

3. `.\scripts\copy-snapshot-data.ps1 -Environment test`（先 dry-run 看列數）→ `-Execute`。
   **這一步是必要的**：`Proril_Sales_Center` 的 `M_User`/`M_Permission` 還停在
   2026-09-03 的快照，1.0 之後新增的帳號與權限都沒進去，不重灌的話 2.0 一切過去
   會看到一份過期的帳號權限。`M_PermissionGroup` 也要一起灌，否則群組預設功能是空的。

4. `.\scripts\scaffold-sales-center.ps1` —— 這支的 `-ExcludeAuthTables` 預設已改成
   `$false`（連同 `M_PermissionGroup` 一起納入）。在步驟 2/3 做完之前先不要跑，
   跑了會因為新庫還沒有 `M_PermissionGroup` 而少產出對映。
   在那之前 `api/Data/SalesCenter/MUser.cs`/`MPermission.cs`/`MPermissionGroup.cs`
   與 `SalesCenterDbContext` 的對映是**手寫**的（照 1.0 fluent mapping 抄），
   跑完 scaffold 應該要一致。

5. `.\scripts\drift.ps1 -From snapshot -To prod` 收尾。

## 功能主檔（M_System / M_Function）只搬 2.0 用得到的列（2026-09-14）

權限控管第二輪把 `M_Permission` 切到 `Proril_Sales_Center` 之後，功能主檔跟著切：
`api/` 的 `MSystems` / `MFunctions` 改打 `SalesCenterDbContext`，
`ProrilWebDbContext` 不再對映這兩張表。

### 關鍵：**只複製 2.0 真的有頁面的那幾列**，不是整張表

`PRORIL_WEB.M_Function` 有 90+ 個功能，絕大多數是 2.0 還沒搬的模組（品異、託工、包裝、
報價、庫存…）。整份複製的話 2.0 的權限管理樹會長出一堆點下去 404 的功能。
所以新庫只有：

| SystemNo | SystemName | FunctionNo | FunctionName | 2.0 路由 |
|---|---|---|---|---|
| 0 | 系統設定 | 1 | 權限管理 | `system/permission-manager` |
| 0 | 系統設定 | 8 | 人員管理 | `system/user-manager` |
| 7 | 業務議題 | 16 | 類別維護 | `sales-issue/kind-maintain` |
| 7 | 業務議題 | 17 | 議題維護 | `sales-issue/issues` |
| 32 | 業務檢索 | 410 | 銷貨檢索 | `sales-search/shipping-inquiry` |
| 32 | 業務檢索 | 420 | 未完成訂單 | `sales-search/unfinished-orders` |
| 32 | 業務檢索 | 425 | 訂單資料檢核 | `sales-search/order-info-verify` |
| 32 | 業務檢索 | 440 | 客戶檢索 | `sales-search/customer` |

沒收的（1.0 有、2.0 沒有對應頁面）：`101` 格式匯入、`199` 測試區、`18` 議題檢視
（`aStatus = 'N'` 早就停用）、`441` 客戶相關資訊（1.0 註記無 UI 入口）、
`430` 預估報價、`460` 成品報價。

要改這個範圍就改 `database/PermissionMasterSeed.sql` 的 `@FunctionNos`。
**加一列之前先確認 `app/composables/useAppNavigation.ts` 的 `NAV_MODULES` 有對應路由**，
否則側欄不會顯示它（側欄只列有對照路由的功能），權限樹卻勾得到，容易誤會。

### 這件事踩到的兩個工具陷阱

1. **`copy-snapshot-data.ps1` 會整批覆蓋**，跑下去就把上面這件事推翻了。
   已在該腳本加 `$script:PartialRowTables = @('M_System', 'M_Function')` 把這兩張排除，
   它們的資料改由 `PermissionMasterSeed.sql` 維護。

2. **`publish.ps1 -Environment snapshot` 會把 `M_Function` 建成 `varchar`**。
   `Tables/M_Function.sql` 是 `PRORIL_WEB` 的正本（`varchar`），但
   `FunctionName`/`GroupName` 存了中文，在 `Proril_Sales_Center` 的 Latin1 collation
   底下會變成 `?`。所以這兩張表**不要靠 publish 建**，用 `PermissionMasterSeed.sql`
   （它自己 `CREATE TABLE` 並把那兩欄開成 `nvarchar`）。
   之後若有人對 `snapshot` 環境跑 publish，DACPAC 會想把 `nvarchar` 改回 `varchar`——
   看到這個 drift 不要套用。`Tables/M_System.sql` 本來就是 `nvarchar`，沒這個問題。

### `M_PermissionLinkType` 仍留在 `PRORIL_WEB`

功能細項（權限樹第三層）沒有跟著搬，因為 1.0 `FileQueryApiController` 還會 `Add`。
`GetMPermissionLinkType` 回的是全部的列，組樹時掛不到功能節點的會自動被忽略
（`app/utils/permissionTree.ts` 的 `buildPermissionTree`），所以樹是對的。
跟 2.0 這 8 個功能有關的細項只有 4 列：

| FunctionNo | LinkType | LinkTypeName |
|---|---|---|
| 17 | 10 | SOP-新增 |
| 17 | 20 | SOP-公開 |
| 410 | 100 | 顯示金額欄位 |
| 420 | 100 | 顯示金額欄位 |

> 順帶記一個既有問題：`OrderInfoVerifyApiController` 會檢查
> `(functionNo 425, linkType 100)` 的欄位級權限，但 `M_PermissionLinkType`
> **沒有這一列**，代表權限樹上根本勾不到它，只能靠 admin 或直接寫 DB。
> 1.0 也是同樣狀況，不是這次搬壞的。

### 需要人工執行

在 **`Proril_Sales_Center`** 上跑 `database/PermissionMasterSeed.sql`
（建表 + 從同 instance 的 `PRORIL_WEB` 複製那幾列，可重複執行，腳本最後會自己驗中文）。

**跑之前 2.0 是壞的**：`api/` 已經改讀新庫的 `M_System`/`M_Function`，表還不存在的話
側欄會空、topbar 環境圖示不見、權限樹長不出來。

正式區那份 `Proril_Sales_Center` 建好之後也要跑一次——腳本是從**同一個 instance 的
`PRORIL_WEB`** 撈，不是寫死值，所以正式區會自動拿到正式區的 `M_System.ImagePath`
（環境圖示就是靠這個欄位分辨正式/測試區的）。

## FunctionNo 改成 AAABBCC 格式（2026-09-14）

`M_Function.FunctionNo` 從「int 流水號」改成「看得出歸屬的定長字串」：

    AAABBCC   AAA = SystemNo（補零 3 位）
              BB  = GroupNo （補零 2 位）
              CC  = 同一個 SystemNo+GroupNo 底下的序號（補零 2 位）

欄位 `varchar(8)`（比 7 碼多留一位）。定長的用意是字串排序等於
「系統別 → 群組 → 序號」的正確順序。

| 舊 | 新 | 功能 | SystemNo | GroupNo |
|---|---|---|---|---|
| 1 | `0000101` | 權限管理 | 0 | 1 |
| 8 | `0000102` | 人員管理 | 0 | 1 |
| 16 | `0070101` | 類別維護 | 7 | 1 |
| 17 | `0070102` | 議題維護 | 7 | 1 |
| 410 | `0320101` | 銷貨檢索 | 32 | 1 |
| 420 | `0320102` | 未完成訂單 | 32 | 1 |
| 440 | `0320103` | 客戶檢索 | 32 | 1 |
| 425 | `0320201` | 訂單資料檢核 | 32 | 2 |

腳本是 `database/FunctionNoFormatMigration.sql`（**測試區已執行完成**），
之後維護 `M_Function` 內容仍然走 `PermissionMasterSeed.sql`（那支已同步改成輸出新號）。

### 連帶改到的表

| 表 | 欄位 | 變更 |
|---|---|---|
| `M_Function` | `FunctionNo` | int → varchar(8)，換新號 |
| `M_Permission` | `FunctionNo` | int → varchar(8)，8 個換新號，其餘 501 列保留舊數字字串 |
| `M_PermissionGroup` | `FunctionNo` | 同上 |
| `M_PermissionLinkType` | `FunctionNo` | **整張表從 `PRORIL_WEB` 搬進新庫**，varchar(8)，只收這 8 個功能的 4 列細項 |
| `H_FileLink` | `LinkFunctionNo` | int → varchar(8)，429 列 `17` → `0070102`，其他模組的列保留舊數字字串 |

`M_PermissionLinkType` 原本是「留在 `PRORIL_WEB` 唯讀」（1.0 的 `FileQueryApiController`
還會 `Add`），但改號之後跨庫已經對不起來（舊庫 int 17 vs 新庫 `'0070102'`），
權限樹第三層與欄位級權限會整個斷掉，只能一起搬。
**代價**：1.0 之後在舊庫新增的細項不會自動同步，要靠人重跑 migration 的那一段。

### ⚠️ 與 PRORIL_WEB 的 schema 永久分岔

**`PRORIL_WEB` 完全沒動**——1.0 還在用 int 的 `FunctionNo`。所以這幾張表的欄位型別
在兩個庫**永久不同**：

    PRORIL_WEB           int
    Proril_Sales_Center  varchar(8)

後果（**看到不要當成漏同步**）：
- `publish.ps1 -Environment snapshot` 會想把 varchar(8) 改回 int —— **不要套用**
- `drift.ps1` 對 snapshot 會一直報這幾個欄位的差異 —— 屬預期

`database/Tables/` 底下的 .sql 是 **`PRORIL_WEB` 的正本**，維持 int，不要跟著改。

### 備份與重跑

migration 會先把 4 張表複製成 `*_bak_FunctionNo`。腳本**不可重入**，
偵測到 `M_Function.FunctionNo` 已經是 varchar 就會直接擋下來（要重來請先從備份還原）。

> 踩過的坑：**不要在 T-SQL 區塊註解裡寫出 `/` 緊接 `*` 的組合**（例如寫檔案路徑萬用字元時）。
> T-SQL 的區塊註解可以巢狀，那會多開一層註解、把後面的程式碼連同環境防呆一起吃掉，
> 而且只會冒一句 `Missing end comment mark` 就繼續跑下去。第一次執行時
> `DB_NAME()` 檢查、`DB_ID('PRORIL_WEB')` 檢查、防重入檢查就是這樣全部失效的。

## M_User.Password 清空（2026-09-14）

`Proril_Sales_Center.M_User.Password` 全部 45 列設成 `NULL`，
備份在 `dbo.M_User_bak_Password`（`ID` / `Account` / `Password`）。

可以這樣做的前提是**2.0 的登入只走 SSO**：`app/pages/login.vue` 沒有帳密表單，
前端完全沒有呼叫 `MainApi/Login`，走的是 `/api/auth/sso` → `MainApi/LoginSso`，
而 `LoginSso` 只檢查「`X-Internal-Secret` + 帳號存在 + `IsEnable` + 未鎖定」，不看密碼。

`PRORIL_WEB.M_User` **沒有動**，1.0 站台的帳密登入不受影響。

> **還沒處理的不一致**：`MainApi/AddUser` 與 `MainApi/ResetPassword` 仍然會寫入
> `AES(帳號)` 當密碼。在純 SSO 的前提下這兩段已經沒有意義，新建的帳號反而會是
> 45 個帳號裡唯一有密碼的。要嘛把那兩段拿掉、要嘛連 `MainApi/Login` 一起下架。

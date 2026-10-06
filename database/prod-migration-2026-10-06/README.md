# 2026-10-06：1.0 Excel 匯出版型搬進 2.0 正式區

腳本：`copy-xls-format-from-1.0.ps1`（預設 dry-run，加 `-Execute` 才寫入）。

| 1.0 來源（PRORIL_WEB） | 2.0 `CMN_XlsFileFormat.PermissionKey` |
|---|---|
| `PUR_XlsFileFormat` FunctionNo 410 | `salesSearch.mixSalesShipping`（銷貨檢索） |
| `PUR_XlsFileFormat` FunctionNo 420 | `salesSearch.queryUnFinish`（未完成訂單） |
| `CMN_XlsFileFormat` FunctionNo 425 | `salesSearch.orderInfoVerify`（訂單資料檢核） |

- 1.0 銷貨檢索／未完成訂單的版型其實在 **PUR** 那張，訂單資料檢核才在 CMN；2.0 只有 CMN 一張。
- `FunctionSubNo`（0 有金額／1 無金額）與樣式欄位照搬，`StyleWrapText` 留 NULL。
  1.0 的顏色字串 2.0 的 `XlsStyleCodec` 讀得懂，不轉。
- 目標已有同一組 (PermissionKey, FunctionSubNo) 就跳過；`-Replace` 先刪再寫。整批一個交易。
- 正式區沒有一個帳號能同時讀 `PRORIL_WEB` 又寫新庫，所以分兩條連線：
  來源 `-SourceEnv prod`（`PRORIL_DB_PROD`），目標 `-TargetEnv snapshot-prod`（`PRORIL_DB_SNAPSHOT_PROD`）。
  測試區用 `-SourceEnv test -TargetEnv snapshot`。

## 跑法

```powershell
cd database
.\prod-migration-2026-10-06\copy-xls-format-from-1.0.ps1            # dry-run
.\prod-migration-2026-10-06\copy-xls-format-from-1.0.ps1 -Execute
```

## 執行紀錄

- 2026-10-06 正式區（51002）已執行：5 組共 602 筆
  （銷貨檢索 0/1 = 140/108、未完成訂單 0/1 = 172/136、訂單資料檢核 0 = 46）。
- 測試區（50002）未執行。
- 1.0 訂單資料檢核只有「有金額」的「訂單細項」分頁：無金額權限的人，以及「訂單總表」分頁，
  匯出時仍用 2.0 預設版面。

---

# 未完成訂單 ERP 來源顯示 `??ERP`

腳本：`fix-unfinorder-temp-collation.ps1`（預設 dry-run，`-Environment snapshot|snapshot-prod`，加 `-Execute` 才寫入）。

- 原因：`prc_QueryUnfinOrder`／`prc_QueryUnfinOrder_1` 的 `#TmpDataSet.COP_Source` 是 `varchar(7)`、
  沒指定定序，吃到 tempdb 的 `SQL_Latin1_General_CP1_CI_AS`，`'浦瑞ERP'` 寫進去變 `'??ERP'`。
  畫面與匯出（品號細項、訂單細項、訂單統計三個有 ERP 欄的分頁）都受影響。
- 修法：該欄補 `COLLATE DATABASE_DEFAULT`。腳本讀資料庫**現行**定義只替換那一行，
  不重跑 `SalesOrderUnfinishObjectsMigration.sql`（那支會把 `V_UnfinOrder` 蓋回
  `NpsSerialNoObjectsMigration.sql` 之前的版本）。原始腳本與 `prod-migration-2026-09-21/03-create-procedures.sql`
  也已同步修正，之後建庫不會再出現。
- 執行紀錄：測試區（50002）2026-10-06 已執行並驗證回傳 `浦瑞ERP`／`芳晟ERP`；正式區（51002）2026-10-06 已執行並驗證。
- API 有查詢快取，修完要重新按「查詢」才會重跑 SP。

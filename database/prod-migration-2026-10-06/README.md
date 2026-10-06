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

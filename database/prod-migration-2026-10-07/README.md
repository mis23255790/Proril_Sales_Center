# 2026-10-07：刪除 Proril_Sales_Center 已停用的表

腳本：`drop-retired-tables.sql`（每張先檢查存在才刪，可重複執行）。

| 表 | 原因 |
|---|---|
| `M_Function_bak_FunctionNo` | `FunctionNoFormatMigration.sql` 第 0 段的備份 |
| `M_Permission_bak_FunctionNo` | 同上 |
| `M_PermissionGroup_bak_FunctionNo` | 同上 |
| `H_FileLink_bak_FunctionNo` | 同上 |
| `M_PermissionGroup` | 2026-09-23 改角色制（`RBAC_*`）後應用層不讀不寫，部門範本也沒轉進 RBAC |

- 只對 `Proril_Sales_Center`。1.0 `PRORIL_WEB` 的 `M_PermissionGroup` 還在用，不動。
- 刪掉之後 `FunctionNoFormatMigration.sql` 沒有還原來源。
- 程式端同步：`SalesCenterDbContext` 拿掉對映、`scaffold-sales-center.ps1` 排除、
  `M_PermissionGroup` 移出 `TABLES.txt` 並刪除 `Tables/M_PermissionGroup.sql`。

## 跑法

SSMS 開 `drop-retired-tables.sql` 按 F5，或：

```powershell
cd database
sqlcmd -S 192.168.1.142,51002 -U <帳號> -d Proril_Sales_Center -C -f 65001 -i prod-migration-2026-10-07\drop-retired-tables.sql
```

## 執行紀錄

- 2026-10-07 測試區（50002）已執行。
- 2026-10-07 正式區（51002）已執行。

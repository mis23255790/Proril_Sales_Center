using Microsoft.EntityFrameworkCore;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

/// <summary>
/// 手寫的對映，放在 scaffold 產物（SalesCenterDbContext.cs）之外，
/// 重跑 database/scripts/scaffold-sales-center.ps1 不會被洗掉。
/// </summary>
public partial class SalesCenterDbContext
{
    partial void OnModelCreatingPartial(ModelBuilder modelBuilder)
    {
        // 銘版序號直連 View，見 database/NpsSerialNoObjectsMigration.sql、Services/SerialNoSource.cs
        modelBuilder.Entity<VNpsSerialNo>(entity =>
        {
            entity.HasNoKey().ToView("V_NPS_SerialNo");
        });
    }
}

namespace Proril.SalesIssue.Api.Data;

/// <summary>
/// V_NPS_SerialNo：銘版序號直連 View（Proril_Sales_Center 跨庫讀 PRORIL_WEB.dbo.NPS_D_Order），
/// 建立腳本是 database/NpsSerialNoObjectsMigration.sql。
/// 對映寫在 SalesCenterDbContext.Custom.cs（不是 scaffold 產物，重跑 scaffold 不會洗掉）。
/// </summary>
public class VNpsSerialNo
{
    /// <summary><c>OrderType-RTRIM(OrderNo)+OrderSno</c>，與 COP_SalesOrder 的 TH014-RTRIM(TH015)TH016 同規則。</summary>
    public string SerialKey { get; set; } = null!;
    public string SerialNosJson { get; set; } = null!;
}

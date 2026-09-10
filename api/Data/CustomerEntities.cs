namespace Proril.SalesIssue.Api.Data;

/*
 * 客戶資料維護 + 任務(Mission)信件往來記錄（1.0 CustomerApiController）用到的資料表。
 *
 * 跟 Entities.cs / OrderInfoVerifyEntities.cs 管的表無關，開獨立檔案。
 * 實際 DB 對映在 ProrilWebDbContext.OnModelCreating 用 Fluent API 明確指定，
 * 欄位名稱大小寫務必跟 DB 一致（collation 是 case-sensitive）。
 */

/// <summary>M_Customer：客戶資料維護主檔。</summary>
public class MCustomer
{
    public int Id { get; set; }
    public string? CustomerNo { get; set; }
    public string? LongName { get; set; }
    public string? ShortName { get; set; }
    public string? Ship { get; set; }
    public string? Transport { get; set; }
    public string? ContactName { get; set; }
    public string? ContactPhone { get; set; }
    public string? ContactEmail { get; set; }
}

/// <summary>V_COP_Customer：ERP 同步過來的客戶清單 View，唯讀（HasNoKey）。</summary>
public class VCopCustomer
{
    public string? CustomerNo { get; set; }
    public string? LongName { get; set; }
    public string? ShortName { get; set; }
    public string? Ship { get; set; }
    public string? Transport { get; set; }
    public string? ContactName { get; set; }
    public string? ContactPhone { get; set; }
    public string? ContactEmail { get; set; }
}

/// <summary>
/// D_CustormerOrder：任務(Mission)對應的客戶訂單/聯繫記錄主檔。
/// 表名沿用 1.0 的拼字（Custormer，非 Customer）——DB 實際表名就是這樣，不更正。
/// </summary>
public class DCustormerOrder
{
    public int Id { get; set; }
    public string CoNo { get; set; } = null!;
    public string CoMemo { get; set; } = null!;
    public string MissionNo { get; set; } = null!;
}

/// <summary>D_MailDetail：附掛在 D_CustormerOrder 底下的信件往來記錄，可拖曳排序。</summary>
public class DMailDetail
{
    public int Id { get; set; }
    public string MdNo { get; set; } = null!;

    /// <summary>0 = 接收，1 = 發送（沿用 1.0，前端渲染成聊天泡泡樣式）。</summary>
    public byte MdType { get; set; }

    public string? Content { get; set; }
    public string CoNo { get; set; } = null!;
    public DateTime? CreateTime { get; set; }
    public int Sort { get; set; }
}

/// <summary>
/// AddMail 專用的請求 DTO：在 <see cref="DMailDetail"/> 上多帶 MissionNo，
/// 用來反查 CoNo，MissionNo 本身不寫進 D_MailDetail —— 刻意不對映到 DbContext。
/// </summary>
public class DMailDetailViewModel : DMailDetail
{
    public string MissionNo { get; set; } = null!;
}

using Microsoft.EntityFrameworkCore;

namespace Proril.SalesIssue.Api.Data;

/// <summary>
/// 業務議題的 DbContext。
///
/// 這是 database-first：schema 由 <c>database/</c> 的 DACPAC 管，這裡只做對映，
/// **不要**用 EF Migrations 去改 DB。PRORIL_WEB 裡混著鼎新 ERP 的表，
/// 讓 EF 認為自己擁有整個 model 會很危險。
///
/// 欄位名一律明確寫出來，不靠慣例推導。DB 是 case-sensitive collation，
/// 例如 <c>aStatus</c> 是小寫 a、<c>zipFile</c> 是小寫 z，猜錯會噴 Invalid column name。
/// </summary>
public class SalesIssueDbContext : DbContext
{
    public SalesIssueDbContext(DbContextOptions<SalesIssueDbContext> options) : base(options) { }

    public virtual DbSet<DWorkProcess> DWorkProcesses { get; set; } = null!;
    public virtual DbSet<DWorkProcessDetail> DWorkProcessDetails { get; set; } = null!;
    public virtual DbSet<DWorkProcessSearch> DWorkProcessSearches { get; set; } = null!;
    public virtual DbSet<DWorkProcessCustomer> DWorkProcessCustomers { get; set; } = null!;
    public virtual DbSet<DWorkProcessPermission> DWorkProcessPermissions { get; set; } = null!;
    public virtual DbSet<MWorkProcessPhrase> MWorkProcessPhrases { get; set; } = null!;
    public virtual DbSet<MWorkProcessType> MWorkProcessTypes { get; set; } = null!;
    public virtual DbSet<CrmCustomer> CrmCustomers { get; set; } = null!;
    public virtual DbSet<MUser> MUsers { get; set; } = null!;
    public virtual DbSet<MPermission> MPermissions { get; set; } = null!;
    public virtual DbSet<HFileLink> HFileLinks { get; set; } = null!;
    public virtual DbSet<VErpcustomer> VErpcustomers { get; set; } = null!;

    // ---- 訂單資料檢核（OrderInfoVerify），見 OrderInfoVerifyEntities.cs ----
    public virtual DbSet<VPoList> VPoLists { get; set; } = null!;
    public virtual DbSet<VPoDetailList> VPoDetailLists { get; set; } = null!;
    public virtual DbSet<CopPoCheck> CopPoChecks { get; set; } = null!;
    public virtual DbSet<CopPoDetailCheck> CopPoDetailChecks { get; set; } = null!;
    public virtual DbSet<CopCheckRule> CopCheckRules { get; set; } = null!;
    public virtual DbSet<CopPassCheck> CopPassChecks { get; set; } = null!;
    public virtual DbSet<VProductEnglishAll> VProductEnglishAlls { get; set; } = null!;
    public virtual DbSet<CopDepData> CopDepData { get; set; } = null!;
    public virtual DbSet<VUpFileData> VUpFileData { get; set; } = null!;
    public virtual DbSet<CopGetCredit> CopGetCredits { get; set; } = null!;
    public virtual DbSet<CopGetCreditCrm> CopGetCreditCrms { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<DWorkProcess>(entity =>
        {
            entity.ToTable("D_WorkProcess");
            entity.HasKey(e => e.Id).HasName("PK_M_WorkProcess");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Wpno).HasColumnName("WPNo").HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.AStatus).HasColumnName("aStatus").HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.SopTitle).HasMaxLength(200).HasDefaultValue("");
            entity.Property(e => e.PhraseList).HasMaxLength(500);
            entity.Property(e => e.VerNo).HasMaxLength(40).IsUnicode(false);
            entity.Property(e => e.Creator).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Leader).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Authorize).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Modifier).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.ProgressStatus).HasDefaultValue(10);
            entity.Property(e => e.PubDate).HasColumnType("datetime");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<DWorkProcessDetail>(entity =>
        {
            entity.ToTable("D_WorkProcessDetail");
            entity.HasKey(e => e.Id);
            // 1.0 的 NonClusteredIndex-20231221-145816，(WPNo, SNo) 唯一
            entity.HasIndex(e => new { e.Wpno, e.Sno }).IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Wpno).HasColumnName("WPNo").HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Sno).HasColumnName("SNo").HasMaxLength(4).IsUnicode(false);
            entity.Property(e => e.ZipFile).HasColumnName("zipFile").HasMaxLength(200).IsUnicode(false);
            entity.Property(e => e.AStatus).HasColumnName("aStatus").HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.ProcessCaption).HasMaxLength(200);
            entity.Property(e => e.UploadFile).HasMaxLength(200).IsUnicode(false);
            entity.Property(e => e.RenameFile).HasMaxLength(200).IsUnicode(false);
            entity.Property(e => e.Worker).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Creator).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Modifier).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<DWorkProcessSearch>(entity =>
        {
            entity.ToTable("D_WorkProcessSearch");
            entity.HasKey(e => e.Id);

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Wpno).HasColumnName("WPNo").HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.AStatus).HasColumnName("aStatus").HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.PhraseType).HasMaxLength(4).IsUnicode(false);
            entity.Property(e => e.PhraseCode).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Creator).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Modifier).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<DWorkProcessCustomer>(entity =>
        {
            entity.ToTable("D_WorkProcessCustomer");
            entity.HasKey(e => e.Id);

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Wpno).HasColumnName("WPNo").HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.AStatus).HasColumnName("aStatus").HasMaxLength(1).IsUnicode(false).HasDefaultValue("Y");
            entity.Property(e => e.CustomerNo).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.CustomerType).HasMaxLength(10).IsUnicode(false).HasDefaultValue("1");
            entity.Property(e => e.Creator).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Modifier).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<DWorkProcessPermission>(entity =>
        {
            entity.ToTable("D_WorkProcessPermission");
            entity.HasKey(e => e.Id).HasName("PK__D_WorkPr__3214EC277D1A598F");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Wpno).HasColumnName("WPNo").HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Account).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Creator).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.Modifier).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<MWorkProcessPhrase>(entity =>
        {
            entity.ToTable("M_WorkProcessPhrase");
            entity.HasKey(e => e.Id).HasName("PK_M_Phrase");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus).HasColumnName("aStatus").HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.Directions).IsUnicode(false);
            entity.Property(e => e.Creator).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<MWorkProcessType>(entity =>
        {
            entity.ToTable("M_WorkProcessType");
            entity.HasKey(e => e.Id).HasName("PK_M_WorkType");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus).HasColumnName("aStatus").HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.Descript).IsUnicode(false);
            entity.Property(e => e.Creator).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<CrmCustomer>(entity =>
        {
            entity.ToTable("CRM_Customer");
            entity.HasKey(e => e.Id);

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus).HasColumnName("aStatus").HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.ContactEmail).HasColumnName("ContactEMail");
            entity.Property(e => e.ContactFax).HasColumnName("ContactFAX");
            entity.Property(e => e.ContactTel1).HasColumnName("ContactTEL1");
            entity.Property(e => e.ContactTel2).HasColumnName("ContactTEL2");
            entity.Property(e => e.ErpcustomerNo).HasColumnName("ERPCustomerNo");
            entity.Property(e => e.ErpheadCustomer).HasColumnName("ERPHeadCustomer");
            entity.Property(e => e.Erpsource).HasColumnName("ERPSource");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<MUser>(entity =>
        {
            entity.ToTable("M_User");
            entity.HasKey(e => e.Id).HasName("PK__M_User__3214EC27F2F69166");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.LastChangePwd).HasColumnType("datetime");
        });

        modelBuilder.Entity<MPermission>(entity =>
        {
            entity.ToTable("M_Permission");
            entity.HasKey(e => e.Id).HasName("PK__M_Permis__3214EC274A3FED69");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<HFileLink>(entity =>
        {
            entity.ToTable("H_FileLink");
            entity.HasKey(e => e.Id).HasName("PK__H_FileLi__3214EC279A1BB9B4");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.UpdateTime).HasColumnType("datetime");
        });

        modelBuilder.Entity<VErpcustomer>(entity =>
        {
            entity.HasNoKey().ToView("V_ERPCustomer");

            entity.Property(e => e.Erpsource).HasColumnName("ERPSource").HasMaxLength(7).IsUnicode(false);
            entity.Property(e => e.Ma001).HasColumnName("MA001").HasMaxLength(10);
            entity.Property(e => e.Ma002).HasColumnName("MA002").HasMaxLength(30);
            entity.Property(e => e.Ma003).HasColumnName("MA003").HasMaxLength(80);
            entity.Property(e => e.Ma005).HasColumnName("MA005").HasMaxLength(30);
            entity.Property(e => e.Ma006).HasColumnName("MA006").HasMaxLength(20);
            entity.Property(e => e.Ma007).HasColumnName("MA007").HasMaxLength(20);
            entity.Property(e => e.Ma008).HasColumnName("MA008").HasMaxLength(20);
            entity.Property(e => e.Ma009).HasColumnName("MA009").HasMaxLength(60);
            entity.Property(e => e.Ma019).HasColumnName("MA019").HasMaxLength(6);
            entity.Property(e => e.Ma023).HasColumnName("MA023").HasMaxLength(255);
            entity.Property(e => e.Ma024).HasColumnName("MA024").HasMaxLength(255);
            entity.Property(e => e.ErpheadCustomer).HasColumnName("ERPHeadCustomer").HasMaxLength(10);
        });

        // ---------------------------------------------------- 訂單資料檢核（OrderInfoVerify）

        modelBuilder.Entity<VPoList>(entity =>
        {
            entity.HasNoKey().ToView("V_POList");

            entity.Property(e => e.ConfirmFlag).HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.CopSource).HasMaxLength(7).IsUnicode(false).HasColumnName("COP_Source");
            entity.Property(e => e.FaxNo).HasMaxLength(20).HasColumnName("FAX_NO");
            entity.Property(e => e.FinFlag).HasMaxLength(1);
            entity.Property(e => e.Packinglist備註).HasMaxLength(255).HasColumnName("PACKINGLIST備註");
            entity.Property(e => e.TelNo).HasMaxLength(20).HasColumnName("TEL_NO");
            entity.Property(e => e.交易條件).HasMaxLength(1);
            entity.Property(e => e.交易條件名稱).HasMaxLength(40);
            entity.Property(e => e.付款條件).HasMaxLength(16);
            entity.Property(e => e.付款檢核).HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.價格條件).HasMaxLength(40);
            entity.Property(e => e.匯率).HasColumnType("numeric(20, 9)");
            entity.Property(e => e.單別).HasMaxLength(4).IsFixedLength();
            entity.Property(e => e.單別名稱).HasMaxLength(40);
            entity.Property(e => e.單號).HasMaxLength(11).IsFixedLength();
            entity.Property(e => e.客戶代號).HasMaxLength(10);
            entity.Property(e => e.客戶名稱).HasMaxLength(30);
            entity.Property(e => e.客戶單號).HasMaxLength(20);
            entity.Property(e => e.幣別).HasMaxLength(4);
            entity.Property(e => e.業務人員).HasMaxLength(10);
            entity.Property(e => e.業務名稱).HasMaxLength(30);
            entity.Property(e => e.流程代號).HasMaxLength(2);
            entity.Property(e => e.目的港口).HasMaxLength(40);
            entity.Property(e => e.總數量).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.訂單日期).HasMaxLength(8);
            entity.Property(e => e.訂單金額).HasColumnType("numeric(21, 6)");
            entity.Property(e => e.課稅別).HasMaxLength(1);
            entity.Property(e => e.起始港口).HasMaxLength(40);
            entity.Property(e => e.送貨地址一).HasMaxLength(255);
            entity.Property(e => e.送貨地址二).HasMaxLength(255);
            entity.Property(e => e.連絡人).HasMaxLength(30);
            entity.Property(e => e.運輸方式).HasMaxLength(1);
            entity.Property(e => e.部門代號).HasMaxLength(10);
            entity.Property(e => e.附件檔案).HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.預交日).HasMaxLength(1).IsUnicode(false);
        });

        modelBuilder.Entity<VPoDetailList>(entity =>
        {
            entity.HasNoKey().ToView("V_PODetailList");

            entity.Property(e => e.CopSource).HasMaxLength(7).IsUnicode(false).HasColumnName("COP_Source");
            entity.Property(e => e.FinFlag).HasMaxLength(1);
            entity.Property(e => e.匯率).HasColumnType("numeric(20, 9)");
            entity.Property(e => e.台幣金額).HasColumnType("numeric(38, 11)");
            entity.Property(e => e.品名).HasMaxLength(120);
            entity.Property(e => e.品號).HasMaxLength(40);
            entity.Property(e => e.單位).HasMaxLength(6);
            entity.Property(e => e.單別).HasMaxLength(4).IsFixedLength();
            entity.Property(e => e.單號).HasMaxLength(11).IsFixedLength();
            entity.Property(e => e.外幣單價).HasColumnType("numeric(21, 6)");
            entity.Property(e => e.外幣金額).HasColumnType("numeric(21, 6)");
            entity.Property(e => e.幣別).HasMaxLength(4);
            entity.Property(e => e.序號).HasMaxLength(4).IsFixedLength();
            entity.Property(e => e.英文品名).HasMaxLength(120);
            entity.Property(e => e.英文規格).HasMaxLength(120);
            entity.Property(e => e.規格).HasMaxLength(120);
            entity.Property(e => e.訂單數量).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.預交日).HasMaxLength(8);
        });

        modelBuilder.Entity<CopPoCheck>(entity =>
        {
            entity.ToTable("COP_PoCheck");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus).HasMaxLength(1).IsUnicode(false).HasColumnName("aStatus");
            entity.Property(e => e.AvailableAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.AvailableChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.ChkTime).HasColumnType("datetime");
            entity.Property(e => e.CopSource).HasMaxLength(20).HasColumnName("COP_Source");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.Credit30Wchk).HasMaxLength(20).HasDefaultValue("Y").HasColumnName("Credit30WChk");
            entity.Property(e => e.CustAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.CustAmtZeroChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.CustPochk).HasMaxLength(20).HasDefaultValue("Y").HasColumnName("CustPOChk");
            entity.Property(e => e.CustSumAmtChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.DepBlankChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.DepChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.DetailChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.FinChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.InPortChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.OrderChkNo).HasMaxLength(20).IsUnicode(false);
            entity.Property(e => e.OutPortChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.PackListBlankChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.PaidChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.PoNo).HasMaxLength(20);
            entity.Property(e => e.PreDateChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.PriceBlankChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.ProcessCodeChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.RateChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.SumAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.SumQty).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.TradeChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.TransChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.UpFileChk).HasMaxLength(20).HasDefaultValue("Y");
        });

        modelBuilder.Entity<CopPoDetailCheck>(entity =>
        {
            entity.ToTable("COP_PoDetailCheck");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus).HasMaxLength(1).IsUnicode(false).HasColumnName("aStatus");
            entity.Property(e => e.AmtChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.ChkTime).HasColumnType("datetime");
            entity.Property(e => e.CopSource).HasMaxLength(20).HasColumnName("COP_Source");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.FinChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.LinkChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.LinkMoqamtChk).HasMaxLength(20).HasDefaultValue("Y").HasColumnName("LinkMOQAmtChk");
            entity.Property(e => e.LinkNoChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.LinkPriceChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.LinkQtyChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.LinkSnoChk).HasMaxLength(20).HasDefaultValue("Y").HasColumnName("LinkSNoChk");
            entity.Property(e => e.LinkTypeChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.MoqamtChk).HasMaxLength(20).HasDefaultValue("Y").HasColumnName("MOQAmtChk");
            entity.Property(e => e.OrderChkNo).HasMaxLength(20).IsUnicode(false);
            entity.Property(e => e.PackListChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.PoNo).HasMaxLength(20);
            entity.Property(e => e.PriceChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.ProductNo).HasMaxLength(20);
            entity.Property(e => e.ProductNoChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.QtyChk).HasMaxLength(20).HasDefaultValue("Y");
            entity.Property(e => e.Sno).HasMaxLength(4).IsUnicode(false).HasColumnName("SNo");
        });

        modelBuilder.Entity<CopCheckRule>(entity =>
        {
            entity.ToTable("COP_CheckRule");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus).HasMaxLength(1).IsUnicode(false).HasColumnName("aStatus");
            entity.Property(e => e.ChkField).HasMaxLength(40).IsUnicode(false);
            entity.Property(e => e.ChkLevel).HasMaxLength(10);
            entity.Property(e => e.ChkRule).HasMaxLength(120);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.Erpfield).HasMaxLength(40).IsUnicode(false).HasColumnName("ERPField");
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.PassFlag).HasMaxLength(1).IsUnicode(false);
            entity.Property(e => e.RecType).HasMaxLength(40).IsUnicode(false);
        });

        modelBuilder.Entity<CopPassCheck>(entity =>
        {
            entity.ToTable("COP_PassCheck");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus).HasMaxLength(1).IsUnicode(false).HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.OrderChkNo).HasMaxLength(20).IsUnicode(false);
            entity.Property(e => e.PassItems).HasMaxLength(40).IsUnicode(false);
            entity.Property(e => e.PassMemo).HasMaxLength(500);
            entity.Property(e => e.PassTime).HasColumnType("datetime");
            entity.Property(e => e.Sno).HasMaxLength(4).IsUnicode(false);
        });

        modelBuilder.Entity<VProductEnglishAll>(entity =>
        {
            entity.HasNoKey().ToView("V_Product_English_All");

            entity.Property(e => e.ProductName).HasMaxLength(120);
            entity.Property(e => e.ProductNameE).HasMaxLength(120).HasColumnName("ProductName_E");
            entity.Property(e => e.ProductNo).HasMaxLength(40);
            entity.Property(e => e.Specification).HasMaxLength(120);
            entity.Property(e => e.SpecificationE).HasMaxLength(120).HasColumnName("Specification_E");
        });

        modelBuilder.Entity<CopDepData>(entity =>
        {
            entity.ToTable("COP_DepData");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus).HasMaxLength(1).IsUnicode(false).HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.DepName).HasMaxLength(120);
            entity.Property(e => e.DepNo).HasMaxLength(10).IsUnicode(false);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.OrderName).HasMaxLength(120);
            entity.Property(e => e.OrderNameAll).HasMaxLength(120).HasColumnName("OrderName_All");
            entity.Property(e => e.OrderType).HasMaxLength(10).IsUnicode(false);
        });

        modelBuilder.Entity<VUpFileData>(entity =>
        {
            entity.HasNoKey().ToView("V_UpFileData");

            entity.Property(e => e.AddDate).HasMaxLength(10).IsFixedLength();
            entity.Property(e => e.AddTime).HasMaxLength(10).IsFixedLength();
            entity.Property(e => e.CompanyId).HasMaxLength(20).IsFixedLength().HasColumnName("CompanyID");
            entity.Property(e => e.DocId).HasMaxLength(10).IsFixedLength().HasColumnName("DocID");
            entity.Property(e => e.FileName).HasMaxLength(100);
            entity.Property(e => e.KeyFields).HasMaxLength(100);
            entity.Property(e => e.KeyValues).HasMaxLength(4000);
            entity.Property(e => e.Parent).HasMaxLength(10).IsFixedLength();
            entity.Property(e => e.Revision).HasMaxLength(10).IsFixedLength();
            entity.Property(e => e.SeqNo).HasMaxLength(10).IsFixedLength();
            entity.Property(e => e.Type).HasMaxLength(10).IsFixedLength();
            entity.Property(e => e.UserId).HasMaxLength(10).IsFixedLength().HasColumnName("UserID");
        });

        // keyless，只給 Set<T>().FromSqlInterpolated(...) 用，不對應任何表/view
        modelBuilder.Entity<CopGetCredit>().HasNoKey();
        modelBuilder.Entity<CopGetCreditCrm>().HasNoKey();
    }
}

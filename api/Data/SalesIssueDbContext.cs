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
        });
    }
}

using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

public partial class SalesCenterDbContext : DbContext
{
    public SalesCenterDbContext(DbContextOptions<SalesCenterDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<CopCheckRule> CopCheckRules { get; set; }

    public virtual DbSet<CopDepDatum> CopDepData { get; set; }

    public virtual DbSet<CrmCustomer> CrmCustomers { get; set; }

    public virtual DbSet<DWorkProcess> DWorkProcesses { get; set; }

    public virtual DbSet<DWorkProcessCustomer> DWorkProcessCustomers { get; set; }

    public virtual DbSet<DWorkProcessDetail> DWorkProcessDetails { get; set; }

    public virtual DbSet<DWorkProcessPermission> DWorkProcessPermissions { get; set; }

    public virtual DbSet<DWorkProcessSearch> DWorkProcessSearches { get; set; }

    public virtual DbSet<HFileLink> HFileLinks { get; set; }

    public virtual DbSet<MFunction> MFunctions { get; set; }

    public virtual DbSet<MPermission> MPermissions { get; set; }

    public virtual DbSet<MPermissionGroup> MPermissionGroups { get; set; }

    public virtual DbSet<MPermissionLinkType> MPermissionLinkTypes { get; set; }

    public virtual DbSet<MSystem> MSystems { get; set; }

    public virtual DbSet<MUser> MUsers { get; set; }

    public virtual DbSet<MWorkProcessPhrase> MWorkProcessPhrases { get; set; }

    public virtual DbSet<MWorkProcessType> MWorkProcessTypes { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<CopCheckRule>(entity =>
        {
            entity.ToTable("COP_CheckRule");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.ChkField)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.ChkLevel).HasMaxLength(10);
            entity.Property(e => e.ChkRule).HasMaxLength(120);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.Erpfield)
                .HasMaxLength(40)
                .IsUnicode(false)
                .HasColumnName("ERPField");
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.PassFlag)
                .HasMaxLength(1)
                .IsUnicode(false);
            entity.Property(e => e.RecType)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.TestDacPak).HasColumnName("testDacPak");
        });

        modelBuilder.Entity<CopDepDatum>(entity =>
        {
            entity.ToTable("COP_DepData");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.DepName).HasMaxLength(120);
            entity.Property(e => e.DepNo)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.OrderName).HasMaxLength(120);
            entity.Property(e => e.OrderNameAll)
                .HasMaxLength(120)
                .HasColumnName("OrderName_All");
            entity.Property(e => e.OrderType)
                .HasMaxLength(10)
                .IsUnicode(false);
        });

        modelBuilder.Entity<CrmCustomer>(entity =>
        {
            entity.ToTable("CRM_Customer");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasDefaultValue("Y")
                .HasColumnName("aStatus");
            entity.Property(e => e.Addr1)
                .HasMaxLength(100)
                .HasDefaultValue("");
            entity.Property(e => e.Addr2)
                .HasMaxLength(100)
                .HasDefaultValue("");
            entity.Property(e => e.AreaCode)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("");
            entity.Property(e => e.ContactEmail)
                .HasMaxLength(100)
                .HasDefaultValue("")
                .HasColumnName("ContactEMail");
            entity.Property(e => e.ContactFax)
                .HasMaxLength(40)
                .HasDefaultValue("")
                .HasColumnName("ContactFAX");
            entity.Property(e => e.ContactName)
                .HasMaxLength(60)
                .HasDefaultValue("");
            entity.Property(e => e.ContactTel1)
                .HasMaxLength(40)
                .HasDefaultValue("")
                .HasColumnName("ContactTEL1");
            entity.Property(e => e.ContactTel2)
                .HasMaxLength(40)
                .HasDefaultValue("")
                .HasColumnName("ContactTEL2");
            entity.Property(e => e.CountryCode)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.CustomerNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.CustomerSource)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("");
            entity.Property(e => e.ErpcustomerNo)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("")
                .HasColumnName("ERPCustomerNo");
            entity.Property(e => e.ErpheadCustomer)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("")
                .HasColumnName("ERPHeadCustomer");
            entity.Property(e => e.Erpsource)
                .HasMaxLength(20)
                .HasDefaultValue("")
                .HasColumnName("ERPSource");
            entity.Property(e => e.LongName).HasMaxLength(200);
            entity.Property(e => e.Memo)
                .HasMaxLength(500)
                .HasDefaultValue("");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.PotentialCustom)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasDefaultValue("N");
            entity.Property(e => e.SalesName)
                .HasMaxLength(40)
                .HasDefaultValue("");
            entity.Property(e => e.SalesNo)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("");
            entity.Property(e => e.ShortName).HasMaxLength(40);
        });

        modelBuilder.Entity<DWorkProcess>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK_M_WorkProcess");

            entity.ToTable("D_WorkProcess");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.Authorize)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Leader)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.PhraseList).HasMaxLength(500);
            entity.Property(e => e.ProgressStatus).HasDefaultValue(10);
            entity.Property(e => e.PubDate).HasColumnType("datetime");
            entity.Property(e => e.SopTitle)
                .HasMaxLength(200)
                .HasDefaultValue("");
            entity.Property(e => e.VerNo)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.Wpno)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("WPNo");
        });

        modelBuilder.Entity<DWorkProcessCustomer>(entity =>
        {
            entity.ToTable("D_WorkProcessCustomer");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasDefaultValue("Y")
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.CustomerNo)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.CustomerType)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("1");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Wpno)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("WPNo");
        });

        modelBuilder.Entity<DWorkProcessDetail>(entity =>
        {
            entity.ToTable("D_WorkProcessDetail");

            entity.HasIndex(e => new { e.Wpno, e.Sno }, "NonClusteredIndex-20231221-145816").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.ProcessCaption).HasMaxLength(200);
            entity.Property(e => e.RenameFile).HasMaxLength(200);
            entity.Property(e => e.Sno)
                .HasMaxLength(4)
                .IsUnicode(false)
                .HasColumnName("SNo");
            entity.Property(e => e.UploadFile).HasMaxLength(200);
            entity.Property(e => e.Worker)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Wpno)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("WPNo");
            entity.Property(e => e.ZipFile)
                .HasMaxLength(200)
                .IsUnicode(false)
                .HasColumnName("zipFile");
        });

        modelBuilder.Entity<DWorkProcessPermission>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__D_WorkPr__3214EC277D1A598F");

            entity.ToTable("D_WorkProcessPermission");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Account)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Wpno)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("WPNo");
        });

        modelBuilder.Entity<DWorkProcessSearch>(entity =>
        {
            entity.ToTable("D_WorkProcessSearch");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.PhraseCode)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.PhraseType)
                .HasMaxLength(4)
                .IsUnicode(false);
            entity.Property(e => e.Wpno)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("WPNo");
        });

        modelBuilder.Entity<HFileLink>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__H_FileLi__3214EC279A1BB9B4");

            entity.ToTable("H_FileLink");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.FilePath)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.FileType)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.LinkFunctionNo)
                .HasMaxLength(8)
                .IsUnicode(false)
                .HasDefaultValue("0");
            entity.Property(e => e.LinkNo)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.UpdateTime).HasColumnType("datetime");
            entity.Property(e => e.UpdateUser)
                .HasMaxLength(10)
                .IsUnicode(false);
        });

        modelBuilder.Entity<MFunction>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__M_Functi__3214EC2746E5CF47");

            entity.ToTable("M_Function");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasDefaultValue("Y")
                .HasColumnName("aStatus");
            // FunctionName / GroupName 在 Proril_Sales_Center 是 nvarchar（來源 PRORIL_WEB
            // 是 varchar，兩庫 collation 不同，照搬會讓中文功能名變成 ?），
            // 見 database/PortingNotes.md「為什麼有 9 個欄位型別跟來源不一樣」。
            entity.Property(e => e.FunctionName).HasMaxLength(20);
            entity.Property(e => e.FunctionNo)
                .HasMaxLength(8)
                .IsUnicode(false);
            entity.Property(e => e.GroupName).HasMaxLength(20);
            entity.Property(e => e.Href).HasMaxLength(50);
            entity.Property(e => e.ImagrePath)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.RedirectHref).HasMaxLength(50);
        });

        modelBuilder.Entity<MPermission>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__M_Permis__3214EC274A3FED69");

            entity.ToTable("M_Permission");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.FunctionNo)
                .HasMaxLength(8)
                .IsUnicode(false);
            entity.Property(e => e.LinkNumber)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.PermissionLinkTypeId).HasColumnName("PermissionLinkTypeID");
        });

        modelBuilder.Entity<MPermissionGroup>(entity =>
        {
            entity.ToTable("M_PermissionGroup");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.FunctionNo)
                .HasMaxLength(8)
                .IsUnicode(false);
            entity.Property(e => e.GroupDesc).HasMaxLength(50);
            entity.Property(e => e.GroupNo)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.TypeDesc).HasMaxLength(50);
        });

        modelBuilder.Entity<MPermissionLinkType>(entity =>
        {
            entity.ToTable("M_PermissionLinkType");

            entity.HasIndex(e => new { e.FunctionNo, e.LinkType, e.ParentLinkTypeId },
                "NonClusteredIndex-20231116-083304").IsUnique();

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.FunctionNo)
                .HasMaxLength(8)
                .IsUnicode(false);
            entity.Property(e => e.LinkTypeName)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.Modifier)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.ModifyTime).HasColumnType("datetime");
            entity.Property(e => e.ParentLinkTypeId).HasColumnName("ParentLinkTypeID");
        });

        modelBuilder.Entity<MSystem>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__M_System__3214EC279302271C");

            entity.ToTable("M_System");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Href)
                .HasMaxLength(50)
                .HasDefaultValue("");
            entity.Property(e => e.ImagePath)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.RedirectHref).HasMaxLength(50);
            entity.Property(e => e.SystemName).HasMaxLength(20);
            entity.Property(e => e.TypeName).HasMaxLength(20);
        });

        modelBuilder.Entity<MUser>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__M_User__3214EC27F2F69166");

            entity.ToTable("M_User");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.Account)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.LastChangePwd).HasColumnType("datetime");
            entity.Property(e => e.Password)
                .HasMaxLength(50)
                .IsUnicode(false);
            // UserName 在 Proril_Sales_Center 是 nvarchar(40)（來源 PRORIL_WEB 是
            // varchar(40)，兩庫 collation 不同，照搬會讓中文姓名變成 ?），
            // 見 database/PortingNotes.md「為什麼有 7 個欄位型別跟來源不一樣」。
            entity.Property(e => e.UserName).HasMaxLength(40);
        });

        modelBuilder.Entity<MWorkProcessPhrase>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK_M_Phrase");

            entity.ToTable("M_WorkProcessPhrase");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.PhraseCode)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.PhraseName).HasMaxLength(40);
            entity.Property(e => e.PhraseType)
                .HasMaxLength(4)
                .IsUnicode(false);
            entity.Property(e => e.PotentialCustom)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasDefaultValue("N");
            entity.Property(e => e.Principal)
                .HasMaxLength(10)
                .IsUnicode(false);
        });

        modelBuilder.Entity<MWorkProcessType>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK_M_WorkType");

            entity.ToTable("M_WorkProcessType");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.TypeCode)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.TypeName).HasMaxLength(40);
        });

        // prc_QueryUnfinOrder(_1) 的結果集，keyless，只給 Set<T>().FromSqlInterpolated(...) 用，
        // 不對應任何表/view。跟 ProrilWebDbContext 的註冊一字不差（同一個 UnfinOrder 型別，
        // 兩支 SP 搬進 Proril_Sales_Center 之後 Controller 改打這個 DbContext 執行）。
        modelBuilder.Entity<UnfinOrder>(entity =>
        {
            entity.HasNoKey();
            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.CopSource).HasColumnName("COP_Source");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}

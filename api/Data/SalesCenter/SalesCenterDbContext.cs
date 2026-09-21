using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Data;

namespace Proril.SalesIssue.Api.Data.SalesCenter;

/*
 * CopCheckRule / CopDepData / CopPassCheck / CopPoCheck / CopPoDetailCheck / CopGetCredit /
 * CopGetCreditCrm / VPoList / VPoDetailList / VProductEnglishAll / VUpFileData 對映到
 * OrderInfoVerifyEntities.cs 的手寫 POCO（跟 ProrilWebDbContext 共用同一份型別），
 * 不是這支 scaffold 自己產生的型別——專案慣例是手寫乾淨命名，不要 dotnet ef scaffold
 * 產生的 VPolist / CopDepDatum 這種怪名字（見 OrderInfoVerifyEntities.cs 開頭註解）。
 * scaffold-sales-center.ps1 重跑時會把這幾個 DbSet 洗回 scaffold 型別，記得跑完要照這裡改回來。
 *
 * CopCheckRule / CopPassCheck / CopPoCheck / CopPoDetailCheck / VProductEnglishAll
 * 這五個名字跟 Data/SalesCenter/ 底下同名的 scaffold 產物撞名，那幾個檔案目前留著沒刪
 * （刪除被安全機制擋下），所以這裡一律用完整命名空間 Proril.SalesIssue.Api.Data.X 明確指定，
 * 不能只寫裸名——裸名在這幾個型別上會是 CS0104 ambiguous reference。
 */

public partial class SalesCenterDbContext : DbContext
{
    public SalesCenterDbContext(DbContextOptions<SalesCenterDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<CopAvailableAmt> CopAvailableAmts { get; set; }

    public virtual DbSet<Proril.SalesIssue.Api.Data.CopCheckRule> CopCheckRules { get; set; }

    public virtual DbSet<CopDepData> CopDepData { get; set; }

    public virtual DbSet<Proril.SalesIssue.Api.Data.CopPassCheck> CopPassChecks { get; set; }

    public virtual DbSet<Proril.SalesIssue.Api.Data.CopPoCheck> CopPoChecks { get; set; }

    public virtual DbSet<Proril.SalesIssue.Api.Data.CopPoDetailCheck> CopPoDetailChecks { get; set; }

    public virtual DbSet<CopGetCredit> CopGetCredits { get; set; }

    public virtual DbSet<CopGetCreditCrm> CopGetCreditCrms { get; set; }

    public virtual DbSet<VCopCustomer> VCopCustomers { get; set; }

    public virtual DbSet<CopProductCheck> CopProductChecks { get; set; }

    public virtual DbSet<CopSalesOrder> CopSalesOrders { get; set; }

    public virtual DbSet<CrmCustomer> CrmCustomers { get; set; }

    public virtual DbSet<CrmCustomerMemo> CrmCustomerMemos { get; set; }

    public virtual DbSet<DWorkProcess> DWorkProcesses { get; set; }

    public virtual DbSet<DWorkProcessCustomer> DWorkProcessCustomers { get; set; }

    public virtual DbSet<DWorkProcessDetail> DWorkProcessDetails { get; set; }

    public virtual DbSet<DWorkProcessPermission> DWorkProcessPermissions { get; set; }

    public virtual DbSet<DWorkProcessSearch> DWorkProcessSearches { get; set; }

    public virtual DbSet<HFileLink> HFileLinks { get; set; }

    public virtual DbSet<HFileLinkBakFunctionNo> HFileLinkBakFunctionNos { get; set; }

    public virtual DbSet<MDepartment> MDepartments { get; set; }

    public virtual DbSet<MFunction> MFunctions { get; set; }

    public virtual DbSet<MFunctionBakFunctionNo> MFunctionBakFunctionNos { get; set; }

    public virtual DbSet<MPermission> MPermissions { get; set; }

    public virtual DbSet<MPermissionBakFunctionNo> MPermissionBakFunctionNos { get; set; }

    public virtual DbSet<MPermissionGroup> MPermissionGroups { get; set; }

    public virtual DbSet<MPermissionGroupBakFunctionNo> MPermissionGroupBakFunctionNos { get; set; }

    public virtual DbSet<MPermissionLinkType> MPermissionLinkTypes { get; set; }

    public virtual DbSet<MSystem> MSystems { get; set; }

    public virtual DbSet<MUser> MUsers { get; set; }

    public virtual DbSet<MUserBakPassword> MUserBakPasswords { get; set; }

    public virtual DbSet<MWorkProcessPhrase> MWorkProcessPhrases { get; set; }

    public virtual DbSet<MWorkProcessType> MWorkProcessTypes { get; set; }

    public virtual DbSet<VCopmoq> VCopmoqs { get; set; }

    public virtual DbSet<VCopnoChk> VCopnoChks { get; set; }

    public virtual DbSet<VErpcustomer> VErpcustomers { get; set; }

    public virtual DbSet<VPoDetailList> VPoDetailLists { get; set; }

    public virtual DbSet<VPoList> VPoLists { get; set; }

    public virtual DbSet<Proril.SalesIssue.Api.Data.VProductEnglishAll> VProductEnglishAlls { get; set; }

    public virtual DbSet<VSalesTotal> VSalesTotals { get; set; }

    public virtual DbSet<VUnfinOrder> VUnfinOrders { get; set; }

    public virtual DbSet<VUpFileData> VUpFileData { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.UseCollation("Chinese_Taiwan_Stroke_BIN");

        modelBuilder.Entity<CopAvailableAmt>(entity =>
        {
            entity.ToTable("COP_AvailableAmt");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.AvailableAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.AvailableSetAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.CustNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.GainAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.NotifyAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.OrderAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.OrderAmtRate).HasColumnType("numeric(16, 6)");
            entity.Property(e => e.OrderChkNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.PreGainAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.ReceivableAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.ReceivableSumAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.UnbilledAmt).HasColumnType("numeric(16, 3)");
        });

        modelBuilder.Entity<Proril.SalesIssue.Api.Data.CopCheckRule>(entity =>
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
            // testDacPak：測試區 50002 的 COP_CheckRule 多出來的測試欄位，PRORIL_WEB／
            // 手寫的 Data.CopCheckRule 都沒有這個屬性，EF 不映射的欄位會直接忽略，不用理它。
        });

        modelBuilder.Entity<CopDepData>(entity =>
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

        modelBuilder.Entity<Proril.SalesIssue.Api.Data.CopPassCheck>(entity =>
        {
            entity.ToTable("COP_PassCheck");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.OrderChkNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.PassItems)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.PassMemo).HasMaxLength(500);
            entity.Property(e => e.PassTime).HasColumnType("datetime");
            entity.Property(e => e.Sno)
                .HasMaxLength(4)
                .IsUnicode(false);
        });

        modelBuilder.Entity<Proril.SalesIssue.Api.Data.CopPoCheck>(entity =>
        {
            entity.ToTable("COP_PoCheck");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.AvailableAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.AvailableChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.ChkTime).HasColumnType("datetime");
            entity.Property(e => e.CopSource)
                .HasMaxLength(20)
                .HasColumnName("COP_Source");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.Credit30Wchk)
                .HasMaxLength(20)
                .HasDefaultValue("Y")
                .HasColumnName("Credit30WChk");
            entity.Property(e => e.CustAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.CustAmtZeroChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.CustPochk)
                .HasMaxLength(20)
                .HasDefaultValue("Y")
                .HasColumnName("CustPOChk");
            entity.Property(e => e.CustSumAmtChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.DepBlankChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.DepChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.DetailChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.FinChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.InPortChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.OrderChkNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.OutPortChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.PackListBlankChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.PaidChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.PoNo).HasMaxLength(20);
            entity.Property(e => e.PreDateChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.PriceBlankChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.ProcessCodeChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.RateChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.SumAmt).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.SumQty).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.TradeChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.TransChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.UpFileChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
        });

        modelBuilder.Entity<Proril.SalesIssue.Api.Data.CopPoDetailCheck>(entity =>
        {
            entity.ToTable("COP_PoDetailCheck");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.AmtChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.ChkTime).HasColumnType("datetime");
            entity.Property(e => e.CopSource)
                .HasMaxLength(20)
                .HasColumnName("COP_Source");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.FinChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.LinkChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.LinkMoqamtChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y")
                .HasColumnName("LinkMOQAmtChk");
            entity.Property(e => e.LinkNoChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.LinkPriceChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.LinkQtyChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.LinkSnoChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y")
                .HasColumnName("LinkSNoChk");
            entity.Property(e => e.LinkTypeChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.MoqamtChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y")
                .HasColumnName("MOQAmtChk");
            entity.Property(e => e.OrderChkNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.PackListChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.PoNo).HasMaxLength(20);
            entity.Property(e => e.PriceChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.ProductNo).HasMaxLength(20);
            entity.Property(e => e.ProductNoChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.QtyChk)
                .HasMaxLength(20)
                .HasDefaultValue("Y");
            entity.Property(e => e.Sno)
                .HasMaxLength(4)
                .IsUnicode(false)
                .HasColumnName("SNo");
        });

        modelBuilder.Entity<CopProductCheck>(entity =>
        {
            entity.ToTable("COP_ProductCheck");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasDefaultValue("Y")
                .HasColumnName("aStatus");
            entity.Property(e => e.ChkNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.ChkSource)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.ChkTime).HasColumnType("datetime");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.Ext1Chk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.Ext2Chk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.Ext3Chk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.FinChk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.FloatChk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.Hzchk)
                .HasMaxLength(10)
                .HasDefaultValue("")
                .HasColumnName("HZChk");
            entity.Property(e => e.Memo)
                .HasMaxLength(500)
                .HasDefaultValue("");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.NoChk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.OrderChkNo)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("");
            entity.Property(e => e.Phchk)
                .HasMaxLength(10)
                .HasDefaultValue("")
                .HasColumnName("PHChk");
            entity.Property(e => e.PlusChk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.ProductName).HasMaxLength(120);
            entity.Property(e => e.ProductNameEn)
                .HasMaxLength(120)
                .HasColumnName("ProductName_EN");
            entity.Property(e => e.ProductNo).HasMaxLength(40);
            entity.Property(e => e.ProductSpec).HasMaxLength(120);
            entity.Property(e => e.ProductSpecEn)
                .HasMaxLength(120)
                .HasColumnName("ProductSpec_EN");
            entity.Property(e => e.StartChk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.VolChk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.WireSizeChk)
                .HasMaxLength(10)
                .HasDefaultValue("");
            entity.Property(e => e.WireSpecChk)
                .HasMaxLength(10)
                .HasDefaultValue("");
        });

        modelBuilder.Entity<CopSalesOrder>(entity =>
        {
            entity.ToTable("COP_SalesOrder");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CopSource)
                .HasMaxLength(10)
                .HasDefaultValue("")
                .HasColumnName("COP_Source");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator).HasMaxLength(40);
            entity.Property(e => e.CustomerName).HasMaxLength(80);
            entity.Property(e => e.CustomerNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.FooterFlag)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasDefaultValue("");
            entity.Property(e => e.Memo).HasMaxLength(500);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier).HasMaxLength(40);
            entity.Property(e => e.PlanNumber).HasMaxLength(40);
            entity.Property(e => e.PlanNumber1).HasMaxLength(40);
            entity.Property(e => e.SumAmt)
                .HasDefaultValue(0m)
                .HasColumnType("numeric(21, 6)");
            entity.Property(e => e.SumQty)
                .HasDefaultValue(0m)
                .HasColumnType("numeric(16, 3)");
            entity.Property(e => e.Ta001)
                .HasMaxLength(4)
                .IsFixedLength()
                .HasColumnName("TA001");
            entity.Property(e => e.Ta0011)
                .HasMaxLength(4)
                .IsFixedLength()
                .HasColumnName("TA0011");
            entity.Property(e => e.Ta002)
                .HasMaxLength(11)
                .IsFixedLength()
                .HasColumnName("TA002");
            entity.Property(e => e.Ta0021)
                .HasMaxLength(11)
                .IsFixedLength()
                .HasColumnName("TA0021");
            entity.Property(e => e.Ta026)
                .HasMaxLength(4)
                .HasColumnName("TA026");
            entity.Property(e => e.Ta027)
                .HasMaxLength(11)
                .HasColumnName("TA027");
            entity.Property(e => e.Ta028)
                .HasMaxLength(4)
                .HasColumnName("TA028");
            entity.Property(e => e.Tc012)
                .HasMaxLength(20)
                .HasDefaultValue("")
                .HasColumnName("TC012");
            entity.Property(e => e.Tg003)
                .HasMaxLength(50)
                .HasDefaultValue("")
                .HasColumnName("TG003");
            entity.Property(e => e.Tg011)
                .HasMaxLength(4)
                .HasColumnName("TG011");
            entity.Property(e => e.Tg012)
                .HasColumnType("numeric(16, 3)")
                .HasColumnName("TG012");
            entity.Property(e => e.Th001)
                .HasMaxLength(50)
                .HasDefaultValue("")
                .HasColumnName("TH001");
            entity.Property(e => e.Th002)
                .HasMaxLength(50)
                .HasColumnName("TH002");
            entity.Property(e => e.Th003)
                .HasMaxLength(50)
                .HasColumnName("TH003");
            entity.Property(e => e.Th004)
                .HasMaxLength(40)
                .HasColumnName("TH004");
            entity.Property(e => e.Th005)
                .HasMaxLength(120)
                .HasColumnName("TH005");
            entity.Property(e => e.Th006)
                .HasMaxLength(120)
                .HasColumnName("TH006");
            entity.Property(e => e.Th007)
                .HasMaxLength(10)
                .HasColumnName("TH007");
            entity.Property(e => e.Th008)
                .HasColumnType("numeric(16, 3)")
                .HasColumnName("TH008");
            entity.Property(e => e.Th009)
                .HasMaxLength(6)
                .HasColumnName("TH009");
            entity.Property(e => e.Th012)
                .HasColumnType("numeric(21, 6)")
                .HasColumnName("TH012");
            entity.Property(e => e.Th013)
                .HasColumnType("numeric(21, 6)")
                .HasColumnName("TH013");
            entity.Property(e => e.Th014)
                .HasMaxLength(4)
                .HasColumnName("TH014");
            entity.Property(e => e.Th015)
                .HasMaxLength(11)
                .HasColumnName("TH015");
            entity.Property(e => e.Th016)
                .HasMaxLength(4)
                .HasColumnName("TH016");
            entity.Property(e => e.Th018)
                .HasMaxLength(255)
                .HasDefaultValue("")
                .HasColumnName("TH018");
            entity.Property(e => e.Th024)
                .HasColumnType("numeric(16, 3)")
                .HasColumnName("TH024");
            entity.Property(e => e.Th037)
                .HasColumnType("numeric(21, 6)")
                .HasColumnName("TH037");
            entity.Property(e => e.Th038)
                .HasColumnType("numeric(21, 6)")
                .HasColumnName("TH038");
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

        modelBuilder.Entity<CrmCustomerMemo>(entity =>
        {
            entity.ToTable("CRM_CustomerMemo");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.CustomerNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.FileName).HasMaxLength(200);
            entity.Property(e => e.MemoDesc).HasMaxLength(1000);
            entity.Property(e => e.MemoType).HasMaxLength(40);
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(40)
                .IsUnicode(false);
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

        modelBuilder.Entity<HFileLinkBakFunctionNo>(entity =>
        {
            entity
                .HasNoKey()
                .ToTable("H_FileLink_bak_FunctionNo");

            entity.Property(e => e.FilePath)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.FileType)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Id)
                .ValueGeneratedOnAdd()
                .HasColumnName("ID");
            entity.Property(e => e.LinkNo)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.UpdateTime).HasColumnType("datetime");
            entity.Property(e => e.UpdateUser)
                .HasMaxLength(10)
                .IsUnicode(false);
        });

        modelBuilder.Entity<MDepartment>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__M_Depart__3214EC2799095914");

            entity.ToTable("M_Department");

            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.DepCode)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.DepLeader)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.DepName)
                .HasMaxLength(40)
                .IsUnicode(false);
            entity.Property(e => e.Directions).IsUnicode(false);
            entity.Property(e => e.IsEnable).HasDefaultValue(true);
            entity.Property(e => e.OrgChartFlag).HasDefaultValue(true);
            entity.Property(e => e.ParentsDep)
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
            entity.Property(e => e.FunctionName)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.FunctionNo)
                .HasMaxLength(8)
                .IsUnicode(false);
            entity.Property(e => e.GroupName)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.Href).HasMaxLength(50);
            entity.Property(e => e.ImagrePath)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.RedirectHref).HasMaxLength(50);
        });

        modelBuilder.Entity<MFunctionBakFunctionNo>(entity =>
        {
            entity
                .HasNoKey()
                .ToTable("M_Function_bak_FunctionNo");

            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.FunctionName)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.GroupName)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.Href).HasMaxLength(50);
            entity.Property(e => e.Id)
                .ValueGeneratedOnAdd()
                .HasColumnName("ID");
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

        modelBuilder.Entity<MPermissionBakFunctionNo>(entity =>
        {
            entity
                .HasNoKey()
                .ToTable("M_Permission_bak_FunctionNo");

            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Id)
                .ValueGeneratedOnAdd()
                .HasColumnName("ID");
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

        modelBuilder.Entity<MPermissionGroupBakFunctionNo>(entity =>
        {
            entity
                .HasNoKey()
                .ToTable("M_PermissionGroup_bak_FunctionNo");

            entity.Property(e => e.AStatus)
                .HasMaxLength(1)
                .IsUnicode(false)
                .HasColumnName("aStatus");
            entity.Property(e => e.CreateTime).HasColumnType("datetime");
            entity.Property(e => e.Creator)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.GroupDesc).HasMaxLength(50);
            entity.Property(e => e.GroupNo)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Id)
                .ValueGeneratedOnAdd()
                .HasColumnName("ID");
            entity.Property(e => e.ModiTime).HasColumnType("datetime");
            entity.Property(e => e.Modifier)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.TypeDesc).HasMaxLength(50);
        });

        modelBuilder.Entity<MPermissionLinkType>(entity =>
        {
            entity.ToTable("M_PermissionLinkType");

            entity.HasIndex(e => new { e.FunctionNo, e.LinkType, e.ParentLinkTypeId }, "NonClusteredIndex-20231116-083304").IsUnique();

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
            entity.Property(e => e.UserName)
                .HasMaxLength(40)
                .IsUnicode(false);
        });

        modelBuilder.Entity<MUserBakPassword>(entity =>
        {
            entity
                .HasNoKey()
                .ToTable("M_User_bak_Password");

            entity.Property(e => e.Account)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Id)
                .ValueGeneratedOnAdd()
                .HasColumnName("ID");
            entity.Property(e => e.Password)
                .HasMaxLength(50)
                .IsUnicode(false);
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

        modelBuilder.Entity<VCopmoq>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("V_COPMOQ");

            entity.Property(e => e.ByQtyCurrency)
                .HasMaxLength(4)
                .IsFixedLength();
            entity.Property(e => e.ByQtyFlag).HasMaxLength(1);
            entity.Property(e => e.ByQtyPrice).HasColumnType("numeric(21, 6)");
            entity.Property(e => e.CheckDate).HasMaxLength(8);
            entity.Property(e => e.Currency)
                .HasMaxLength(4)
                .IsFixedLength();
            entity.Property(e => e.CustomerNo).HasMaxLength(10);
            entity.Property(e => e.EndDate).HasMaxLength(8);
            entity.Property(e => e.Erpsource)
                .HasMaxLength(4)
                .IsUnicode(false)
                .HasColumnName("ERPSource");
            entity.Property(e => e.ProductName).HasMaxLength(120);
            entity.Property(e => e.ProductNo).HasMaxLength(40);
            entity.Property(e => e.Qty).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.StartDate)
                .HasMaxLength(8)
                .IsFixedLength();
            entity.Property(e => e.StartDateD)
                .HasMaxLength(8)
                .IsFixedLength()
                .HasColumnName("StartDate_D");
            entity.Property(e => e.Unit)
                .HasMaxLength(6)
                .IsFixedLength();
        });

        modelBuilder.Entity<VCopnoChk>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("V_COPNoChk");

            entity.Property(e => e.C01)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.E01)
                .HasMaxLength(20)
                .IsUnicode(false);
        });

        modelBuilder.Entity<VErpcustomer>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("V_ERPCustomer");

            entity.Property(e => e.ErpheadCustomer)
                .HasMaxLength(10)
                .HasColumnName("ERPHeadCustomer");
            entity.Property(e => e.Erpsource)
                .HasMaxLength(7)
                .IsUnicode(false)
                .HasColumnName("ERPSource");
            entity.Property(e => e.Ma001)
                .HasMaxLength(10)
                .HasColumnName("MA001");
            entity.Property(e => e.Ma002)
                .HasMaxLength(30)
                .HasColumnName("MA002");
            entity.Property(e => e.Ma003)
                .HasMaxLength(80)
                .HasColumnName("MA003");
            entity.Property(e => e.Ma004)
                .HasMaxLength(30)
                .HasColumnName("MA004");
            entity.Property(e => e.Ma005)
                .HasMaxLength(30)
                .HasColumnName("MA005");
            entity.Property(e => e.Ma006)
                .HasMaxLength(20)
                .HasColumnName("MA006");
            entity.Property(e => e.Ma007)
                .HasMaxLength(20)
                .HasColumnName("MA007");
            entity.Property(e => e.Ma008)
                .HasMaxLength(20)
                .HasColumnName("MA008");
            entity.Property(e => e.Ma009)
                .HasMaxLength(60)
                .HasColumnName("MA009");
            entity.Property(e => e.Ma010)
                .HasMaxLength(20)
                .HasColumnName("MA010");
            entity.Property(e => e.Ma016)
                .HasMaxLength(10)
                .HasColumnName("MA016");
            entity.Property(e => e.Ma017)
                .HasMaxLength(6)
                .HasColumnName("MA017");
            entity.Property(e => e.Ma018)
                .HasMaxLength(6)
                .HasColumnName("MA018");
            entity.Property(e => e.Ma019)
                .HasMaxLength(6)
                .HasColumnName("MA019");
            entity.Property(e => e.Ma020)
                .HasMaxLength(8)
                .HasColumnName("MA020");
            entity.Property(e => e.Ma021)
                .HasMaxLength(8)
                .HasColumnName("MA021");
            entity.Property(e => e.Ma022)
                .HasMaxLength(8)
                .HasColumnName("MA022");
            entity.Property(e => e.Ma023)
                .HasMaxLength(255)
                .HasColumnName("MA023");
            entity.Property(e => e.Ma024)
                .HasMaxLength(255)
                .HasColumnName("MA024");
            entity.Property(e => e.Ma025)
                .HasMaxLength(255)
                .HasColumnName("MA025");
            entity.Property(e => e.Ma026)
                .HasMaxLength(255)
                .HasColumnName("MA026");
            entity.Property(e => e.Ma027)
                .HasMaxLength(255)
                .HasColumnName("MA027");
            entity.Property(e => e.Ma066)
                .HasMaxLength(1)
                .HasColumnName("MA066");
            entity.Property(e => e.Ma082)
                .HasMaxLength(1)
                .HasColumnName("MA082");
        });

        modelBuilder.Entity<VPoDetailList>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("V_PODetailList");

            // 前置單價/前置單別/前置單號/前置序號/前置數量：測試區 50002 這個 View 多出來的
            // 欄位（PRORIL_WEB／手寫的 Data.VPoDetailList 都沒有），EF 不映射的欄位直接忽略。
            entity.Property(e => e.CopSource)
                .HasMaxLength(7)
                .IsUnicode(false)
                .HasColumnName("COP_Source");
            entity.Property(e => e.FinFlag).HasMaxLength(1);
            entity.Property(e => e.匯率).HasColumnType("numeric(20, 9)");
            entity.Property(e => e.台幣金額).HasColumnType("numeric(38, 11)");
            entity.Property(e => e.品名).HasMaxLength(120);
            entity.Property(e => e.品號).HasMaxLength(40);
            entity.Property(e => e.單位).HasMaxLength(6);
            entity.Property(e => e.單別)
                .HasMaxLength(4)
                .IsFixedLength();
            entity.Property(e => e.單號)
                .HasMaxLength(11)
                .IsFixedLength();
            entity.Property(e => e.外幣單價).HasColumnType("numeric(21, 6)");
            entity.Property(e => e.外幣金額).HasColumnType("numeric(21, 6)");
            entity.Property(e => e.幣別).HasMaxLength(4);
            entity.Property(e => e.序號)
                .HasMaxLength(4)
                .IsFixedLength();
            entity.Property(e => e.英文品名).HasMaxLength(120);
            entity.Property(e => e.英文規格).HasMaxLength(120);
            entity.Property(e => e.規格).HasMaxLength(120);
            entity.Property(e => e.訂單數量).HasColumnType("numeric(16, 3)");
            entity.Property(e => e.預交日).HasMaxLength(8);
        });

        modelBuilder.Entity<VPoList>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("V_POList");

            entity.Property(e => e.ConfirmFlag)
                .HasMaxLength(1)
                .IsUnicode(false);
            entity.Property(e => e.CopSource)
                .HasMaxLength(7)
                .IsUnicode(false)
                .HasColumnName("COP_Source");
            entity.Property(e => e.FaxNo)
                .HasMaxLength(20)
                .HasColumnName("FAX_NO");
            entity.Property(e => e.FinFlag).HasMaxLength(1);
            entity.Property(e => e.Packinglist備註)
                .HasMaxLength(255)
                .HasColumnName("PACKINGLIST備註");
            entity.Property(e => e.TelNo)
                .HasMaxLength(20)
                .HasColumnName("TEL_NO");
            entity.Property(e => e.交易條件).HasMaxLength(1);
            entity.Property(e => e.交易條件名稱).HasMaxLength(40);
            entity.Property(e => e.付款條件).HasMaxLength(16);
            entity.Property(e => e.付款檢核)
                .HasMaxLength(1)
                .IsUnicode(false);
            entity.Property(e => e.價格條件).HasMaxLength(40);
            entity.Property(e => e.匯率).HasColumnType("numeric(20, 9)");
            entity.Property(e => e.單別)
                .HasMaxLength(4)
                .IsFixedLength();
            entity.Property(e => e.單別名稱).HasMaxLength(40);
            entity.Property(e => e.單號)
                .HasMaxLength(11)
                .IsFixedLength();
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
            entity.Property(e => e.附件檔案)
                .HasMaxLength(1)
                .IsUnicode(false);
            entity.Property(e => e.預交日)
                .HasMaxLength(1)
                .IsUnicode(false);
        });

        modelBuilder.Entity<Proril.SalesIssue.Api.Data.VProductEnglishAll>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("V_Product_English_All");

            entity.Property(e => e.ProductName).HasMaxLength(120);
            entity.Property(e => e.ProductNameE)
                .HasMaxLength(120)
                .HasColumnName("ProductName_E");
            entity.Property(e => e.ProductNo).HasMaxLength(40);
            entity.Property(e => e.Specification).HasMaxLength(120);
            entity.Property(e => e.SpecificationE)
                .HasMaxLength(120)
                .HasColumnName("Specification_E");
        });

        modelBuilder.Entity<VSalesTotal>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("V_SalesTotal");

            entity.Property(e => e.CustomerNo)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.TotalAmt).HasColumnType("numeric(38, 6)");
            entity.Property(e => e.TotalQty).HasColumnType("numeric(38, 3)");
            entity.Property(e => e.Ym)
                .HasMaxLength(32)
                .HasColumnName("YM");
        });

        modelBuilder.Entity<VUnfinOrder>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("V_UnfinOrder");

            entity.Property(e => e.CopSource)
                .HasMaxLength(7)
                .IsUnicode(false)
                .HasColumnName("COP_Source");
            entity.Property(e => e.FooterFlag)
                .HasMaxLength(1)
                .IsUnicode(false);
            entity.Property(e => e.Ma002)
                .HasMaxLength(30)
                .HasColumnName("MA002");
            entity.Property(e => e.Mq002)
                .HasMaxLength(40)
                .HasColumnName("MQ002");
            entity.Property(e => e.Mv002)
                .HasMaxLength(30)
                .HasColumnName("MV002");
            entity.Property(e => e.Ntd)
                .HasColumnType("numeric(38, 11)")
                .HasColumnName("NTD");
            entity.Property(e => e.PlanNumber).HasMaxLength(20);
            entity.Property(e => e.Tc001)
                .HasMaxLength(4)
                .IsFixedLength()
                .HasColumnName("TC001");
            entity.Property(e => e.Tc002)
                .HasMaxLength(11)
                .IsFixedLength()
                .HasColumnName("TC002");
            entity.Property(e => e.Tc003)
                .HasMaxLength(8)
                .HasColumnName("TC003");
            entity.Property(e => e.Tc004)
                .HasMaxLength(10)
                .HasColumnName("TC004");
            entity.Property(e => e.Tc006)
                .HasMaxLength(10)
                .HasColumnName("TC006");
            entity.Property(e => e.Tc008)
                .HasMaxLength(4)
                .HasColumnName("TC008");
            entity.Property(e => e.Tc009)
                .HasColumnType("numeric(20, 9)")
                .HasColumnName("TC009");
            entity.Property(e => e.Tc010)
                .HasMaxLength(255)
                .HasColumnName("TC010");
            entity.Property(e => e.Tc014)
                .HasMaxLength(16)
                .HasColumnName("TC014");
            entity.Property(e => e.Tc016)
                .HasMaxLength(1)
                .HasColumnName("TC016");
            entity.Property(e => e.Tc019)
                .HasMaxLength(1)
                .HasColumnName("TC019");
            entity.Property(e => e.Td003)
                .HasMaxLength(4)
                .IsFixedLength()
                .HasColumnName("TD003");
            entity.Property(e => e.Td004)
                .HasMaxLength(40)
                .HasColumnName("TD004");
            entity.Property(e => e.Td005)
                .HasMaxLength(120)
                .HasColumnName("TD005");
            entity.Property(e => e.Td006)
                .HasMaxLength(120)
                .HasColumnName("TD006");
            entity.Property(e => e.Td008)
                .HasColumnType("numeric(16, 3)")
                .HasColumnName("TD008");
            entity.Property(e => e.Td010)
                .HasMaxLength(6)
                .HasColumnName("TD010");
            entity.Property(e => e.Td011)
                .HasColumnType("numeric(21, 6)")
                .HasColumnName("TD011");
            entity.Property(e => e.Td012)
                .HasColumnType("numeric(21, 6)")
                .HasColumnName("TD012");
            entity.Property(e => e.Td013)
                .HasMaxLength(8)
                .HasColumnName("TD013");
            entity.Property(e => e.Td024)
                .HasColumnType("numeric(16, 3)")
                .HasColumnName("TD024");
        });

        modelBuilder.Entity<VUpFileData>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("V_UpFileData");

            entity.Property(e => e.AddDate)
                .HasMaxLength(10)
                .IsFixedLength();
            entity.Property(e => e.AddTime)
                .HasMaxLength(10)
                .IsFixedLength();
            entity.Property(e => e.CompanyId)
                .HasMaxLength(20)
                .IsFixedLength()
                .HasColumnName("CompanyID");
            entity.Property(e => e.DocId)
                .HasMaxLength(10)
                .IsFixedLength()
                .HasColumnName("DocID");
            entity.Property(e => e.FileName).HasMaxLength(100);
            entity.Property(e => e.KeyFields).HasMaxLength(100);
            entity.Property(e => e.KeyValues).HasMaxLength(4000);
            entity.Property(e => e.Parent)
                .HasMaxLength(10)
                .IsFixedLength();
            entity.Property(e => e.Revision)
                .HasMaxLength(10)
                .IsFixedLength();
            entity.Property(e => e.SeqNo)
                .HasMaxLength(10)
                .IsFixedLength();
            entity.Property(e => e.Type)
                .HasMaxLength(10)
                .IsFixedLength();
            entity.Property(e => e.UserId)
                .HasMaxLength(10)
                .IsFixedLength()
                .HasColumnName("UserID");
        });

        // keyless，只給 Set<T>().FromSqlInterpolated(...) 用，不對應任何表/view
        modelBuilder.Entity<CopGetCredit>().HasNoKey();
        modelBuilder.Entity<CopGetCreditCrm>().HasNoKey();

        // prc_QueryUnfinOrder(_1) 的結果集欄位是 ID / COP_Source / Mq002 / Tc001...，
        // 其餘屬性跟 1.0 同名同型免對映，只有 Id 跟 CopSource 的實際欄名不同，
        // 照抄 ProrilWebDbContext 的 HasColumnName，少了會噴
        // 「Cannot create a DbSet for 'UnfinOrder' because this type is not included in the model」。
        modelBuilder.Entity<UnfinOrder>(entity =>
        {
            entity.HasNoKey();
            entity.Property(e => e.Id).HasColumnName("ID");
            entity.Property(e => e.CopSource).HasColumnName("COP_Source");
        });

        modelBuilder.Entity<VCopCustomer>(entity =>
        {
            entity.HasNoKey().ToView("V_COP_Customer");

            entity.Property(e => e.ContactEmail).HasMaxLength(60).HasColumnName("ContactEMail");
            entity.Property(e => e.ContactName).HasMaxLength(30);
            entity.Property(e => e.ContactPhone).HasMaxLength(20);
            entity.Property(e => e.CustomerNo).HasMaxLength(10);
            entity.Property(e => e.LongName).HasMaxLength(80);
            entity.Property(e => e.Ship).HasMaxLength(10);
            entity.Property(e => e.ShortName).HasMaxLength(30);
            entity.Property(e => e.Transport).HasMaxLength(8);
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}

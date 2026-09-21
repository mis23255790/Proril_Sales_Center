using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Proril.SalesIssue.Api.Controllers.Shared;
using Proril.SalesIssue.Api.Data;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Helpers;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.Customer;

/// <summary>
/// 客戶資料維護 + 任務(Mission)信件往來記錄 API。端點名稱與參數比照 1.0 CustomerApi。
///
/// GetCustomerList_2 是共用查詢，1.0 被報價、未結案訂單查詢、業務出貨等多個不相干模組
/// 拿去查 ERP 客戶資料，這裡只搬 API 本身。
/// </summary>
[Authorize]
public class CustomerApiController : BaseApiController
{
    // D_CustormerOrder / D_MailDetail 目前只有這支在用，還沒搬到 Proril_Sales_Center
    // （沒有既有的 ObjectsMigration 腳本），BaseApiController 不再帶 ProrilWebDbContext，
    // 這支自己單獨注入一份。VCopCustomer 已經搬過去了，打 scDb（見 GetCustomerList_2）。
    private readonly ProrilWebDbContext db;

    public CustomerApiController(
        ProrilWebDbContext db,
        SalesCenterDbContext scDb,
        JwtHelper jwtHelper,
        ILogger<CustomerApiController> logger) : base(scDb, jwtHelper, logger)
    {
        this.db = db;
    }

    // ------------------------------------------------------------------ 客戶資料

    /// <summary>客戶資料維護頁用的全量清單。</summary>
    // [HttpGet]
    // public List<MCustomer> GetCustomerList()
    //     => db.MCustomers.ToList();

    /// <summary>
    /// 依代號/全名/簡稱查 ERP 同步過來的客戶清單（V_COP_Customer）。
    ///
    /// ERP 同步字串常帶尾端空白，這裡兩邊都 trim 再比對——1.0 是直接 == 比對，
    /// 遇到帶空白的資料會查不到，屬已知既有問題（見 CLAUDE.md）。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel GetCustomerList_2(string? customerNo, string? customerName, string? customerShortName)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetCustomerList_2), $"customerNo:{customerNo}, customerName:{customerName}, customerShortName:{customerShortName}");

        var query = scDb.VCopCustomers.AsNoTracking().AsQueryable();

        if (!string.IsNullOrEmpty(customerNo))
        {
            var trimmed = customerNo.Trim();
            query = query.Where(c => c.CustomerNo != null && c.CustomerNo.Trim() == trimmed);
        }
        if (!string.IsNullOrEmpty(customerName))
        {
            var trimmed = customerName.Trim();
            query = query.Where(c => c.LongName != null && c.LongName.Trim() == trimmed);
        }
        if (!string.IsNullOrEmpty(customerShortName))
        {
            var trimmed = customerShortName.Trim();
            query = query.Where(c => c.ShortName != null && c.ShortName.Trim() == trimmed);
        }

        ca.IsSuccess = true;
        ca.Body = query.ToList();
        return ca;
    }

    // ------------------------------------------------------------------ 任務信件往來記錄

    /// <summary>單一任務(missionNo)底下的信件往來記錄，依 Sort 排序。</summary>
    // [HttpGet]
    // public CustomApiViewModel GetMailList(string missionNo)
    // {
    //     var ca = new CustomApiViewModel { IsSuccess = false };

    //     WriteStepLog(nameof(GetMailList), $"missionNo:{missionNo}");

    //     var coNo = db.DCustormerOrders.Where(o => o.MissionNo == missionNo).Select(o => o.CoNo).First();

    //     ca.IsSuccess = true;
    //     ca.Body = db.DMailDetails.AsNoTracking().Where(m => m.CoNo == coNo).OrderBy(m => m.Sort).ToList();
    //     return ca;
    // }

    /// <summary>把一筆信件記錄跟前一筆/後一筆交換排序。</summary>
    // [HttpGet]
    // public CustomApiViewModel ChangeMailSort(string mdNo, bool isUp)
    // {
    //     var ca = new CustomApiViewModel { IsSuccess = false };

    //     WriteStepLog(nameof(ChangeMailSort), $"mdNo:{mdNo}, isUp:{isUp}");

    //     var current = db.DMailDetails.First(m => m.MdNo == mdNo);
    //     var sort = current.Sort;

    //     if (sort == 1 && isUp)
    //     {
    //         ca.Message = "已至頂部";
    //         return ca;
    //     }

    //     var newSort = isUp ? sort - 1 : sort + 1;
    //     var swap = db.DMailDetails.FirstOrDefault(m => m.CoNo == current.CoNo && m.Sort == newSort);

    //     if (swap != null)
    //     {
    //         current.Sort = swap.Sort;
    //         swap.Sort = sort;
    //     }
    //     else
    //     {
    //         current.Sort = newSort;
    //     }

    //     db.SaveChanges();
    //     ca.IsSuccess = true;
    //     return ca;
    // }

    /// <summary>刪除一筆信件記錄。</summary>
    // [HttpGet]
    // public CustomApiViewModel DeleteMail(string mdNo)
    // {
    //     var ca = new CustomApiViewModel { IsSuccess = false };

    //     WriteStepLog(nameof(DeleteMail), $"mdNo:{mdNo}");

    //     var mail = db.DMailDetails.FirstOrDefault(m => m.MdNo == mdNo);
    //     if (mail is null)
    //     {
    //         ca.Message = "查無此筆資料";
    //         return ca;
    //     }

    //     db.DMailDetails.Remove(mail);
    //     db.SaveChanges();
    //     ca.IsSuccess = true;
    //     return ca;
    // }

    /// <summary>新增一筆信件記錄，接在該任務對應客戶訂單的信件清單最後。</summary>
    // [HttpGet]
    // public CustomApiViewModel AddMail([FromQuery] DMailDetailViewModel mailModel)
    // {
    //     var ca = new CustomApiViewModel { IsSuccess = false };

    //     WriteStepLog(nameof(AddMail), $"missionNo:{mailModel.MissionNo}");

    //     var coNo = db.DCustormerOrders.Where(o => o.MissionNo == mailModel.MissionNo).Select(o => o.CoNo).First();

    //     // 找目前最大 Sort +1；db.DMailDetails 是 IQueryable，LastOrDefault() 沒辦法轉譯成
    //     // SQL（EF Core 不支援），改用 OrderByDescending + FirstOrDefault 達到同樣效果。
    //     var lastSort = db.DMailDetails.Where(m => m.CoNo == coNo)
    //         .OrderByDescending(m => m.Sort)
    //         .Select(m => (int?)m.Sort)
    //         .FirstOrDefault();

    //     mailModel.MdNo = Guid.NewGuid().ToString();
    //     mailModel.CreateTime = DateTime.Now;
    //     mailModel.CoNo = coNo;
    //     mailModel.Sort = (lastSort ?? 0) + 1;

    //     db.DMailDetails.Add(mailModel);
    //     db.SaveChanges();

    //     ca.IsSuccess = true;
    //     ca.Body = mailModel;
    //     return ca;
    // }

    /// <summary>更新一筆信件記錄的內容。</summary>
    // [HttpGet]
    // public CustomApiViewModel UpdateMail([FromQuery] DMailDetail mailModel)
    // {
    //     var ca = new CustomApiViewModel { IsSuccess = false };

    //     WriteStepLog(nameof(UpdateMail), $"mdNo:{mailModel.MdNo}");

    //     var mail = db.DMailDetails.First(m => m.MdNo == mailModel.MdNo);
    //     mail.CreateTime = DateTime.Now;
    //     mail.Content = mailModel.Content;
    //     mail.MdType = mailModel.MdType;
    //     mail.Sort = mailModel.Sort;

    //     db.SaveChanges();
    //     ca.IsSuccess = true;
    //     return ca;
    // }
}

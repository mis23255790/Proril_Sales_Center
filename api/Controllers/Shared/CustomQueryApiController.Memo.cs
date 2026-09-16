using Microsoft.AspNetCore.Mvc;
using Proril.SalesIssue.Api.Data.SalesCenter;
using Proril.SalesIssue.Api.Models;

namespace Proril.SalesIssue.Api.Controllers.Shared;

/*
 * 客戶「情報」（CRM_CustomerMemo），客戶相關資訊頁的「情報」頁籤在用。
 *
 * 端點掛在 CustomQueryApiController 是照 1.0 的位置（CustomQueryApi/GetCustomMemo、
 * CustomQueryApi/SetCustomMemo）。路由是 [controller]/[action] 從 class 名稱產生的，
 * class 名不能改，所以只能用 partial 另開檔案，不能搬去別的 controller。
 *
 * CRM_CustomerMemo 已切連線到 Proril_Sales_Center（scDb）：1.0 全站 grep 過，
 * 讀寫這張表的只有這兩支，是單一擁有者。
 */
public partial class CustomQueryApiController
{
    /// <summary>
    /// 某個客戶的情報清單，join M_User 帶出作者姓名。
    ///
    /// <paramref name="customerNo"/> 是**內網**客戶代號。只帶 <paramref name="erpCustomerNo"/>
    /// （從 ERP 客戶清單點進客戶相關資訊、那個 ERP 客戶還沒建內網客戶）時一律回空清單——
    /// 情報是掛在內網客戶底下的，沒有內網客編就沒有東西可查。這是 1.0 的既有行為。
    /// </summary>
    /// <param name="wpNo">1.0 簽章裡有這個參數，但過濾邏輯整段被註解掉，沒有作用。維持原樣。</param>
    [HttpGet]
    public CustomApiViewModel GetCustomMemo(string? wpNo, string? customerNo, string? erpCustomerNo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(GetCustomMemo), $"customerNo:{customerNo}, erpCustomerNo:{erpCustomerNo}");

        var memos = scDb.CrmCustomerMemos.Where(m => m.AStatus == ActiveStatus.Active).ToList();

        if (!string.IsNullOrWhiteSpace(customerNo))
        {
            var target = customerNo.Trim();
            memos = memos.Where(m => (m.CustomerNo ?? "").Trim() == target).ToList();
        }
        else if (!string.IsNullOrWhiteSpace(erpCustomerNo))
        {
            memos.Clear();
        }

        var userNameByAccount = scDb.MUsers.ToList()
            .GroupBy(u => (u.Account ?? "").Trim())
            .ToDictionary(g => g.Key, g => g.First().UserName ?? "");

        ca.IsSuccess = true;
        ca.Body = memos
            .OrderByDescending(m => m.CreateTime)
            .Select(m =>
            {
                userNameByAccount.TryGetValue((m.Creator ?? "").Trim(), out var userName);
                return new CrmCustomerMemoViewModel(m) { CreatorName = userName ?? "" };
            })
            .ToList();
        return ca;
    }

    /// <summary>
    /// 新增或更新一筆情報。<c>Id</c> &lt;= 0 是新增，否則更新該筆。
    ///
    /// **與 1.0 的差異**：1.0 更新時用 <c>DataHelper.combineModel</c> 反射把非 null 欄位
    /// 整包蓋過去，等於前端漏送哪個欄位就保留舊值。這裡只更新畫面真的編得到的兩個欄位
    /// （MemoType / MemoDesc），其餘（CustomerNo / Creator / CreateTime）一律不動——
    /// 反射整包覆蓋很容易在加欄位時把不該改的欄位一起改掉。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel SetCustomMemo([FromQuery] CrmCustomerMemo customMemo)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(SetCustomMemo), $"id:{customMemo.Id}, customerNo:{customMemo.CustomerNo}");

        var account = GetAccountByToken();

        if (customMemo.Id <= 0)
        {
            if (string.IsNullOrWhiteSpace(customMemo.CustomerNo))
            {
                ca.Message = "新增情報需要內網客戶代號";
                return ca;
            }

            scDb.CrmCustomerMemos.Add(new CrmCustomerMemo
            {
                CustomerNo = customMemo.CustomerNo.Trim(),
                MemoType = customMemo.MemoType,
                MemoDesc = customMemo.MemoDesc,
                FileName = customMemo.FileName,
                AStatus = ActiveStatus.Active,
                Creator = account,
                CreateTime = DateTime.Now
            });
        }
        else
        {
            var target = scDb.CrmCustomerMemos
                .FirstOrDefault(m => m.Id == customMemo.Id && m.AStatus == ActiveStatus.Active);
            if (target is null)
            {
                ca.Message = $"查無情報資料 id:{customMemo.Id}";
                return ca;
            }

            target.MemoType = customMemo.MemoType;
            target.MemoDesc = customMemo.MemoDesc;
            target.Modifier = account;
            target.ModiTime = DateTime.Now;
        }

        scDb.SaveChanges();

        ca.IsSuccess = true;
        return ca;
    }

    /// <summary>
    /// 軟刪除一筆情報（aStatus 改 N）。
    ///
    /// **1.0 沒有這支**：那邊的情報建了就刪不掉，畫面上也沒有刪除按鈕。這裡補上，
    /// 因為情報是自由輸入的備註，打錯字或貼錯客戶沒有補救管道並不合理。
    /// </summary>
    [HttpGet]
    public CustomApiViewModel DeleteCustomMemo(int id)
    {
        var ca = new CustomApiViewModel { IsSuccess = false };

        WriteStepLog(nameof(DeleteCustomMemo), $"id:{id}");

        var target = scDb.CrmCustomerMemos
            .FirstOrDefault(m => m.Id == id && m.AStatus == ActiveStatus.Active);
        if (target is null)
        {
            ca.Message = $"查無情報資料 id:{id}";
            return ca;
        }

        target.AStatus = ActiveStatus.Inactive;
        target.Modifier = GetAccountByToken();
        target.ModiTime = DateTime.Now;
        scDb.SaveChanges();

        ca.IsSuccess = true;
        return ca;
    }
}

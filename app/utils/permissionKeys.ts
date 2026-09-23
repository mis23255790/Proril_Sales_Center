/**
 * 字串權限 `module.function.action`（M_PermissionDef.PermissionKey）。
 * `.view` = 進得去這個功能，其餘是功能底下的細項。
 *
 * 跟後端 api/Models/Enums.cs 的 `PermissionKeys`、資料
 * database/PermissionDefObjectsMigration.sql **三邊要一起改**。
 * 放在 utils/ 由 Nuxt 自動 import，頁面直接用 `PERMISSION_KEYS.salesSearch.xxx`。
 */
export const PERMISSION_KEYS = {
  system: {
    permissionManagerView: 'system.permissionManager.view',
    userManagerView: 'system.userManager.view',
    groupPermissionView: 'system.groupPermission.view'
  },
  salesIssue: {
    kindMaintainView: 'salesIssue.kindMaintain.view',
    processMaintainView: 'salesIssue.processMaintain.view',
    processMaintainCreateSop: 'salesIssue.processMaintain.createSop',
    processMaintainPublishSop: 'salesIssue.processMaintain.publishSop'
  },
  salesSearch: {
    mixSalesShippingView: 'salesSearch.mixSalesShipping.view',
    mixSalesShippingViewAmount: 'salesSearch.mixSalesShipping.viewAmount',
    queryUnFinishView: 'salesSearch.queryUnFinish.view',
    queryUnFinishViewAmount: 'salesSearch.queryUnFinish.viewAmount',
    customQueryView: 'salesSearch.customQuery.view',
    orderInfoVerifyView: 'salesSearch.orderInfoVerify.view',
    orderInfoVerifyViewAmount: 'salesSearch.orderInfoVerify.viewAmount'
  }
} as const

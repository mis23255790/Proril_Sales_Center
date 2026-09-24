/**
 * 權限樹節點的 PermissionKey（RBAC_Permission，單一樹自我參照）。
 * 頁面 = `module.function`（勾了就進得去），細項 = `module.function.action`。
 *
 * 跟後端 api/Models/Enums.cs 的 `PermissionKeys`、資料
 * RBAC_Permission（database/RbacObjectsMigration.sql）**三邊要一起改**。
 * 放在 utils/ 由 Nuxt 自動 import，頁面直接用 `PERMISSION_KEYS.salesSearch.xxx`。
 */
export const PERMISSION_KEYS = {
  system: {
    permissionManager: 'system.permissionManager',
    userManager: 'system.userManager'
    // system.groupPermission 已隨角色制停用（RBAC_Permission.aStatus = 'N'）
  },
  salesIssue: {
    kindMaintain: 'salesIssue.kindMaintain',
    processMaintain: 'salesIssue.processMaintain',
    processMaintainCreateSop: 'salesIssue.processMaintain.createSop',
    processMaintainPublishSop: 'salesIssue.processMaintain.publishSop'
  },
  salesSearch: {
    mixSalesShipping: 'salesSearch.mixSalesShipping',
    mixSalesShippingViewAmount: 'salesSearch.mixSalesShipping.viewAmount',
    queryUnFinish: 'salesSearch.queryUnFinish',
    queryUnFinishViewAmount: 'salesSearch.queryUnFinish.viewAmount',
    customQuery: 'salesSearch.customQuery',
    orderInfoVerify: 'salesSearch.orderInfoVerify',
    orderInfoVerifyViewAmount: 'salesSearch.orderInfoVerify.viewAmount'
  }
} as const

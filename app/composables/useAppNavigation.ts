export type AppNavItem = {
  label: string
  to: string
}

export type AppNavModule = {
  label: string
  labelEn: string
  icon: string
  to: string
  enabled: boolean
  groups: {
    groupName: string
    items: AppNavItem[]
  }[]
}

const NAV_MODULES: AppNavModule[] = [
  {
    label: '測試系統',
    labelEn: 'Test',
    icon: 'i-lucide-flask-conical',
    to: '/test',
    enabled: true,
    groups: [
      {
        groupName: '資料管理',
        items: [
          { label: '客戶資料維護', to: '/test/customer-maintain' },
          { label: '產品資料維護', to: '/test/product-maintain' },
          { label: '測試標準維護', to: '/test/test-standard-maintain' }
        ]
      },
      {
        groupName: '生管作業',
        items: [
          { label: '訂單管理', to: '/test/purchase-order-maintain' }
        ]
      },
      {
        groupName: '測試作業',
        items: [
          { label: '測試作業', to: '/test/test-work' },
          { label: '著托測試', to: '/test/test-work-dragging' },
          { label: '覆核列表', to: '/test/test-recheck' },
          { label: '測試歷史', to: '/test/test-history' },
          { label: '測試歷史(舊版)', to: '/test/test-history-old' }
        ]
      }
    ]
  },
  {
    label: '檢索系統',
    labelEn: 'Query',
    icon: 'i-lucide-search',
    to: '/query',
    enabled: true,
    groups: [
      {
        groupName: '資料檢索',
        items: [
          { label: '品號檢索', to: '/query/product-query' },
          { label: '文檔檢索', to: '/query/file-query' },
          { label: 'BOM檢索', to: '/query/bom-query' }
        ]
      }
    ]
  },
  {
    label: '品異單',
    labelEn: 'Q-Exception',
    icon: 'i-lucide-triangle-alert',
    to: '/q-exception',
    enabled: false,
    groups: [
      {
        groupName: '品質異常管理',
        items: [
          { label: '組裝品異單', to: '/q-exception/assembly' }
        ]
      }
    ]
  },
  {
    label: '供應鏈管理',
    labelEn: 'Supplier Chain',
    icon: 'i-lucide-network',
    to: '/supplier-chain',
    enabled: false,
    groups: [
      {
        groupName: '託工管理',
        items: [
          { label: '托工管理', to: '/supplier-chain/sft-schedule' },
          { label: '預設供應商', to: '/supplier-chain/sft-set-line' },
          { label: '採購管理', to: '/supplier-chain/purchase-maintain' },
          { label: '供應鏈群組維護', to: '/supplier-chain/group-line' },
          { label: '供應鏈看板', to: '/supplier-chain/line-kanban' }
        ]
      },
      {
        groupName: '用料模擬與預測',
        items: [
          { label: '詢問單用料模擬', to: '/supplier-chain/mas-product-query' },
          { label: '訂單用料模擬', to: '/supplier-chain/order-product-query' },
          { label: '銷售預測', to: '/supplier-chain/inv-forecast' }
        ]
      },
      {
        groupName: 'BOM 成本計算',
        items: [
          { label: 'BOM 成本計算', to: '/supplier-chain/bom-cost' },
          { label: '材質維護', to: '/supplier-chain/bom-cost-material-base' },
          { label: '材質時價維護', to: '/supplier-chain/bom-cost-price-set' },
          { label: '匯率維護', to: '/supplier-chain/bom-cost-currency' },
          { label: '品號時價維護', to: '/supplier-chain/bom-cost-product-set' },
          { label: '組件分類時價維護', to: '/supplier-chain/bom-cost-class-set' },
          { label: '託工依據材質報價維護', to: '/supplier-chain/bom-cost-manual-tbl' },
          { label: '關稅比例維護', to: '/supplier-chain/bom-cost-tariff' },
          { label: '製令加價設定', to: '/supplier-chain/bom-cost-cable-process' }
        ]
      }
    ]
  },
  {
    label: '包裝系統',
    labelEn: 'Package',
    icon: 'i-lucide-package',
    to: '/package',
    enabled: false,
    groups: [
      {
        groupName: '基本資料維護',
        items: [
          { label: '包裝箱維護', to: '/package/carton-maintain' },
          { label: '品號維護', to: '/package/product-maintain' },
          { label: '報關行維護', to: '/package/custom-broker' },
          { label: '特定欄位維護', to: '/package/clm-code' },
          { label: '客戶格式維護', to: '/package/customer-packing-style' }
        ]
      },
      {
        groupName: '出貨作業',
        items: [
          { label: '出貨批號維護', to: '/package/pack-maintain' },
          { label: '預覽與編輯', to: '/package/edit-and-preview' },
          { label: '包裝看板', to: '/package/dashboard' }
        ]
      }
    ]
  },
  {
    label: '組裝BOM表管理',
    labelEn: 'Assembly BOM',
    icon: 'i-lucide-git-branch',
    to: '/assembly-bom',
    enabled: false,
    groups: [
      {
        groupName: 'BOM 管理',
        items: [
          { label: 'BOM爆炸圖形單', to: '/assembly-bom/assembly-list' },
          { label: '訂單', to: '/assembly-bom/order-module' },
          { label: '成品BOM表連結', to: '/assembly-bom/product-link' }
        ]
      }
    ]
  },
  {
    label: '銘版及標籤管理',
    labelEn: 'PBS Label',
    icon: 'i-lucide-tag',
    to: '/pbs',
    enabled: false,
    groups: [
      {
        groupName: '基本資料管理',
        items: [
          { label: '項目規格維護', to: '/pbs/pbs-model' },
          { label: '型號規格維護', to: '/pbs/model' },
          { label: 'FLA電流表維護', to: '/pbs/fla-base' },
          { label: '標示基本資料維護', to: '/pbs/label-base' },
          { label: '銘版及標籤樣版維護', to: '/pbs/label-template' },
          { label: '特定欄位對照維護', to: '/pbs/special-field' },
          { label: '產品樣板設定', to: '/pbs/product-setting' },
          { label: '零件標籤樣版設定', to: '/pbs/part-template' },
          { label: '編號規則維護', to: '/pbs/auto-no-rule' },
          { label: '編號使用紀錄', to: '/pbs/auto-no-log' }
        ]
      },
      {
        groupName: '列印作業',
        items: [
          { label: '銘版及標籤列印作業', to: '/pbs/order' }
        ]
      }
    ]
  },
  {
    label: '訂單照片',
    labelEn: 'App Picture',
    icon: 'i-lucide-camera',
    to: '/app-picture',
    enabled: false,
    groups: [
      {
        groupName: '拍照作業',
        items: [
          { label: '成品拍照作業', to: '/app-picture/order-list' },
          { label: '零件拍照作業', to: '/app-picture/part-list' }
        ]
      },
      {
        groupName: '條碼列印',
        items: [
          { label: '成品條碼列印', to: '/app-picture/print-product-barcode' },
          { label: '零件條碼列印', to: '/app-picture/print-part-barcode' }
        ]
      }
    ]
  },
  {
    label: '進料檢驗系統',
    labelEn: 'Inspection',
    icon: 'i-lucide-clipboard-check',
    to: '/inspection',
    enabled: false,
    groups: [
      {
        groupName: '基本資料管理',
        items: [
          { label: '郵件與副本設定', to: '/inspection/email-setting' },
          { label: '部門人員設定', to: '/inspection/department' },
          { label: '檢驗標準維護', to: '/inspection/qc-product' }
        ]
      },
      {
        groupName: '進料品質管理',
        items: [
          { label: '進料檢驗作業', to: '/inspection/incoming-inspection' },
          { label: '進料檢驗查詢', to: '/inspection/incoming-inspection-search' },
          { label: '進料檢驗修改', to: '/inspection/incoming-inspection-edit' },
          { label: '進料品異單維護', to: '/inspection/abnormal-quality' }
        ]
      }
    ]
  },
  {
    label: '庫存管理',
    labelEn: 'Warehouse',
    icon: 'i-lucide-warehouse',
    to: '/warehouse',
    enabled: false,
    groups: [
      {
        groupName: '倉儲作業',
        items: [
          { label: '倉管', to: '/warehouse/maintain' },
          { label: '自動倉儲對帳', to: '/warehouse/compare' },
          { label: '3F 庫存查詢', to: '/warehouse/stock-list' },
          { label: '3F 庫存調整', to: '/warehouse/stock-transfer' }
        ]
      }
    ]
  }
]

export const useAppNavigation = () => {
  const enabledModules = NAV_MODULES.filter(mod => mod.enabled)

  const findItemByPath = (path: string) => {
    for (const mod of enabledModules) {
      for (const group of mod.groups) {
        const item = group.items.find(i => i.to === path)
        if (item) return { module: mod, group, item }
      }
    }
    return null
  }

  return {
    modules: enabledModules,
    findItemByPath
  }
}

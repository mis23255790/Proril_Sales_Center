// M_System：系統別主檔，topbar 用 imagePath 顯示正式區/測試區環境圖示。
export interface MSystem {
  id: number
  systemNo: number
  systemName: string
  systemType: number
  typeName?: string | null
  sort: number
  imagePath?: string | null
  href: string
  redirectHref?: string | null
}

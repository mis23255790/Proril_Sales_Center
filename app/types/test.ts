export interface ApiResponse<T = any> {
  isSuccess: boolean
  message?: string | null
  body?: T
  body2?: any
}

export interface MemoItem {
  id: number
  memo: string
  createTime: string
  userName: string
  verNo?: string
}

export interface MCustomer {
  id: number
  customerNo: string
  longName: string
  shortName: string
  ship?: string
  transport?: string
  contactName?: string
  contactPhone?: string
  contactEmail?: string
}

export interface ProductListItem {
  id: number
  productNo: string
  productName: string
  specification: string
  modelName: string
  phase: string
  frequency: string
  voltage: string
  testNo?: string
  testName?: string
  testType?: number
}

export interface DTestStandard {
  id: number
  testNo: string
  testName: string
  maxWater?: number
  maxLift?: number
  maxWatt?: number
  maxAmpere?: number
  standardWater?: number
  standardLift?: number
  standardWatt?: number
  standardAmpere?: number
  testType: number
  testPlace: string
  phase: string
  frequency: string
  voltage: string
  testRule?: string
  passFlag: string
  memo?: string
  hasNameplate: string
}

export interface DTestStandardViewModel extends DTestStandard {
  ruleKey?: string
  ruleValue?: string
}

export interface ProductDetailRow {
  title: string
  metric: string
  imperial: string
  standard: string
}

export interface ProductDetailViewModel {
  testName: string
  testNo: string
  testPlace: string
  passFlag: string
  productDetail: ProductDetailRow[]
}

export interface HWorkOrder {
  id?: number
  woNo: string
  productNo: string
  maxWater?: number
  maxLift?: number
  maxWatt?: number
  maxAmpere?: number
  standardWater?: number
  standardLift?: number
  standardWatt?: number
  standardAmpere?: number
  passFlag: string
  tester?: string
  testTime?: string
  testPlace: string
}

export interface WoByPoItem {
  poNo: string
  woNo: string
  serialNo: string
  productNo: string
  testNo: string
  modelName: string
  shippingDate?: string
  planNumber: string
  testPlace: string
  checkQty: string
  total: number
  phase: string
  frequency: string
  voltage: string
  passFlag: string
  testName: string
}

export interface ProductByWoItem {
  serialNo: string
  productNo: string
  productName: string
  frequency: string
  id: number
  modelName: string
  phase: string
  specification: string
  voltage: string
  planNumber: string
  testRule?: string
  ruleValue?: string
  ruleName?: string
}

export interface PoDetailViewModel {
  planNumber: string
  productNo: string
  qty: number
  testNo?: string
  testName?: string
  serialNosJson?: string
  testType?: number
  testTypeDescription?: string
  customerNo: string
  modelName: string
  phase: string
  frequency: string
  voltage: string
  testQty: number
  passFlag: string
  hasNameplate: string
}

// GetPoList_2 double-serializes its body via JsonConvert.SerializeObject (Newtonsoft),
// which keeps PascalCase — unlike every other endpoint's camelCase envelope.
export interface DWorkOrderRow {
  Id: number
  WoNo: string
  WoStatus: number
}

export interface PoListItem {
  PoNo: string
  PlanNumber: string
  CustomerNo: string
  ShippingDate?: string
  PoStatus?: number
  Abandoner?: string | null
  Detail_Abandoner?: string | null
  Detail_Qty?: number
  DW_ID?: number | null
  Wos?: DWorkOrderRow[]
}

export interface FailedWoItem {
  woNo: string
  serialNo: string
  testNo: string
  productNo: string
  modelName: string
  planNumber: string
  shippingDate?: string
}

export interface TestHistoryItem {
  id: number
  testTime: string
  tester: string
  woStatus: number
  poNo: string
  woNo: string
  serialNo: string
  productNo: string
  testNo: string
  modelName: string
  phase: string
  frequency: string
  voltage: string
  shippingDate?: string
  planNumber: string
  userName: string
  woStatusName: string
  testPlace: string
  passFlag: string
}

export interface HTestDataOld {
  id: number
  serialNo: string
  shippingDate?: string
  shippingDateTw?: string
  shortName: string
  checkSno: string
  productNo: string
  modelName: string
  voltage: string
  phase: string
  frequency: string
  maxWater?: number
  maxLift?: number
  maxWatt?: number
  maxAmpere?: number
  standardWater?: number
  standardLift?: number
  standardWatt?: number
  standardAmpere?: number
  tester: string
  testResults: string
  failProcess?: string
}

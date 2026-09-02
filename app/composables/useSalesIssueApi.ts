import type { ApiResponse } from '~/types/api'
import type {
  CrmCustomer,
  IssuePhraseLink,
  SalesIssue,
  SalesIssueDetail,
  WorkPhrase
} from '~/types/salesIssue'
import { DEFAULT_VER_NO } from '~/types/salesIssue'

/** 舊系統 FunctionId.ProcessMaintain，上傳 log 用。 */
export const SALES_ISSUE_FUNCTION_NO = 17

/**
 * 業務議題後端 API。
 *
 * 全部打舊 PRORIL 的 WorkProcessApi（經由 /api/proxy 轉發），
 * 不新增後端、不動資料庫。參數大小寫刻意跟後端 action 簽章一致，方便對照舊碼。
 */
export const useSalesIssueApi = () => {
  const { apiFetch } = useApi()

  const get = <T>(path: string, params?: Record<string, any>) =>
    apiFetch<ApiResponse<T>>(path, { params })

  const post = <T>(path: string, params?: Record<string, any>) =>
    apiFetch<ApiResponse<T>>(path, { method: 'POST', params })

  // ---------------------------------------------------------------- 議題列表

  /** 議題列表（編輯視角，後端會做權限過濾）。空字串 = 不篩選。 */
  const getIssueList = (filter: {
    category?: string
    customer?: string
    caption?: string
    content?: string
    startDate?: string
    endDate?: string
    pubOnly?: boolean
  } = {}) =>
    get<SalesIssue[]>('/WorkProcessApi/GetSOPList_Edit', {
      type2_phrase_name: filter.category ?? '',
      type3_phrase_name: filter.customer ?? '',
      caption_name: filter.caption ?? '',
      content_name: filter.content ?? '',
      pub_only: filter.pubOnly ?? false,
      startDate: filter.startDate ?? '',
      endDate: filter.endDate ?? ''
    })

  /**
   * 取得下一個議題編號。
   *
   * 後端沒有 max(wpno) 的 API，舊碼是把全部議題撈回來自己取最大值 —— 這裡照做。
   * 這是 read-modify-write，兩人同時新增有機會撞號；舊系統本來就這樣，先不改。
   */
  const getNextWpno = async () => {
    const res = await get<SalesIssue[]>('/WorkProcessApi/GetSOPListAll')
    const maxId = (res?.body ?? []).reduce((max, item) => {
      const n = Number.parseInt(item.wpno, 10)
      return Number.isNaN(n) ? max : Math.max(max, n)
    }, 0)
    return String(maxId + 1).padStart(6, '0')
  }

  // ---------------------------------------------------------------- 議題表頭

  const getIssue = (wpno: string) =>
    get<SalesIssue>('/WorkProcessApi/GetSOPOrder', { wpno })

  const saveIssue = (payload: {
    wpno: string
    customerNo?: string
    sopTitle?: string
    descript?: string
    /** 類別 (phraseType 02) 的 code，分號分隔 */
    type2PhraseCode?: string
    /** 職能主題 (phraseType 03) 的 code，分號分隔 */
    type3PhraseCode?: string
    phraseList?: string
    pubFlag: boolean
    finFlag: boolean
  }) =>
    get<SalesIssue>('/WorkProcessApi/SaveOrder', {
      WPNo: payload.wpno,
      CustomerNo: payload.customerNo ?? '',
      SopTitle: payload.sopTitle ?? '',
      Descript: payload.descript ?? '',
      Type2PhraseCode: payload.type2PhraseCode ?? '',
      Type3PhraseCode: payload.type3PhraseCode ?? '',
      PhraseList: payload.phraseList ?? '',
      VerNo: DEFAULT_VER_NO,
      PubDate: new Date().toISOString(),
      PubFlag: payload.pubFlag,
      FinFlag: payload.finFlag,
      aStatus: 'Y'
    })

  /** 軟刪除：把 aStatus 寫成 N。 */
  const disableIssue = (wpNo: string) =>
    get<unknown>('/WorkProcessApi/DisableOrder', { wpNo })

  // ---------------------------------------------------------------- 進度明細

  const getDetails = (wpNo: string) =>
    get<SalesIssueDetail[]>('/WorkProcessApi/GetSOPDetail', { wpNo })

  const getDetail = (wpNo: string, sNo: string | number) =>
    get<SalesIssueDetail>('/WorkProcessApi/GetSOPDetailWSNo', { wpNo, sNo })

  /**
   * 取單筆進度（編輯內文時用）。
   *
   * 名字叫 GetEditorText，但 `body` 回的是**整個 DWorkProcessDetail 物件**
   * （`ca.Body = qry[0]`），不是內文字串 —— 要自己取 `.processContent`。
   *
   * 另外這支是少數**沒有幫 SNo 補零**的 API（其他像 GetSOPDetailWSNo /
   * SaveDetail / DeleteSno 內部都會 `$"{nSno:0000}"`），所以呼叫端要自己補到 4 碼，
   * 否則 `o.Sno == SNo` 比不到，會回「查無資料」。
   */
  const getDetailContent = (wpNo: string, sNo: string | number) =>
    get<SalesIssueDetail>('/WorkProcessApi/GetEditorText', {
      WPNo: wpNo,
      SNo: String(sNo).trim().padStart(4, '0')
    })

  /**
   * 存一則進度。
   *
   * 必須用 multipart POST：內文含 base64 圖片時 query string 會超過長度上限，
   * 舊碼註解寫的「controller 收到是 null」就是這個原因。
   */
  const saveDetail = (payload: {
    wpno: string
    sno: string | number
    processCaption?: string
    processCaption2?: string
    processContent?: string
    worker?: string
    uploadFile?: string
    renameFile?: string
  }) => {
    const form = new FormData()
    form.append('WPNo', payload.wpno)
    form.append('SNo', String(payload.sno))
    form.append('ProcessCaption', payload.processCaption ?? '')
    form.append('ProcessCaption2', payload.processCaption2 ?? '')
    form.append('ProcessContent', payload.processContent ?? '')
    form.append('Worker', payload.worker ?? '')
    form.append('UploadFile', payload.uploadFile ?? '')
    form.append('RenameFile', payload.renameFile ?? '')
    form.append('aStatus', 'Y')

    return apiFetch<ApiResponse<SalesIssueDetail>>('/WorkProcessApi/SaveDetail', {
      method: 'POST',
      body: form
    })
  }

  const deleteDetail = (wpNo: string, sNo: string | number) =>
    post<unknown>('/WorkProcessApi/DeleteSno', { wpNo, sNo })

  /** 取得議題目前最大的 sno，新增進度時用來接號。 */
  const getMaxSno = async (wpNo: string) => {
    const res = await getDetails(wpNo)
    return (res?.body ?? []).reduce((max, item) => {
      const n = Number.parseInt(item.sno, 10)
      return Number.isNaN(n) ? max : Math.max(max, n)
    }, 0)
  }

  // ---------------------------------------------------------------- 關鍵字

  /** 依 phraseType 取關鍵字主檔（後端只回 aStatus = Y）。 */
  const getPhrases = (typeCode: string) =>
    get<WorkPhrase[]>('/WorkProcessApi/GetKindList', { typeCode })

  const savePhrase = (payload: {
    phraseType: string
    phraseCode: string
    phraseName: string
    pubFlag?: boolean
    principal?: string
    potentialCustom?: string
  }) =>
    get<unknown>('/WorkProcessApi/SaveKindData', {
      phraseType: payload.phraseType,
      phraseCode: payload.phraseCode,
      phraseName: payload.phraseName,
      pubFlag: payload.pubFlag ?? false,
      principal: payload.principal ?? '',
      PotentialCustom: payload.potentialCustom ?? ''
    })

  /** 這張議題掛了哪些關鍵字。 */
  const getIssuePhrases = (wpno: string) =>
    get<IssuePhraseLink[]>('/WorkProcessApi/GetWPOrderPhrase', { wpno })

  /** 整批覆寫議題的關鍵字。三個 list 用分號分隔且必須同索引對齊。 */
  const setIssuePhrases = (
    wpno: string,
    phrases: { phraseType: string, phraseCode: string, phraseName: string }[]
  ) =>
    get<unknown>('/WorkProcessApi/SetWPOrderPhrase', {
      wpno,
      strPhraseTypeList: phrases.map(p => p.phraseType).join(';'),
      strPhraseCodeList: phrases.map(p => p.phraseCode).join(';'),
      strPhraseNameList: phrases.map(p => p.phraseName).join(';')
    })

  /** 這張議題掛了哪些客戶。 */
  const getIssueCustomers = (wpno: string) =>
    get<any[]>('/WorkProcessApi/GetWPOrderCustom', { wpno })

  const setIssueCustomers = (wpno: string, customerNos: string[]) =>
    get<unknown>('/WorkProcessApi/SetWPOrderCustom', {
      wpno,
      strCustomNoList: customerNos.join(';'),
      strCustomNo2List: ''
    })

  const getCustomers = () =>
    get<CrmCustomer[]>('/CustomQueryApi/GetCustom', {
      customNo: '',
      erpCustomNo: '',
      includeErpCustom: true
    })

  // ---------------------------------------------------------------- 權限

  /**
   * 讓所有人可編輯這張議題。
   *
   * 000000 是舊系統的「全體使用者」保留帳號，每次存檔後都要補寫一次，
   * 否則 GetSOPList_Edit 的權限過濾會把這張議題擋掉，只有 admin 看得到。
   *
   * `strAccountList` 後端是用 `JsonConvert.DeserializeObject<List<string>>` 解的，
   * **必須送 JSON 陣列字串**。送成 '000000' 會在後端丟例外、回 isSuccess: false，
   * 而前端不看這個結果，症狀就是「存檔成功但列表看不到」。
   */
  const grantAllUsersEdit = (wpNo: string) =>
    get<unknown>('/WorkProcessApi/SetWPNoPermissionEdit', {
      wpNo,
      strAccountList: JSON.stringify(['000000'])
    })

  return {
    getIssueList,
    getNextWpno,
    getIssue,
    saveIssue,
    disableIssue,
    getDetails,
    getDetail,
    getDetailContent,
    saveDetail,
    deleteDetail,
    getMaxSno,
    getPhrases,
    savePhrase,
    getIssuePhrases,
    setIssuePhrases,
    getIssueCustomers,
    setIssueCustomers,
    getCustomers,
    grantAllUsersEdit
  }
}

import type { ApiResponse } from '~/types/api'
import type { IssueAttachment } from '~/types/salesIssue'
import { DEFAULT_VER_NO } from '~/types/salesIssue'
import { SALES_ISSUE_FUNCTION_NO } from '~/composables/useSalesIssueApi'

/**
 * 附件的中間層目錄。
 *
 * 後端 FormatHelper.getDcuMiddleLayer(wpNo) = floor(wpNo * 2 / 1000)，
 * 用來避免單一目錄塞太多檔。**一定要用 wpNo 算**，不能用別的數字 ——
 * EnumTempUploadAttach / UpdateDBAttachFile 兩支後端 API 都是用 wpNo 去組路徑，
 * 上傳時算出不同的層級，檔案就會落在後端找不到的地方。
 *
 * （舊 JS `onClickAddAttach()` 是用「目前附件筆數」算的，wpNo < 500 時剛好都是 0
 * 所以看不出來，wpNo 到 500 以上就會壞。這裡修掉。）
 */
export const dcuMiddleLayer = (wpNo: string) => {
  const n = Number.parseInt(wpNo, 10)
  const layer = Number.isNaN(n) ? 0 : Math.floor((n * 2) / 1000)
  return String(layer).padStart(5, '0')
}

/**
 * 業務議題附件。
 *
 * 後端把一則進度的所有附件壓成一個 zip 存在 share root，
 * 畫面要編輯時得先解壓到使用者的 temp 目錄，改完再壓回去。流程固定是：
 *
 *   1. ClearSOPTempPath   清掉自己的 temp 目錄
 *   2. UnzipAttachFileList 把 zip 解到 temp（檔名還原成原始檔名）
 *   3. SaveByFileName      新選的檔案上傳到同一個 temp 目錄
 *   4. UpdateDBAttachFile  把最終檔名清單寫回 D_WorkProcessDetail
 *   5. ZipAttachFileList   temp 目錄重新壓成 zip
 *
 * 4 與 5 的順序取決於這則進度存不存在（見 commit()）。
 */
export const useIssueAttachments = () => {
  const { apiFetch } = useApi()
  const { account } = useAuthAccount()

  const get = <T>(path: string, params?: Record<string, any>) =>
    apiFetch<ApiResponse<T>>(path, { params })

  /** 分號分隔字串轉陣列，順手濾掉空值。 */
  const splitNames = (value?: string | null) =>
    (value ?? '').split(';').map(s => s.trim()).filter(Boolean)

  /** DB 存的 uploadFile / renameFile 是同索引對齊的兩串分號字串。 */
  const parseAttachments = (uploadFile?: string | null, renameFile?: string | null): IssueAttachment[] => {
    const uploads = splitNames(uploadFile)
    const renames = splitNames(renameFile)
    return uploads.map((name, i) => ({ uploadFile: name, renameFile: renames[i] }))
  }

  const tempDir = (wpNo: string, sNo: string | number) =>
    `/temp/${account.value}/Doc_SOP/${dcuMiddleLayer(wpNo)}/${sNo}`

  /**
   * 步驟 1 + 2：把這則進度的附件解壓到 temp 目錄備用。
   *
   * `extSubPath` **必須傳 sNo**，不能傳空字串：它決定檔案解到
   * `Doc_SOP/{dcu}/{extSubPath}`，而後面的 EnumTempUploadAttach /
   * ZipAttachFileList / UpdateDBAttachFile 都是去 `Doc_SOP/{dcu}/{sNo}` 找。
   * 傳空字串的話既有附件會解到上一層，重壓時後端會回「原始檔案不存在」，
   * 結果就是編輯一則有附件的進度、加一個新檔，舊附件全部消失。
   */
  const prepareTemp = async (wpNo: string, sNo: string | number) => {
    try {
      await get('/WorkProcessApi/ClearSOPTempPath', { wpNo, edit_path: String(sNo) })
      await get('/WorkProcessApi/UnzipAttachFileList', {
        wpNo,
        sNo,
        verNo: DEFAULT_VER_NO,
        extSubPath: String(sNo)
      })
    } catch (err) {
      // 新建的進度還沒有 zip，解壓失敗是正常的，不要打斷編輯流程。
      console.log('useIssueAttachments prepareTemp -->', err)
    }
  }

  /** 步驟 3：上傳一個檔案到 temp 目錄。 */
  const uploadTemp = async (wpNo: string, sNo: string | number, file: File) => {
    const form = new FormData()
    form.append('files', file)
    form.append('saveByFileName', `${tempDir(wpNo, sNo)}/${file.name}`)
    form.append('linkFuncNo', String(SALES_ISSUE_FUNCTION_NO))
    form.append('linkNo', '0')

    return apiFetch<ApiResponse<unknown>>('/UploadApi/SaveByFileName', {
      method: 'POST',
      body: form
    })
  }

  /** 從 temp 目錄刪掉一個檔案（尚未 commit 前的刪除）。 */
  const deleteTemp = (wpNo: string, sNo: string | number, uploadFile: string) =>
    get('/WorkProcessApi/DelDetailAttach', {
      wpNo,
      sNo,
      edit_path: String(sNo),
      uploadFile
    })

  /**
   * 步驟 4 + 5：把 temp 目錄的檔案清單落地。
   *
   * detailId > 0（既有進度）→ 先 Zip 再寫 DB：zip 檔名要用 detailId，已經知道了。
   * detailId <= 0（新進度）→ 先寫 DB 拿回 detailId，才有辦法組 zip 檔名。
   *
   * 兩條路都必須「Zip 與寫 DB 用同一份、同順序的檔名清單」——
   * renameFile 是後端依序重編的（1.pdf、2.docx…），順序一亂就對不回原始檔名。
   */
  const commit = async (
    wpNo: string,
    sNo: string | number,
    detailId: number,
    fileNames: string[]
  ) => {
    const strUploadFiles = JSON.stringify(fileNames)
    const editPath = String(sNo)

    if (detailId > 0) {
      await get('/WorkProcessApi/ZipAttachFileList', {
        wpNo,
        sNo,
        verNo: DEFAULT_VER_NO,
        edit_path: editPath,
        strUploadFiles,
        zip_file_name_woV: `${wpNo}.${detailId}`
      })
      await get('/WorkProcessApi/UpdateDBAttachFile', {
        wpNo,
        sNo,
        verNo: DEFAULT_VER_NO,
        edit_path: editPath,
        strUploadFiles
      })
      return detailId
    }

    const res = await get<{ id: number }>('/WorkProcessApi/UpdateDBAttachFile', {
      wpNo,
      sNo,
      verNo: DEFAULT_VER_NO,
      edit_path: editPath,
      strUploadFiles
    })
    const newId = res?.body?.id ?? 0
    await get('/WorkProcessApi/ZipAttachFileList', {
      wpNo,
      sNo,
      verNo: DEFAULT_VER_NO,
      edit_path: editPath,
      strUploadFiles,
      zip_file_name_woV: `${wpNo}.${newId}`
    })
    return newId
  }

  /**
   * 下載一個附件。
   *
   * GetDownloadUrl 會順手把 zip 解到 temp，然後回傳 /ShareRoot/... 這種
   * 相對於「.NET 站台根目錄」的路徑（不在 /api 底下）。
   * 直接開會變成跨網域，所以走自家 Nitro 的 /api/download 轉一手，
   * 順便補上 Content-Disposition 讓瀏覽器真的存檔而不是內嵌預覽。
   */
  const download = async (wpNo: string, sNo: string | number, uploadFile: string) => {
    const res = await get<string>('/WorkProcessApi/GetDownloadUrl', { wpNo, sNo, uploadFile })
    if (!res?.isSuccess || !res.body) {
      throw new Error(res?.message || `取得 ${uploadFile} 下載網址失敗`)
    }
    const url = `/api/download?path=${encodeURIComponent(res.body)}&name=${encodeURIComponent(uploadFile)}`
    window.open(url, '_blank')
  }

  return {
    parseAttachments,
    splitNames,
    prepareTemp,
    uploadTemp,
    deleteTemp,
    commit,
    download
  }
}

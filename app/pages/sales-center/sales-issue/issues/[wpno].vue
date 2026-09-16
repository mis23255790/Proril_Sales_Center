<script setup lang="ts">
/**
 * 議題編輯。
 *
 * 路由參數 wpno 為 "new" 時是新增；存檔時才向後端要號並改寫網址，
 * 這樣重新整理／分享連結拿到的都是真正的議題編號。
 */
import type { CrmCustomer, SalesIssue, SalesIssueDetail, WorkPhrase } from '~/types/salesIssue'
import { NEW_ISSUE_WPNO, PHRASE_TYPE } from '~/types/salesIssue'
import ConfirmDialog from '~/components/common/ConfirmDialog.vue'

const route = useRoute()
const api = useSalesIssueApi()
const toast = useToast()
const overlay = useOverlay()
const { breadcrumbFor, appPath } = useAppNavigation()

const routeWpno = computed(() => String(route.params.wpno ?? ''))
const isNew = computed(() => routeWpno.value === 'new')

/** 尚未存檔的新議題用哨兵值，存檔後換成真正的編號。 */
const wpno = ref(isNew.value ? NEW_ISSUE_WPNO : padWpno(routeWpno.value))

const loading = ref(false)
const saving = ref(false)
const issue = ref<SalesIssue | null>(null)
const details = ref<SalesIssueDetail[]>([])
const categories = ref<WorkPhrase[]>([])
const customers = ref<CrmCustomer[]>([])

const form = reactive({
  sopTitle: '',
  descript: '',
  pubFlag: true,
  finFlag: false
})

/** 已選的類別（phraseType 02）的 phraseCode。 */
const selectedCategoryCodes = ref<string[]>([])

/**
 * 已選的客戶別（customerNo），單選，最後只會保留一筆。
 * D_WorkProcessCustomer／1.0 的「選擇客戶別」雖然支援一筆議題掛多個客戶，
 * 但這是 2.0 刻意的產品決策，不比照 1.0：存檔時只送一筆給 SetWPOrderCustom，
 * 原本掛多個客戶的舊議題存檔後其餘客戶會被移除。
 */
const selectedCustomerNo = ref('')

/**
 * 基本資料欄可左右收合成窄邊欄，讓進度紀錄拿到更多寬度；只在 xl 兩欄並排時有意義，
 * 手機／平板單欄堆疊時欄位一律照常顯示（見 template 的 xl: 條件 class）。
 */
const basicInfoExpanded = ref(true)

useSeoMeta({
  title: () => `${form.sopTitle || '新增議題'} · 業務議題 · PRORIL 業務中心`
})

// ------------------------------------------------------------------ 讀取

const loadMasters = async () => {
  try {
    const [phraseRes, customerRes] = await Promise.all([
      api.getPhrases(PHRASE_TYPE.CATEGORY),
      api.getCustomers()
    ])
    categories.value = phraseRes?.isSuccess ? (phraseRes.body ?? []) : []
    customers.value = customerRes?.isSuccess ? (customerRes.body ?? []) : []
  } catch (err) {
    console.log('issue editor loadMasters failed -->', err)
  }
}

const loadDetails = async () => {
  try {
    const res = await api.getDetails(wpno.value)
    details.value = res?.isSuccess ? (res.body ?? []) : []
  } catch (err) {
    console.log('issue editor loadDetails failed -->', err)
    details.value = []
  }
}

const loadIssue = async () => {
  if (wpno.value === NEW_ISSUE_WPNO) return

  loading.value = true
  try {
    const res = await api.getIssue(wpno.value)
    if (!res?.isSuccess || !res.body) {
      toast.add({ title: '找不到這筆議題', description: res?.message ?? '', color: 'error' })
      return
    }

    issue.value = res.body
    form.sopTitle = res.body.sopTitle ?? ''
    form.descript = res.body.descript ?? ''
    form.pubFlag = res.body.pubFlag ?? true
    form.finFlag = res.body.finFlag ?? false

    selectedCategoryCodes.value = parsePhraseTriples(res.body)
      .filter(p => p.phraseType === PHRASE_TYPE.CATEGORY)
      .map(p => p.phraseCode)

    // 單選，但舊資料可能在 D_WorkProcessCustomer 掛了不只一個客戶；
    // GetSOPOrder 的 customerNo 對早期資料常是空的，兩邊都要看，取第一個當顯示值即可。
    const linkRes = await api.getIssueCustomers(wpno.value)
    const linkedNos = (linkRes?.body ?? [])
      .map(c => String(c?.customerNo ?? '').trim())
      .filter(Boolean)
    const headerNo = (res.body.customerNo ?? '').trim()
    selectedCustomerNo.value = headerNo || linkedNos[0] || ''

    await loadDetails()
  } catch (err) {
    console.log('issue editor loadIssue failed -->', err)
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await loadMasters()
  await loadIssue()
})

// ------------------------------------------------------------------ 衍生

/** 客戶下拉選項，比照 1.0「選擇客戶別」清單的欄位組合（代碼／ERP 代碼／簡稱／全名）。 */
const customerOptions = computed(() =>
  customers.value.map(c => ({
    label: `${c.customerNo}(${(c.erpcustomerNo ?? '').trim()})-${c.shortName || c.customerNo}${c.longName ? ` · ${c.longName}` : ''}`,
    value: String(c.customerNo ?? '').trim()
  }))
)

const categoryOptions = computed(() =>
  categories.value.map(c => ({ label: c.phraseName, value: c.phraseCode }))
)

const selectedCategoryNames = computed(() =>
  selectedCategoryCodes.value
    .map(code => categories.value.find(c => c.phraseCode === code)?.phraseName)
    .filter((n): n is string => Boolean(n))
)

const selectedCustomerName = computed(() =>
  customers.value.find(c => String(c.customerNo ?? '').trim() === selectedCustomerNo.value)?.shortName ?? ''
)

const customerNamesDisplay = computed(() => selectedCustomerName.value || issue.value?.customerName || '')

/**
 * 進度由新到舊。
 *
 * 後端 GetSOPDetail 是 `OrderBy(ProcessCaption)`（升冪），因為標題慣例上放日期。
 * 進度看板要看最新的，所以前端反過來排；標題相同時再用 sno 分先後。
 */
const sortedDetails = computed(() =>
  [...details.value].sort((a, b) => {
    const byCaption = String(b.processCaption ?? '').localeCompare(String(a.processCaption ?? ''))
    if (byCaption !== 0) return byCaption
    return Number.parseInt(b.sno, 10) - Number.parseInt(a.sno, 10)
  })
)

const nextSno = computed(() =>
  details.value.reduce((max, d) => {
    const n = Number.parseInt(d.sno, 10)
    return Number.isNaN(n) ? max : Math.max(max, n)
  }, 0) + 1
)

const attachmentsOf = (detail: SalesIssueDetail) => splitList(detail.uploadFile)

// ------------------------------------------------------------------ 存檔

const save = async () => {
  if (!form.sopTitle.trim()) {
    toast.add({ title: '請填寫議題主題', color: 'warning' })
    return
  }

  saving.value = true
  try {
    const creating = wpno.value === NEW_ISSUE_WPNO
    const targetWpno = creating ? await api.getNextWpno() : wpno.value

    const res = await api.saveIssue({
      wpno: targetWpno,
      customerNo: selectedCustomerNo.value,
      sopTitle: form.sopTitle.trim(),
      descript: form.descript,
      type2PhraseCode: selectedCategoryCodes.value.join(';'),
      type3PhraseCode: '',
      phraseList: selectedCategoryNames.value.join(';'),
      pubFlag: form.pubFlag,
      finFlag: form.finFlag
    })

    if (!res?.isSuccess) {
      toast.add({ title: '存檔失敗', description: res?.message ?? '', color: 'error' })
      return
    }

    wpno.value = targetWpno

    // 這三步在舊系統是分開的 API，缺一項就會出現「存了但列表看不到 / 沒有客戶別」。
    await api.grantAllUsersEdit(targetWpno)
    await api.setIssuePhrases(
      targetWpno,
      selectedCategoryCodes.value.map(code => ({
        phraseType: PHRASE_TYPE.CATEGORY,
        phraseCode: code,
        phraseName: categories.value.find(c => c.phraseCode === code)?.phraseName ?? ''
      }))
    )
    await api.setIssueCustomers(targetWpno, selectedCustomerNo.value ? [selectedCustomerNo.value] : [])

    toast.add({ title: '議題已儲存', color: 'success' })

    if (creating) {
      await navigateTo(appPath(`sales-issue/issues/${targetWpno}`), { replace: true })
    }
    await loadIssue()
  } catch (err) {
    console.log('issue editor save failed -->', err)
    toast.add({ title: '存檔失敗', color: 'error' })
  } finally {
    saving.value = false
  }
}

// ------------------------------------------------------------------ 進度

const progressOpen = ref(false)
const editingDetail = ref<SalesIssueDetail | null>(null)
const expanded = ref<Record<string, boolean>>({})

const toggleExpanded = (sno: string) => {
  expanded.value[sno] = !expanded.value[sno]
}

const requireSavedIssue = () => {
  if (wpno.value !== NEW_ISSUE_WPNO) return true
  toast.add({
    title: '請先儲存議題',
    description: '進度要掛在議題底下，議題還沒有編號。',
    color: 'warning'
  })
  return false
}

const addProgress = () => {
  if (!requireSavedIssue()) return
  editingDetail.value = null
  progressOpen.value = true
}

const editProgress = (detail: SalesIssueDetail) => {
  editingDetail.value = detail
  progressOpen.value = true
}

const confirmModal = overlay.create(ConfirmDialog)

const removeProgress = async (detail: SalesIssueDetail) => {
  try {
    const confirmed = await confirmModal.open({
      title: '刪除進度',
      description: `確定要刪除「${detail.processCaption || `#${detail.sno}`}」這則進度？`,
      confirmLabel: '刪除',
      confirmColor: 'error'
    }).result

    if (!confirmed) return

    const res = await api.deleteDetail(wpno.value, detail.sno)
    if (!res?.isSuccess) {
      toast.add({ title: '刪除失敗', description: res?.message ?? '', color: 'error' })
      return
    }
    toast.add({ title: '已刪除', color: 'success' })
    await loadDetails()
  } catch (err) {
    console.log('issue editor removeProgress failed -->', err)
    toast.add({ title: '刪除失敗', color: 'error' })
  }
}

const attachments = useIssueAttachments()

const downloadAttachment = async (detail: SalesIssueDetail, name: string) => {
  try {
    await attachments.download(wpno.value, detail.sno, name)
  } catch (err) {
    console.log('issue editor downloadAttachment failed -->', err)
    toast.add({ title: '下載失敗', description: String(err), color: 'error' })
  }
}
</script>

<template>
  <div class="flex flex-col xl:h-full">
    <FullPageLoading :show="loading" />

    <div class="sticky top-0 z-20 mb-4 flex flex-wrap items-center justify-between gap-3 bg-white pb-2 dark:bg-white xl:shrink-0">
      <UBreadcrumb :items="breadcrumbFor(appPath('sales-issue/issues'), isNew ? '新增議題' : `#${wpno}`)" />

      <UButton icon="i-lucide-arrow-left" color="neutral" variant="outline" :to="appPath('sales-issue/issues')">
        回議題列表
      </UButton>
    </div>

    <div class="flex flex-col gap-5 xl:min-h-0 xl:flex-1 xl:flex-row">
      <!-- 基本資料：xl 可左右收合成窄邊欄，讓進度紀錄多拿一點寬度 -->
      <div
        class="xl:h-full xl:min-h-0 xl:shrink-0 xl:overflow-y-auto xl:transition-[width] xl:duration-200"
        :class="basicInfoExpanded ? 'xl:w-[22rem]' : 'xl:w-16'"
      >
        <div class="rounded-lg border border-default p-4">
          <div
            class="flex items-center gap-2 text-sm font-semibold text-highlighted"
            :class="!basicInfoExpanded && 'xl:flex-col xl:gap-3'"
          >
            <div class="flex min-w-0 items-center gap-2" :class="!basicInfoExpanded && 'xl:hidden'">
              <UIcon name="i-lucide-file-text" class="size-4 shrink-0 text-primary" />
              <span class="truncate">基本資料</span>
            </div>
            <UIcon
              v-if="!basicInfoExpanded"
              name="i-lucide-file-text"
              class="hidden size-4 shrink-0 text-primary xl:block"
            />
            <UButton
              :icon="basicInfoExpanded ? 'i-lucide-panel-left-close' : 'i-lucide-panel-left-open'"
              color="neutral"
              variant="ghost"
              size="xs"
              class="hidden shrink-0 xl:inline-flex"
              :class="basicInfoExpanded && 'ml-auto'"
              :title="basicInfoExpanded ? '收合' : '展開'"
              @click="basicInfoExpanded = !basicInfoExpanded"
            />
          </div>

          <div class="mt-4 flex flex-col gap-4" :class="!basicInfoExpanded && 'xl:hidden'">
            <UFormField label="主題" required>
              <UInput v-model="form.sopTitle" placeholder="議題主題" class="w-full" />
            </UFormField>

            <UFormField label="客戶別">
              <USelectMenu
                v-model="selectedCustomerNo"
                :items="customerOptions"
                value-key="value"
                label-key="label"
                placeholder="選擇客戶"
                class="w-full"
              />
              <div v-if="selectedCustomerName" class="mt-2 flex flex-wrap gap-1">
                <UBadge color="neutral" variant="subtle" size="sm">
                  {{ selectedCustomerName }}
                </UBadge>
              </div>
            </UFormField>

            <UFormField label="類別" hint="可複選">
              <USelectMenu
                v-model="selectedCategoryCodes"
                :items="categoryOptions"
                value-key="value"
                label-key="label"
                multiple
                placeholder="選擇類別"
                class="w-full"
              />
              <div v-if="selectedCategoryNames.length" class="mt-2 flex flex-wrap gap-1">
                <UBadge v-for="name in selectedCategoryNames" :key="name" color="neutral" variant="subtle" size="sm">
                  {{ name }}
                </UBadge>
              </div>
            </UFormField>

            <UFormField label="最新進度" hint="會顯示在議題列表上">
              <UTextarea v-model="form.descript" :rows="5" placeholder="一句話說明目前狀況" class="w-full" />
            </UFormField>

            <div class="flex flex-col gap-2 rounded-md bg-elevated/50 p-3">
              <UCheckbox v-model="form.pubFlag" label="公開" description="讓有權限的同仁在議題列表看到" />
              <UCheckbox v-model="form.finFlag" label="結案" description="結案後會移到「結案」頁籤" />
            </div>
          </div>
        </div>
      </div>

      <!-- 進度時間軸 -->
      <div class="min-w-0 xl:flex xl:h-full xl:min-h-0 xl:flex-1 xl:flex-col">
        <div class="mb-3 flex items-center justify-between gap-2 xl:shrink-0">
          <h2 class="flex items-center gap-2 text-sm font-semibold text-highlighted">
            <UIcon name="i-lucide-history" class="size-4 text-primary" />
            進度紀錄
            <UBadge color="neutral" variant="subtle" size="sm">
              {{ details.length }}
            </UBadge>
          </h2>
          <UButton icon="i-lucide-plus" size="sm" @click="addProgress">
            新增進度
          </UButton>
        </div>

        <div class="xl:min-h-0 xl:flex-1 xl:overflow-x-hidden xl:overflow-y-auto">
          <div
            v-if="!sortedDetails.length"
            class="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-default py-16 text-center xl:h-full"
          >
            <UIcon name="i-lucide-message-square-plus" class="size-8 text-dimmed" />
            <p class="font-medium text-highlighted">
              還沒有任何進度
            </p>
            <p class="text-sm text-muted">
              新增第一則進度，記錄與客戶的往來內容。
            </p>
          </div>

          <div v-else class="flex flex-col gap-3">
            <div
              v-for="detail in sortedDetails"
              :key="detail.sno"
              class="overflow-hidden rounded-lg border border-default"
            >
              <div class="flex flex-wrap items-center gap-2 border-b border-default bg-elevated/40 px-4 py-2.5">
                <UIcon name="i-lucide-calendar-days" class="size-4 shrink-0 text-primary" />
                <span class="font-medium text-highlighted">
                  {{ detail.processCaption || `#${detail.sno}` }}
                </span>

                <span class="ml-auto text-xs text-muted">
                  {{ detail.modifierName || detail.creatorName || '' }}
                  {{ toDateTimeString(detail.modiTime || detail.createTime) }}
                </span>

                <UButton
                  :icon="expanded[detail.sno] ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
                  color="neutral"
                  variant="ghost"
                  size="xs"
                  :title="expanded[detail.sno] ? '收合' : '展開'"
                  @click="toggleExpanded(detail.sno)"
                />
                <UButton icon="i-lucide-pencil" color="primary" variant="ghost" size="xs" title="編輯" @click="editProgress(detail)" />
                <UButton icon="i-lucide-trash-2" color="error" variant="ghost" size="xs" title="刪除" @click="removeProgress(detail)" />
              </div>

              <div class="bg-white px-4 py-3">
                <!-- 收合時裁掉高度並加漸層，讓使用者看得出來下面還有內容 -->
                <div class="relative">
                  <IssueContentView
                    :html="detail.processContent"
                    :class="expanded[detail.sno] ? '' : 'max-h-40 overflow-hidden'"
                    empty-text="（無內容）"
                  />
                  <button
                    v-if="!expanded[detail.sno]"
                    type="button"
                    class="absolute inset-x-0 bottom-0 flex h-12 items-end justify-center bg-gradient-to-t from-white to-transparent pb-0.5 text-xs text-gray-500 hover:text-gray-800"
                    @click="toggleExpanded(detail.sno)"
                  >
                    展開全文
                  </button>
                </div>

                <div v-if="attachmentsOf(detail).length" class="mt-1 flex flex-wrap gap-2 border-t border-gray-100 pt-1">
                  <UButton
                    v-for="name in attachmentsOf(detail)"
                    :key="name"
                    icon="i-lucide-paperclip"
                    color="neutral"
                    variant="soft"
                    size="xs"
                    @click="downloadAttachment(detail, name)"
                  >
                    {{ name }}
                  </UButton>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!--
      存檔列：改用 sticky 而不是 fixed。fixed 是相對整個視窗定位，會蓋過側欄，
      跟 footer／body 左邊界對不齊（footer 左邊會有側欄分隔線，這條卻沒有）；
      sticky 是相對頁面自己的正常排版流，寬度自然跟頁面內容（body 範圍）一致，
      也不用再算 bottom-8 去閃開 layout 的 footer，貼齊 body 底部剛好就在 footer 上緣。
    -->
    <div class="sticky bottom-0 z-40 shrink-0 border-t border-default bg-default/95 px-4 py-2 backdrop-blur">
      <div class="mx-auto flex max-w-7xl items-center justify-between gap-3">
        <p class="truncate">
          <span v-if="customerNamesDisplay" class="text-sm text-muted">{{ customerNamesDisplay }} · </span>
          <span class="text-base font-semibold text-highlighted">{{ form.sopTitle || '尚未命名的議題' }}</span>
        </p>
        <UButton icon="i-lucide-save" size="md" :loading="saving" @click="save">
          儲存議題
        </UButton>
      </div>
    </div>

    <IssueProgressModal
      v-model:open="progressOpen"
      :wpno="wpno"
      :issue-title="form.sopTitle"
      :detail="editingDetail"
      :next-sno="nextSno"
      @saved="loadDetails"
    />
  </div>
</template>

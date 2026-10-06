/**
 * 稽核紀錄的顯示：動作名稱／顏色，以及把 Detail JSON 整理成人看得懂的幾行字。
 *
 * Detail 的形狀由後端各寫入點決定（api/Controllers/Shared/MainApiController*.cs 的 WriteAudit）：
 *   - 登入：{ method, reason }
 *   - 新增：{ after: {...} }；刪除：{ before: {...} }；修改：{ before, after }（只放有變的那幾組）
 *   - 增減：{ roles | members | permissions: { added: [], removed: [] } }，成員異動另帶 roleName
 * 認不得的形狀就退回原始 JSON，不會壞掉。
 */

export const AUDIT_ACTIONS: Record<string, { label: string, color: 'success' | 'error' | 'primary' | 'warning' | 'neutral' }> = {
  LOGIN: { label: '登入', color: 'success' },
  LOGIN_FAIL: { label: '登入失敗', color: 'error' },
  CREATE: { label: '新增', color: 'primary' },
  UPDATE: { label: '修改', color: 'warning' },
  DELETE: { label: '刪除', color: 'error' },
  RESET_PASSWORD: { label: '密碼重置', color: 'neutral' },
  UNLOCK: { label: '解除鎖定', color: 'neutral' }
}

export const auditActionLabel = (action: string) => AUDIT_ACTIONS[action]?.label ?? action

const FIELD_LABELS: Record<string, string> = {
  userName: '姓名',
  isEnable: '啟用',
  roleCode: '角色代碼',
  roleName: '角色名稱',
  description: '說明',
  roles: '角色',
  permissions: '權限',
  members: '成員',
  method: '方式',
  reason: '原因'
}

const fieldLabel = (key: string) => FIELD_LABELS[key] ?? key

type Labeler = (key: string) => string

/** 值轉文字。permissions 裡的 key 轉成權限名稱（找不到就顯示 key）。 */
const formatValue = (field: string, value: unknown, permissionLabel: Labeler): string => {
  if (value === null || value === undefined || value === '') return '（空）'
  if (typeof value === 'boolean') return value ? '是' : '否'
  if (Array.isArray(value)) {
    if (!value.length) return '（無）'
    return value.map(v => (field === 'permissions' ? permissionLabel(String(v)) : String(v))).join('、')
  }
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

const isChangeSet = (v: unknown): v is { added?: unknown[], removed?: unknown[] } =>
  !!v && typeof v === 'object' && !Array.isArray(v) && ('added' in v || 'removed' in v)

/** 增減清單：「角色：+A、+B；−C」。 */
const formatChangeSet = (field: string, set: { added?: unknown[], removed?: unknown[] }, permissionLabel: Labeler) => {
  const name = (v: unknown) => (field === 'permissions' ? permissionLabel(String(v)) : String(v))
  const parts = [
    ...(set.added ?? []).map(v => `+${name(v)}`),
    ...(set.removed ?? []).map(v => `−${name(v)}`)
  ]
  return `${fieldLabel(field)}：${parts.join('、') || '（無）'}`
}

/** 把 Detail JSON 整理成幾行說明文字。 */
export const auditDetailLines = (action: string, detail: string | null | undefined, permissionLabel: Labeler = k => k): string[] => {
  if (!detail) return []
  let data: Record<string, unknown>
  try {
    data = JSON.parse(detail)
  } catch {
    return [detail]
  }
  if (!data || typeof data !== 'object') return [detail]

  const lines: string[] = []

  // 登入
  if ('method' in data) {
    const method = data.method === 'sso' ? 'SSO' : data.method === 'password' ? '帳號密碼' : String(data.method)
    lines.push(data.reason ? `${method}：${data.reason}` : method)
  }

  const before = data.before as Record<string, unknown> | undefined
  const after = data.after as Record<string, unknown> | undefined

  if (before && after) {
    for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
      if (JSON.stringify(before[key]) === JSON.stringify(after[key])) continue
      lines.push(`${fieldLabel(key)}：${formatValue(key, before[key], permissionLabel)} → ${formatValue(key, after[key], permissionLabel)}`)
    }
  } else if (after) {
    for (const [key, value] of Object.entries(after)) lines.push(`${fieldLabel(key)}：${formatValue(key, value, permissionLabel)}`)
  } else if (before) {
    const prefix = action === 'DELETE' ? '刪除前' : '原本'
    for (const [key, value] of Object.entries(before)) lines.push(`${prefix}${fieldLabel(key)}：${formatValue(key, value, permissionLabel)}`)
  }

  if (typeof data.roleName === 'string') lines.push(`角色：${data.roleName}`)

  for (const field of ['roles', 'members', 'permissions']) {
    const set = data[field]
    if (isChangeSet(set)) lines.push(formatChangeSet(field, set, permissionLabel))
  }

  return lines.length ? lines : [detail]
}

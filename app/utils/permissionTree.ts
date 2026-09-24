import type { PermissionTreeNode, RBACPermission } from '~/types/system'

/**
 * 權限樹的組樹／取值邏輯（權限管理的角色編輯在用）。
 *
 * 資料是 RBAC_Permission 單一表自我參照（MODULE → GROUP → PAGE → ACTION，parentKey 指父節點），
 * 節點用 PermissionKey 認。MODULE / GROUP 是純分類不能勾；PAGE 勾了 = 進得去，ACTION 是頁面內細項。
 *
 * 停用節點（isActive = false，自己或祖先 aStatus = 'N'）照樣放進樹、標 disabled：
 * 勾選照樣顯示（看得出這個角色原本有），但不能改，collectSelection 也不送——
 * 後端 SaveRole 不會刪停用節點的權限列，節點重新啟用就恢復。
 */

const permissionNodeKey = (permissionKey: string) => `p-${permissionKey}`

/**
 * 依 parentKey 組樹，同層依 sort 排（後端已排好，這裡照原順序掛）。
 * parentKey 指到不存在的節點就當最上層——後端只回祖先鏈接得到最上層的節點，理論上不會發生。
 */
export const buildPermissionTree = (nodes: RBACPermission[]): PermissionTreeNode[] => {
  const byKey = new Map<string, PermissionTreeNode>()
  for (const n of nodes) {
    byKey.set(n.permissionKey, {
      key: permissionNodeKey(n.permissionKey),
      label: n.label,
      checkable: n.nodeType === 'PAGE' || n.nodeType === 'ACTION',
      disabled: n.isActive === false,
      nodeType: n.nodeType,
      permissionKey: n.permissionKey,
      children: []
    })
  }

  const roots: PermissionTreeNode[] = []
  for (const n of nodes) {
    const node = byKey.get(n.permissionKey)!
    const parent = n.parentKey ? byKey.get(n.parentKey) : undefined
    if (parent) parent.children.push(node)
    else roots.push(node)
  }
  return roots
}

/** 攤平成 key → 節點，查找用。 */
export const flattenTree = (nodes: PermissionTreeNode[]) => {
  const map = new Map<string, PermissionTreeNode>()
  const walk = (list: PermissionTreeNode[]) => {
    for (const node of list) {
      map.set(node.key, node)
      walk(node.children)
    }
  }
  walk(nodes)
  return map
}

/** key → 父節點 key，存檔時要往上補功能權限用。 */
export const buildParentMap = (nodes: PermissionTreeNode[]) => {
  const parents = new Map<string, string>()
  const walk = (list: PermissionTreeNode[], parentKey?: string) => {
    for (const node of list) {
      if (parentKey) parents.set(node.key, parentKey)
      walk(node.children, node.key)
    }
  }
  walk(nodes)
  return parents
}

/**
 * 把一串 PermissionKey 對映成樹上的勾選；樹上沒有的 key 與不能勾的分類節點直接略過。
 * 停用節點的勾選照樣收（畫面上顯示成已勾的 disabled）。
 */
export const selectedKeysFromPermissionKeys = (
  nodes: PermissionTreeNode[],
  permissionKeys: (string | null | undefined)[]
) => {
  const byKey = flattenTree(nodes)
  const keys = new Set<string>()
  for (const permissionKey of permissionKeys) {
    if (!permissionKey) continue
    const key = permissionNodeKey(permissionKey.trim())
    if (byKey.get(key)?.checkable) keys.add(key)
  }
  return keys
}

/**
 * 勾到的節點 + 沿路所有祖先的節點 key（頁面、分組、模組）。
 *
 * 細項有權限但頁面沒開等於進不去那個畫面；側欄也要有模組／分組才長得出來。
 * 後端 ResolvePermissionKeys 存檔時也會再補一次。
 */
const withAncestors = (nodes: PermissionTreeNode[], selected: Set<string>) => {
  const byKey = flattenTree(nodes)
  const parents = buildParentMap(nodes)
  const result = new Set<string>()

  for (const key of selected) {
    let cursor: string | undefined = key
    while (cursor) {
      if (byKey.get(cursor)?.permissionKey) result.add(cursor)
      cursor = parents.get(cursor)
    }
  }
  return result
}

/**
 * 把勾選轉成要送給後端的 PermissionKey 陣列。
 * 停用節點不送（後端 ResolvePermissionKeys 會把它當未定義的 key 擋掉；它的權限列後端本來就保留）。
 * 有效節點的祖先一定也有效，所以只要濾掉勾選本身。
 */
export const collectSelection = (nodes: PermissionTreeNode[], selected: Set<string>) => {
  const byKey = flattenTree(nodes)
  const active = new Set([...selected].filter(key => !byKey.get(key)?.disabled))
  return [...withAncestors(nodes, active)].map(key => byKey.get(key)!.permissionKey!)
}

/** 勾到的節點的所有祖先，載入後自動展開用。 */
export const expandedKeysFor = (nodes: PermissionTreeNode[], selected: Set<string>) => {
  const parents = buildParentMap(nodes)
  const keys = new Set<string>()
  for (const key of selected) {
    let cursor = parents.get(key)
    while (cursor) {
      keys.add(cursor)
      cursor = parents.get(cursor)
    }
  }
  return keys
}

import type {
  DepFunction,
  MFunction,
  MPermission,
  MPermissionDef,
  MSystem,
  PermissionDiffItem,
  PermissionTreeNode
} from '~/types/system'

/**
 * 權限樹的組樹／取值邏輯，權限管理（個人）與群組權限（群組範本）共用。
 *
 * 對應 1.0 的 wwwroot/js/system/permission-manager-treeV2.js，但節點改用
 * PermissionKey（`module.function.action`，見 app/utils/permissionKeys.ts）認，
 * 不再用 (FunctionNo, LinkType) 猜。
 */

const typeKey = (systemType: number) => `t-${systemType}`
const systemKey = (systemNo: number) => `s-${systemNo}`
const permissionNodeKey = (permissionKey: string) => `p-${permissionKey}`

/**
 * 組出三層權限樹。
 *
 * 功能節點（M_Function）的勾選代表它的 `.view`（M_PermissionDef 裡 linkType = 1 那列）；
 * 主檔裡沒有 `.view` 的功能照樣長出來但不能勾，免得存出後端認不得的 key。
 * 細項（linkType > 1）依 parentPermissionKey 掛，沒有就掛在同 functionNo 的功能底下。
 */
export const buildPermissionTree = (
  systems: MSystem[],
  functions: MFunction[],
  actions: MPermissionDef[]
): PermissionTreeNode[] => {
  const roots: PermissionTreeNode[] = []
  const systemNodes = new Map<number, PermissionTreeNode>()

  for (const system of systems) {
    let typeNode = roots.find(n => n.key === typeKey(system.systemType))
    if (!typeNode) {
      typeNode = {
        key: typeKey(system.systemType),
        label: system.typeName || '其他',
        checkable: false,
        children: []
      }
      roots.push(typeNode)
    }

    if (systemNodes.has(system.systemNo)) continue

    const systemNode: PermissionTreeNode = {
      key: systemKey(system.systemNo),
      label: system.systemName,
      checkable: false,
      children: []
    }
    typeNode.children.push(systemNode)
    systemNodes.set(system.systemNo, systemNode)
  }

  const viewByFunction = new Map(actions.filter(a => a.linkType === 1).map(a => [a.functionNo, a]))

  const functionNodes = new Map<string, PermissionTreeNode>()
  for (const fn of functions) {
    const parent = systemNodes.get(fn.systemNo)
    // M_Function 可能指到已經不存在／沒列在 M_System 的系統別，掛不上就跳過
    if (!parent) continue

    const view = viewByFunction.get(fn.functionNo)
    const node: PermissionTreeNode = {
      key: view ? permissionNodeKey(view.permissionKey) : `f-${fn.functionNo}`,
      label: fn.functionName || `功能 ${fn.functionNo}`,
      checkable: !!view,
      functionNo: fn.functionNo,
      permissionKey: view?.permissionKey,
      children: []
    }
    parent.children.push(node)
    functionNodes.set(fn.functionNo, node)
  }

  const details = actions.filter(a => a.linkType > 1)
  const detailNodes = new Map<string, PermissionTreeNode>()
  // 先全部建好節點再掛父子，才不用管主檔的排序
  for (const action of details) {
    detailNodes.set(action.permissionKey, {
      key: permissionNodeKey(action.permissionKey),
      label: action.actionName,
      checkable: true,
      functionNo: action.functionNo,
      permissionKey: action.permissionKey,
      children: []
    })
  }
  for (const action of details) {
    const node = detailNodes.get(action.permissionKey)!
    const parent = (action.parentPermissionKey ? detailNodes.get(action.parentPermissionKey) : null)
      ?? functionNodes.get(action.functionNo)
    if (!parent) continue
    parent.children.push(node)
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

/** 把一串 PermissionKey 對映成樹上的勾選；樹上沒有的 key（停用的、回填不到的）直接略過。 */
const selectedKeysFromPermissionKeys = (
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

/** 既有權限（M_Permission）對映成樹上的勾選。 */
export const selectedKeysFromPermissions = (nodes: PermissionTreeNode[], permissions: MPermission[]) =>
  selectedKeysFromPermissionKeys(nodes, permissions.map(p => p.permissionKey))

/** 群組預設功能（M_PermissionGroup）對映成樹上的勾選。 */
export const selectedKeysFromDepFunctions = (nodes: PermissionTreeNode[], depFunctions: DepFunction[]) =>
  selectedKeysFromPermissionKeys(nodes, depFunctions.map(d => d.permissionKey))

/**
 * 勾到的節點 + 沿路祖先的節點 key。
 *
 * 細項有權限但功能本身沒開，等於進不去那個畫面（1.0 processNode 的用意），
 * 所以每個勾到的節點都往上把功能一起算進來。後端存檔時也會再補一次。
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

/** 把勾選轉成要送給後端的 PermissionKey 陣列。 */
export const collectSelection = (nodes: PermissionTreeNode[], selected: Set<string>) => {
  const byKey = flattenTree(nodes)
  return [...withAncestors(nodes, selected)].map(key => byKey.get(key)!.permissionKey!)
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

/**
 * 群組套用前的差異清單：把 incoming（群組範本，可能已微調）套進 current（這個人目前的勾選）
 * 會發生什麼事。套用是聯集，所以 keptOnly 只是「保留不動」，不會被取消。
 *
 * 兩邊都先補上祖先再比，跟實際存檔的結果一致（勾細項會連帶開功能）。
 * 路徑略過最上層的系統類別，只列「系統 / 功能 / 細項」。
 */
export const diffSelection = (
  nodes: PermissionTreeNode[],
  current: Set<string>,
  incoming: Set<string>
) => {
  const byKey = flattenTree(nodes)
  const parents = buildParentMap(nodes)

  const pathOf = (key: string) => {
    const labels: string[] = []
    let cursor: string | undefined = key
    while (cursor) {
      const node = byKey.get(cursor)
      // 沒有父節點的就是最上層系統類別，不列
      if (node && parents.has(cursor)) labels.unshift(node.label)
      cursor = parents.get(cursor)
    }
    return labels.join(' / ')
  }
  const toItem = (key: string): PermissionDiffItem => ({
    permissionKey: byKey.get(key)!.permissionKey!,
    path: pathOf(key)
  })
  const byPath = (a: PermissionDiffItem, b: PermissionDiffItem) => a.path.localeCompare(b.path, 'zh-Hant')

  const currentAll = withAncestors(nodes, current)
  const incomingAll = withAncestors(nodes, incoming)

  return {
    added: [...incomingAll].filter(k => !currentAll.has(k)).map(toItem).sort(byPath),
    existing: [...incomingAll].filter(k => currentAll.has(k)).map(toItem).sort(byPath),
    keptOnly: [...currentAll].filter(k => !incomingAll.has(k)).map(toItem).sort(byPath)
  }
}

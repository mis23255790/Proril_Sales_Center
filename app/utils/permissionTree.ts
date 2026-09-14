import type {
  DepFunction,
  MFunction,
  MPermission,
  MPermissionLinkType,
  MSystem,
  PermissionTreeNode,
  RetLinkType
} from '~/types/system'

/**
 * 權限樹的組樹／取值邏輯，個人權限與群組預設功能兩棵樹共用。
 *
 * 對應 1.0 的 wwwroot/js/system/permission-manager-treeV2.js。
 */

const typeKey = (systemType: number) => `t-${systemType}`
const systemKey = (systemNo: number) => `s-${systemNo}`
const functionKey = (functionNo: string) => `f-${functionNo}`
const linkTypeKey = (id: number) => `l-${id}`

/**
 * 組出三層權限樹。
 *
 * **與 1.0 的差異**：1.0 的 v2AddFunctionEx 把所有 M_PermissionLinkType 一律掛在功能底下，
 * 完全沒有用 ParentLinkTypeID，巢狀的細項會被攤平成兄弟節點。這裡照 ParentLinkTypeID 掛，
 * 樹形才跟資料一致（1.0 另一支 GetPermissionTree API 本來也是這樣設計的）。
 */
export const buildPermissionTree = (
  systems: MSystem[],
  functions: MFunction[],
  linkTypes: MPermissionLinkType[]
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

  const functionNodes = new Map<string, PermissionTreeNode>()
  for (const fn of functions) {
    const parent = systemNodes.get(fn.systemNo)
    // M_Function 可能指到已經不存在／沒列在 M_System 的系統別，掛不上就跳過
    if (!parent) continue

    const node: PermissionTreeNode = {
      key: functionKey(fn.functionNo),
      label: fn.functionName || `功能 ${fn.functionNo}`,
      checkable: true,
      functionNo: fn.functionNo,
      children: []
    }
    parent.children.push(node)
    functionNodes.set(fn.functionNo, node)
  }

  const linkTypeNodes = new Map<number, PermissionTreeNode>()
  // 先全部建好節點再掛父子，才不用管 M_PermissionLinkType 的排序
  for (const lt of linkTypes) {
    linkTypeNodes.set(lt.id, {
      key: linkTypeKey(lt.id),
      label: lt.linkTypeName,
      checkable: true,
      functionNo: lt.functionNo,
      linkType: lt.linkType,
      permissionLinkTypeId: lt.id,
      children: []
    })
  }
  for (const lt of linkTypes) {
    const node = linkTypeNodes.get(lt.id)!
    const parent = (lt.parentLinkTypeId ? linkTypeNodes.get(lt.parentLinkTypeId) : null)
      ?? functionNodes.get(lt.functionNo)
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

/**
 * 把既有權限（M_Permission）對映成樹上的勾選。
 *
 * LinkType <= 1 的列代表「功能本身」；> 1 的是細項，用 (FunctionNo, LinkType) 找節點
 * ——跟 1.0 v2GetFunctionLinkTypeNode 同一個判斷，不是用 PermissionLinkTypeID 找，
 * 因為舊資料有 PermissionLinkTypeID 是 null 的列。
 */
export const selectedKeysFromPermissions = (
  nodes: PermissionTreeNode[],
  permissions: MPermission[]
) => {
  const all = [...flattenTree(nodes).values()]
  const keys = new Set<string>()

  for (const p of permissions) {
    if (p.linkType > 1) {
      const node = all.find(n => n.functionNo === p.functionNo && n.linkType === p.linkType)
      if (node) keys.add(node.key)
      continue
    }
    if (all.some(n => n.key === functionKey(p.functionNo))) keys.add(functionKey(p.functionNo))
  }

  return keys
}

/** 群組預設功能（M_PermissionGroup）對映成樹上的勾選，判斷方式同上。 */
export const selectedKeysFromDepFunctions = (
  nodes: PermissionTreeNode[],
  depFunctions: DepFunction[]
) => selectedKeysFromPermissions(
  nodes,
  depFunctions.map(d => ({
    id: d.id,
    functionNo: d.functionNo ?? '',
    linkType: d.linkType ?? 1,
    permissionLinkTypeId: null
  }))
)

/**
 * 把勾選轉成要送給後端的兩包資料。
 *
 * 每個勾到的節點都往上找 parent，把沿路的 functionNo 一併開啟——
 * 細項有權限但功能本身沒開，等於進不去那個畫面（1.0 processNode 的用意）。
 */
export const collectSelection = (nodes: PermissionTreeNode[], selected: Set<string>) => {
  const byKey = flattenTree(nodes)
  const parents = buildParentMap(nodes)

  const functionNos = new Set<string>()
  const linkTypeMap = new Map<string, RetLinkType>()

  for (const key of selected) {
    let cursor: string | undefined = key
    while (cursor) {
      const node: PermissionTreeNode | undefined = byKey.get(cursor)
      if (node) {
        if (node.functionNo) functionNos.add(node.functionNo)
        if (node.linkType && node.linkType > 1 && node.permissionLinkTypeId) {
          linkTypeMap.set(node.key, {
            FunctionNo: node.functionNo!,
            LinkType: String(node.linkType),
            PermissionLinkTypeID: node.permissionLinkTypeId
          })
        }
      }
      cursor = parents.get(cursor)
    }
  }

  return { functionNos: [...functionNos], linkTypes: [...linkTypeMap.values()] }
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

export const useTablePagination = (pageSize = 10) => {
  const pagination = ref({ pageIndex: 0, pageSize })
  return { pagination }
}

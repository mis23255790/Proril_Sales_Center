export const TEST_TYPE_LABELS: Record<number, string> = {
  0: '未設定',
  1: '全檢',
  2: '抽檢(10%)',
  3: '抽檢(1%)',
  4: '抽檢-MQ(0.75%)',
  5: '抽檢-富蘭克林(AQL 10%)'
}

export const WO_STATUS_LABELS: Record<number, string> = {
  0: '待測試',
  1: '測試通過',
  2: '重新測試',
  3: '特採出貨',
  4: '廢棄',
  5: '測試失敗'
}

export const WO_STATUS_COLORS: Record<number, 'neutral' | 'success' | 'warning' | 'error'> = {
  0: 'neutral',
  1: 'success',
  2: 'warning',
  3: 'warning',
  4: 'neutral',
  5: 'error'
}

export const useTestEnums = () => {
  const testTypeOptions = Object.entries(TEST_TYPE_LABELS)
    .filter(([value]) => value !== '0')
    .map(([value, label]) => ({ label, value: Number(value) }))

  const testPlaceOptions = [
    { label: '實驗室', value: '實驗室' },
    { label: '2F測試', value: '2F測試' }
  ]

  const phaseOptions = [
    { label: '1Ø', value: '1Ø' },
    { label: '3Ø', value: '3Ø' }
  ]

  const frequencyOptions = [
    { label: '50HZ', value: '50HZ' },
    { label: '60HZ', value: '60HZ' }
  ]

  return { testTypeOptions, testPlaceOptions, phaseOptions, frequencyOptions }
}

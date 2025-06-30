import request from '../../utils/httpUtils'

interface ApiResult {
  success: boolean
  message?: string
  data?: any
}

interface LineChartData {
  sensorName: string[]
  maxData: number[]
  minData: number[]
  avgData: number[]
  sensorType?: string
  sensorUnit?: string
  sensorTypeDesc?: string
  totalCount?: number
  validCount?: number
  dataQuality?: string
}

interface DistributionData {
  xData: string[]
  yData: number[]
  sensorType?: string
  sensorUnit?: string
  sensorTypeDesc?: string
  totalCount?: number
  analysisNote?: string
}

interface WarningData {
  fabricateName: string[]
  totalNum: number[]
  level1Num: number[]
  level2Num: number[]
  level3Num: number[]
  mom?: number[]
}

interface SensorTypeInfo {
  code: string
  name: string
  description: string
}

interface SensorTypeStats {
  [key: string]: number
}

@Component
export struct DataStatistics {
  @State currentChart: string = '折线图'
  @State lineChartData: LineChartData | null = null
  @State distributionData: DistributionData | null = null
  @State warningData: WarningData | null = null
  @State warningMonthData: WarningData | null = null
  @State loading: boolean = false
  @State currentPage: number = 0
  @State pageSize: number = 10

  // 传感器类型相关状态
  @State sensorTypes: SensorTypeInfo[] = []
  @State selectedSensorType: string = 'ALL'
  @State distributionSensorType: string = 'ALL' // 数据分布选择的传感器类型
  @State sensorTypeStats: SensorTypeStats = {}
  @State loadingSensorTypes: boolean = false
  @State loadingDistribution: boolean = false
  @State refreshing: boolean = false

  // Canvas相关状态
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private pieSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private pieContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.pieSettings)
  private warningSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private warningContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.warningSettings)
  private monthSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private monthContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.monthSettings)

  aboutToAppear() {
    console.info('DataStatistics 组件初始化')
    this.initializeMockData()
    this.loadSensorTypes()
    this.loadAllData()
  }

  initializeMockData() {
    console.info('初始化模拟数据')
    this.lineChartData = this.getMockLineChartData()
    this.distributionData = this.getMockDistributionData()
    this.warningData = this.getMockWarningData()
    this.warningMonthData = this.getMockWarningMonthData()
    console.info('模拟数据设置完成')
  }

  // =====================================
  // 数据加载相关方法
  // =====================================

  // 加载传感器类型列表
  async loadSensorTypes() {
    this.loadingSensorTypes = true
    try {
      console.info('开始加载传感器类型列表...')

      let result = await request.get('/statistic/sensorTypes') as ApiResult

      if (result?.success && result?.data) {
        this.sensorTypes = result.data as SensorTypeInfo[]
        console.info('传感器类型加载成功:', this.sensorTypes)
      } else {
        console.warn('传感器类型API返回无效数据，使用默认数据')
        this.sensorTypes = this.getDefaultSensorTypes()
      }

      // 加载传感器类型统计
      await this.loadSensorTypeStats()

    } catch (error) {
      console.error('加载传感器类型失败:', error)
      this.sensorTypes = this.getDefaultSensorTypes()
    } finally {
      this.loadingSensorTypes = false
    }
  }

  // 加载传感器类型统计
  async loadSensorTypeStats() {
    try {
      let result = await request.get('/statistic/sensorTypeStats') as ApiResult

      if (result?.success && result?.data) {
        this.sensorTypeStats = result.data as SensorTypeStats
        console.info('传感器类型统计加载成功:', this.sensorTypeStats)
      }
    } catch (error) {
      console.error('加载传感器类型统计失败:', error)
      this.sensorTypeStats = {
        'ALL': 26,
        'STRESS': 10,
        'CABLE_FORCE': 6,
        'DISPLACEMENT': 4,
        'VIBRATION': 3,
        'TEMPERATURE': 2,
        'WIND_SPEED': 1,
        'LOAD': 0,
        'OTHER': 0
      }
    }
  }

  // 获取默认传感器类型
  getDefaultSensorTypes(): SensorTypeInfo[] {
    return [
      { code: 'ALL', name: '全部传感器', description: '显示所有类型传感器' },
      { code: 'STRESS', name: '应力传感器', description: '应力类传感器(MPa)' },
      { code: 'CABLE_FORCE', name: '索力传感器', description: '索力类传感器(KN)' },
      { code: 'DISPLACEMENT', name: '位移传感器', description: '位移类传感器(mm)' },
      { code: 'VIBRATION', name: '振动传感器', description: '振动类传感器(Hz)' },
      { code: 'TEMPERATURE', name: '温度传感器', description: '温度类传感器(℃)' },
      { code: 'WIND_SPEED', name: '风速传感器', description: '风速类传感器(m/s)' },
      { code: 'LOAD', name: '荷载传感器', description: '荷载类传感器(T)' },
      { code: 'OTHER', name: '其他传感器', description: '其他类型传感器' }
    ]
  }

  async loadAllData() {
    this.loading = true
    try {
      console.info('开始加载所有数据...')

      let promiseResults = await Promise.all([
      this.loadLineChart(),
      this.loadDistribution(),
      this.loadWarningData(),
      this.loadWarningMonth()
      ])

      let [lineChart, distribution, warning, warningMonth] = promiseResults

      console.info('=== 数据验证结果 ===')
      console.info('折线图数据验证:', lineChart ? this.validateLineChartData(lineChart) : false)

      if (lineChart && this.validateLineChartData(lineChart)) {
        console.info('设置折线图数据，传感器数量:', lineChart.sensorName.length)
        this.lineChartData = lineChart
      } else {
        console.warn('折线图数据验证失败，保持原有数据')
      }

      if (distribution && this.validateDistributionData(distribution)) {
        this.distributionData = distribution
      }
      if (warning && this.validateWarningData(warning)) {
        this.warningData = warning
      }
      if (warningMonth && this.validateWarningData(warningMonth)) {
        this.warningMonthData = warningMonth
      }

      console.info('=== 最终数据状态 ===')
      console.info('最终lineChartData传感器数量:', this.lineChartData?.sensorName?.length)
      console.info('数据设置完成')
    } catch (error) {
      console.error('加载数据失败:', error)
    } finally {
      this.loading = false
    }
  }

  // 支持传感器类型参数的折线图数据加载
  async loadLineChart(): Promise<LineChartData> {
    try {
      console.info('开始加载折线图数据，传感器类型:', this.selectedSensorType)

      let result = await request.post('/statistic/lineChart', {
        startTime: '2024-08-01',
        endTime: '2024-08-31',
        sensorType: this.selectedSensorType
      }) as ApiResult

      console.info('=== API响应详细信息 ===')
      console.info('API响应成功:', result?.success)
      console.info('API响应消息:', result?.message)
      console.info('API响应数据:', result?.data)

      if (result?.success && result?.data) {
        let data: LineChartData = {
          sensorName: Array.from(result.data.sensorName || []).map(item => String(item)),
          maxData: Array.from(result.data.maxData || []).map(item => Number(item)),
          minData: Array.from(result.data.minData || []).map(item => Number(item)),
          avgData: Array.from(result.data.avgData || []).map(item => Number(item)),
          sensorType: result.data.sensorType || this.selectedSensorType,
          sensorUnit: result.data.sensorUnit || '',
          sensorTypeDesc: result.data.sensorTypeDesc || '',
          totalCount: result.data.totalCount || 0,
          validCount: result.data.validCount || 0,
          dataQuality: result.data.dataQuality || ''
        }

        console.info('=== 处理后的数据 ===')
        console.info('处理后传感器数量:', data.sensorName.length)
        console.info('折线图数据加载成功:', data)
        return data
      } else {
        console.warn('API返回无效数据，使用模拟数据:', result)
        let mockData = this.getMockLineChartDataByType(this.selectedSensorType)
        console.info('模拟数据传感器数量:', mockData.sensorName.length)
        return mockData
      }
    } catch (error) {
      console.error('加载折线图数据失败，使用模拟数据:', error)
      let mockData = this.getMockLineChartDataByType(this.selectedSensorType)
      console.info('异常时模拟数据传感器数量:', mockData.sensorName.length)
      return mockData
    }
  }

  // 数据分布加载 - 支持传感器类型参数
  async loadDistribution(): Promise<DistributionData> {
    try {
      console.info('开始加载数据分布，传感器类型:', this.distributionSensorType)

      let result = await request.post('/statistic/distribution', {
        startTime: '2024-08-01',
        endTime: '2024-08-31',
        sensorType: this.distributionSensorType
      }) as ApiResult

      console.info('=== 分布数据API响应 ===')
      console.info('API响应成功:', result?.success)
      console.info('API响应数据:', result?.data)

      if (result?.success && result?.data) {
        let data: DistributionData = {
          xData: Array.from(result.data.xData || []).map(item => String(item)),
          yData: Array.from(result.data.yData || []).map(item => Number(item)),
          sensorType: result.data.sensorType || this.distributionSensorType,
          sensorUnit: result.data.sensorUnit || '',
          sensorTypeDesc: result.data.sensorTypeDesc || '',
          totalCount: result.data.totalCount || 0,
          analysisNote: result.data.analysisNote || ''
        }

        console.info('分布数据加载成功:', data)
        return data
      } else {
        console.warn('分布API返回无效数据，使用模拟数据:', result)
        return this.getMockDistributionDataByType(this.distributionSensorType)
      }
    } catch (error) {
      console.error('加载分布数据失败，使用模拟数据:', error)
      return this.getMockDistributionDataByType(this.distributionSensorType)
    }
  }

  // 其他数据加载方法
  async loadWarningData(): Promise<WarningData> {
    try {
      let result = await request.post('/statistic/warningData', {
        year: 2024
      }) as ApiResult

      if (result?.success && result?.data) {
        let data: WarningData = {
          fabricateName: Array.from(result.data.fabricateName || []).map(item => String(item)),
          totalNum: Array.from(result.data.totalNum || []).map(item => Number(item)),
          level1Num: Array.from(result.data.level1Num || []).map(item => Number(item)),
          level2Num: Array.from(result.data.level2Num || []).map(item => Number(item)),
          level3Num: Array.from(result.data.level3Num || []).map(item => Number(item)),
          mom: result.data.mom ? Array.from(result.data.mom).map(item => Number(item)) : undefined
        }
        return data
      } else {
        return this.getMockWarningData()
      }
    } catch (error) {
      return this.getMockWarningData()
    }
  }

  async loadWarningMonth(): Promise<WarningData> {
    try {
      let result = await request.post('/statistic/warningMonth', {
        year: 2024
      }) as ApiResult

      if (result?.success && result?.data) {
        let data: WarningData = {
          fabricateName: Array.from(result.data.fabricateName || []).map(item => String(item)),
          totalNum: Array.from(result.data.totalNum || []).map(item => Number(item)),
          level1Num: Array.from(result.data.level1Num || []).map(item => Number(item)),
          level2Num: Array.from(result.data.level2Num || []).map(item => Number(item)),
          level3Num: Array.from(result.data.level3Num || []).map(item => Number(item)),
          mom: result.data.mom ? Array.from(result.data.mom).map(item => Number(item)) : undefined
        }
        return data
      } else {
        return this.getMockWarningMonthData()
      }
    } catch (error) {
      return this.getMockWarningMonthData()
    }
  }

  // =====================================
  // 传感器类型切换处理
  // =====================================

  // 传感器类型改变处理 - 折线图
  async onSensorTypeChange(newType: string) {
    if (this.selectedSensorType === newType) return

    console.info('折线图传感器类型改变:', this.selectedSensorType, '->', newType)
    this.selectedSensorType = newType

    // 重新加载折线图数据
    this.loading = true
    try {
      let lineChartData = await this.loadLineChart()
      if (lineChartData && this.validateLineChartData(lineChartData)) {
        this.lineChartData = lineChartData
        // 重新绘制图表
        setTimeout(() => {
          this.drawLineChart()
        }, 100)
      }
    } catch (error) {
      console.error('切换折线图传感器类型失败:', error)
    } finally {
      this.loading = false
    }
  }

  // 数据分布传感器类型改变处理
  async onDistributionSensorTypeChange(newType: string) {
    if (this.distributionSensorType === newType) return

    console.info('数据分布传感器类型改变:', this.distributionSensorType, '->', newType)
    this.distributionSensorType = newType

    // 重新加载分布数据
    this.loadingDistribution = true
    try {
      let distributionData = await this.loadDistribution()
      if (distributionData && this.validateDistributionData(distributionData)) {
        this.distributionData = distributionData
        // 重新绘制饼状图
        setTimeout(() => {
          this.drawPieChart()
        }, 100)
      }
    } catch (error) {
      console.error('切换分布传感器类型失败:', error)
    } finally {
      this.loadingDistribution = false
    }
  }

  // 刷新所有数据
  async refreshAllData() {
    this.refreshing = true
    try {
      await this.loadSensorTypes()
      await this.loadAllData()
    } catch (error) {
      console.error('刷新数据失败:', error)
    } finally {
      this.refreshing = false
    }
  }

  // =====================================
  // 数据验证方法
  // =====================================

  validateLineChartData(data: any): boolean {
    console.info('=== 数据验证开始 ===')

    if (!data || typeof data !== 'object') {
      console.warn('数据验证失败：数据不存在或不是对象')
      return false
    }

    let requiredFields = ['sensorName', 'maxData', 'minData', 'avgData']
    for (let field of requiredFields) {
      if (!Array.isArray(data[field])) {
        console.warn(`数据验证失败：${field} 不是数组`)
        return false
      }
    }

    let length = data.sensorName.length
    console.info(`数据验证：传感器数量 ${length}`)

    if (data.maxData.length !== length ||
    data.minData.length !== length ||
    data.avgData.length !== length) {
      console.warn('数据验证失败：数组长度不一致')
      console.info(`传感器名称长度: ${data.sensorName.length}`)
      console.info(`最大值长度: ${data.maxData.length}`)
      console.info(`最小值长度: ${data.minData.length}`)
      console.info(`平均值长度: ${data.avgData.length}`)
      return false
    }

    console.info('数据验证成功')
    return true
  }

  validateDistributionData(data: any): boolean {
    return data &&
    Array.isArray(data.xData) &&
    Array.isArray(data.yData) &&
    data.xData.length === data.yData.length
  }

  validateWarningData(data: any): boolean {
    if (!data || typeof data !== 'object') return false
    let requiredFields = ['fabricateName', 'totalNum', 'level1Num', 'level2Num', 'level3Num']
    for (let field of requiredFields) {
      if (!Array.isArray(data[field])) return false
    }
    return true
  }

  // =====================================
  // 模拟数据生成方法
  // =====================================

  // 根据传感器类型获取模拟数据
  getMockLineChartDataByType(sensorType: string): LineChartData {
    console.info('获取模拟数据，类型:', sensorType)

    switch (sensorType) {
      case 'STRESS':
        return {
          sensorName: ['应力传感器-A1', '应力传感器-A2', '应力传感器-A3', '应力传感器-A4'],
          maxData: [17500.0, 8587.0, 9876.0, 8234.0],
          minData: [6666.0, 7123.0, 8123.0, 7234.0],
          avgData: [9234.5, 7856.2, 8999.5, 7734.0],
          sensorType: 'STRESS',
          sensorUnit: 'MPa',
          sensorTypeDesc: '应力传感器',
          totalCount: 150,
          validCount: 142,
          dataQuality: '优秀'
        }
      case 'CABLE_FORCE':
        return {
          sensorName: ['索力传感器-B1', '索力传感器-B2', '索力传感器-B3', '索力传感器-B4'],
          maxData: [1389.0, 1267.0, 1356.0, 1234.0],
          minData: [1156.0, 1176.0, 1198.0, 1123.0],
          avgData: [1267.5, 1215.8, 1277.0, 1178.5],
          sensorType: 'CABLE_FORCE',
          sensorUnit: 'KN',
          sensorTypeDesc: '索力传感器',
          totalCount: 80,
          validCount: 78,
          dataQuality: '良好'
        }
      case 'DISPLACEMENT':
        return {
          sensorName: ['位移传感器-C1', '位移传感器-C2', '位移传感器-C3', '位移传感器-C4'],
          maxData: [15.67, 10.12, 14.89, 12.34],
          minData: [11.23, 7.23, 7.45, 8.12],
          avgData: [13.45, 8.67, 11.17, 10.23],
          sensorType: 'DISPLACEMENT',
          sensorUnit: 'mm',
          sensorTypeDesc: '位移传感器',
          totalCount: 60,
          validCount: 57,
          dataQuality: '良好'
        }
      case 'VIBRATION':
        return {
          sensorName: ['振动传感器-D1', '振动传感器-D2', '振动传感器-D3', '振动传感器-D4'],
          maxData: [0.567, 0.312, 0.445, 0.389],
          minData: [0.123, 0.123, 0.156, 0.145],
          avgData: [0.345, 0.217, 0.301, 0.267],
          sensorType: 'VIBRATION',
          sensorUnit: 'Hz',
          sensorTypeDesc: '振动传感器',
          totalCount: 45,
          validCount: 43,
          dataQuality: '一般'
        }
      case 'TEMPERATURE':
        return {
          sensorName: ['温度传感器-E1', '温度传感器-E2', '温度传感器-E3', '温度传感器-E4'],
          maxData: [26.67, 24.12, 28.45, 25.78],
          minData: [22.23, 21.23, 24.12, 22.45],
          avgData: [24.45, 22.67, 26.28, 24.11],
          sensorType: 'TEMPERATURE',
          sensorUnit: '℃',
          sensorTypeDesc: '温度传感器',
          totalCount: 30,
          validCount: 30,
          dataQuality: '优秀'
        }
      case 'WIND_SPEED':
        return {
          sensorName: ['风速传感器-F1', '风速传感器-F2'],
          maxData: [21.89, 18.45],
          minData: [12.45, 14.23],
          avgData: [17.17, 16.34],
          sensorType: 'WIND_SPEED',
          sensorUnit: 'm/s',
          sensorTypeDesc: '风速传感器',
          totalCount: 20,
          validCount: 19,
          dataQuality: '良好'
        }
      case 'LOAD':
        return {
          sensorName: ['荷载传感器-G1'],
          maxData: [61.89],
          minData: [45.67],
          avgData: [53.78],
          sensorType: 'LOAD',
          sensorUnit: 'T',
          sensorTypeDesc: '荷载传感器',
          totalCount: 15,
          validCount: 14,
          dataQuality: '一般'
        }
      default:
        return this.getMockLineChartData()
    }
  }

  // 根据传感器类型获取模拟分布数据
  getMockDistributionDataByType(sensorType: string): DistributionData {
    console.info('获取模拟分布数据，类型:', sensorType)

    switch (sensorType) {
      case 'STRESS':
        return {
          xData: ["0-1000", "1000-3000", "3000-5000", "5000-8000", "8000-12000", "12000-16000", "16000-20000", "20000以上"],
          yData: [0.15, 0.25, 0.20, 0.18, 0.12, 0.08, 0.02, 0.00],
          sensorType: 'STRESS',
          sensorUnit: 'MPa',
          sensorTypeDesc: '应力传感器',
          totalCount: 150,
          analysisNote: "应力传感器数据主要集中在1000-3000MPa区间(25.0%)。建议关注高应力区间的数据，及时进行结构安全评估。"
        }
      case 'CABLE_FORCE':
        return {
          xData: ["0-500", "500-800", "800-1100", "1100-1400", "1400-1700", "1700-2000", "2000-2500", "2500以上"],
          yData: [0.05, 0.15, 0.30, 0.25, 0.15, 0.08, 0.02, 0.00],
          sensorType: 'CABLE_FORCE',
          sensorUnit: 'KN',
          sensorTypeDesc: '索力传感器',
          totalCount: 80,
          analysisNote: "索力传感器数据主要集中在800-1100KN区间(30.0%)。索力分布应保持相对均匀，异常高值需要重点监测。"
        }
      case 'DISPLACEMENT':
        return {
          xData: ["0-2", "2-5", "5-10", "10-15", "15-20", "20-30", "30-50", "50以上"],
          yData: [0.20, 0.35, 0.25, 0.12, 0.05, 0.02, 0.01, 0.00],
          sensorType: 'DISPLACEMENT',
          sensorUnit: 'mm',
          sensorTypeDesc: '位移传感器',
          totalCount: 60,
          analysisNote: "位移传感器数据主要集中在2-5mm区间(35.0%)。位移数据应控制在设计范围内，超限需要立即处理。"
        }
      case 'VIBRATION':
        return {
          xData: ["0-0.1", "0.1-0.2", "0.2-0.3", "0.3-0.5", "0.5-0.8", "0.8-1.2", "1.2-2.0", "2.0以上"],
          yData: [0.30, 0.25, 0.20, 0.15, 0.07, 0.02, 0.01, 0.00],
          sensorType: 'VIBRATION',
          sensorUnit: 'Hz',
          sensorTypeDesc: '振动传感器',
          totalCount: 45,
          analysisNote: "振动传感器数据主要集中在0-0.1Hz区间(30.0%)。振动频率过高可能影响结构安全，建议加强监测。"
        }
      case 'TEMPERATURE':
        return {
          xData: ["0以下", "0-10", "10-20", "20-25", "25-30", "30-35", "35-40", "40以上"],
          yData: [0.05, 0.15, 0.25, 0.30, 0.18, 0.05, 0.02, 0.00],
          sensorType: 'TEMPERATURE',
          sensorUnit: '℃',
          sensorTypeDesc: '温度传感器',
          totalCount: 30,
          analysisNote: "温度传感器数据主要集中在20-25℃区间(30.0%)。温度变化会影响结构性能，注意极端温度的影响。"
        }
      case 'WIND_SPEED':
        return {
          xData: ["0-2", "2-5", "5-10", "10-15", "15-20", "20-25", "25-30", "30以上"],
          yData: [0.25, 0.35, 0.25, 0.10, 0.03, 0.01, 0.01, 0.00],
          sensorType: 'WIND_SPEED',
          sensorUnit: 'm/s',
          sensorTypeDesc: '风速传感器',
          totalCount: 20,
          analysisNote: "风速传感器数据主要集中在2-5m/s区间(35.0%)。高风速会影响结构稳定性，建议在恶劣天气加强监测。"
        }
      case 'LOAD':
        return {
          xData: ["0-10", "10-20", "20-30", "30-40", "40-50", "50-60", "60-80", "80以上"],
          yData: [0.20, 0.30, 0.25, 0.15, 0.07, 0.02, 0.01, 0.00],
          sensorType: 'LOAD',
          sensorUnit: 'T',
          sensorTypeDesc: '荷载传感器',
          totalCount: 15,
          analysisNote: "荷载传感器数据主要集中在10-20T区间(30.0%)。荷载分布应符合设计预期，过载情况需要及时处理。"
        }
      default:
        return this.getMockDistributionData()
    }
  }

  getMockDistributionData(): DistributionData {
    return {
      xData: ["500-1000", "1000-1500", "1500-2000", "2000-2500", "10000以上"],
      yData: [0.3, 0.2, 0.3, 0.22, 0.33],
      sensorType: 'ALL',
      sensorUnit: '',
      sensorTypeDesc: '全部传感器',
      totalCount: 200,
      analysisNote: "综合传感器数据主要集中在1000-1500区间(25.0%)。建议根据实际工况制定相应的监测策略。"
    }
  }

  getMockWarningData(): WarningData {
    return {
      fabricateName: ["桥身/ 1#桥身", "桥身/2#桥身"],
      totalNum: [22, 8],
      level1Num: [6, 0],
      level2Num: [6, 2],
      level3Num: [10, 6],
      mom: undefined
    }
  }

  getMockWarningMonthData(): WarningData {
    return {
      fabricateName: ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"],
      totalNum: [0, 0, 30, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      level1Num: [0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      level2Num: [0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      level3Num: [0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      mom: [0, 0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0]
    }
  }

  getMockLineChartData(): LineChartData {
    return {
      sensorName: [
        '应力传感器-A1', '应力传感器-A2', '索力传感器-B1', '索力传感器-B2',
        '位移传感器-C1', '位移传感器-C2', '振动传感器-D1', '振动传感器-D2',
        '温度传感器-E1', '温度传感器-E2', '风速传感器-F1', '荷载传感器-G1',
        '应力传感器-A3', '索力传感器-B3', '位移传感器-C3'
      ],
      maxData: [
        17500.0, 8587.0, 1389.0, 1267.0, 15.67, 10.12, 0.567, 0.312,
        26.67, 24.12, 21.89, 61.89, 9876.0, 1356.0, 14.89
      ],
      minData: [
        6666.0, 7123.0, 1156.0, 1176.0, 11.23, 7.23, 0.123, 0.123,
        22.23, 21.23, 12.45, 45.67, 8123.0, 1198.0, 7.45
      ],
      avgData: [
        9234.5, 7856.2, 1267.5, 1215.8, 13.45, 8.67, 0.345, 0.217,
        24.45, 22.67, 17.17, 53.78, 8999.5, 1277.0, 11.17
      ],
      sensorType: 'ALL',
      sensorUnit: '',
      sensorTypeDesc: '全部传感器',
      totalCount: 300,
      validCount: 285,
      dataQuality: '良好'
    }
  }

  // =====================================
  // 主界面构建
  // =====================================

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('数据统计')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')

        Blank()

        Row() {
          if (this.refreshing) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color('#4852C9')
              .margin({ right: 8 })
          }

          Button('刷新')
            .fontSize(14)
            .backgroundColor('#4852C9')
            .enabled(!this.refreshing)
            .onClick(() => {
              console.info('用户点击刷新按钮')
              this.refreshAllData()
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#f8f9fa')

      if (this.loading || this.loadingSensorTypes) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
            .color('#4852C9')

          Text('数据加载中...')
            .fontSize(14)
            .fontColor('#666')
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // 图表选择器
        Row() {
          ForEach(['折线图', '数据分布', '预警分析', '月度预警'], (item: string, index: number) => {
            Text(item)
              .fontSize(14)
              .fontColor(this.currentChart === item ? '#4852C9' : '#666')
              .fontWeight(this.currentChart === item ? FontWeight.Bold : FontWeight.Normal)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor(this.currentChart === item ? '#e8f0fe' : Color.Transparent)
              .borderRadius(16)
              .onClick(() => {
                this.currentChart = item
              })
              .margin({ right: index < 3 ? 8 : 0 })
          })
        }
        .width('100%')
        .padding(16)

        // 传感器类型选择器
        if (this.currentChart === '折线图') {
          this.SensorTypeSelector()
        } else if (this.currentChart === '数据分布') {
          this.DistributionSensorTypeSelector()
        }

        // 图表内容区域
        Scroll() {
          Column() {
            if (this.currentChart === '折线图') {
              this.LineChartView()
            } else if (this.currentChart === '数据分布') {
              this.DistributionView()
            } else if (this.currentChart === '预警分析') {
              this.WarningView()
            } else if (this.currentChart === '月度预警') {
              this.MonthWarningView()
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  // =====================================
  // 传感器类型选择器组件
  // =====================================

  // 折线图传感器类型选择器
  @Builder
  SensorTypeSelector() {
    Column() {
      Row() {
        Text('传感器类型')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .margin({ right: 12 })

        Text('选择要查看的传感器类型')
          .fontSize(12)
          .fontColor('#666')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 12 })

      // 传感器类型选项
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        ForEach(this.sensorTypes, (type: SensorTypeInfo, index: number) => {
          if (type.code === 'OTHER' && this.sensorTypeStats[type.code] === 0) {
            // 如果其他类型传感器数量为0，则不显示
          } else {
            Row() {
              Text(type.name)
                .fontSize(12)
                .fontColor(this.selectedSensorType === type.code ? '#fff' : '#333')
                .fontWeight(this.selectedSensorType === type.code ? FontWeight.Bold : FontWeight.Normal)

              if (this.sensorTypeStats[type.code] !== undefined) {
                Text(`(${this.sensorTypeStats[type.code]})`)
                  .fontSize(10)
                  .fontColor(this.selectedSensorType === type.code ? '#fff' : '#999')
                  .margin({ left: 4 })
              }
            }
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.selectedSensorType === type.code ? '#4852C9' : '#f0f0f0')
            .borderRadius(12)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.onSensorTypeChange(type.code)
            })
            .border({
              width: this.selectedSensorType === type.code ? 0 : 1,
              color: '#e0e0e0'
            })
          }
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 8 })
    .shadow({
      radius: 2,
      color: '#00000010',
      offsetX: 0,
      offsetY: 1
    })
  }

  // 数据分布传感器类型选择器
  @Builder
  DistributionSensorTypeSelector() {
    Column() {
      Row() {
        Text('数据分布类型')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .margin({ right: 12 })

        Text('选择要分析的传感器类型')
          .fontSize(12)
          .fontColor('#666')
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 12 })

      // 传感器类型选项
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        ForEach(this.sensorTypes, (type: SensorTypeInfo, index: number) => {
          if (type.code === 'OTHER' && this.sensorTypeStats[type.code] === 0) {
            // 如果其他类型传感器数量为0，则不显示
          } else {
            Row() {
              Text(type.name)
                .fontSize(12)
                .fontColor(this.distributionSensorType === type.code ? '#fff' : '#333')
                .fontWeight(this.distributionSensorType === type.code ? FontWeight.Bold : FontWeight.Normal)

              if (this.sensorTypeStats[type.code] !== undefined) {
                Text(`(${this.sensorTypeStats[type.code]})`)
                  .fontSize(10)
                  .fontColor(this.distributionSensorType === type.code ? '#fff' : '#999')
                  .margin({ left: 4 })
              }
            }
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.distributionSensorType === type.code ? '#52c41a' : '#f0f0f0')
            .borderRadius(12)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.onDistributionSensorTypeChange(type.code)
            })
            .border({
              width: this.distributionSensorType === type.code ? 0 : 1,
              color: '#e0e0e0'
            })
          }
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 8 })
    .shadow({
      radius: 2,
      color: '#00000010',
      offsetX: 0,
      offsetY: 1
    })
  }

  // =====================================
  // 折线图视图
  // =====================================

  @Builder
  LineChartView() {
    Column() {
      // 传感器类型信息
      if (this.lineChartData?.sensorType && this.lineChartData.sensorType !== 'ALL') {
        Row() {
          Text(`${this.getSensorTypeName(this.lineChartData.sensorType)}数据趋势`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')

          if (this.lineChartData.sensorUnit) {
            Text(`(单位: ${this.lineChartData.sensorUnit})`)
              .fontSize(12)
              .fontColor('#666')
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: 16 })
      } else {
        Text('传感器数据趋势')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 16 })
      }

      if (this.lineChartData &&
      this.lineChartData.sensorName &&
      this.lineChartData.sensorName.length > 0) {

        Column() {
          // 数据概览卡片
          Row() {
            this.DataSummaryCard('传感器数量', this.lineChartData.sensorName.length.toString(), '#1890ff')
            this.DataSummaryCard('最高值', this.getMaxOfMax().toFixed(1), '#f5222d')
            this.DataSummaryCard('最低值', this.getMinValue().toFixed(1), '#52c41a')
            this.DataSummaryCard('平均值', this.getAvgValue().toFixed(1), '#faad14')
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ bottom: 20 })

          // 数据质量指示器
          if (this.lineChartData.dataQuality) {
            Row() {
              Text('数据质量:')
                .fontSize(12)
                .fontColor('#666')
                .margin({ right: 8 })

              Text(this.lineChartData.dataQuality)
                .fontSize(12)
                .fontColor(this.getDataQualityColor(this.lineChartData.dataQuality))
                .fontWeight(FontWeight.Medium)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(this.getDataQualityBgColor(this.lineChartData.dataQuality))
                .borderRadius(4)

              if (this.lineChartData.totalCount && this.lineChartData.validCount) {
                Text(`(${this.lineChartData.validCount}/${this.lineChartData.totalCount})`)
                  .fontSize(10)
                  .fontColor('#999')
                  .margin({ left: 8 })
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: 16 })
          }

          // Canvas折线图
          this.CanvasLineChart()

          // 图例
          Row() {
            this.LegendItem('最大值', '#f5222d')
            this.LegendItem('最小值', '#52c41a')
            this.LegendItem('平均值', '#faad14')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 12, bottom: 20 })

          // 详细数据表格
          this.DataTable()
        }
      } else {
        // 无数据提示
        Column() {
          Text('📊')
            .fontSize(60)
            .opacity(0.3)

          Text(`暂无${this.getSensorTypeName(this.selectedSensorType)}数据`)
            .fontSize(16)
            .fontColor('#999')
            .margin({ top: 16 })

          Text('请尝试选择其他传感器类型或重新加载数据')
            .fontSize(12)
            .fontColor('#ccc')
            .margin({ top: 8 })

          Button('重新加载')
            .fontSize(14)
            .backgroundColor('#4852C9')
            .margin({ top: 16 })
            .onClick(async () => {
              this.loading = true
              try {
                let lineChartData = await this.loadLineChart()
                if (lineChartData && this.validateLineChartData(lineChartData)) {
                  this.lineChartData = lineChartData
                }
              } catch (error) {
                console.error('手动加载失败:', error)
              } finally {
                this.loading = false
              }
            })
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin(16)
    .shadow({
      radius: 4,
      color: '#00000008',
      offsetX: 0,
      offsetY: 2
    })
  }

  // 根据传感器类型代码获取中文名称
  getSensorTypeName(typeCode: string): string {
    let typeMap = {
      'ALL': '全部',
      'STRESS': '应力',
      'CABLE_FORCE': '索力',
      'DISPLACEMENT': '位移',
      'VIBRATION': '振动',
      'TEMPERATURE': '温度',
      'WIND_SPEED': '风速',
      'LOAD': '荷载',
      'OTHER': '其他'
    }
    return typeMap[typeCode] || '未知'
  }

  // 获取数据质量颜色
  getDataQualityColor(quality: string): string {
    switch (quality) {
      case '优秀': return '#52c41a'
      case '良好': return '#1890ff'
      case '一般': return '#faad14'
      case '较差': return '#f5222d'
      default: return '#999'
    }
  }

  // 获取数据质量背景色
  getDataQualityBgColor(quality: string): string {
    switch (quality) {
      case '优秀': return '#f6ffed'
      case '良好': return '#e6f7ff'
      case '一般': return '#fffbe6'
      case '较差': return '#fff1f0'
      default: return '#f5f5f5'
    }
  }

  @Builder
  CanvasLineChart() {
    Column() {
      // 使用条件渲染代替字符串拼接
      if (this.lineChartData?.sensorUnit) {
        Text(`传感器数据趋势图 (${this.lineChartData.sensorUnit})`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .margin({ bottom: 12 })
      } else {
        Text('传感器数据趋势图')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .margin({ bottom: 12 })
      }

      Stack() {
        Canvas(this.context)
          .width('100%')
          .height(280)
          .backgroundColor('#fafafa')
          .onReady(() => {
            this.drawLineChart()
          })
      }
      .width('100%')
      .height(280)
      .borderRadius(8)
      .border({
        width: 1,
        color: '#e8e8e8'
      })
    }
    .width('100%')
  }

  // =====================================
  // Canvas绘制方法
  // =====================================

  private drawLineChart() {
    if (!this.lineChartData || !this.context) {
      console.warn('Canvas绘制失败：数据或上下文不存在')
      return
    }

    console.info('Canvas绘制开始，传感器数量:', this.lineChartData.sensorName.length)

    let canvasWidth = 350
    let canvasHeight = 280
    let padding = { left: 60, right: 40, top: 30, bottom: 60 }
    let chartWidth = canvasWidth - padding.left - padding.right
    let chartHeight = canvasHeight - padding.top - padding.bottom

    // 清空画布
    this.context.clearRect(0, 0, canvasWidth, canvasHeight)

    // 绘制背景
    this.context.fillStyle = '#fafafa'
    this.context.fillRect(0, 0, canvasWidth, canvasHeight)

    // 计算数据范围
    let allValues: number[] = []
    for (let i = 0; i < this.lineChartData.maxData.length; i++) {
      allValues.push(this.lineChartData.maxData[i])
    }
    for (let i = 0; i < this.lineChartData.minData.length; i++) {
      allValues.push(this.lineChartData.minData[i])
    }
    for (let i = 0; i < this.lineChartData.avgData.length; i++) {
      allValues.push(this.lineChartData.avgData[i])
    }

    let minValue = allValues[0]
    let maxValue = allValues[0]
    for (let i = 1; i < allValues.length; i++) {
      if (allValues[i] < minValue) {
        minValue = allValues[i]
      }
      if (allValues[i] > maxValue) {
        maxValue = allValues[i]
      }
    }
    let valueRange = maxValue - minValue || 1

    // 绘制网格线
    this.drawGrid(canvasWidth, canvasHeight, padding, chartWidth, chartHeight, minValue, maxValue, valueRange)

    // 绘制坐标轴
    this.drawAxes(canvasWidth, canvasHeight, padding, chartWidth, chartHeight)

    // 绘制标签
    this.drawLabels(padding, chartWidth, chartHeight, minValue, maxValue, valueRange)

    // 绘制折线和数据点
    this.drawLines(padding, chartWidth, chartHeight, minValue, valueRange)
  }

  private drawGrid(canvasWidth: number, canvasHeight: number, padding: any, chartWidth: number, chartHeight: number, minValue: number, maxValue: number, valueRange: number) {
    this.context.strokeStyle = '#e0e0e0'
    this.context.lineWidth = 0.5

    // 绘制水平网格线
    for (let i = 0; i <= 4; i++) {
      let y = padding.top + (chartHeight * i / 4)
      this.context.beginPath()
      this.context.moveTo(padding.left, y)
      this.context.lineTo(padding.left + chartWidth, y)
      this.context.stroke()
    }

    // 绘制垂直网格线
    if (this.lineChartData && this.lineChartData.sensorName.length > 1) {
      let sensorCount = this.lineChartData.sensorName.length
      for (let i = 0; i < sensorCount; i++) {
        let x = padding.left + (chartWidth * i / (sensorCount - 1))
        this.context.beginPath()
        this.context.moveTo(x, padding.top)
        this.context.lineTo(x, padding.top + chartHeight)
        this.context.stroke()
      }
    }
  }

  private drawAxes(canvasWidth: number, canvasHeight: number, padding: any, chartWidth: number, chartHeight: number) {
    this.context.strokeStyle = '#333'
    this.context.lineWidth = 1

    // 绘制Y轴
    this.context.beginPath()
    this.context.moveTo(padding.left, padding.top)
    this.context.lineTo(padding.left, padding.top + chartHeight)
    this.context.stroke()

    // 绘制X轴
    this.context.beginPath()
    this.context.moveTo(padding.left, padding.top + chartHeight)
    this.context.lineTo(padding.left + chartWidth, padding.top + chartHeight)
    this.context.stroke()
  }

  private drawLabels(padding: any, chartWidth: number, chartHeight: number, minValue: number, maxValue: number, valueRange: number) {
    this.context.fillStyle = '#666'
    this.context.font = '14px sans-serif'
    this.context.textAlign = 'right'

    // Y轴标签
    for (let i = 0; i <= 4; i++) {
      let value = maxValue - (valueRange * i / 4)
      let y = padding.top + (chartHeight * i / 4) + 5
      this.context.fillText(value.toFixed(0), padding.left - 10, y)
    }

    // X轴标签
    if (this.lineChartData) {
      this.context.textAlign = 'center'
      this.context.font = '10px sans-serif'

      let sensorCount = this.lineChartData.sensorName.length

      for (let i = 0; i < sensorCount; i++) {
        let x = padding.left + (chartWidth * i / (sensorCount - 1))
        let label = this.lineChartData.sensorName[i]
        let displayLabel = label.length > 8 ? label.substring(0, 8) + '..' : label

        // 保存当前上下文
        this.context.save()
        // 移动到标签位置
        this.context.translate(x, padding.top + chartHeight + 35)
        // 如果传感器很多，旋转标签
        if (sensorCount > 10) {
          this.context.rotate(-Math.PI / 4)
        }
        this.context.fillText(displayLabel, 0, 0)
        // 恢复上下文
        this.context.restore()
      }
    }
  }

  private drawLines(padding: any, chartWidth: number, chartHeight: number, minValue: number, valueRange: number) {
    if (!this.lineChartData) return

    // 绘制最大值线
    this.drawSingleLine(this.lineChartData.maxData, '#f5222d', padding, chartWidth, chartHeight, minValue, valueRange)
    this.drawDataPoints(this.lineChartData.maxData, '#f5222d', padding, chartWidth, chartHeight, minValue, valueRange)

    // 绘制平均值线
    this.drawSingleLine(this.lineChartData.avgData, '#faad14', padding, chartWidth, chartHeight, minValue, valueRange)
    this.drawDataPoints(this.lineChartData.avgData, '#faad14', padding, chartWidth, chartHeight, minValue, valueRange)

    // 绘制最小值线
    this.drawSingleLine(this.lineChartData.minData, '#52c41a', padding, chartWidth, chartHeight, minValue, valueRange)
    this.drawDataPoints(this.lineChartData.minData, '#52c41a', padding, chartWidth, chartHeight, minValue, valueRange)
  }

  private drawSingleLine(data: number[], color: string, padding: any, chartWidth: number, chartHeight: number, minValue: number, valueRange: number) {
    if (data.length < 2) return

    this.context.strokeStyle = color
    this.context.lineWidth = 2

    this.context.beginPath()
    for (let i = 0; i < data.length; i++) {
      let x = padding.left + (chartWidth * i / (data.length - 1))
      let y = padding.top + chartHeight - ((data[i] - minValue) / valueRange) * chartHeight

      if (i === 0) {
        this.context.moveTo(x, y)
      } else {
        this.context.lineTo(x, y)
      }
    }
    this.context.stroke()
  }

  private drawDataPoints(data: number[], color: string, padding: any, chartWidth: number, chartHeight: number, minValue: number, valueRange: number) {
    this.context.fillStyle = color
    this.context.strokeStyle = '#fff'
    this.context.lineWidth = 1

    for (let i = 0; i < data.length; i++) {
      let x = padding.left + (chartWidth * i / (data.length - 1))
      let y = padding.top + chartHeight - ((data[i] - minValue) / valueRange) * chartHeight

      this.context.beginPath()
      this.context.arc(x, y, 3, 0, 2 * Math.PI)
      this.context.fill()
      this.context.stroke()
    }
  }

  @Builder
  LegendItem(label: string, color: string) {
    Row() {
      Circle({ width: 8, height: 8 })
        .fill(color)
        .margin({ right: 4 })

      Text(label)
        .fontSize(12)
        .fontColor('#666')
    }
    .margin({ right: 16 })
  }

  // =====================================
  // 辅助计算方法
  // =====================================

  getSafeValue(value: any): number {
    if (typeof value === 'number' && !isNaN(value) && isFinite(value)) {
      return Math.max(0, value)
    }
    return 0
  }

  getMaxOfMax(): number {
    if (!this.lineChartData || !this.lineChartData.maxData) {
      return 0
    }
    let validValues = this.lineChartData.maxData.filter(val => typeof val === 'number' && !isNaN(val) && isFinite(val))
    if (validValues.length === 0) {
      return 0
    }

    let maxVal = validValues[0]
    for (let i = 1; i < validValues.length; i++) {
      if (validValues[i] > maxVal) {
        maxVal = validValues[i]
      }
    }
    return maxVal
  }

  getMinValue(): number {
    if (!this.lineChartData || !this.lineChartData.minData) {
      return 0
    }
    let validValues = this.lineChartData.minData.filter(val => typeof val === 'number' && !isNaN(val) && isFinite(val))
    if (validValues.length === 0) {
      return 0
    }

    let minVal = validValues[0]
    for (let i = 1; i < validValues.length; i++) {
      if (validValues[i] < minVal) {
        minVal = validValues[i]
      }
    }
    return minVal
  }

  getAvgValue(): number {
    if (!this.lineChartData || !this.lineChartData.avgData) {
      return 0
    }
    let validValues = this.lineChartData.avgData.filter(val => typeof val === 'number' && !isNaN(val) && isFinite(val))
    if (validValues.length === 0) {
      return 0
    }

    let sum = validValues.reduce((a, b) => a + b, 0)
    return sum / validValues.length
  }

  @Builder
  DataSummaryCard(title: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(title)
        .fontSize(10)
        .fontColor('#666')
        .margin({ top: 4 })
    }
    .padding(8)
    .backgroundColor(Color.White)
    .borderRadius(6)
    .width(75)
    .border({
      width: 1,
      color: color,
      style: BorderStyle.Solid
    })
    .shadow({
      radius: 2,
      color: '#00000008',
      offsetX: 0,
      offsetY: 1
    })
  }

  // =====================================
  // 数据表格组件
  // =====================================

  @Builder
  DataTable() {
    Column() {
      // 表格标题和分页控制
      Row() {
        Text('详细数据')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .alignSelf(ItemAlign.Start)

        Blank()

        Text(`共 ${this.lineChartData?.sensorName?.length || 0} 个传感器`)
          .fontSize(12)
          .fontColor('#666')
          .margin({ right: 8 })

        if (this.lineChartData && this.lineChartData.sensorName.length > this.pageSize) {
          Row() {
            Button('上一页')
              .fontSize(12)
              .backgroundColor(this.currentPage > 0 ? '#4852C9' : '#d9d9d9')
              .enabled(this.currentPage > 0)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick(() => {
                if (this.currentPage > 0) {
                  this.currentPage--
                }
              })
              .margin({ right: 8 })

            Text(`${this.currentPage + 1}/${this.getTotalPages()}`)
              .fontSize(12)
              .fontColor('#666')
              .margin({ right: 8 })

            Button('下一页')
              .fontSize(12)
              .backgroundColor(this.currentPage < this.getTotalPages() - 1 ? '#4852C9' : '#d9d9d9')
              .enabled(this.currentPage < this.getTotalPages() - 1)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick(() => {
                if (this.currentPage < this.getTotalPages() - 1) {
                  this.currentPage++
                }
              })
          }
        }
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 显示所有数据的选项
      Row() {
        Button(this.pageSize === 1000 ? '分页显示' : '显示全部')
          .fontSize(12)
          .backgroundColor('#52c41a')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .onClick(() => {
            if (this.pageSize === 1000) {
              this.pageSize = 10
              this.currentPage = 0
            } else {
              this.pageSize = 1000 // 设置一个很大的数字来显示所有数据
              this.currentPage = 0
            }
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ bottom: 8 })

      // 表头
      Row() {
        Text('传感器')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .width(this.calculateColumnWidth('sensor'))
          .textAlign(TextAlign.Center)
        Text('最大值')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .width(this.calculateColumnWidth('max'))
          .textAlign(TextAlign.Center)
        Text('最小值')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .width(this.calculateColumnWidth('min'))
          .textAlign(TextAlign.Center)
        Text('平均值')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .width(this.calculateColumnWidth('avg'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12, left: 8, right: 8 })
      .backgroundColor('#e6f7ff')
      .borderRadius(6)
      .border({
        width: 1,
        color: '#d9d9d9'
      })

      // 数据行 - 使用分页数据
      if (this.lineChartData) {
        Text(`显示 ${this.getPagedSensorNames().length} / ${this.lineChartData.sensorName.length} 个传感器`)
          .fontSize(10)
          .fontColor('#999')
          .margin({ top: 8, bottom: 8 })

        ForEach(this.getPagedSensorNames(), (sensor: string, index: number) => {
          Row() {
            Text(sensor)
              .fontSize(12)
              .fontColor('#333')
              .width(this.calculateColumnWidth('sensor'))
              .textAlign(TextAlign.Center)
              .margin({ right: 4 })
            if (this.lineChartData) {
              Text(this.getSafeValue(this.lineChartData.maxData[this.getRealIndex(index)]).toFixed(2))
                .fontSize(12)
                .fontColor('#f5222d')
                .fontWeight(FontWeight.Medium)
                .width(this.calculateColumnWidth('max'))
                .textAlign(TextAlign.Center)
                .margin({ right: 4 })
              Text(this.getSafeValue(this.lineChartData.minData[this.getRealIndex(index)]).toFixed(2))
                .fontSize(12)
                .fontColor('#52c41a')
                .fontWeight(FontWeight.Medium)
                .width(this.calculateColumnWidth('min'))
                .textAlign(TextAlign.Center)
                .margin({ right: 4 })
              Text(this.getSafeValue(this.lineChartData.avgData[this.getRealIndex(index)]).toFixed(2))
                .fontSize(12)
                .fontColor('#faad14')
                .fontWeight(FontWeight.Medium)
                .width(this.calculateColumnWidth('avg'))
                .textAlign(TextAlign.Center)
            }
          }
          .width('100%')
          .padding({ top: 10, bottom: 10, left: 8, right: 8 })
          .backgroundColor(index % 2 === 0 ? '#fafafa' : Color.White)
          .border({
            width: { bottom: 1 },
            color: '#f0f0f0'
          })
        })
      }
    }
    .width('100%')
    .margin({ top: 16 })
    .backgroundColor(Color.White)
    .borderRadius(8)
    .border({
      width: 1,
      color: '#d9d9d9'
    })
    .shadow({
      radius: 2,
      color: '#00000008',
      offsetX: 0,
      offsetY: 1
    })
  }

  // 分页相关辅助方法
  getTotalPages(): number {
    if (!this.lineChartData || !this.lineChartData.sensorName) {
      return 1
    }
    return Math.ceil(this.lineChartData.sensorName.length / this.pageSize)
  }

  getPagedSensorNames(): string[] {
    if (!this.lineChartData || !this.lineChartData.sensorName) {
      return []
    }

    let startIndex = this.currentPage * this.pageSize
    let endIndex = Math.min(startIndex + this.pageSize, this.lineChartData.sensorName.length)
    return this.lineChartData.sensorName.slice(startIndex, endIndex)
  }

  getRealIndex(pagedIndex: number): number {
    return this.currentPage * this.pageSize + pagedIndex
  }

  calculateColumnWidth(type: string): string {
    switch (type) {
      case 'sensor': return '40%'
      case 'max': return '20%'
      case 'min': return '20%'
      case 'avg': return '20%'
      default: return '25%'
    }
  }

  // =====================================
  // 数据分布视图
  // =====================================

  @Builder
  DistributionView() {
    Column() {
      // 标题区域
      Row() {
        Column() {
          if (this.distributionData?.sensorTypeDesc && this.distributionData.sensorTypeDesc !== '全部传感器') {
            Text(`${this.distributionData.sensorTypeDesc}分布分析`)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a1a')
          } else {
            Text('数值分布分析')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a1a')
          }

          if (this.distributionData?.sensorUnit) {
            Text(`${this.distributionData.sensorTypeDesc || '传感器'}数据区间分布统计 (${this.distributionData.sensorUnit})`)
              .fontSize(12)
              .fontColor('#666')
              .margin({ top: 2 })
          } else {
            Text('传感器数据区间分布统计')
              .fontSize(12)
              .fontColor('#666')
              .margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Stack() {
          Circle({ width: 40, height: 40 })
            .fill('#e6f7ff')
          Text('🥧')
            .fontSize(20)
        }
      }
      .width('100%')
      .margin({ bottom: 20 })

      if (this.loadingDistribution) {
        // 加载状态
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#52c41a')

          Text('数据分析中...')
            .fontSize(14)
            .fontColor('#666')
            .margin({ top: 8 })
        }
        .width('100%')
        .height(300)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.distributionData && this.distributionData.xData.length > 0) {
        // 数据总览卡片
        Row() {
          this.DistributionSummaryCard('数据区间', this.distributionData.xData.length.toString(), '#1890ff')
          this.DistributionSummaryCard('样本数量', (this.distributionData.totalCount || 0).toString(), '#52c41a')
          this.DistributionSummaryCard('最高占比', this.getMaxPercentage().toFixed(1) + '%', '#f5222d')
          this.DistributionSummaryCard('平均占比', this.getAvgPercentage().toFixed(1) + '%', '#faad14')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 24 })

        // 饼状图和图例
        Row() {
          Column() {
            Text('区间分布饼状图')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')
              .margin({ bottom: 16 })
              .alignSelf(ItemAlign.Start)

            Stack() {
              Canvas(this.pieContext)
                .width(200)
                .height(200)
                .backgroundColor('#fafafa')
                .onReady(() => {
                  this.drawPieChart()
                })
            }
            .width(200)
            .height(200)
            .borderRadius(100)
            .border({
              width: 1,
              color: '#e8e8e8'
            })
          }
          .width('50%')
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text('数据详情')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')
              .margin({ bottom: 12 })
              .alignSelf(ItemAlign.Start)

            ForEach(this.distributionData.xData || [], (range: string, index: number) => {
              this.PieLegendItem(range, this.getSafeValue(this.distributionData!.yData[index]), index)
            })
          }
          .width('50%')
          .padding({ left: 16 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#fafafa')
        .borderRadius(12)
        .margin({ bottom: 16 })
        .alignItems(VerticalAlign.Top)

        // 分析说明
        if (this.distributionData.analysisNote) {
          Column() {
            Text('分析说明')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')
              .margin({ bottom: 12 })
              .alignSelf(ItemAlign.Start)

            Text(this.distributionData.analysisNote)
              .fontSize(12)
              .fontColor('#666')
              .lineHeight(18)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#f6ffed')
          .borderRadius(8)
          .border({
            width: 1,
            color: '#d9f7be'
          })
          .margin({ bottom: 16 })
        }

        this.DistributionLegend()

      } else {
        Column() {
          Stack() {
            Circle({ width: 80, height: 80 })
              .fill('#f0f0f0')
            Text('📈')
              .fontSize(40)
              .opacity(0.6)
          }
          .margin({ bottom: 16 })

          Text(`暂无${this.getSensorTypeName(this.distributionSensorType)}分布数据`)
            .fontSize(16)
            .fontColor('#999')
            .margin({ bottom: 8 })

          Text('数据加载中或暂无相关统计信息')
            .fontSize(12)
            .fontColor('#ccc')

          Button('重新加载')
            .fontSize(14)
            .backgroundColor('#52c41a')
            .borderRadius(20)
            .margin({ top: 16 })
            .onClick(async () => {
              this.loadingDistribution = true
              try {
                let distributionData = await this.loadDistribution()
                if (distributionData && this.validateDistributionData(distributionData)) {
                  this.distributionData = distributionData
                }
              } catch (error) {
                console.error('手动加载分布数据失败:', error)
              } finally {
                this.loadingDistribution = false
              }
            })
        }
        .width('100%')
        .height(300)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .margin(16)
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }

  // =====================================
  // 饼状图绘制方法
  // =====================================

  private drawPieChart() {
    if (!this.distributionData || !this.pieContext) {
      return
    }

    let canvasSize = 200
    let centerX = canvasSize / 2
    let centerY = canvasSize / 2
    let radius = 70

    this.pieContext.clearRect(0, 0, canvasSize, canvasSize)
    this.pieContext.fillStyle = '#fafafa'
    this.pieContext.fillRect(0, 0, canvasSize, canvasSize)

    let total = 0
    for (let i = 0; i < this.distributionData.yData.length; i++) {
      total += this.getSafeValue(this.distributionData.yData[i])
    }

    if (total === 0) {
      this.pieContext.strokeStyle = '#ddd'
      this.pieContext.lineWidth = 2
      this.pieContext.beginPath()
      this.pieContext.arc(centerX, centerY, radius, 0, 2 * Math.PI)
      this.pieContext.stroke()
      return
    }

    let currentAngle = -Math.PI / 2

    for (let i = 0; i < this.distributionData.yData.length; i++) {
      let value = this.getSafeValue(this.distributionData.yData[i])
      let percentage = value / total
      let sliceAngle = percentage * 2 * Math.PI

      this.pieContext.fillStyle = this.getDistributionColor(i)
      this.pieContext.beginPath()
      this.pieContext.moveTo(centerX, centerY)
      this.pieContext.arc(centerX, centerY, radius, currentAngle, currentAngle + sliceAngle)
      this.pieContext.closePath()
      this.pieContext.fill()

      this.pieContext.strokeStyle = '#fff'
      this.pieContext.lineWidth = 2
      this.pieContext.stroke()

      if (percentage > 0.05) {
        let labelAngle = currentAngle + sliceAngle / 2
        let labelX = centerX + Math.cos(labelAngle) * (radius * 0.7)
        let labelY = centerY + Math.sin(labelAngle) * (radius * 0.7)

        this.pieContext.fillStyle = '#fff'
        this.pieContext.font = 'bold 12px sans-serif'
        this.pieContext.textAlign = 'center'
        this.pieContext.textBaseline = 'middle'
        this.pieContext.fillText(`${(percentage * 100).toFixed(1)}%`, labelX, labelY)
      }

      currentAngle += sliceAngle
    }

    this.pieContext.fillStyle = '#fafafa'
    this.pieContext.beginPath()
    this.pieContext.arc(centerX, centerY, 25, 0, 2 * Math.PI)
    this.pieContext.fill()

    this.pieContext.fillStyle = '#333'
    this.pieContext.font = 'bold 14px sans-serif'
    this.pieContext.textAlign = 'center'
    this.pieContext.textBaseline = 'middle'
    this.pieContext.fillText('分布', centerX, centerY)
  }

  @Builder
  PieLegendItem(range: string, percentage: number, index: number) {
    Row() {
      Circle({ width: 12, height: 12 })
        .fill(this.getDistributionColor(index))
        .margin({ right: 8 })

      Column() {
        if (this.distributionData?.sensorUnit) {
          Text(`${range}${this.distributionData.sensorUnit}`)
            .fontSize(12)
            .fontColor('#333')
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .textAlign(TextAlign.Start)
        } else {
          Text(range)
            .fontSize(12)
            .fontColor('#333')
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .textAlign(TextAlign.Start)
        }

        Text(`${(percentage * 100).toFixed(1)}%`)
          .fontSize(11)
          .fontColor('#666')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 4, bottom: 4, left: 8, right: 8 })
    .backgroundColor(Color.White)
    .borderRadius(6)
    .margin({ bottom: 6 })
    .border({
      width: 1,
      color: '#f0f0f0'
    })
    .shadow({
      radius: 1,
      color: '#00000005',
      offsetX: 0,
      offsetY: 1
    })
  }

  @Builder
  DistributionSummaryCard(title: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(title)
        .fontSize(10)
        .fontColor('#666')
        .margin({ top: 4 })
    }
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .width(70)
    .border({
      width: 1,
      color: color,
      style: BorderStyle.Solid
    })
    .shadow({
      radius: 4,
      color: '#00000008',
      offsetX: 0,
      offsetY: 1
    })
  }

  @Builder
  DistributionLegend() {
    Column() {
      Text('分布说明')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Row() {
        this.DistributionLegendItem('高分布区间', '#ff4d4f', '占比超过25%')
        this.DistributionLegendItem('中分布区间', '#faad14', '占比15%-25%')
        this.DistributionLegendItem('低分布区间', '#52c41a', '占比低于15%')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)

      if (this.distributionData?.sensorType && this.distributionData.sensorType !== 'ALL') {
        Text(`* ${this.distributionData.sensorTypeDesc || '传感器'}数据基于当前时间段内的传感器数值统计分析`)
          .fontSize(10)
          .fontColor('#999')
          .margin({ top: 12 })
          .textAlign(TextAlign.Center)
          .width('100%')
      } else {
        Text('* 数据基于当前时间段内的传感器数值统计分析')
          .fontSize(10)
          .fontColor('#999')
          .margin({ top: 12 })
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#f8fffe')
    .borderRadius(8)
    .border({
      width: 1,
      color: '#e6fffb'
    })
  }

  @Builder
  DistributionLegendItem(label: string, color: string, description: string) {
    Column() {
      Row() {
        Circle({ width: 8, height: 8 })
          .fill(color)
          .margin({ right: 6 })

        Text(label)
          .fontSize(11)
          .fontColor('#333')
          .fontWeight(FontWeight.Medium)
      }
      .margin({ bottom: 4 })

      Text(description)
        .fontSize(9)
        .fontColor('#666')
        .textAlign(TextAlign.Center)
        .width(80)
    }
    .alignItems(HorizontalAlign.Center)
  }

  // =====================================
  // 预警分析视图 - 完整版本
  // =====================================

  @Builder
  WarningView() {
    Column() {
      // 标题区域
      Row() {
        Column() {
          Text('预警分析统计')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a1a')

          Text('各构件预警级别分布情况')
            .fontSize(12)
            .fontColor('#666')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Stack() {
          Circle({ width: 40, height: 40 })
            .fill('#fff1f0')
          Text('⚠️')
            .fontSize(20)
        }
      }
      .width('100%')
      .margin({ bottom: 20 })

      if (this.warningData && this.warningData.fabricateName.length > 0) {
        // 预警统计概览
        Row() {
          this.WarningSummaryCard('总预警数', this.getTotalWarnings().toString(), '#ff4d4f')
          this.WarningSummaryCard('构件数量', this.warningData.fabricateName.length.toString(), '#1890ff')
          this.WarningSummaryCard('最高级别', this.getHighestLevel().toString() + '级', '#faad14')
          this.WarningSummaryCard('平均预警', this.getAverageWarnings().toFixed(1), '#52c41a')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 24 })

        // 预警条形图
        Column() {
          Text('预警级别分布图')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Stack() {
            Canvas(this.warningContext)
              .width('100%')
              .height(280)
              .backgroundColor('#fafafa')
              .onReady(() => {
                this.drawWarningChart()
              })
          }
          .width('100%')
          .height(280)
          .borderRadius(12)
          .border({
            width: 1,
            color: '#e8e8e8'
          })
          .margin({ bottom: 16 })

          // 图例
          Row() {
            this.LegendItem('1级预警', '#52c41a')
            this.LegendItem('2级预警', '#faad14')
            this.LegendItem('3级预警', '#ff4d4f')
            this.LegendItem('总计', '#1890ff')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(12)
        .margin({ bottom: 16 })

        // 详细数据卡片
        ForEach(this.warningData.fabricateName || [], (fabricate: string, index: number) => {
          this.WarningDetailCard(fabricate, index)
        })

        // 预警分析说明
        this.WarningAnalysisNote()

      } else {
        // 无数据状态
        Column() {
          Stack() {
            Circle({ width: 80, height: 80 })
              .fill('#fff1f0')
            Text('⚠️')
              .fontSize(40)
              .opacity(0.6)
          }
          .margin({ bottom: 16 })

          Text('暂无预警数据')
            .fontSize(16)
            .fontColor('#999')
            .margin({ bottom: 8 })

          Text('当前时间段内无预警记录')
            .fontSize(12)
            .fontColor('#ccc')

          Button('重新加载')
            .fontSize(14)
            .backgroundColor('#4852C9')
            .borderRadius(20)
            .margin({ top: 16 })
            .onClick(() => {
              this.loadAllData()
            })
        }
        .width('100%')
        .height(300)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .margin(16)
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }

  // 绘制预警条形图
  private drawWarningChart() {
    if (!this.warningData || !this.warningContext) {
      return
    }

    let canvasWidth = 320
    let canvasHeight = 280
    let padding = { left: 80, right: 30, top: 30, bottom: 60 }
    let chartWidth = canvasWidth - padding.left - padding.right
    let chartHeight = canvasHeight - padding.top - padding.bottom

    // 清空画布
    this.warningContext.clearRect(0, 0, canvasWidth, canvasHeight)
    this.warningContext.fillStyle = '#fafafa'
    this.warningContext.fillRect(0, 0, canvasWidth, canvasHeight)

    // 计算最大值
    let maxValue = 0
    for (let i = 0; i < this.warningData.totalNum.length; i++) {
      let total = this.getSafeValue(this.warningData.totalNum[i])
      if (total > maxValue) {
        maxValue = total
      }
    }
    maxValue = Math.max(maxValue, 1)

    // 绘制网格线
    this.warningContext.strokeStyle = '#e0e0e0'
    this.warningContext.lineWidth = 0.5
    for (let i = 0; i <= 5; i++) {
      let y = padding.top + (chartHeight * i / 5)
      this.warningContext.beginPath()
      this.warningContext.moveTo(padding.left, y)
      this.warningContext.lineTo(padding.left + chartWidth, y)
      this.warningContext.stroke()
    }

    // 绘制坐标轴
    this.warningContext.strokeStyle = '#333'
    this.warningContext.lineWidth = 1
    this.warningContext.beginPath()
    this.warningContext.moveTo(padding.left, padding.top)
    this.warningContext.lineTo(padding.left, padding.top + chartHeight)
    this.warningContext.lineTo(padding.left + chartWidth, padding.top + chartHeight)
    this.warningContext.stroke()

    // 绘制Y轴标签
    this.warningContext.fillStyle = '#666'
    this.warningContext.font = '12px sans-serif'
    this.warningContext.textAlign = 'right'
    for (let i = 0; i <= 5; i++) {
      let value = maxValue - (maxValue * i / 5)
      let y = padding.top + (chartHeight * i / 5) + 4
      this.warningContext.fillText(Math.round(value).toString(), padding.left - 10, y)
    }

    // 绘制条形图
    let barWidth = chartWidth / this.warningData.fabricateName.length * 0.8
    let barSpacing = chartWidth / this.warningData.fabricateName.length * 0.2

    for (let i = 0; i < this.warningData.fabricateName.length; i++) {
      let x = padding.left + (chartWidth / this.warningData.fabricateName.length) * i + barSpacing / 2

      // 绘制各级别预警条
      let level1 = this.getSafeValue(this.warningData.level1Num[i])
      let level2 = this.getSafeValue(this.warningData.level2Num[i])
      let level3 = this.getSafeValue(this.warningData.level3Num[i])

      let currentY = padding.top + chartHeight

      // 3级预警（底部，红色）
      if (level3 > 0) {
        let height = (level3 / maxValue) * chartHeight
        this.warningContext.fillStyle = '#ff4d4f'
        this.warningContext.fillRect(x, currentY - height, barWidth, height)
        currentY -= height
      }

      // 2级预警（中间，橙色）
      if (level2 > 0) {
        let height = (level2 / maxValue) * chartHeight
        this.warningContext.fillStyle = '#faad14'
        this.warningContext.fillRect(x, currentY - height, barWidth, height)
        currentY -= height
      }

      // 1级预警（顶部，绿色）
      if (level1 > 0) {
        let height = (level1 / maxValue) * chartHeight
        this.warningContext.fillStyle = '#52c41a'
        this.warningContext.fillRect(x, currentY - height, barWidth, height)
      }

      // 绘制条形图边框
      this.warningContext.strokeStyle = '#fff'
      this.warningContext.lineWidth = 1
      let totalHeight = ((level1 + level2 + level3) / maxValue) * chartHeight
      this.warningContext.strokeRect(x, padding.top + chartHeight - totalHeight, barWidth, totalHeight)

      // 绘制X轴标签
      this.warningContext.fillStyle = '#666'
      this.warningContext.font = '10px sans-serif'
      this.warningContext.textAlign = 'center'
      let label = this.warningData.fabricateName[i]
      let displayLabel = label.length > 8 ? label.substring(0, 8) + '..' : label
      this.warningContext.fillText(displayLabel, x + barWidth / 2, padding.top + chartHeight + 20)

      // 绘制数值标签
      let total = level1 + level2 + level3
      if (total > 0) {
        this.warningContext.fillStyle = '#333'
        this.warningContext.font = 'bold 11px sans-serif'
        this.warningContext.fillText(total.toString(), x + barWidth / 2, padding.top + chartHeight - totalHeight - 5)
      }
    }
  }

  @Builder
  WarningDetailCard(fabricate: string, index: number) {
    Column() {
      // 构件名称和总计
      Row() {
        Column() {
          Text(fabricate)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
            .margin({ bottom: 4 })
            .width('100%')
            .textAlign(TextAlign.Start)

          Text(`总预警: ${this.getSafeValue(this.warningData!.totalNum[index])}次`)
            .fontSize(12)
            .fontColor('#666')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 风险等级指示器
        Column() {
          Text(this.getWarningLevel(index))
            .fontSize(12)
            .fontColor('#fff')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.getWarningLevelColor(index))
            .borderRadius(10)
            .textAlign(TextAlign.Center)

          Text('风险等级')
            .fontSize(10)
            .fontColor('#999')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ bottom: 12 })

      // 预警级别详情
      Row() {
        this.WarningLevelCard('1级', this.getSafeValue(this.warningData!.level1Num[index]), '#52c41a', '正常')
        this.WarningLevelCard('2级', this.getSafeValue(this.warningData!.level2Num[index]), '#faad14', '注意')
        this.WarningLevelCard('3级', this.getSafeValue(this.warningData!.level3Num[index]), '#ff4d4f', '严重')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      // 预警占比进度条
      Column() {
        Text('预警分布')
          .fontSize(12)
          .fontColor('#666')
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        this.WarningProgressBar(index)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#fafafa')
    .borderRadius(12)
    .margin({ bottom: 12 })
    .border({
      width: 1,
      color: '#f0f0f0'
    })
    .shadow({
      radius: 2,
      color: '#00000008',
      offsetX: 0,
      offsetY: 1
    })
  }

  @Builder
  WarningProgressBar(index: number) {
    if (!this.warningData) {
      Row() {
        Text('暂无预警数据')
          .fontSize(10)
          .fontColor('#999')
      }
      .width('100%')
      .height(20)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#f5f5f5')
      .borderRadius(10)
    } else {
      Column() {
        if (this.getWarningTotal(index) === 0) {
          Row() {
            Text('暂无预警数据')
              .fontSize(10)
              .fontColor('#999')
          }
          .width('100%')
          .height(20)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#f5f5f5')
          .borderRadius(10)
        } else {
          Row() {
            // 1级预警
            if (this.getLevel1Percent(index) > 0) {
              Row()
                .width(`${this.getLevel1Percent(index)}%`)
                .height(8)
                .backgroundColor('#52c41a')
            }

            // 2级预警
            if (this.getLevel2Percent(index) > 0) {
              Row()
                .width(`${this.getLevel2Percent(index)}%`)
                .height(8)
                .backgroundColor('#faad14')
            }

            // 3级预警
            if (this.getLevel3Percent(index) > 0) {
              Row()
                .width(`${this.getLevel3Percent(index)}%`)
                .height(8)
                .backgroundColor('#ff4d4f')
            }
          }
          .width('100%')
          .height(8)
          .borderRadius(4)
          .backgroundColor('#f0f0f0')

          // 百分比标签
          Row() {
            if (this.getLevel1Percent(index) > 0) {
              Text(`1级: ${this.getLevel1Percent(index).toFixed(1)}%`)
                .fontSize(9)
                .fontColor('#52c41a')
            }
            if (this.getLevel2Percent(index) > 0) {
              Text(`2级: ${this.getLevel2Percent(index).toFixed(1)}%`)
                .fontSize(9)
                .fontColor('#faad14')
                .margin({ left: 8 })
            }
            if (this.getLevel3Percent(index) > 0) {
              Text(`3级: ${this.getLevel3Percent(index).toFixed(1)}%`)
                .fontSize(9)
                .fontColor('#ff4d4f')
                .margin({ left: 8 })
            }
          }
          .width('100%')
          .margin({ top: 4 })
        }
      }
    }
  }

  @Builder
  WarningSummaryCard(title: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(title)
        .fontSize(10)
        .fontColor('#666')
        .margin({ top: 4 })
    }
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .width(70)
    .border({
      width: 1,
      color: color,
      style: BorderStyle.Solid
    })
    .shadow({
      radius: 4,
      color: '#00000008',
      offsetX: 0,
      offsetY: 1
    })
  }

  @Builder
  WarningLevelCard(title: string, count: number, color: string, description: string) {
    Column() {
      Text(Math.round(count).toString())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(title)
        .fontSize(11)
        .fontColor('#333')
        .margin({ top: 2 })

      Text(description)
        .fontSize(9)
        .fontColor('#999')
        .margin({ top: 1 })
    }
    .padding(8)
    .backgroundColor(Color.White)
    .borderRadius(6)
    .width(70)
    .border({
      width: 1,
      color: color,
      style: BorderStyle.Solid
    })
  }

  @Builder
  WarningAnalysisNote() {
    Column() {
      Text('预警分析说明')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Row() {
        this.AnalysisNoteItem('🟢', '1级预警', '设备状态正常，定期监测')
        this.AnalysisNoteItem('🟡', '2级预警', '需要关注，加强监测频率')
        this.AnalysisNoteItem('🔴', '3级预警', '紧急情况，立即处理')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)

      Text('* 预警级别基于传感器数据异常程度自动判定，建议及时关注高级别预警')
        .fontSize(10)
        .fontColor('#999')
        .margin({ top: 12 })
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#f6ffed')
    .borderRadius(8)
    .border({
      width: 1,
      color: '#d9f7be'
    })
    .margin({ top: 16 })
  }

  @Builder
  AnalysisNoteItem(icon: string, title: string, description: string) {
    Column() {
      Text(icon)
        .fontSize(16)
        .margin({ bottom: 4 })

      Text(title)
        .fontSize(11)
        .fontColor('#333')
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 2 })

      Text(description)
        .fontSize(9)
        .fontColor('#666')
        .textAlign(TextAlign.Center)
        .width(80)
    }
    .alignItems(HorizontalAlign.Center)
  }

  // =====================================
  // 月度预警视图 - 完整版本
  // =====================================

  @Builder
  MonthWarningView() {
    Column() {
      // 标题区域
      Row() {
        Column() {
          Text('月度预警趋势')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a1a')

          Text('全年预警数据变化趋势分析')
            .fontSize(12)
            .fontColor('#666')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Stack() {
          Circle({ width: 40, height: 40 })
            .fill('#e6f7ff')
          Text('📈')
            .fontSize(20)
        }
      }
      .width('100%')
      .margin({ bottom: 20 })

      if (this.warningMonthData && this.warningMonthData.fabricateName.length > 0) {
        // 月度统计概览
        Row() {
          this.MonthSummaryCard('年度总计', this.getYearTotalWarnings().toString(), '#1890ff')
          this.MonthSummaryCard('峰值月份', this.getPeakMonth(), '#ff4d4f')
          this.MonthSummaryCard('活跃月数', this.getActiveMonths().toString(), '#52c41a')
          this.MonthSummaryCard('月均预警', this.getMonthAverage().toFixed(1), '#faad14')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 24 })

        // 月度趋势图
        Column() {
          Text('月度预警趋势图')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Stack() {
            Canvas(this.monthContext)
              .width('100%')
              .height(300)
              .backgroundColor('#fafafa')
              .onReady(() => {
                this.drawMonthTrendChart()
              })
          }
          .width('100%')
          .height(300)
          .borderRadius(12)
          .border({
            width: 1,
            color: '#e8e8e8'
          })
          .margin({ bottom: 16 })

          // 图例
          Row() {
            this.LegendItem('总预警', '#1890ff')
            this.LegendItem('1级预警', '#52c41a')
            this.LegendItem('2级预警', '#faad14')
            this.LegendItem('3级预警', '#ff4d4f')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(Color.White)
        .borderRadius(12)
        .margin({ bottom: 16 })

        // 月度详细数据
        this.MonthDetailList()

        // 趋势分析说明
        this.MonthTrendAnalysis()

      } else {
        // 无数据状态
        Column() {
          Stack() {
            Circle({ width: 80, height: 80 })
              .fill('#e6f7ff')
            Text('📈')
              .fontSize(40)
              .opacity(0.6)
          }
          .margin({ bottom: 16 })

          Text('暂无月度数据')
            .fontSize(16)
            .fontColor('#999')
            .margin({ bottom: 8 })

          Text('本年度暂无预警记录')
            .fontSize(12)
            .fontColor('#ccc')

          Button('重新加载')
            .fontSize(14)
            .backgroundColor('#4852C9')
            .borderRadius(20)
            .margin({ top: 16 })
            .onClick(() => {
              this.loadAllData()
            })
        }
        .width('100%')
        .height(300)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .margin(16)
    .shadow({
      radius: 8,
      color: '#00000010',
      offsetX: 0,
      offsetY: 2
    })
  }

  // 绘制月度趋势图
  private drawMonthTrendChart() {
    if (!this.warningMonthData || !this.monthContext) {
      return
    }

    let canvasWidth = 320
    let canvasHeight = 300
    let padding = { left: 50, right: 30, top: 30, bottom: 50 }
    let chartWidth = canvasWidth - padding.left - padding.right
    let chartHeight = canvasHeight - padding.top - padding.bottom

    // 清空画布
    this.monthContext.clearRect(0, 0, canvasWidth, canvasHeight)
    this.monthContext.fillStyle = '#fafafa'
    this.monthContext.fillRect(0, 0, canvasWidth, canvasHeight)

    // 计算最大值
    let maxValue = 0
    for (let i = 0; i < this.warningMonthData.totalNum.length; i++) {
      let total = this.getSafeValue(this.warningMonthData.totalNum[i])
      if (total > maxValue) {
        maxValue = total
      }
    }
    maxValue = Math.max(maxValue, 1)

    // 绘制网格线
    this.monthContext.strokeStyle = '#e0e0e0'
    this.monthContext.lineWidth = 0.5
    for (let i = 0; i <= 5; i++) {
      let y = padding.top + (chartHeight * i / 5)
      this.monthContext.beginPath()
      this.monthContext.moveTo(padding.left, y)
      this.monthContext.lineTo(padding.left + chartWidth, y)
      this.monthContext.stroke()
    }

    // 绘制坐标轴
    this.monthContext.strokeStyle = '#333'
    this.monthContext.lineWidth = 1
    this.monthContext.beginPath()
    this.monthContext.moveTo(padding.left, padding.top)
    this.monthContext.lineTo(padding.left, padding.top + chartHeight)
    this.monthContext.lineTo(padding.left + chartWidth, padding.top + chartHeight)
    this.monthContext.stroke()

    // 绘制Y轴标签
    this.monthContext.fillStyle = '#666'
    this.monthContext.font = '12px sans-serif'
    this.monthContext.textAlign = 'right'
    for (let i = 0; i <= 5; i++) {
      let value = maxValue - (maxValue * i / 5)
      let y = padding.top + (chartHeight * i / 5) + 4
      this.monthContext.fillText(Math.round(value).toString(), padding.left - 10, y)
    }

    // 绘制月度折线图
    this.drawMonthLines(padding, chartWidth, chartHeight, maxValue)

    // 绘制X轴月份标签
    this.monthContext.fillStyle = '#666'
    this.monthContext.font = '10px sans-serif'
    this.monthContext.textAlign = 'center'
    for (let i = 0; i < this.warningMonthData.fabricateName.length; i++) {
      let x = padding.left + (chartWidth * i / (this.warningMonthData.fabricateName.length - 1))
      let month = this.warningMonthData.fabricateName[i]
      this.monthContext.fillText(month, x, padding.top + chartHeight + 20)
    }
  }

  private drawMonthLines(padding: any, chartWidth: number, chartHeight: number, maxValue: number) {
    if (!this.warningMonthData) return

    // 绘制总预警趋势线
    this.drawMonthLine(this.warningMonthData.totalNum, '#1890ff', padding, chartWidth, chartHeight, maxValue, 3)

    // 绘制各级别预警趋势线
    this.drawMonthLine(this.warningMonthData.level1Num, '#52c41a', padding, chartWidth, chartHeight, maxValue, 2)
    this.drawMonthLine(this.warningMonthData.level2Num, '#faad14', padding, chartWidth, chartHeight, maxValue, 2)
    this.drawMonthLine(this.warningMonthData.level3Num, '#ff4d4f', padding, chartWidth, chartHeight, maxValue, 2)

    // 绘制数据点
    this.drawMonthPoints(this.warningMonthData.totalNum, '#1890ff', padding, chartWidth, chartHeight, maxValue, 4)
    this.drawMonthPoints(this.warningMonthData.level1Num, '#52c41a', padding, chartWidth, chartHeight, maxValue, 3)
    this.drawMonthPoints(this.warningMonthData.level2Num, '#faad14', padding, chartWidth, chartHeight, maxValue, 3)
    this.drawMonthPoints(this.warningMonthData.level3Num, '#ff4d4f', padding, chartWidth, chartHeight, maxValue, 3)
  }

  private drawMonthLine(data: number[], color: string, padding: any, chartWidth: number, chartHeight: number, maxValue: number, lineWidth: number) {
    if (data.length < 2) return

    this.monthContext.strokeStyle = color
    this.monthContext.lineWidth = lineWidth

    this.monthContext.beginPath()
    for (let i = 0; i < data.length; i++) {
      let x = padding.left + (chartWidth * i / (data.length - 1))
      let y = padding.top + chartHeight - ((this.getSafeValue(data[i]) / maxValue) * chartHeight)

      if (i === 0) {
        this.monthContext.moveTo(x, y)
      } else {
        this.monthContext.lineTo(x, y)
      }
    }
    this.monthContext.stroke()
  }

  private drawMonthPoints(data: number[], color: string, padding: any, chartWidth: number, chartHeight: number, maxValue: number, radius: number) {
    this.monthContext.fillStyle = color
    this.monthContext.strokeStyle = '#fff'
    this.monthContext.lineWidth = 1

    for (let i = 0; i < data.length; i++) {
      let value = this.getSafeValue(data[i])
      if (value > 0) { // 只绘制有数据的点
        let x = padding.left + (chartWidth * i / (data.length - 1))
        let y = padding.top + chartHeight - ((value / maxValue) * chartHeight)

        this.monthContext.beginPath()
        this.monthContext.arc(x, y, radius, 0, 2 * Math.PI)
        this.monthContext.fill()
        this.monthContext.stroke()

        // 显示数值标签
        if (value > 0) {
          this.monthContext.fillStyle = color
          this.monthContext.font = 'bold 10px sans-serif'
          this.monthContext.textAlign = 'center'
          this.monthContext.fillText(value.toString(), x, y - 8)
        }
      }
    }
  }

  @Builder
  MonthDetailList() {
    Column() {
      Text('月度详细数据')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      ForEach(this.warningMonthData?.fabricateName || [], (month: string, index: number) => {
        this.MonthDetailItem(month, index)
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#fafafa')
    .borderRadius(12)
    .margin({ bottom: 16 })
  }

  @Builder
  MonthDetailItem(month: string, index: number) {
    if (this.warningMonthData) {
      Row() {
        // 月份
        Text(month)
          .fontSize(14)
          .fontColor(this.getMonthHasData(index) ? '#333' : '#999')
          .fontWeight(this.getMonthHasData(index) ? FontWeight.Medium : FontWeight.Normal)
          .width(60)

        // 预警数据
        Row() {
          this.MonthWarningCard('总计', this.getMonthTotal(index), this.getMonthHasData(index) ? '#1890ff' : '#d9d9d9')
          this.MonthWarningCard('1级', this.getMonthLevel1(index), this.getMonthHasData(index) ? '#52c41a' : '#d9d9d9')
          this.MonthWarningCard('2级', this.getMonthLevel2(index), this.getMonthHasData(index) ? '#faad14' : '#d9d9d9')
          this.MonthWarningCard('3级', this.getMonthLevel3(index), this.getMonthHasData(index) ? '#ff4d4f' : '#d9d9d9')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.SpaceBetween)

        // 环比变化
        if (this.warningMonthData.mom && this.warningMonthData.mom[index] !== null && this.warningMonthData.mom[index] !== undefined) {
          Text(`${this.getMonthMomValue(index) > 0 ? '+' : ''}${(this.getMonthMomValue(index) * 100).toFixed(1)}%`)
            .fontSize(11)
            .fontColor(this.getMonthMomValue(index) > 0 ? '#ff4d4f' : this.getMonthMomValue(index) < 0 ? '#52c41a' : '#999')
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.getMonthMomValue(index) > 0 ? '#fff1f0' : this.getMonthMomValue(index) < 0 ? '#f6ffed' : '#f5f5f5')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8)
            .width(60)
            .textAlign(TextAlign.Center)
        } else {
          Text('--')
            .fontSize(11)
            .fontColor('#ccc')
            .width(60)
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .padding({ top: 8, bottom: 8, left: 12, right: 12 })
      .backgroundColor(this.getMonthHasData(index) ? Color.White : '#f8f8f8')
      .borderRadius(8)
      .margin({ bottom: 6 })
      .border({
        width: this.getMonthHasData(index) ? 1 : 0,
        color: this.getMonthHasData(index) ? '#e8e8e8' : Color.Transparent
      })
      .shadow({
        radius: this.getMonthHasData(index) ? 1 : 0,
        color: '#00000005',
        offsetX: 0,
        offsetY: 1
      })
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  MonthSummaryCard(title: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(title)
        .fontSize(10)
        .fontColor('#666')
        .margin({ top: 4 })
    }
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .width(70)
    .border({
      width: 1,
      color: color,
      style: BorderStyle.Solid
    })
    .shadow({
      radius: 4,
      color: '#00000008',
      offsetX: 0,
      offsetY: 1
    })
  }

  @Builder
  MonthWarningCard(title: string, count: number, color: string) {
    Column() {
      Text(Math.round(count).toString())
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(title)
        .fontSize(10)
        .fontColor('#666')
    }
    .padding(4)
    .backgroundColor(Color.White)
    .borderRadius(4)
    .width(45)
  }

  @Builder
  MonthTrendAnalysis() {
    Column() {
      Text('趋势分析')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      // 分析卡片
      Column() {
        Row() {
          Column() {
            Text('📊')
              .fontSize(20)
              .margin({ bottom: 4 })
            Text('数据洞察')
              .fontSize(11)
              .fontColor('#666')
          }
          .width(60)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text(this.getTrendInsight())
              .fontSize(12)
              .fontColor('#333')
              .lineHeight(18)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Divider()
          .color('#f0f0f0')
          .margin({ top: 12, bottom: 12 })

        Row() {
          Column() {
            Text('💡')
              .fontSize(20)
              .margin({ bottom: 4 })
            Text('建议措施')
              .fontSize(11)
              .fontColor('#666')
          }
          .width(60)
          .alignItems(HorizontalAlign.Center)

          Column() {
            Text(this.getRecommendation())
              .fontSize(12)
              .fontColor('#333')
              .lineHeight(18)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#f0f9ff')
      .borderRadius(8)
      .border({
        width: 1,
        color: '#bae7ff'
      })
    }
    .width('100%')
    .margin({ top: 16 })
  }

  // =====================================
  // 工具方法 - 数据分布相关
  // =====================================

  private getDistributionColor(index: number): string {
    let colors = ['#1890ff', '#52c41a', '#faad14', '#f5222d', '#722ed1', '#13c2c2', '#eb2f96', '#fa8c16']
    return colors[index % colors.length]
  }

  private getMaxPercentage(): number {
    if (!this.distributionData || !this.distributionData.yData.length) {
      return 0
    }
    let validValues = this.distributionData.yData.filter(val => typeof val === 'number' && !isNaN(val))
    if (validValues.length === 0) return 0

    let maxVal = validValues[0]
    for (let i = 1; i < validValues.length; i++) {
      if (validValues[i] > maxVal) {
        maxVal = validValues[i]
      }
    }
    return maxVal * 100
  }

  private getMinPercentage(): number {
    if (!this.distributionData || !this.distributionData.yData.length) {
      return 0
    }
    let validValues = this.distributionData.yData.filter(val => typeof val === 'number' && !isNaN(val))
    if (validValues.length === 0) return 0

    let minVal = validValues[0]
    for (let i = 1; i < validValues.length; i++) {
      if (validValues[i] < minVal) {
        minVal = validValues[i]
      }
    }
    return minVal * 100
  }

  private getAvgPercentage(): number {
    if (!this.distributionData || !this.distributionData.yData.length) {
      return 0
    }
    let validValues = this.distributionData.yData.filter(val => typeof val === 'number' && !isNaN(val))
    if (validValues.length === 0) return 0

    let sum = validValues.reduce((a, b) => a + b, 0)
    return (sum / validValues.length) * 100
  }

  // =====================================
  // 预警相关工具方法
  // =====================================

  private getTotalWarnings(): number {
    if (!this.warningData) return 0
    return this.warningData.totalNum.reduce((sum, val) => sum + this.getSafeValue(val), 0)
  }

  private getHighestLevel(): number {
    if (!this.warningData) return 1
    let hasLevel3 = this.warningData.level3Num.some(val => this.getSafeValue(val) > 0)
    let hasLevel2 = this.warningData.level2Num.some(val => this.getSafeValue(val) > 0)
    return hasLevel3 ? 3 : hasLevel2 ? 2 : 1
  }

  private getAverageWarnings(): number {
    if (!this.warningData || this.warningData.fabricateName.length === 0) return 0
    return this.getTotalWarnings() / this.warningData.fabricateName.length
  }

  private getWarningTotal(index: number): number {
    if (!this.warningData) return 0
    return this.getSafeValue(this.warningData.totalNum[index])
  }

  private getLevel1Percent(index: number): number {
    if (!this.warningData) return 0
    let total = this.getWarningTotal(index)
    if (total === 0) return 0
    return (this.getSafeValue(this.warningData.level1Num[index]) / total) * 100
  }

  private getLevel2Percent(index: number): number {
    if (!this.warningData) return 0
    let total = this.getWarningTotal(index)
    if (total === 0) return 0
    return (this.getSafeValue(this.warningData.level2Num[index]) / total) * 100
  }

  private getLevel3Percent(index: number): number {
    if (!this.warningData) return 0
    let total = this.getWarningTotal(index)
    if (total === 0) return 0
    return (this.getSafeValue(this.warningData.level3Num[index]) / total) * 100
  }

  private getWarningLevel(index: number): string {
    if (!this.warningData) return '正常'
    let level3 = this.getSafeValue(this.warningData.level3Num[index])
    let level2 = this.getSafeValue(this.warningData.level2Num[index])
    let level1 = this.getSafeValue(this.warningData.level1Num[index])

    if (level3 > 0) return '高风险'
    if (level2 > 0) return '中风险'
    if (level1 > 0) return '低风险'
    return '正常'
  }

  private getWarningLevelColor(index: number): string {
    if (!this.warningData) return '#52c41a'
    let level3 = this.getSafeValue(this.warningData.level3Num[index])
    let level2 = this.getSafeValue(this.warningData.level2Num[index])
    let level1 = this.getSafeValue(this.warningData.level1Num[index])

    if (level3 > 0) return '#ff4d4f'
    if (level2 > 0) return '#faad14'
    if (level1 > 0) return '#52c41a'
    return '#d9d9d9'
  }

  // =====================================
  // 月度预警相关工具方法
  // =====================================

  private getYearTotalWarnings(): number {
    if (!this.warningMonthData) return 0
    return this.warningMonthData.totalNum.reduce((sum, val) => sum + this.getSafeValue(val), 0)
  }

  private getPeakMonth(): string {
    if (!this.warningMonthData || this.warningMonthData.totalNum.length === 0) return '--'
    let maxValue = 0
    let maxIndex = 0

    for (let i = 0; i < this.warningMonthData.totalNum.length; i++) {
      let value = this.getSafeValue(this.warningMonthData.totalNum[i])
      if (value > maxValue) {
        maxValue = value
        maxIndex = i
      }
    }

    return maxValue > 0 ? this.warningMonthData.fabricateName[maxIndex] : '--'
  }

  private getActiveMonths(): number {
    if (!this.warningMonthData) return 0
    return this.warningMonthData.totalNum.filter(val => this.getSafeValue(val) > 0).length
  }

  private getMonthAverage(): number {
    if (!this.warningMonthData || this.warningMonthData.fabricateName.length === 0) return 0
    let activeMonths = this.getActiveMonths()
    return activeMonths > 0 ? this.getYearTotalWarnings() / activeMonths : 0
  }

  private getMonthHasData(index: number): boolean {
    if (!this.warningMonthData) return false
    return this.getSafeValue(this.warningMonthData.totalNum[index]) > 0
  }

  private getMonthTotal(index: number): number {
    if (!this.warningMonthData) return 0
    return this.getSafeValue(this.warningMonthData.totalNum[index])
  }

  private getMonthLevel1(index: number): number {
    if (!this.warningMonthData) return 0
    return this.getSafeValue(this.warningMonthData.level1Num[index])
  }

  private getMonthLevel2(index: number): number {
    if (!this.warningMonthData) return 0
    return this.getSafeValue(this.warningMonthData.level2Num[index])
  }

  private getMonthLevel3(index: number): number {
    if (!this.warningMonthData) return 0
    return this.getSafeValue(this.warningMonthData.level3Num[index])
  }

  private getMonthMomValue(index: number): number {
    if (!this.warningMonthData || !this.warningMonthData.mom) return 0
    return this.warningMonthData.mom[index] || 0
  }

  private getTrendInsight(): string {
    if (!this.warningMonthData) return '暂无足够数据进行分析'

    let totalWarnings = this.getYearTotalWarnings()
    let activeMonths = this.getActiveMonths()
    let peakMonth = this.getPeakMonth()

    if (totalWarnings === 0) {
      return '本年度运行状态良好，未出现预警事件。建议继续保持定期监测和维护。'
    }

    if (activeMonths === 1) {
      return `预警主要集中在${peakMonth}，建议重点关注该时段的设备状态和环境因素。`
    }

    if (activeMonths <= 3) {
      return `预警相对集中，峰值出现在${peakMonth}。建议分析预警集中期的共同因素，制定针对性预防措施。`
    }

    return `预警分布较为分散，全年共${activeMonths}个月出现预警。建议建立长期监测机制，定期评估设备状态。`
  }

  private getRecommendation(): string {
    if (!this.warningMonthData) return '建议完善数据收集，确保监测系统正常运行'

    let totalWarnings = this.getYearTotalWarnings()
    let activeMonths = this.getActiveMonths()

    if (totalWarnings === 0) {
      return '继续保持现有的维护标准，建议定期进行预防性检查，确保系统稳定运行。'
    }

    if (totalWarnings > 50) {
      return '预警频次较高，建议：1) 加强日常巡检频率；2) 升级关键设备；3) 优化预警阈值设置。'
    }

    if (activeMonths > 6) {
      return '预警持续时间较长，建议：1) 深入分析根本原因；2) 制定长期改进计划；3) 加强人员培训。'
    }

    return '预警情况可控，建议：1) 持续监测预警趋势；2) 完善应急响应机制；3) 定期回顾和优化。'
  }
}
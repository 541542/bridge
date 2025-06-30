import request from '../../utils/httpUtils'
import promptAction from '@ohos.promptAction'

interface ApiResult {
  success: boolean
  message?: string
  data?: any
}

interface AlarmItem {
  alarmId: string
  structureName: string
  fabricateName: string
  detectionType: string
  alarmLevel: string
  alarmContent: string
  alarmTime: string
  updateTime: string
  status: number
}

interface AlarmListResult {
  total: number
  rows: AlarmItem[]
}

@Component
export struct EarlyWarning {
  @Link currentTab: string
  @State alarmList: AlarmItem[] = []
  @State loading: boolean = false
  @State refreshing: boolean = false
  @State filterStatus: number = -1 // -1: 全部, 0: 未处理, 1: 已处理
  @State filterLevel: string = '全部'
  @State selectedAlarm: AlarmItem | null = null
  @State showDialog: boolean = false
  @State filteredCount: number = 0 // 添加筛选结果计数

  aboutToAppear() {
    console.info('EarlyWarning 组件初始化')
    this.initializeMockAlarms()
    this.loadAlarmList()
  }

  initializeMockAlarms() {
    this.alarmList = [
      {
        alarmId: 'ALARM_001_2024090215491',
        structureName: '南京长江大桥',
        fabricateName: 'LA-1',
        detectionType: '应力',
        alarmLevel: '3级',
        alarmContent: '传感器测量值超过3级告警阈值:车重采集值:52.1T,超3级阈值[50.0~75.0]',
        alarmTime: '2024-09-02T15:49:11',
        updateTime: '2024-09-02T15:49:24',
        status: 0
      },
      {
        alarmId: 'ALARM_002_2024090215543',
        structureName: '高邮湖大桥',
        fabricateName: 'LB-2',
        detectionType: '索力',
        alarmLevel: '2级',
        alarmContent: '传感器测量值超过2级告警阈值:索力采集值:180kN,超2级阈值[150.0~200.0]',
        alarmTime: '2024-09-02T15:54:38',
        updateTime: '2024-09-02T15:54:36',
        status: 1
      },
      {
        alarmId: 'ALARM_003_2024090310234',
        structureName: '苏通长江大桥',
        fabricateName: 'LC-3',
        detectionType: '位移',
        alarmLevel: '3级',
        alarmContent: '结构位移异常:位移值:15.8mm,超3级阈值[15.0~20.0]',
        alarmTime: '2024-09-03T10:23:45',
        updateTime: '2024-09-03T10:23:45',
        status: 0
      },
      {
        alarmId: 'ALARM_004_2024090516552',
        structureName: '润扬长江大桥',
        fabricateName: 'LB-5',
        detectionType: '索力',
        alarmLevel: '1级',
        alarmContent: '索力轻微偏差:索力值:1180kN,接近1级阈值[1150~1250]',
        alarmTime: '2024-09-05T16:55:28',
        updateTime: '2024-09-05T17:02:45',
        status: 1
      },
      {
        alarmId: 'ALARM_005_2024090618321',
        structureName: '泰州长江大桥',
        fabricateName: 'LD-4',
        detectionType: '温度',
        alarmLevel: '3级',
        alarmContent: '结构温度异常:温度值:65.2℃,超3级阈值[60.0~70.0]',
        alarmTime: '2024-09-06T18:32:15',
        updateTime: '2024-09-06T18:32:15',
        status: 0
      },
      {
        alarmId: 'ALARM_006_2024090712456',
        structureName: '江阴长江大桥',
        fabricateName: 'LE-6',
        detectionType: '振动',
        alarmLevel: '2级',
        alarmContent: '振动频率超标:频率值:2.8Hz,超2级阈值[2.5~3.0]',
        alarmTime: '2024-09-07T12:45:32',
        updateTime: '2024-09-07T13:02:18',
        status: 1
      }
    ]

    console.info('模拟数据初始化完成，预警数量:', this.alarmList.length)
    this.updateFilteredCount()
  }

  // 更新筛选计数
  private updateFilteredCount() {
    this.filteredCount = this.getFilteredAlarmList().length
    console.info(`筛选更新: 状态=${this.filterStatus}, 级别=${this.filterLevel}, 结果数=${this.filteredCount}`)
  }

  async loadAlarmList() {
    this.loading = true
    try {
      console.info('开始加载预警列表...')
      let result = await request.post('/alarm/getList', {}) as ApiResult
      console.info('预警列表API响应:', JSON.stringify(result, null, 2))

      if (result?.success && result?.data) {
        let alarmData = result.data as AlarmListResult
        console.info('解析后的预警数据:', JSON.stringify(alarmData, null, 2))

        if (alarmData?.rows && alarmData.rows.length > 0) {
          this.alarmList = alarmData.rows.map((item, index) => {
            console.info(`处理第${index + 1}条预警数据:`, JSON.stringify(item, null, 2))
            let processedItem = {
              alarmId: item.alarmId || '',
              structureName: item.structureName || '未知结构物',
              fabricateName: item.fabricateName || '未知构件',
              detectionType: item.detectionType || '未知类型',
              alarmLevel: item.alarmLevel || '1级',
              alarmContent: item.alarmContent || '暂无详细信息',
              alarmTime: item.alarmTime || new Date().toISOString(),
              updateTime: item.updateTime || new Date().toISOString(),
              status: typeof item.status === 'number' ? item.status : 0
            }
            console.info(`处理后的第${index + 1}条数据:`, JSON.stringify(processedItem, null, 2))
            return processedItem
          })
          console.info('预警列表加载成功，数量:', this.alarmList.length)
          this.updateFilteredCount()
        } else {
          console.warn('API返回空数据，保留模拟数据')
        }
      } else {
        console.warn('API调用失败，保留模拟数据:', result?.message)
      }
    } catch (error) {
      console.error('加载预警列表失败:', error)
      promptAction.showToast({
        message: '网络异常，显示本地数据',
        duration: 2000,
      })
    } finally {
      this.loading = false
      this.refreshing = false
    }
  }

  async handleAlarm(alarmId: string) {
    if (!alarmId || alarmId.trim() === '') {
      console.error('预警ID为空:', alarmId)
      promptAction.showToast({
        message: '预警ID无效，请重试',
        duration: 2000,
      })
      return
    }

    console.info('开始处理预警，ID:', alarmId)

    try {
      let requestParams = {
        alarmId: alarmId.trim()
      }

      console.info('请求参数:', JSON.stringify(requestParams, null, 2))

      let result = await request.post('/alarm/handle', requestParams) as ApiResult

      console.info('处理预警响应:', JSON.stringify(result, null, 2))

      if (result?.success) {
        promptAction.showToast({
          message: '预警处理成功',
          duration: 2000,
        })

        let index = this.alarmList.findIndex(item => item.alarmId === alarmId)
        if (index !== -1) {
          this.alarmList[index].status = 1
          this.alarmList[index].updateTime = new Date().toISOString()
          console.info('本地数据已更新，索引:', index)
          this.updateFilteredCount() // 更新筛选计数
        }
        this.showDialog = false
      } else {
        console.error('处理预警失败，原因:', result?.message)
        promptAction.showToast({
          message: result?.message || '处理失败',
          duration: 2000,
        })
      }
    } catch (error) {
      console.error('处理预警异常:', error)
      promptAction.showToast({
        message: '网络异常，请稍后重试',
        duration: 2000,
      })
    }
  }

  getFilteredAlarmList(): AlarmItem[] {
    return this.alarmList.filter(item => {
      let statusMatch = this.filterStatus === -1 || item.status === this.filterStatus
      let levelMatch = this.filterLevel === '全部' || item.alarmLevel === this.filterLevel
      return statusMatch && levelMatch
    })
  }

  getAlarmLevelColor(level: string): string {
    switch (level) {
      case '1级': return '#52c41a'
      case '2级': return '#faad14'
      case '3级': return '#f5222d'
      default: return '#1890ff'
    }
  }

  getStatusText(status: number): string {
    return status === 0 ? '未处理' : '已处理'
  }

  getStatusColor(status: number): string {
    return status === 0 ? '#f5222d' : '#52c41a'
  }

  formatDateTime(dateStr: string): string {
    if (!dateStr) return '未知时间'
    try {
      let date = new Date(dateStr)
      if (isNaN(date.getTime())) return dateStr
      return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
    } catch {
      return dateStr
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('预警管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')

        Blank()

        Button('刷新')
          .fontSize(14)
          .backgroundColor('#4852C9')
          .onClick(() => {
            console.info('用户点击预警刷新按钮')
            this.refreshing = true
            this.loadAlarmList()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#f8f9fa')

      // 筛选器 - 改进布局和交互
      Column() {
        // 状态筛选
        Row() {
          Text('状态筛选:')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
            .margin({ right: 12 })

          ForEach([
            { label: '全部', value: -1 },
            { label: '未处理', value: 0 },
            { label: '已处理', value: 1 }
          ], (item: { label: string, value: number }) => {
            Text(item.label)
              .fontSize(12)
              .fontColor(this.filterStatus === item.value ? '#fff' : '#666')
              .fontWeight(this.filterStatus === item.value ? FontWeight.Bold : FontWeight.Normal)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.filterStatus === item.value ? '#4852C9' : '#f0f0f0')
              .borderRadius(16)
              .onClick(() => {
                console.info(`切换状态筛选: ${item.label} (${item.value})`)
                this.filterStatus = item.value
                this.updateFilteredCount()
              })
              .margin({ right: 8 })
          })
        }
        .width('100%')
        .margin({ bottom: 12 })

        // 级别筛选
        Row() {
          Text('级别筛选:')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333')
            .margin({ right: 12 })

          ForEach(['全部', '1级', '2级', '3级'], (level: string) => {
            Text(level)
              .fontSize(12)
              .fontColor(this.filterLevel === level ? '#fff' : '#666')
              .fontWeight(this.filterLevel === level ? FontWeight.Bold : FontWeight.Normal)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.filterLevel === level ? this.getLevelFilterColor(level) : '#f0f0f0')
              .borderRadius(16)
              .onClick(() => {
                console.info(`切换级别筛选: ${level}`)
                this.filterLevel = level
                this.updateFilteredCount()
              })
              .margin({ right: 8 })
          })
        }
        .width('100%')

        // 筛选结果提示
        Row() {
          Text(`筛选结果: ${this.filteredCount} 条预警`)
            .fontSize(12)
            .fontColor('#666')
            .margin({ top: 8 })

          Blank()

          if (this.filterStatus !== -1 || this.filterLevel !== '全部') {
            Text('清除筛选')
              .fontSize(12)
              .fontColor('#4852C9')
              .onClick(() => {
                this.filterStatus = -1
                this.filterLevel = '全部'
                this.updateFilteredCount()
              })
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor(Color.White)
      .border({
        width: { bottom: 1 },
        color: '#f0f0f0'
      })

      // 统计信息
      Row() {
        this.StatCard('总预警', this.alarmList.length, '#1890ff')
        this.StatCard('未处理', this.alarmList.filter(item => item.status === 0).length, '#f5222d')
        this.StatCard('已处理', this.alarmList.filter(item => item.status === 1).length, '#52c41a')
        this.StatCard('3级预警', this.alarmList.filter(item => item.alarmLevel === '3级').length, '#ff4d4f')
      }
      .width('100%')
      .padding(16)
      .justifyContent(FlexAlign.SpaceBetween)
      .backgroundColor('#f8f9fa')

      // 主要内容区域 - 修复滚动问题
      if (this.loading && !this.refreshing) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
            .color('#4852C9')

          Text('加载预警数据中...')
            .fontSize(14)
            .fontColor('#666')
            .margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // 预警列表 - 优化布局
        Refresh({ refreshing: this.refreshing, offset: 50, friction: 66 }) {
          if (this.getFilteredAlarmList().length === 0) {
            // 空状态
            Column() {
              Text('📋')
                .fontSize(60)
                .opacity(0.3)

              Text('暂无预警数据')
                .fontSize(16)
                .fontColor('#999')
                .margin({ top: 16 })

              if (this.filterStatus !== -1 || this.filterLevel !== '全部') {
                Text('当前筛选条件下无数据，请调整筛选条件')
                  .fontSize(12)
                  .fontColor('#ccc')
                  .margin({ top: 8 })

                Button('清除筛选')
                  .fontSize(14)
                  .backgroundColor('#4852C9')
                  .margin({ top: 16 })
                  .onClick(() => {
                    this.filterStatus = -1
                    this.filterLevel = '全部'
                    this.updateFilteredCount()
                  })
              } else {
                Text('请检查网络连接或稍后重试')
                  .fontSize(12)
                  .fontColor('#ccc')
                  .margin({ top: 8 })
              }
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          } else {
            // 有数据时显示列表
            List({ space: 8 }) {
              ForEach(this.getFilteredAlarmList(), (alarm: AlarmItem, index: number) => {
                ListItem() {
                  this.AlarmItemView(alarm, index)
                }
              })

              // 添加底部间距，确保最后一项可以完全显示
              ListItem() {
                Column()
                  .width('100%')
                  .height(80)
              }
            }
            .width('100%')
            .height('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .scrollBar(BarState.Auto)
            .edgeEffect(EdgeEffect.Spring)
          }
        }
        .onRefreshing(() => {
          this.loadAlarmList()
        })
        .layoutWeight(1)
      }

      // 预警详情对话框
      if (this.showDialog && this.selectedAlarm) {
        this.AlarmDetailDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  // 获取级别筛选按钮颜色
  private getLevelFilterColor(level: string): string {
    switch (level) {
      case '1级': return '#52c41a'
      case '2级': return '#faad14'
      case '3级': return '#f5222d'
      default: return '#4852C9'
    }
  }

  @Builder
  StatCard(title: string, count: number, color: string) {
    Column() {
      Text(count.toString())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(title)
        .fontSize(12)
        .fontColor('#666')
        .margin({ top: 4 })
    }
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(8)
    .width(80)
    .shadow({
      radius: 2,
      color: '#00000010',
      offsetX: 0,
      offsetY: 1
    })
  }

  @Builder
  AlarmItemView(alarm: AlarmItem, index: number) {
    Column() {
      // 头部信息
      Row() {
        Row() {
          Circle({ width: 8, height: 8 })
            .fill(this.getAlarmLevelColor(alarm.alarmLevel))
            .margin({ right: 6 })

          Text(alarm.alarmLevel || '未知级别')
            .fontSize(12)
            .fontColor(this.getAlarmLevelColor(alarm.alarmLevel))
            .fontWeight(FontWeight.Bold)
        }

        Blank()

        Row() {
          Text('#' + (index + 1))
            .fontSize(10)
            .fontColor('#999')
            .margin({ right: 8 })

          Text(this.getStatusText(alarm.status))
            .fontSize(12)
            .fontColor(this.getStatusColor(alarm.status))
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(alarm.status === 0 ? '#fff2f0' : '#f6ffed')
            .borderRadius(10)
        }
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 结构物信息
      Row() {
        Text(alarm.structureName || '未知结构物')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        if (alarm.fabricateName) {
          Text(' - ' + alarm.fabricateName)
            .fontSize(12)
            .fontColor('#666666')
        }

        Blank()

        Text(alarm.detectionType || '未知类型')
          .fontSize(12)
          .fontColor('#1890ff')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#e6f7ff')
          .borderRadius(10)
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 预警内容
      Text(alarm.alarmContent || '暂无详细信息')
        .fontSize(13)
        .fontColor('#333333')
        .lineHeight(18)
        .width('100%')
        .margin({ bottom: 8 })
        .padding(8)
        .backgroundColor('#f8f9fa')
        .borderRadius(6)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 时间和操作
      Row() {
        Column() {
          Text('预警时间: ' + this.formatDateTime(alarm.alarmTime))
            .fontSize(11)
            .fontColor('#999999')

          if (alarm.updateTime) {
            Text('更新时间: ' + this.formatDateTime(alarm.updateTime))
              .fontSize(11)
              .fontColor('#999999')
              .margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row() {
          Button('详情')
            .fontSize(12)
            .backgroundColor('#f0f0f0')
            .fontColor('#666')
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .constraintSize({ minWidth: 60 })
            .onClick(() => {
              this.selectedAlarm = alarm
              this.showDialog = true
            })

          if (alarm.status === 0) {
            Button('处理')
              .fontSize(12)
              .backgroundColor('#4852C9')
              .fontColor(Color.White)
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .constraintSize({ minWidth: 60 })
              .margin({ left: 8 })
              .onClick(() => {
                console.info('点击处理按钮，预警信息:', alarm)

                if (!alarm.alarmId || alarm.alarmId.trim() === '') {
                  console.error('预警ID无效:', alarm.alarmId)
                  promptAction.showToast({
                    message: '预警数据异常，请刷新后重试',
                    duration: 2000,
                  })
                  return
                }

                this.handleAlarm(alarm.alarmId)
              })
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: '#00000008',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      this.selectedAlarm = alarm
      this.showDialog = true
    })
  }

  @Builder
  AlarmDetailDialog() {
    if (this.selectedAlarm) {
      // 全屏遮罩
      Stack() {
        // 背景遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.5)')
          .onClick(() => {
            this.showDialog = false
          })

        // 对话框内容
        Column() {
          // 标题栏
          Row() {
            Text('预警详情')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')

            Blank()

            Button('✕')
              .fontSize(16)
              .backgroundColor(Color.Transparent)
              .fontColor('#999')
              .padding(8)
              .onClick(() => {
                this.showDialog = false
              })
          }
          .width('100%')
          .padding({ bottom: 16 })

          // 内容区域
          Scroll() {
            Column() {
              this.DetailRow('预警ID', this.selectedAlarm.alarmId)
              this.DetailRow('结构物', this.selectedAlarm.structureName)
              this.DetailRow('构件', this.selectedAlarm.fabricateName)
              this.DetailRow('监测类型', this.selectedAlarm.detectionType)
              this.DetailRow('预警级别', this.selectedAlarm.alarmLevel, this.getAlarmLevelColor(this.selectedAlarm.alarmLevel))
              this.DetailRow('状态', this.getStatusText(this.selectedAlarm.status), this.getStatusColor(this.selectedAlarm.status))
              this.DetailRow('预警时间', this.formatDateTime(this.selectedAlarm.alarmTime))
              this.DetailRow('更新时间', this.formatDateTime(this.selectedAlarm.updateTime))

              Column() {
                Text('预警内容')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#333')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 8 })

                Text(this.selectedAlarm.alarmContent)
                  .fontSize(14)
                  .fontColor('#666')
                  .lineHeight(20)
                  .width('100%')
                  .padding(12)
                  .backgroundColor('#f8f9fa')
                  .borderRadius(8)
              }
              .width('100%')
              .margin({ top: 16 })
            }
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)

          // 操作按钮
          if (this.selectedAlarm.status === 0) {
            Row() {
              Button('取消')
                .fontSize(14)
                .backgroundColor('#f0f0f0')
                .fontColor('#666')
                .layoutWeight(1)
                .onClick(() => {
                  this.showDialog = false
                })

              Button('标记为已处理')
                .fontSize(14)
                .backgroundColor('#4852C9')
                .fontColor(Color.White)
                .layoutWeight(1)
                .margin({ left: 12 })
                .onClick(() => {
                  this.handleAlarm(this.selectedAlarm!.alarmId)
                })
            }
            .width('100%')
            .margin({ top: 16 })
          } else {
            Button('关闭')
              .fontSize(14)
              .backgroundColor('#4852C9')
              .fontColor(Color.White)
              .width('100%')
              .margin({ top: 16 })
              .onClick(() => {
                this.showDialog = false
              })
          }
        }
        .width('90%')
        .constraintSize({ maxHeight: '80%' })
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius(16)
        .shadow({
          radius: 20,
          color: '#00000020',
          offsetX: 0,
          offsetY: 10
        })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(999)
    }
  }

  @Builder
  DetailRow(label: string, value: string, color?: string) {
    Row() {
      Text(label + ':')
        .fontSize(14)
        .fontColor('#333')
        .fontWeight(FontWeight.Bold)
        .width(80)

      Text(value || '暂无')
        .fontSize(14)
        .fontColor(color || '#666')
        .layoutWeight(1)
        .textAlign(TextAlign.Start)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }
}
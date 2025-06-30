import {DataStatistics} from '../view/dataStatistics/DataStatistics'
import {EarlyWarning} from '../view/earlyWarning/EarlyWarning'

@Entry
@Component
struct Home {
  @State currentTab: string = '数据统计'

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End }) {
        TabContent() {
          DataStatistics()
        }
        .tabBar(this.TabBuilder({
          label: '数据统计',
          active: $r('app.media.statistics_active'),
          primary: $r('app.media.statistics_primary')
        }))

        TabContent() {
          EarlyWarning({ currentTab: $currentTab })
        }
        .tabBar(this.TabBuilder({
          label: '预警管理',
          active: $r('app.media.warning_active'),
          primary: $r('app.media.warning_primary')
        }))
      }
      .scrollable(false)
      .vertical(false)
      .onChange((index: number) => {
        this.currentTab = index == 0 ? '数据统计' : '预警管理'
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  TabBuilder(params) {
    Column() {
      Image(this.currentTab == params.label ? params.active : params.primary)
        .width(22)
        .height(22)
        .margin({bottom:2})
      Text(params.label)
        .fontColor(this.currentTab == params.label ? $r('app.color.activeColor') : $r('app.color.primaryColor'))
        .fontSize(12)
    }
    .padding({ top: 8, bottom: 8 })
  }
}
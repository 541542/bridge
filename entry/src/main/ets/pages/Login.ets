import {LoginTab} from '../view/login/LoginTab';

@Entry
@Component
struct Login {
  build() {
    Column() {
      LoginTab()
      Text('技术支持 中软国际教育科技股份有限公司')
        .fontColor('#fff').fontSize(10).offset({ y: 80 })
    }
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundImage($r('app.media.bg'))
    .backgroundImageSize({ width: '100%', height: '100%' })
    .width('100%').height('100%')
  }
}

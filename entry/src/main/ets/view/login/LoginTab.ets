import request from '../../utils/httpUtils'
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

interface ApiResult {
  success: boolean
  message?: string
  data?: any
}

@Component
export struct LoginTab {
  @State userName: string = '18130075146'
  @State passWord: string = 'BHM123456'
  @State loginEnabled: boolean = true
  @State isLoading: boolean = false
  @State showPassword: boolean = false

  build() {
    Column() {
      // 应用Logo和标题
      Column() {
        Image($r('app.media.app_icon'))
          .width(80)
          .height(80)
          .borderRadius(16)
          .margin({ bottom: 16 })

        Text('桥梁监控系统')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .margin({ bottom: 8 })

        Text('Bridge Health Monitoring')
          .fontSize(14)
          .fontColor('#999')
          .margin({ bottom: 32 })
      }

      // 登录表单
      Column() {
        Text('账号登录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
          .margin({ bottom: 24 })
          .alignSelf(ItemAlign.Start)

        // 手机号输入框
        Column() {
          Text('手机号')
            .fontSize(14)
            .fontColor('#333')
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 8 })

          Row() {
            Image($r('app.media.icon'))
              .width(20)
              .height(20)
              .margin({ right: 12 })
              .fillColor('#999')

            TextInput({
              text: this.userName,
              placeholder: '请输入手机号'
            })
              .backgroundColor(Color.Transparent)
              .border({ width: 0 })
              .layoutWeight(1)
              .fontSize(16)
              .placeholderColor('#ccc')
              .onChange((value: string) => {
                this.userName = value;
                this.updateLoginEnabled();
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#f8f9fa')
          .borderRadius(12)
          .border({
            width: 1,
            color: '#e8e8e8'
          })
        }
        .width('100%')
        .margin({ bottom: 20 })

        // 密码输入框
        Column() {
          Text('密码')
            .fontSize(14)
            .fontColor('#333')
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 8 })

          Row() {
            Image($r('app.media.icon'))
              .width(20)
              .height(20)
              .margin({ right: 12 })
              .fillColor('#999')

            TextInput({
              text: this.passWord,
              placeholder: '请输入密码'
            })
              .type(this.showPassword ? InputType.Normal : InputType.Password)
              .backgroundColor(Color.Transparent)
              .border({ width: 0 })
              .layoutWeight(1)
              .fontSize(16)
              .placeholderColor('#ccc')
              .onChange((value: string) => {
                this.passWord = value;
                this.updateLoginEnabled();
              })

            Image($r('app.media.icon'))
              .width(20)
              .height(20)
              .fillColor('#999')
              .onClick(() => {
                this.showPassword = !this.showPassword
              })
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#f8f9fa')
          .borderRadius(12)
          .border({
            width: 1,
            color: '#e8e8e8'
          })
        }
        .width('100%')
        .margin({ bottom: 32 })

        // 登录按钮
        Button() {
          if (this.isLoading) {
            Row() {
              LoadingProgress()
                .width(20)
                .height(20)
                .color(Color.White)
                .margin({ right: 8 })

              Text('登录中...')
                .fontSize(16)
                .fontColor(Color.White)
            }
          } else {
            Text('立即登录')
              .fontSize(16)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
        }
        .width('100%')
        .height(48)
        .backgroundColor(this.loginEnabled && !this.isLoading ? '#4852C9' : '#ccc')
        .borderRadius(12)
        .enabled(this.loginEnabled && !this.isLoading)
        .onClick(() => {
          this.toLogin()
        })
        .margin({ bottom: 16 })

        // 其他登录方式或提示
        Row() {
          Text('首次使用？')
            .fontSize(12)
            .fontColor('#999')

          Text('联系管理员获取账号')
            .fontSize(12)
            .fontColor('#4852C9')
            .margin({ left: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(24)
      .backgroundColor('rgba(255, 255, 255, 0.95)')
      .borderRadius(16)
      .backdropBlur(10)
    }
    .width('85%')
    .constraintSize({ maxWidth: 400 })
  }

  updateLoginEnabled() {
    this.loginEnabled = this.userName.length > 0 && this.passWord.length > 0
  }

  //登录
  async toLogin() {
    if (!this.loginEnabled || this.isLoading) {
      return
    }

    // 简单的手机号验证
    const phoneRegex = /^1[3-9]\d{9}$/
    if (!phoneRegex.test(this.userName)) {
      promptAction.showToast({
        message: '请输入正确的手机号',
        duration: 2000,
      });
      return
    }

    this.isLoading = true

    try {
      const params = {
        "userName": this.userName,
        "passWord": this.passWord,
        "port": 1
      }

      const result = await request.post('/account/login', params) as ApiResult

      if (result?.success) {
        //存储会话
        const bhmToken = result?.data;
        PersistentStorage.PersistProp('bhm-token', bhmToken);

        promptAction.showToast({
          message: '登录成功',
          duration: 1500,
        });

        // 延迟跳转，让用户看到成功提示
        setTimeout(() => {
          router.replaceUrl({
            url: 'pages/Home'
          })
        }, 1000)
      } else {
        promptAction.showToast({
          message: result?.message || '登录失败，请检查账号密码',
          duration: 2000,
        });
      }
    } catch (err) {
      console.log('登录异常:', JSON.stringify(err))
      promptAction.showToast({
        message: '网络异常，请稍后重试',
        duration: 2000,
      });
    } finally {
      this.isLoading = false
    }
  }
}
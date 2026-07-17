import { AuthModeItem } from '../model/AuthModeItem';

@Entry
@Component
struct Index {
  private navStack: NavPathStack = new NavPathStack();
  @State authModes: AuthModeItem[] = [];

  aboutToAppear(): void {
    this.authModes = [
      AuthModeItem.create('basic', '基础认证', '用户名 + 密码', 'A', 'BasicAuthPage'),
      AuthModeItem.create('bearer', '令牌认证', 'OAuth2 / API 令牌', 'T', 'BearerAuthPage'),
      AuthModeItem.create('digest', '摘要认证', 'HTTP 摘要认证', 'D', 'DigestAuthPage'),
      AuthModeItem.create('custom', '自定义请求头', 'API 密钥 / 自定义认证', 'K', 'CustomAuthPage'),
    ];
  }

  build() {
    Navigation(this.navStack) {
      Column({ space: 16 }) {
        Text('WebDav 客户端演示')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 20, bottom: 8 })

        Text('选择认证方式连接您的 WebDav 服务端')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ bottom: 16 })

        ForEach(this.authModes, (mode: AuthModeItem) => {
          Row({ space: 16 }) {
            Text(mode.icon)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor('#007DFF')
              .borderRadius(8)
              .width(56)
              .height(56)
              .textAlign(TextAlign.Center)

            Column({ space: 4 }) {
              Text(mode.title)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
              Text(mode.description)
                .fontSize(13)
                .fontColor('#999999')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 4, color: '#1A000000', offsetY: 2 })
          .onClick(() => {
            this.navStack.pushPathByName(mode.pagePath, null);
          })
        }, (mode: AuthModeItem) => mode.id)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .titleMode(NavigationTitleMode.Mini)
    .title('WebDav 客户端')
    .mode(NavigationMode.Stack)
  }
}

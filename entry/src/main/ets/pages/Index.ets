import { MainPage } from './MainPage';
import { window } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State showSplash: boolean = true;

  async setStatusBar() {
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#fff7f8f3',
      statusBarContentColor: '#000000'
    });
  }

  async aboutToAppear() {
    await this.setStatusBar();
    setTimeout(() => {
      this.showSplash = false;
    }, 3000);
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      if (this.showSplash) {
        Column() {
          Image($r('app.media.app_icon'))
            .width('80%')
            .height('80%')
            .objectFit(ImageFit.Contain)
            .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#fff7f8f3')
        .justifyContent(FlexAlign.Center)

        Button('跳过')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('rgba(0, 0, 0, 0.4)')
          .borderRadius(20)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .margin({ top: 60, right: 16 })
          .onClick(() => {
            this.showSplash = false;
          })
      } else {
        MainPage()
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
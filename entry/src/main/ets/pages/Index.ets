import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  build() {
    Column() {
      Image($r('app.media.app_icon'))
        .width(120)
        .height(120)
        .borderRadius(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FF8C00')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      setTimeout(() => {
        router.replaceUrl({
          url: 'pages/MainPage'
        });
      }, 3000);
    })
  }

  aboutToAppear(): void {
    setTimeout(() => {
      router.replaceUrl({
        url: 'pages/MainPage'
      });
    }, 3000);
  }
}
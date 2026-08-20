import { MainPage } from './MainPage';

@Entry
@Component
struct Index {
  @State showSplash: boolean = true;

  build() {
    Stack() {
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
      } else {
        MainPage()
      }
    }
    .width('100%')
    .height('100%')
  }

  aboutToAppear(): void {
    setTimeout(() => {
      this.showSplash = false;
    }, 3000);
  }
}
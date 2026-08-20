import { BookshelfPage } from './BookshelfPage';
import { LibraryPage } from './LibraryPage';
import { ProfilePage } from './ProfilePage';

@Component
export struct MainPage {
  @State currentIndex: number = 0;

  @Builder
  navItem(index: number, icon: string, title: string) {
    Column() {
      SymbolGlyph($r(icon))
        .fontSize(24)
        .fontColor([this.currentIndex === index ? '#FF8C00' : '#999999'])
      Text(title)
        .fontSize(12)
        .fontColor(this.currentIndex === index ? '#FF8C00' : '#999999')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = index;
    })
  }

  build() {
    Column() {
      Stack() {
        if (this.currentIndex === 0) {
          BookshelfPage()
        } else if (this.currentIndex === 1) {
          LibraryPage()
        } else {
          ProfilePage()
        }
      }
      .layoutWeight(1)

      Row() {
        this.navItem(0, 'sys.symbol.books', '书架')
        this.navItem(1, 'sys.symbol.building_2', '书库')
        this.navItem(2, 'sys.symbol.person', '我的')
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 1 }, color: '#E5E5E5' })
    }
    .width('100%')
    .height('100%')
  }
}
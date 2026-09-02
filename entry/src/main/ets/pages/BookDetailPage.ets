import { util } from '@kit.ArkTS';
import { router, window } from '@kit.ArkUI';
import { UserProfileManager } from '../model/UserProfileManager';

interface Book {
  id: string;
  title: string;
  author: string;
  hashtags: string[];
  description: string;
  fileName: string;
  cover: string;
}

interface RouterParams {
  bookId: string;
}

class BookModel {
  static async getBookById(bookId: string): Promise<Book | null> {
    try {
      const context = getContext().resourceManager;
      const fileData = await context.getRawFileContent('book_list.json');
      const decoder = new util.TextDecoder('utf-8');
      const jsonString = decoder.decodeToString(fileData);
      const books: Book[] = JSON.parse(jsonString);
      return books.find(book => book.id === bookId) || null;
    } catch (error) {
      console.error('Failed to load book:', error);
      return null;
    }
  }
}

@Entry
@Component
struct BookDetailPage {
  @State book: Book | null = null;
  @State isLoading: boolean = true;
  @State isInBookshelf: boolean = false;
  @State bookId: string = '';
  @State lastBookshelfVersion: number = -1;

  private getCoverResource(cover: string): Resource {
    switch (cover) {
      case 'book_cover_1.png': return $r('app.media.book_cover_1');
      case 'book_cover_2.png': return $r('app.media.book_cover_2');
      case 'book_cover_3.png': return $r('app.media.book_cover_3');
      case 'book_cover_4.png': return $r('app.media.book_cover_4');
      case 'book_cover_5.png': return $r('app.media.book_cover_5');
      default: return $r('app.media.app_icon');
    }
  }

  async aboutToAppear() {
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#F5F5F5',
      statusBarContentColor: '#000000'
    });

    const params = router.getParams() as RouterParams;
    this.bookId = params.bookId;
    
    this.book = await BookModel.getBookById(this.bookId);
    await this.refreshBookshelfStatus();
    this.isLoading = false;
  }

  async refreshBookshelfStatus() {
    const manager = await UserProfileManager.getInstance();
    this.isInBookshelf = manager.isInBookshelf(this.bookId);
    this.lastBookshelfVersion = manager.getVersion();
  }

  async onPageShow() {
    const manager = await UserProfileManager.getInstance();
    const currentVersion = manager.getVersion();
    if (currentVersion !== this.lastBookshelfVersion) {
      await this.refreshBookshelfStatus();
    }
  }

  async toggleBookshelf() {
    const manager = await UserProfileManager.getInstance();
    this.isInBookshelf = await manager.toggleBookshelf(this.bookId);
    this.lastBookshelfVersion = manager.getVersion();
  }

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([Color.Black])
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })

        Blank().layoutWeight(1)

        Button(this.isInBookshelf ? '已加入书架' : '加入书架')
          .fontSize(14)
          .fontColor(this.isInBookshelf ? '#FF8C00' : Color.White)
          .backgroundColor(this.isInBookshelf ? '#FFF3E0' : '#FF8C00')
          .borderRadius(16)
          .height(32)
          .onClick(() => {
            this.toggleBookshelf();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#FF8C00')
      } else if (this.book) {
        Column() {
          Column() {
            Image(this.book ? this.getCoverResource(this.book.cover) : $r('app.media.app_icon'))
              .width(120)
              .height(160)
              .borderRadius(8)
              .objectFit(ImageFit.Cover)
              .margin({ bottom: 16 })

            Text(this.book.title)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })

            Text(`作者: ${this.book.author}`)
              .fontSize(16)
              .fontColor('#666666')
              .margin({ bottom: 16 })

            Row() {
              ForEach(this.book.hashtags, (tag: string) => {
                Text(`#${tag}`)
                  .fontSize(14)
                  .fontColor('#FF8C00')
                  .backgroundColor('#FFF3E0')
                  .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                  .borderRadius(16)
                  .margin({ right: 8 })
              })
            }
            .margin({ bottom: 24 })

            Text('简介')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 8 })

            Text(this.book.description)
              .fontSize(15)
              .fontColor('#666666')
              .lineHeight(24)
          }
          .width('100%')
          .padding(24)
          .backgroundColor('#F5F5F5')
          .borderRadius(12)
          .margin(16)

          Button('开始阅读')
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor('#FF8C00')
            .borderRadius(24)
            .width('90%')
            .height(48)
            .onClick(() => {
              router.pushUrl({
                url: 'pages/BookReaderPage',
                params: {
                  fileName: this.book?.fileName,
                  title: this.book?.title,
                  bookId: this.book?.id
                }
              });
            })
        }
        .layoutWeight(1)
        .gesture(
          PanGesture()
            .onActionEnd((event: GestureEvent) => {
              if (event.offsetX > 100) {
                router.back();
              } else if (event.offsetX < -100) {
                router.pushUrl({
                  url: 'pages/BookReaderPage',
                  params: {
                    fileName: this.book?.fileName,
                    title: this.book?.title,
                    bookId: this.book?.id
                  }
                });
              }
            })
        )
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
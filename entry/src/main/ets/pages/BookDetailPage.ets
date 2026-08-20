import { util } from '@kit.ArkTS';
import { router } from '@kit.ArkUI';
import { BookshelfManager } from '../model/BookshelfManager';

interface Book {
  id: string;
  title: string;
  author: string;
  hashtags: string[];
  description: string;
  fileName: string;
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

  async aboutToAppear() {
    const params = router.getParams() as RouterParams;
    this.bookId = params.bookId;
    
    this.book = await BookModel.getBookById(this.bookId);
    const manager = await BookshelfManager.getInstance();
    this.isInBookshelf = manager.isInBookshelf(this.bookId);
    this.isLoading = false;
  }

  async toggleBookshelf() {
    const manager = await BookshelfManager.getInstance();
    this.isInBookshelf = await manager.toggleBookshelf(this.bookId);
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

        Text(this.book?.title || '书籍详情')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(40)
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
            Text(this.book.title)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 16 })

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
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin(16)

          Row() {
            Button(this.isInBookshelf ? '已加入书架' : '加入书架')
              .fontSize(16)
              .fontColor(this.isInBookshelf ? '#FF8C00' : Color.White)
              .backgroundColor(this.isInBookshelf ? '#FFF3E0' : '#FF8C00')
              .borderRadius(24)
              .layoutWeight(1)
              .height(48)
              .onClick(() => {
                this.toggleBookshelf();
              })

            Button('开始阅读')
              .fontSize(16)
              .fontColor(Color.White)
              .backgroundColor('#333333')
              .borderRadius(24)
              .layoutWeight(1)
              .height(48)
              .margin({ left: 16 })
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/BookReaderPage',
                  params: {
                    fileName: this.book?.fileName,
                    title: this.book?.title
                  }
                });
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
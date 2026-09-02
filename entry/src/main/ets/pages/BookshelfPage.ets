import { util } from '@kit.ArkTS';
import { router } from '@kit.ArkUI';
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

class BookModel {
  static async getBookList(): Promise<Book[]> {
    try {
      const context = getContext().resourceManager;
      const fileData = await context.getRawFileContent('book_list.json');
      const decoder = new util.TextDecoder('utf-8');
      const jsonString = decoder.decodeToString(fileData);
      const books: Book[] = JSON.parse(jsonString);
      return books;
    } catch (error) {
      console.error('Failed to load book list:', error);
      return [];
    }
  }
}

@Component
export struct BookshelfPage {
  @State bookList: Book[] = [];
  @State isLoading: boolean = true;
  private lastVersion: number = -1;
  private profileManager: UserProfileManager | null = null;

  async aboutToAppear() {
    await this.loadBooks();
  }

  async loadBooks() {
    const allBooks = await BookModel.getBookList();
    const manager = await UserProfileManager.getInstance();
    this.profileManager = manager;
    const currentVersion = manager.getVersion();
    
    if (currentVersion !== this.lastVersion) {
      this.isLoading = true;
      const bookshelfIds = manager.getAllBookIds();
      this.bookList = allBooks.filter(book => bookshelfIds.includes(book.id));
      this.lastVersion = currentVersion;
      this.isLoading = false;
    }
  }

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

  @Builder
  bookItem(book: Book) {
    Column() {
      Row() {
        Image(this.getCoverResource(book.cover))
          .width(60)
          .height(80)
          .borderRadius(4)
          .objectFit(ImageFit.Cover)
          .margin({ right: 12 })
        Column() {
        Text(book.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        if (this.profileManager && this.profileManager.getProgressPercent(book.id) > 0) {
          Text(`已读${this.profileManager.getProgressPercent(book.id)}%`)
            .fontSize(12)
            .fontColor('#FF8C00')
        }
        Text(`#${book.id}`)
          .fontSize(14)
          .fontColor('#999999')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(`作者: ${book.author}`)
        .fontSize(14)
        .fontColor('#666666')
        .margin({ top: 8 })

      Row() {
        ForEach(book.hashtags, (tag: string) => {
          Text(`#${tag}`)
            .fontSize(12)
            .fontColor('#FF8C00')
            .backgroundColor('#FFF3E0')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(4)
            .margin({ right: 8 })
        })
      }
      .margin({ top: 8 })

      Text(book.description)
        .fontSize(13)
        .fontColor('#888888')
        .margin({ top: 8 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ bottom: 12 })
    .shadow({ radius: 2, color: '#E0E0E0', offsetX: 0, offsetY: 1 })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/BookDetailPage',
        params: {
          bookId: book.id
        }
      });
    })
  }

  build() {
    Column() {
      Text('书架')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 16, top: 16, bottom: 12 })
        .width('100%')

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#FF8C00')
      } else if (this.bookList.length === 0) {
        Column() {
          Text('暂无收藏书籍')
            .fontSize(16)
            .fontColor('#999999')
          Text('去书城添加感兴趣的书籍吧')
            .fontSize(14)
            .fontColor('#CCCCCC')
            .margin({ top: 8 })
        }
      } else {
        List() {
          ForEach(this.bookList, (book: Book) => {
            ListItem() {
              this.bookItem(book)
            }
            .padding({ left: 16, right: 16 })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean) => {
      if (isVisible) {
        this.loadBooks();
      }
    })
  }
}
import { util } from '@kit.ArkTS';
import { router } from '@kit.ArkUI';

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
export struct LibraryPage {
  @State allBooks: Book[] = [];
  @State searchText: string = '';
  @State isLoading: boolean = true;

  private filteredBooks: Book[] = [];

  getFilteredBooks(): Book[] {
    if (!this.searchText.trim()) {
      return this.allBooks;
    }
    const keyword = this.searchText.toLowerCase().trim();
    return this.allBooks.filter(book => {
      const titleMatch = book.title.toLowerCase().includes(keyword);
      const authorMatch = book.author.toLowerCase().includes(keyword);
      const hashtagMatch = book.hashtags.some(tag => 
        tag.toLowerCase().includes(keyword) || `#${tag.toLowerCase()}`.includes(keyword)
      );
      return titleMatch || authorMatch || hashtagMatch;
    });
  }

  async aboutToAppear() {
    this.allBooks = await BookModel.getBookList();
    this.isLoading = false;
  }

  @Builder
  bookItem(book: Book) {
    Column() {
      Row() {
        Text(book.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Text(`#${book.id}`)
          .fontSize(14)
          .fontColor('#999999')
      }
      .width('100%')

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

  @Builder
  bookItemGrid(book: Book) {
    Row() {
      Image($r('app.media.app_icon'))
        .width(60)
        .height(80)
        .borderRadius(4)
        .objectFit(ImageFit.Cover)

      Column() {
        Text(book.title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(book.author)
          .fontSize(11)
          .fontColor('#666666')
          .margin({ top: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          ForEach(book.hashtags.slice(0, 2), (tag: string) => {
            Text(`#${tag}`)
              .fontSize(10)
              .fontColor('#FF8C00')
              .backgroundColor('#FFF3E0')
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .borderRadius(2)
              .margin({ right: 4 })
          })
        }
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 8 })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding(8)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
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

  isSearching(): boolean {
    return this.searchText.trim().length > 0;
  }

  build() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(18)
          .fontColor(['#999999'])
          .margin({ left: 12 })

        TextInput({ placeholder: '搜索书名、作者或标签' })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(Color.Transparent)
          .placeholderColor('#999999')
          .placeholderFont({ size: 14 })
          .fontSize(14)
          .fontColor('#333333')
          .margin({ left: 8, right: 12 })
          .onChange((value: string) => {
            this.searchText = value;
          })
      }
      .width('95%')
      .height(48)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ left: 20, right: 20, top: 16, bottom: 12 })

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#FF8C00')
      } else if (this.isSearching()) {
        List() {
          ForEach(this.getFilteredBooks(), (book: Book) => {
            ListItem() {
              this.bookItem(book)
            }
            .padding({ left: 16, right: 16 })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      } else {
        Grid() {
          ForEach(this.allBooks, (book: Book) => {
            GridItem() {
              this.bookItemGrid(book)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .columnsTemplate('1fr 1fr')
        .rowsGap(4)
        .columnsGap(4)
        .padding({ left: 8, right: 8, bottom: 8 })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
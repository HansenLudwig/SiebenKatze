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
export struct LibraryPage {
  @State allBooks: Book[] = [];
  @State searchText: string = '';
  @State isLoading: boolean = true;
  @State currentTab: number = 1;
  @State currentSubTab: number = 0;

  private tabs: string[] = ['发现', '小说', '图书', '听书', '漫剧', '必读榜'];
  private subTabs: string[] = ['推荐榜', '大热榜', '完结榜', '好评榜'];
  private filteredBooks: Book[] = [];
  private profileManager: UserProfileManager | null = null;

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
    this.profileManager = await UserProfileManager.getInstance();
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
        if (this.profileManager && this.profileManager.getProgressPercent(book.id) > 0) {
          Text(`已读${this.profileManager.getProgressPercent(book.id)}%`)
            .fontSize(12)
            .fontColor('#FF8C00')
        }
        Text(`#${book.id}`)
          .fontSize(14)
          .fontColor('#999999')
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

        Row() {
          Text(book.author)
            .fontSize(11)
            .fontColor('#666666')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.profileManager && this.profileManager.getProgressPercent(book.id) > 0) {
            Text(`已读${this.profileManager.getProgressPercent(book.id)}%`)
              .fontSize(10)
              .fontColor('#FF8C00')
          }
        }
        .margin({ top: 4 })
        .width('100%')

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

      Scroll() {
        Row() {
          ForEach(this.tabs, (tab: string, index?: number) => {
            Column() {
              Text(tab)
                .fontSize(index === this.currentTab ? 20 : 17)
                .fontColor(index === this.currentTab ? '#FF8C00' : '#666666')
                .fontWeight(index === this.currentTab ? FontWeight.Bold : FontWeight.Normal)

              if (index === this.currentTab) {
                Row()
                  .width(20)
                  .height(3)
                  .backgroundColor('#FF8C00')
                  .borderRadius(2)
                  .margin({ top: 4 })
              }
            }
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .onClick(() => {
              if (index !== undefined) {
                this.currentTab = index;
              }
            })
          })
        }
        .justifyContent(FlexAlign.Start)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 12, right: 12 })
      .margin({ bottom: 8 })
      .align(Alignment.Start)

      if (this.currentTab === 1) {
        Row() {
          ForEach(this.subTabs, (tab: string, index?: number) => {
            Text(tab)
              .fontSize(13)
              .fontColor(index === this.currentSubTab ? '#FF8C00' : '#999999')
              .fontWeight(index === this.currentSubTab ? FontWeight.Bold : FontWeight.Normal)
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .borderRadius(16)
              .backgroundColor(index === this.currentSubTab ? '#FFF3E0' : Color.Transparent)
              .onClick(() => {
                if (index !== undefined) {
                  this.currentSubTab = index;
                }
              })
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 8 })
        .justifyContent(FlexAlign.Start)
      }

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#FF8C00')
      } else if (this.currentTab !== 1) {
        Column() {
          Text('敬请期待')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.currentSubTab !== 0) {
        Column() {
          Text('敬请期待')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
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
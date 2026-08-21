import { util } from '@kit.ArkTS';
import { router, window } from '@kit.ArkUI';
import { BookshelfManager } from '../model/BookshelfManager';

interface ReaderParams {
  fileName: string;
  title: string;
  bookId: string;
}

@Entry
@Component
struct BookReaderPage {
  @State content: string = '';
  @State title: string = '';
  @State isLoading: boolean = true;
  @State showMenu: boolean = false;
  @State isPageMode: boolean = false;
  @State currentPage: number = 0;
  @State pages: string[] = [];
  @State bookId: string = '';
  @State isInBookshelf: boolean = false;

  async aboutToAppear() {
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#FFF9F0',
      statusBarContentColor: '#333333'
    });

    const params = router.getParams() as ReaderParams;
    this.title = params.title || '阅读';
    this.bookId = params.bookId || '';
    
    const manager = await BookshelfManager.getInstance();
    this.isInBookshelf = manager.isInBookshelf(this.bookId);
    
    try {
      const context = getContext().resourceManager;
      const fileData = await context.getRawFileContent(params.fileName);
      const decoder = new util.TextDecoder('utf-8');
      this.content = decoder.decodeToString(fileData);
      this.pages = this.splitContentToPages(this.content);
    } catch (error) {
      console.error('Failed to load book content:', error);
      this.content = '无法加载书籍内容';
      this.pages = [this.content];
    }
    this.isLoading = false;
  }

  async toggleBookshelf() {
    const manager = await BookshelfManager.getInstance();
    this.isInBookshelf = await manager.toggleBookshelf(this.bookId);
  }

  splitContentToPages(content: string): string[] {
    const charsPerPage = 800;
    const pages: string[] = [];
    for (let i = 0; i < content.length; i += charsPerPage) {
      pages.push(content.slice(i, i + charsPerPage));
    }
    return pages;
  }

  async aboutToDisappear() {
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#F5F5F5',
      statusBarContentColor: '#000000'
    });
  }

  toggleMenu() {
    this.showMenu = !this.showMenu;
  }

  prevPage() {
    if (this.currentPage > 0) {
      this.currentPage--;
    } else {
      router.back();
    }
  }

  nextPage() {
    if (this.currentPage < this.pages.length - 1) {
      this.currentPage++;
    }
  }

  @Builder
  topMenu() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([Color.White])
      }
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        router.back();
      })

      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Button(this.isInBookshelf ? '已加入书架' : '加入书架')
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.toggleBookshelf();
        })

      Button() {
        SymbolGlyph($r('sys.symbol.ellipsis_circle'))
          .fontSize(20)
          .fontColor([Color.White])
      }
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .height(50)
    .backgroundColor('#FF8C00')
    .padding({ left: 12, right: 12 })
  }

  @Builder
  bottomMenu() {
    Row() {
      Column() {
        SymbolGlyph($r('sys.symbol.list_bullet'))
          .fontSize(24)
          .fontColor([Color.Black])
        Text('目录')
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(8)

      Column() {
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(24)
          .fontColor([Color.Black])
        Text('讨论')
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(8)

      Column() {
        SymbolGlyph($r('sys.symbol.moon'))
          .fontSize(24)
          .fontColor([Color.Black])
        Text('夜间模式')
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(8)

      Column() {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(24)
          .fontColor([Color.Black])
        Text('阅读设置')
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(8)
      .onClick(() => {
        this.isPageMode = !this.isPageMode;
        this.currentPage = 0;
        this.showMenu = false;
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#E5E5E5' })
  }

  @Builder
  scrollContent() {
    Scroll() {
      Column() {
        Text(this.content)
          .fontSize(16)
          .fontColor('#333333')
          .lineHeight(28)
          .padding(20)
          .onClick(() => {
            this.toggleMenu();
          })
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
    .scrollBarColor('#CCCCCC')
    .scrollBarWidth(4)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  pageContent() {
    Stack() {
      Text(this.pages[this.currentPage] || '')
        .fontSize(16)
        .fontColor('#333333')
        .lineHeight(28)
        .padding(20)

      Row() {
        Column()
          .width('20%')
          .height('100%')
          .onClick(() => {
            this.prevPage();
          })

        Column()
          .width('60%')
          .height('100%')
          .onClick(() => {
            this.toggleMenu();
          })

        Column()
          .width('20%')
          .height('100%')
          .onClick(() => {
            this.nextPage();
          })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .gesture(
      PanGesture()
        .onActionEnd((event: GestureEvent) => {
          if (event.offsetX > 50) {
            this.prevPage();
          } else if (event.offsetX < -50) {
            this.nextPage();
          }
        })
    )
  }

  build() {
    Stack() {
      Column() {
        if (this.showMenu) {
          this.topMenu()
        }

        if (this.isLoading) {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#FF8C00')
        } else if (this.isPageMode) {
          this.pageContent()
        } else {
          this.scrollContent()
        }

        if (this.showMenu) {
          this.bottomMenu()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFF9F0')
    }
    .width('100%')
    .height('100%')
  }
}
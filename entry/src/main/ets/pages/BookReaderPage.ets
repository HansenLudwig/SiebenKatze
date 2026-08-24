import { util } from '@kit.ArkTS';
import { router, window } from '@kit.ArkUI';
import { BookshelfManager } from '../model/BookshelfManager';

interface ReaderParams {
  fileName: string;
  title: string;
  bookId: string;
}

interface PageInfo {
  startIndex: number;
  endIndex: number;
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
  @State pages: PageInfo[] = [];
  @State bookId: string = '';
  @State isInBookshelf: boolean = false;
  @State displayHeight: number = 0;
  @State textHeight: number = 0;

  private paragraphs: string[] = [];
  private readonly lineHeight: number = 28;
  private readonly fontSize: number = 16;
  private readonly textPadding: number = 40;
  private estimatedLinesPerPage: number = 20;

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
      this.paragraphs = this.splitToParagraphs(this.content);
    } catch (error) {
      console.error('Failed to load book content:', error);
      this.content = '无法加载书籍内容';
      this.paragraphs = [this.content];
    }
    this.isLoading = false;
  }

  splitToParagraphs(content: string): string[] {
    return content.split(/\n+/).filter(p => p.trim().length > 0);
  }

  calculatePagesForHeight(height: number) {
    const availableHeight = height - this.textPadding * 2;
    const linesPerPage = Math.floor(availableHeight / this.lineHeight);
    this.estimatedLinesPerPage = Math.max(linesPerPage, 10);
    
    this.pages = [];
    let currentLines = 0;
    let startIndex = 0;
    
    for (let i = 0; i < this.paragraphs.length; i++) {
      const para = this.paragraphs[i];
      const charPerLine = Math.floor(this.getDisplayWidth() / (this.fontSize * 0.6));
      const paraLines = Math.ceil(para.length / charPerLine) + 0.5;
      
      if (currentLines + paraLines > this.estimatedLinesPerPage && currentLines > 0) {
        this.pages.push({ startIndex, endIndex: i - 1 });
        startIndex = i;
        currentLines = 0;
      }
      
      currentLines += paraLines;
    }
    
    if (startIndex < this.paragraphs.length) {
      this.pages.push({ startIndex, endIndex: this.paragraphs.length - 1 });
    }
  }

  getDisplayWidth(): number {
    return this.displayHeight > 0 ? 360 : 360;
  }

  async toggleBookshelf() {
    const manager = await BookshelfManager.getInstance();
    this.isInBookshelf = await manager.toggleBookshelf(this.bookId);
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

  getCurrentPageContent(): string {
    if (this.pages.length === 0 || this.currentPage >= this.pages.length) {
      return this.content;
    }
    const page = this.pages[this.currentPage];
    return this.paragraphs.slice(page.startIndex, page.endIndex + 1).join('\n\n');
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
          .fontSize(this.fontSize)
          .fontColor('#333333')
          .lineHeight(this.lineHeight)
          .padding(this.textPadding)
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
      Text(this.getCurrentPageContent())
        .fontSize(this.fontSize)
        .fontColor('#333333')
        .lineHeight(this.lineHeight)
        .padding(this.textPadding)
        .width('100%')
        .onAreaChange((oldValue: Area, newValue: Area) => {
          if (this.pages.length === 0 && newValue.height > 0) {
            this.textHeight = newValue.height as number;
          }
        })

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
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const newHeight = newValue.height as number;
      if (this.isPageMode && newHeight > 0 && newHeight !== this.displayHeight) {
        this.displayHeight = newHeight;
        this.calculatePagesForHeight(newHeight);
      }
    })
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
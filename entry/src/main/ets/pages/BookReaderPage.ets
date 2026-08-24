import { util } from '@kit.ArkTS';
import { router, window } from '@kit.ArkUI';
import { UserProfileManager } from '../model/UserProfileManager';

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
  @State scrollOffset: number = 0;
  @State displayWidth: number = 0;
  @State displayHeight: number = 0;

  private readonly lineHeight: number = 28;
  private readonly fontSize: number = 16;
  private readonly textPaddingH: number = 20;
  private readonly textPaddingV: number = 20;
  private profileManager: UserProfileManager | null = null;
  private scrollScroller: Scroller = new Scroller();
  private needsRecalc: boolean = true;
  private isSwiping: boolean = false;

  async aboutToAppear() {
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#FFF9F0',
      statusBarContentColor: '#333333'
    });

    const params = router.getParams() as ReaderParams;
    this.title = params.title || '阅读';
    this.bookId = params.bookId || '';
    
    this.profileManager = await UserProfileManager.getInstance();
    this.isInBookshelf = this.profileManager.isInBookshelf(this.bookId);
    this.isPageMode = this.profileManager.getPageMode();
    
    try {
      const context = getContext().resourceManager;
      const fileData = await context.getRawFileContent(params.fileName);
      const decoder = new util.TextDecoder('utf-8');
      this.content = decoder.decodeToString(fileData);
    } catch (error) {
      console.error('Failed to load book content:', error);
      this.content = '无法加载书籍内容';
    }

    const progress = this.profileManager.getReadingProgress(this.bookId);
    if (progress) {
      this.currentPage = progress.currentPage;
      this.scrollOffset = progress.scrollOffset;
    }

    this.isLoading = false;
  }

  measureTextWidth(text: string): number {
    let width = 0;
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF ||
          code >= 0x3000 && code <= 0x303F ||
          code >= 0xFF00 && code <= 0xFFEF ||
          code >= 0xF900 && code <= 0xFAFF ||
          code >= 0x2E80 && code <= 0x2EFF ||
          code >= 0x3400 && code <= 0x4DBF) {
        width += this.fontSize;
      } else {
        width += this.fontSize * 0.55;
      }
    }
    return width;
  }

  countLinesForText(text: string, textWidth: number): number {
    const lines = text.split('\n');
    let totalLines = 0;
    for (const line of lines) {
      if (line.length === 0) {
        totalLines += 1;
        continue;
      }
      const lineWidth = this.measureTextWidth(line);
      totalLines += Math.max(1, Math.ceil(lineWidth / textWidth));
    }
    return totalLines;
  }

  calculatePages() {
    if (this.displayWidth <= 0 || this.displayHeight <= 0 || this.content.length === 0) {
      return;
    }

    const textWidth = this.displayWidth - this.textPaddingH * 2;
    const textHeight = this.displayHeight - this.textPaddingV * 2;
    const linesPerPage = Math.max(Math.floor(textHeight / this.lineHeight), 5);

    const allLines: string[] = [];
    const rawLines = this.content.split('\n');
    for (const rawLine of rawLines) {
      if (rawLine.length === 0) {
        allLines.push('');
        continue;
      }
      let remaining = rawLine;
      while (remaining.length > 0) {
        let charCount = 0;
        let currentWidth = 0;
        for (let i = 0; i < remaining.length; i++) {
          const code = remaining.charCodeAt(i);
          const charWidth = (code >= 0x4E00 && code <= 0x9FFF ||
            code >= 0x3000 && code <= 0x303F ||
            code >= 0xFF00 && code <= 0xFFEF ||
            code >= 0xF900 && code <= 0xFAFF ||
            code >= 0x2E80 && code <= 0x2EFF ||
            code >= 0x3400 && code <= 0x4DBF) ? this.fontSize : this.fontSize * 0.55;
          if (currentWidth + charWidth > textWidth && charCount > 0) {
            break;
          }
          currentWidth += charWidth;
          charCount++;
        }
        if (charCount === 0) {
          charCount = 1;
        }
        allLines.push(remaining.substring(0, charCount));
        remaining = remaining.substring(charCount);
      }
    }

    this.pages = [];
    let lineIndex = 0;
    while (lineIndex < allLines.length) {
      const endLine = Math.min(lineIndex + linesPerPage, allLines.length);
      this.pages.push(allLines.slice(lineIndex, endLine).join('\n'));
      lineIndex = endLine;
    }

    if (this.currentPage >= this.pages.length) {
      this.currentPage = Math.max(0, this.pages.length - 1);
    }
    this.needsRecalc = false;
  }

  async toggleBookshelf() {
    const manager = await UserProfileManager.getInstance();
    this.isInBookshelf = await manager.toggleBookshelf(this.bookId);
  }

  async aboutToDisappear() {
    if (this.profileManager && this.bookId) {
      await this.profileManager.saveReadingProgress(this.bookId, this.currentPage, this.scrollOffset);
    }
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
        SymbolGlyph($r(this.isPageMode ? 'sys.symbol.doc_plaintext' : 'sys.symbol.book'))
          .fontSize(24)
          .fontColor([Color.Black])
        Text(this.isPageMode ? '滚动模式' : '翻页模式')
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(8)
      .onClick(() => {
        this.isPageMode = !this.isPageMode;
        if (this.profileManager) {
          this.profileManager.setPageMode(this.isPageMode);
        }
        this.currentPage = 0;
        this.showMenu = false;
        if (this.isPageMode) {
          this.needsRecalc = true;
        }
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#E5E5E5' })
  }

  @Builder
  scrollContent() {
    Scroll(this.scrollScroller) {
      Column() {
        Text(this.content)
          .fontSize(this.fontSize)
          .fontColor('#333333')
          .lineHeight(this.lineHeight)
          .padding({ left: this.textPaddingH, right: this.textPaddingH, top: this.textPaddingV, bottom: this.textPaddingV })
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
    .onDidScroll(() => {
      const offset = this.scrollScroller.currentOffset();
      this.scrollOffset = offset.yOffset;
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      if (newValue.height > 0 && this.scrollOffset > 0) {
        this.scrollScroller.scrollEdge(Edge.Top);
        this.scrollScroller.scrollTo({ xOffset: 0, yOffset: this.scrollOffset });
        this.scrollOffset = 0;
      }
    })
  }

  @Builder
  pageContent() {
    Stack() {
      Column() {
        Text(this.pages[this.currentPage] || '')
          .fontSize(this.fontSize)
          .fontColor('#333333')
          .lineHeight(this.lineHeight)
          .padding({ left: this.textPaddingH, right: this.textPaddingH, top: this.textPaddingV, bottom: this.textPaddingV })
          .width('100%')
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Row() {
        Column()
          .width('15%')
          .height('100%')
          .onClick(() => {
            if (!this.isSwiping) {
              this.prevPage();
            }
            this.isSwiping = false;
          })
          .gesture(
            PanGesture()
              .onActionStart(() => {
                this.isSwiping = true;
              })
              .onActionEnd((event: GestureEvent) => {
                if (event.offsetX > 30) {
                  this.prevPage();
                }
              })
          )

        Column()
          .width('70%')
          .height('100%')
          .onClick(() => {
            if (!this.isSwiping) {
              this.toggleMenu();
            }
            this.isSwiping = false;
          })
          .gesture(
            PanGesture()
              .onActionStart(() => {
                this.isSwiping = true;
              })
              .onActionEnd((event: GestureEvent) => {
                if (event.offsetX < -30) {
                  this.nextPage();
                } else if (event.offsetX > 30) {
                  this.prevPage();
                }
              })
          )

        Column()
          .width('15%')
          .height('100%')
          .onClick(() => {
            if (!this.isSwiping) {
              this.nextPage();
            }
            this.isSwiping = false;
          })
          .gesture(
            PanGesture()
              .onActionStart(() => {
                this.isSwiping = true;
              })
              .onActionEnd((event: GestureEvent) => {
                if (event.offsetX < -30) {
                  this.nextPage();
                }
              })
          )
      }
      .width('100%')
      .height('100%')

      if (!this.showMenu) {
        Text(`${this.currentPage + 1}/${this.pages.length}`)
          .fontSize(12)
          .fontColor('#000000')
          .backgroundColor('#80000000')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(10)
          .position({ x: '100%', y: '100%' })
          .translate({ x: '-100%', y: '-100%' })
          .margin({ right: 12, bottom: 12 })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const newWidth = newValue.width as number;
      const newHeight = newValue.height as number;
      if (this.isPageMode && (newWidth !== this.displayWidth || newHeight !== this.displayHeight || this.needsRecalc)) {
        this.displayWidth = newWidth;
        this.displayHeight = newHeight;
        this.calculatePages();
      }
    })
  }

  build() {
    Stack() {
      Column() {
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
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFF9F0')

      if (this.showMenu) {
        Column() {
          this.topMenu()

          Column() {
          }
          .layoutWeight(1)
          .width('100%')
          .onClick(() => {
            this.showMenu = false;
          })

          this.bottomMenu()
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
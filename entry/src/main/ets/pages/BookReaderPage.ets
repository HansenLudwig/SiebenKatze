import { util } from '@kit.ArkTS';
import { router, window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { UserProfileManager } from '../model/UserProfileManager';
import { EpubParser } from '../model/EpubParser';

interface ReaderParams {
  fileName: string;
  title: string;
  bookId: string;
}

class ReaderBridge {
  updateScroll: (offset: number) => void = (_offset: number): void => {};
  onViewerReady: () => void = (): void => {};
  onEpubRendered: () => void = (): void => {};
  onPdfRendered: () => void = (): void => {};
  requestToggleMenu: () => void = (): void => {};
}

@Entry
@Component
struct BookReaderPage {
  @State content: string = '';
  @State title: string = '';
  @State isLoading: boolean = true;
  @State showMenu: boolean = false;
  @State showSettings: boolean = false;
  @State isPageMode: boolean = false;
  @State currentPage: number = 0;
  @State pages: string[] = [];
  @State bookId: string = '';
  @State isInBookshelf: boolean = false;
  @State scrollOffset: number = 0;
  @State displayWidth: number = 0;
  @State displayHeight: number = 0;
  @State fileFormat: string = 'txt';
  @State webViewController: webview.WebviewController = new webview.WebviewController();

  private readonly lineHeight: number = 28;
  private readonly fontSize: number = 16;
  private readonly textPaddingH: number = 20;
  private readonly textPaddingV: number = 20;
  private profileManager: UserProfileManager | null = null;
  private scrollScroller: Scroller = new Scroller();
  private needsRecalc: boolean = true;
  private isSwiping: boolean = false;
  private webContentLoaded: boolean = false;
  private base64Data: string = '';
  private bridge: ReaderBridge = new ReaderBridge();
  private isSliding: boolean = false;
  @State pageOffsetX: number = 0;

  async aboutToAppear() {
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#FFF9F0',
      statusBarContentColor: '#333333'
    });

    const params = router.getParams() as ReaderParams;
    this.title = params.title || '阅读';
    this.bookId = params.bookId || '';

    const ext: string = params.fileName.split('.').pop()?.toLowerCase() || 'txt';
    if (ext === 'epub') {
      this.fileFormat = 'epub';
    } else if (ext === 'pdf') {
      this.fileFormat = 'pdf';
    } else {
      this.fileFormat = 'txt';
    }

    this.profileManager = await UserProfileManager.getInstance();
    this.isInBookshelf = this.profileManager.isInBookshelf(this.bookId);
    this.isPageMode = this.profileManager.getPageMode();

    const progress = this.profileManager.getReadingProgress(this.bookId);
    if (progress) {
      this.currentPage = progress.currentPage;
      this.scrollOffset = progress.scrollOffset;
    }

    if (this.fileFormat === 'txt') {
      try {
        const context = getContext().resourceManager;
        const fileData = await context.getRawFileContent(params.fileName);
        const decoder = new util.TextDecoder('utf-8');
        this.content = decoder.decodeToString(fileData);
      } catch (error) {
        console.error('Failed to load book content:', error);
        this.content = '无法加载书籍内容';
      }
      this.isLoading = false;
    } else {
      try {
        this.base64Data = await EpubParser.toBase64(getContext(), params.fileName);
      } catch (error) {
        console.error('Failed to convert book to base64:', error);
        this.base64Data = '';
      }
      this.isLoading = false;
    }

    this.bridge.updateScroll = (offset: number): void => {
      this.scrollOffset = offset;
    };
    this.bridge.onViewerReady = (): void => {
      this.sendContentToViewer();
    };
    this.bridge.onEpubRendered = (): void => {
      this.webContentLoaded = true;
      if (this.isPageMode) {
        setTimeout(() => {
          this.webViewController.runJavaScript(`setPageMode(true, ${this.scrollOffset})`);
        }, 300);
      } else if (this.scrollOffset > 0) {
        setTimeout(() => {
          this.webViewController.runJavaScript(`window.scrollTo(0, ${this.scrollOffset})`);
        }, 300);
      }
    };
    this.bridge.onPdfRendered = (): void => {
      this.webContentLoaded = true;
      if (this.isPageMode) {
        setTimeout(() => {
          this.webViewController.runJavaScript(`setPageMode(true, ${this.scrollOffset})`);
        }, 300);
      } else if (this.scrollOffset > 0) {
        setTimeout(() => {
          this.webViewController.runJavaScript(`window.scrollTo(0, ${this.scrollOffset})`);
        }, 300);
      }
    };
    this.bridge.requestToggleMenu = (): void => {
      this.showMenu = !this.showMenu;
    };
  }

  private sendContentToViewer() {
    if (!this.base64Data) {
      return;
    }
    if (this.fileFormat === 'epub') {
      this.webViewController.runJavaScript(`loadEpubFromBase64("${this.base64Data}")`);
    } else if (this.fileFormat === 'pdf') {
      this.webViewController.runJavaScript(`loadPdfFromBase64("${this.base64Data}")`);
    }
  }

  measureTextWidth(text: string): number {
    let width: number = 0;
    for (let i = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i);
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

  calculatePages() {
    if (this.displayWidth <= 0 || this.displayHeight <= 0 || this.content.length === 0) {
      return;
    }

    const textWidth: number = this.displayWidth - this.textPaddingH * 2;
    const textHeight: number = this.displayHeight - this.textPaddingV * 2;
    const linesPerPage: number = Math.max(Math.floor(textHeight / this.lineHeight), 5);

    const allLines: string[] = [];
    const rawLines: string[] = this.content.split('\n');
    for (let r = 0; r < rawLines.length; r++) {
      const rawLine: string = rawLines[r];
      if (rawLine.length === 0) {
        allLines.push('');
        continue;
      }
      let remaining: string = rawLine;
      while (remaining.length > 0) {
        let charCount: number = 0;
        let currentWidth: number = 0;
        for (let i = 0; i < remaining.length; i++) {
          const code: number = remaining.charCodeAt(i);
          const charWidth: number = (code >= 0x4E00 && code <= 0x9FFF ||
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
    let lineIndex: number = 0;
    while (lineIndex < allLines.length) {
      const endLine: number = Math.min(lineIndex + linesPerPage, allLines.length);
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
      if (this.fileFormat === 'txt') {
        await this.profileManager.saveReadingProgress(this.bookId, this.currentPage, this.scrollOffset);
      } else {
        await this.profileManager.saveReadingProgress(this.bookId, 0, this.scrollOffset);
      }
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

  applyPageMode(pageMode: boolean) {
    if (this.fileFormat === 'txt') {
      if (pageMode) {
        const offset = this.scrollScroller.currentOffset();
        const scrollY: number = offset.yOffset;
        if (this.displayHeight > 0 && scrollY > 0) {
          this.currentPage = Math.floor(scrollY / this.displayHeight);
        } else {
          this.currentPage = 0;
        }
        this.needsRecalc = true;
      } else {
        if (this.pages.length > 0 && this.currentPage > 0 && this.displayHeight > 0) {
          const linesPerPage: number = Math.max(Math.floor((this.displayHeight - this.textPaddingV * 2) / this.lineHeight), 5);
          this.scrollOffset = this.currentPage * linesPerPage * this.lineHeight;
        }
      }
    }
    this.isPageMode = pageMode;
    if (this.profileManager) {
      this.profileManager.setPageMode(this.isPageMode);
    }
    if (this.fileFormat !== 'txt') {
      this.webViewController.runJavaScript(`setPageMode(${this.isPageMode})`);
    }
    this.showSettings = false;
    this.showMenu = false;
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

  slideToPrevPage() {
    if (this.isSliding) return;
    if (this.currentPage <= 0) {
      router.back();
      return;
    }
    this.isSliding = true;
    this.currentPage--;
    this.pageOffsetX = -this.displayWidth;
    setTimeout(() => {
      animateTo({ duration: 280, curve: Curve.EaseInOut, onFinish: () => {
        this.isSliding = false;
      }}, () => {
        this.pageOffsetX = 0;
      });
    }, 16);
  }

  slideToNextPage() {
    if (this.isSliding) return;
    if (this.currentPage >= this.pages.length - 1) return;
    this.isSliding = true;
    this.currentPage++;
    this.pageOffsetX = this.displayWidth;
    setTimeout(() => {
      animateTo({ duration: 280, curve: Curve.EaseInOut, onFinish: () => {
        this.isSliding = false;
      }}, () => {
        this.pageOffsetX = 0;
      });
    }, 16);
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
    Column() {
      if (this.showSettings) {
        Column() {
          Text('翻页方式')
            .fontSize(15)
            .fontColor('#333333')
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 12 })

          Row() {
            Button('滚动')
              .fontSize(14)
              .fontColor(this.isPageMode ? '#666666' : '#FFFFFF')
              .backgroundColor(this.isPageMode ? '#F0F0F0' : '#FF8C00')
              .borderRadius(20)
              .height(36)
              .layoutWeight(1)
              .onClick(() => {
                this.applyPageMode(false);
              })

            Button('侧滑')
              .fontSize(14)
              .fontColor(this.isPageMode ? '#FFFFFF' : '#666666')
              .backgroundColor(this.isPageMode ? '#FF8C00' : '#F0F0F0')
              .borderRadius(20)
              .height(36)
              .layoutWeight(1)
              .margin({ left: 12 })
              .onClick(() => {
                this.applyPageMode(true);
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        .backgroundColor('#FFFFFF')
        .border({ width: { bottom: 1 }, color: '#E5E5E5' })
      }

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
          Text('设置')
            .fontSize(12)
            .fontColor('#333333')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .padding(8)
        .onClick(() => {
          this.showSettings = !this.showSettings;
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 1 }, color: '#E5E5E5' })
    }
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
      .translate({ x: this.pageOffsetX })

      Row() {
        Column()
          .width('15%')
          .height('100%')
          .onClick(() => {
            if (!this.isSwiping) {
              this.slideToPrevPage();
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
                  this.slideToPrevPage();
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
                  this.slideToNextPage();
                } else if (event.offsetX > 30) {
                  this.slideToPrevPage();
                }
              })
          )

        Column()
          .width('15%')
          .height('100%')
          .onClick(() => {
            if (!this.isSwiping) {
              this.slideToNextPage();
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
                  this.slideToNextPage();
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
    .clip(true)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const newWidth: number = newValue.width as number;
      const newHeight: number = newValue.height as number;
      if (this.isPageMode && (newWidth !== this.displayWidth || newHeight !== this.displayHeight || this.needsRecalc)) {
        this.displayWidth = newWidth;
        this.displayHeight = newHeight;
        this.calculatePages();
      }
    })
  }

  @Builder
  webReader() {
    Web({
      src: this.fileFormat === 'epub' ? $rawfile('epub_viewer.html') : $rawfile('pdf_viewer.html'),
      controller: this.webViewController
    })
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#FFF9F0')
      .domStorageAccess(true)
      .javaScriptAccess(true)
      .fileAccess(true)
      .javaScriptProxy({
        object: this.bridge as object,
        name: 'readerBridge',
        methodList: ['updateScroll', 'onViewerReady', 'onEpubRendered', 'onPdfRendered', 'requestToggleMenu'],
        controller: this.webViewController
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
        } else if (this.fileFormat === 'txt') {
          if (this.isPageMode) {
            this.pageContent()
          } else {
            this.scrollContent()
          }
        } else {
          this.webReader()
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

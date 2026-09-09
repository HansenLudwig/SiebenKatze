import { util } from '@kit.ArkTS';
import { router, window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { common, Want } from '@kit.AbilityKit';
import { FunctionComponent, FunctionController, ButtonType } from '@kit.AgentFrameworkKit';
import { UserProfileManager } from '../model/UserProfileManager';
import { EpubParser } from '../model/EpubParser';
import { AgentDataHelper } from '../model/AgentDataHelper';

interface ReaderParams {
  fileName: string;
  title: string;
  bookId: string;
  author: string;
}

class ReaderBridge {
  updateScroll: (offset: number) => void = (_offset: number): void => {};
  onViewerReady: () => void = (): void => {};
  onEpubRendered: () => void = (): void => {};
  onPdfRendered: () => void = (): void => {};
  requestToggleMenu: () => void = (): void => {};
  updateTotalPages: (total: number) => void = (_total: number): void => {};
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
  private author: string = '';
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
  private webContentLoaded: boolean = false;
  private base64Data: string = '';
  private bridge: ReaderBridge = new ReaderBridge();
  private _totalPages: number = 0;
  @State offsetX: number = 0;
  @State leftPageContent: string = '';
  @State midPageContent: string = '';
  @State rightPageContent: string = '';
  @State showProgressToast: boolean = false;
  @State agentQueryText: string = '你好';

  private readonly AGENT_ID: string = 'agentf0c9eddc463447e290513ec174eb57cd'; // 'agentf0c9eddc463447e290513ec174eb57cd'; // 'agent-a2a-sieben-katze';
  private functionController: FunctionController = new FunctionController();
  private agentSupported: boolean = false;

  async aboutToAppear() {
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#FFF9F0',
      statusBarContentColor: '#333333'
    });

    const params = router.getParams() as ReaderParams;
    this.title = params.title || '阅读';
    this.bookId = params.bookId || '';
    this.author = params.author || '';

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
    if (progress && (progress.scrollOffset > 0 || progress.currentPage > 0)) {
      this.currentPage = progress.currentPage;
      this.scrollOffset = progress.scrollOffset;
      this.showProgressToast = true;
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

    this.writeLastBookData();

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
          this.showProgressToast = false;
        }, 300);
      } else if (this.scrollOffset > 0) {
        setTimeout(() => {
          this.webViewController.runJavaScript(`window.scrollTo(0, ${this.scrollOffset})`);
          this.showProgressToast = false;
        }, 300);
      } else {
        this.showProgressToast = false;
      }
    };
    this.bridge.onPdfRendered = (): void => {
      this.webContentLoaded = true;
      if (this.isPageMode) {
        setTimeout(() => {
          this.webViewController.runJavaScript(`setPageMode(true, ${this.scrollOffset})`);
          this.showProgressToast = false;
        }, 300);
      } else if (this.scrollOffset > 0) {
        setTimeout(() => {
          this.webViewController.runJavaScript(`window.scrollTo(0, ${this.scrollOffset})`);
          this.showProgressToast = false;
        }, 300);
      } else {
        this.showProgressToast = false;
      }
    };
    this.bridge.requestToggleMenu = (): void => {
      this.toggleMenu();
    };
    this.bridge.updateTotalPages = (total: number): void => {
      this._totalPages = total;
    };

    if (this.AGENT_ID.length > 0) {
      this.loadBookListForAgent();
      try {
        const uiContext = getContext(this) as common.UIAbilityContext;
        this.functionController.isAgentSupport(uiContext, this.AGENT_ID).then((supported: boolean) => {
          this.agentSupported = supported;
          console.info('[Agent] isAgentSupport result: ' + supported);
        }).catch((err: BusinessError) => {
          this.agentSupported = false;
          console.error('[Agent] isAgentSupport failed: code=' + err.code + ' msg=' + err.message);
        });
      } catch (e) {
        this.agentSupported = false;
        console.error('[Agent] isAgentSupport exception: ' + e);
      }
      this.functionController.on('agentDialogOpened', () => {
        console.info('[Agent] dialog opened');
      });
      this.functionController.on('agentDialogClosed', () => {
        console.info('[Agent] dialog closed');
        this.showMenu = false;
      });
    }
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
    this._totalPages = this.pages.length;
    this.needsRecalc = false;
  }

  async toggleBookshelf() {
    const manager = await UserProfileManager.getInstance();
    this.isInBookshelf = await manager.toggleBookshelf(this.bookId);
  }

  private doSaveProgress() {
    if (!this.profileManager || !this.bookId) return;
    let progressPercent: number = 0;
    if (this.fileFormat === 'txt') {
      if (this.isPageMode && this.pages.length > 0 && this.currentPage > 0 && this.displayHeight > 0) {
        const linesPerPage: number = Math.max(Math.floor((this.displayHeight - this.textPaddingV * 2) / this.lineHeight), 5);
        this.scrollOffset = this.currentPage * linesPerPage * this.lineHeight;
      } else if (!this.isPageMode) {
        const offset = this.scrollScroller.currentOffset();
        this.scrollOffset = offset.yOffset;
      }
      if (this._totalPages > 0) {
        progressPercent = Math.min(Math.round(this.currentPage / this._totalPages * 100), 100);
      }
    } else {
      if (this._totalPages > 0) {
        const page: number = Math.floor(this.scrollOffset / this.displayHeight);
        progressPercent = Math.min(Math.round(page / this._totalPages * 100), 100);
      }
    }
    this.profileManager.saveReadingProgress(this.bookId, this.currentPage, this.scrollOffset, progressPercent);
    this.writeLastBookData();
  }

  private writeLastBookData(): void {
    const totalPages: number = this.fileFormat === 'txt' ? this.pages.length : this._totalPages;
    let progressPercent: number = 0;
    if (totalPages > 0) {
      if (this.fileFormat === 'txt' && this.pages.length > 0) {
        progressPercent = Math.min(Math.round(this.currentPage / totalPages * 100), 100);
      } else if (this._totalPages > 0 && this.displayHeight > 0) {
        const page: number = Math.floor(this.scrollOffset / this.displayHeight);
        progressPercent = Math.min(Math.round(page / this._totalPages * 100), 100);
      }
    }
    const lastBookObj: Record<string, Object> = {
      'bookId': this.bookId,
      'title': this.title,
      'author': this.author,
      'format': this.fileFormat.toUpperCase(),
      'currentPage': this.currentPage,
      'totalPages': totalPages,
      'progressPercent': progressPercent
    };
    AgentDataHelper.writeLastBook(getContext(this) as common.Context, JSON.stringify(lastBookObj));
  }

  onPageHide() {
    this.doSaveProgress();
  }

  async aboutToDisappear() {
    this.doSaveProgress();
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#F5F5F5',
      statusBarContentColor: '#000000'
    });
  }

  toggleMenu() {
    if (!this.showMenu) {
      this.buildAgentQueryText();
    }
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
        this.simulatePageContent();
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
      this.simulatePageContent();
    } else {
      router.back();
    }
  }

  nextPage() {
    if (this.currentPage < this.pages.length - 1) {
      this.currentPage++;
      this.simulatePageContent();
    }
  }

  private simulatePageContent() {
    this.midPageContent = this.pages[this.currentPage] || '';
    if (this.currentPage > 0) {
      this.leftPageContent = this.pages[this.currentPage - 1] || '';
    } else {
      this.leftPageContent = '';
    }
    if (this.currentPage < this.pages.length - 1) {
      this.rightPageContent = this.pages[this.currentPage + 1] || '';
    } else {
      this.rightPageContent = '';
    }
  }

  private pageAnimateTo(targetOffset: number, isForward: boolean) {
    animateTo({
      duration: 280,
      curve: Curve.EaseOut,
      onFinish: () => {
        if (targetOffset !== 0) {
          if (isForward && this.currentPage < this.pages.length - 1) {
            this.currentPage++;
          } else if (!isForward && this.currentPage > 0) {
            this.currentPage--;
          }
        }
        this.offsetX = 0;
        this.simulatePageContent();
      }
    }, () => {
      this.offsetX = targetOffset;
    });
  }

  private buildAgentQueryText() {
    const totalPages: number = this.fileFormat === 'txt' ? this.pages.length : this._totalPages;
    let progressPercent: number = 0;
    if (totalPages > 0) {
      if (this.fileFormat === 'txt' && this.pages.length > 0) {
        progressPercent = Math.min(Math.round(this.currentPage / totalPages * 100), 100);
      } else if (this._totalPages > 0 && this.displayHeight > 0) {
        const page: number = Math.floor(this.scrollOffset / this.displayHeight);
        progressPercent = Math.min(Math.round(page / this._totalPages * 100), 100);
      }
    }

    let prevSnippet: string = '';
    if (this.leftPageContent.length > 0) {
      prevSnippet = this.leftPageContent.length > 200
        ? this.leftPageContent.substring(this.leftPageContent.length - 200) : this.leftPageContent;
    }
    let nextSnippet: string = '';
    if (this.rightPageContent.length > 0) {
      nextSnippet = this.rightPageContent.length > 200
        ? this.rightPageContent.substring(0, 200) : this.rightPageContent;
    }

    const contextObj: Record<string, Object> = {
      'title': this.title,
      'format': this.fileFormat.toUpperCase(),
      'currentPage': this.currentPage,
      'totalPages': totalPages,
      'progressPercent': progressPercent,
      'currentContent': this.midPageContent,
      'prevContent': prevSnippet,
      'nextContent': nextSnippet,
    };
    AgentDataHelper.writeBookContext(getContext(this) as common.Context, JSON.stringify(contextObj));

    let text: string = `我正在阅读《${this.title}》（${this.fileFormat.toUpperCase()}格式），`;
    text += `当前在第${this.currentPage + 1}页，共${totalPages}页，阅读进度${progressPercent}%。`;
    if (this.fileFormat === 'txt' && this.midPageContent.length > 0) {
      text += `\n\n当前页面内容：\n${this.midPageContent}`;
    }
    if (prevSnippet.length > 0) {
      text += `\n\n上一页末尾内容：\n${prevSnippet}`;
    }
    if (nextSnippet.length > 0) {
      text += `\n\n下一页开头内容：\n${nextSnippet}`;
    }
    this.agentQueryText = text;
    console.info('[Agent] queryText built, length=' + text.length);
  }

  private async loadBookListForAgent() {
    try {
      const ctx = getContext(this).resourceManager;
      const rawFile: Uint8Array = await ctx.getRawFileContent('book_list.json');
      const decoder = new util.TextDecoder('utf-8');
      const bookListJson: string = decoder.decodeToString(rawFile);
      AppStorage.setOrCreate<string>('agent_book_list', bookListJson);
      AgentDataHelper.writeBookList(getContext(this) as common.Context, bookListJson);
    } catch (e) {
      console.error('[Agent] load book list failed: ' + e);
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

      FunctionComponent({
        agentId: this.AGENT_ID,
        onError: (err: BusinessError) => {
          console.error('[Agent] FunctionComponent error: code=' + err.code + ' msg=' + err.message);
        },
        options: {
          title: '',
          buttonType: ButtonType.CIRCLE,
          isShowShadow: false,
          backgroundColor: '#00000000',
          iconColors: ['#FFFFFF'],
          titleColors: ['#FFFFFF'],
          queryText: this.agentQueryText,
        },
        controller: this.functionController
      })
        .width(36)
        .height(36)

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
      const newWidth: number = newValue.width as number;
      const newHeight: number = newValue.height as number;
      if (newWidth > 0) this.displayWidth = newWidth;
      if (newHeight > 0) this.displayHeight = newHeight;
      if (newHeight > 0 && this.scrollOffset > 0) {
        this.scrollScroller.scrollEdge(Edge.Top);
        this.scrollScroller.scrollTo({ xOffset: 0, yOffset: this.scrollOffset });
        this.scrollOffset = 0;
        this.showProgressToast = false;
      }
    })
  }

  @Builder
  pageContent() {
    Stack() {
      Column() {
        Text(this.rightPageContent)
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

      Column() {
        Text(this.midPageContent)
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
      .translate({ x: this.offsetX >= 0 ? 0 : this.offsetX })

      Column() {
        Text(this.leftPageContent)
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
      .translate({ x: -this.displayWidth + this.offsetX })

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
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        PanGesture(new PanGestureOptions({ direction: PanDirection.Horizontal }))
          .onActionStart(() => {
            this.offsetX = 0;
          })
          .onActionUpdate((event?: GestureEvent) => {
            if (event) {
              if (event.offsetX > 0 && this.currentPage <= 0) {
                this.offsetX = event.offsetX * 0.3;
              } else if (event.offsetX < 0 && this.currentPage >= this.pages.length - 1) {
                this.offsetX = event.offsetX * 0.3;
              } else {
                this.offsetX = event.offsetX;
              }
            }
          })
          .onActionEnd(() => {
            if (this.offsetX < -50 && this.currentPage < this.pages.length - 1) {
              this.pageAnimateTo(-this.displayWidth, true);
            } else if (this.offsetX > 50 && this.currentPage > 0) {
              this.pageAnimateTo(this.displayWidth, false);
            } else if (this.offsetX > 15 && this.currentPage <= 0) {
              router.back();
            } else {
              this.pageAnimateTo(0, false);
            }
          }),
        TapGesture()
          .onAction(() => {
            this.toggleMenu();
          })
      )
    )
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const newWidth: number = newValue.width as number;
      const newHeight: number = newValue.height as number;
      if (this.isPageMode && (newWidth !== this.displayWidth || newHeight !== this.displayHeight || this.needsRecalc)) {
        let savedLineIndex: number = 0;
        if (!this.needsRecalc && this.displayHeight > 0 && this.currentPage > 0) {
          const oldLinesPerPage: number = Math.max(Math.floor((this.displayHeight - this.textPaddingV * 2) / this.lineHeight), 5);
          savedLineIndex = this.currentPage * oldLinesPerPage;
        }
        this.displayWidth = newWidth;
        this.displayHeight = newHeight;
        this.calculatePages();
        if (savedLineIndex > 0) {
          const newLinesPerPage: number = Math.max(Math.floor((this.displayHeight - this.textPaddingV * 2) / this.lineHeight), 5);
          this.currentPage = Math.min(Math.floor(savedLineIndex / newLinesPerPage), Math.max(0, this.pages.length - 1));
        }
        this.simulatePageContent();
        this.showProgressToast = false;
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
        methodList: ['updateScroll', 'onViewerReady', 'onEpubRendered', 'onPdfRendered', 'requestToggleMenu', 'updateTotalPages'],
        controller: this.webViewController
      })
      .onAreaChange((oldValue: Area, newValue: Area) => {
        const newWidth: number = newValue.width as number;
        const newHeight: number = newValue.height as number;
        if (newWidth > 0 && newHeight > 0 && (newWidth !== this.displayWidth || newHeight !== this.displayHeight)) {
          this.displayWidth = newWidth;
          this.displayHeight = newHeight;
          if (this.webContentLoaded && this.isPageMode) {
            this.webViewController.runJavaScript('if(typeof refreshPageLayout==="function")refreshPageLayout()');
          }
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

      if (this.showProgressToast) {
        Row() {
          LoadingProgress()
            .width(16)
            .height(16)
            .color('#FFFFFF')
          Text('阅读进度加载中')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .margin({ left: 8 })
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#CC000000')
        .borderRadius(20)
        .position({ x: '50%', y: '50%' })
        .translate({ x: '-50%', y: '-50%' })
      }
    }
    .width('100%')
    .height('100%')
  }
}

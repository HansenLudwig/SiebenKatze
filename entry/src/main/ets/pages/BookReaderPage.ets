import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { router, window } from '@kit.ArkUI';
import { bookParser } from '@hms.core.readerservice.bookParser';
import { ReadPageComponent, readerCore } from '@hms.core.readerservice.readerComponent';
import { UserProfileManager } from '../model/UserProfileManager';

interface ReaderParams {
  fileName: string;
  title: string;
  bookId: string;
}

@Entry
@Component
struct BookReaderPage {
  @State title: string = '';
  @State isLoading: boolean = true;
  @State showMenu: boolean = false;
  @State bookId: string = '';
  @State isInBookshelf: boolean = false;
  @State currentPageInfo: string = '';
  @State nightMode: boolean = false;
  @State flipMode: string = '0';

  private controller: readerCore.ReaderComponentController = new readerCore.ReaderComponentController();
  private profileManager: UserProfileManager | null = null;
  private lastStartDomPos: string = '';
  private lastSpineIndex: number = 0;
  private bookParserHandler: bookParser.BookParserHandler | null = null;
  private sandboxEpubPath: string = '';
  private abilityContext: common.UIAbilityContext | null = null;
  private readerSetupDone: boolean = false;

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

    try {
      const context = getContext() as common.UIAbilityContext;
      this.abilityContext = context;
      const filesDir = context.filesDir;
      this.sandboxEpubPath = `${filesDir}/${params.fileName}`;

      if (!fs.accessSync(this.sandboxEpubPath)) {
        const rawContent = await context.resourceManager.getRawFileContent(params.fileName);
        const file = fs.openSync(this.sandboxEpubPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
        fs.writeSync(file.fd, rawContent.buffer);
        fs.closeSync(file);
      }

      this.bookParserHandler = await bookParser.getDefaultHandler(this.sandboxEpubPath);

      const bookInfo = this.bookParserHandler.getBookInfo();
      console.info('[Reader] BookInfo: ' + JSON.stringify(bookInfo));
      const catalog = this.bookParserHandler.getCatalogList();
      console.info('[Reader] Catalog count: ' + catalog.length);
      const spine = this.bookParserHandler.getSpineList();
      console.info('[Reader] Spine count: ' + spine.length);
      for (let i = 0; i < spine.length; i++) {
        console.info('[Reader] Spine[' + i + ']: ' + JSON.stringify(spine[i]));
      }
    } catch (error) {
      console.error('[Reader] Failed to prepare epub:', JSON.stringify(error));
      this.isLoading = false;
      return;
    }

    this.isLoading = false;
  }

  async aboutToDisappear() {
    if (this.profileManager && this.bookId && this.readerSetupDone) {
      await this.profileManager.saveReadingProgressDomPos(
        this.bookId, this.lastSpineIndex, this.lastStartDomPos
      );
    }
    if (this.readerSetupDone) {
      this.controller.releaseBook();
    }
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#F5F5F5',
      statusBarContentColor: '#000000'
    });
  }

  async toggleBookshelf() {
    const manager = await UserProfileManager.getInstance();
    this.isInBookshelf = await manager.toggleBookshelf(this.bookId);
  }

  toggleMenu() {
    this.showMenu = !this.showMenu;
  }

  async setupReader(ctrl: readerCore.ReaderComponentController) {
    if (this.readerSetupDone) {
      return;
    }

    console.info('[Reader] setupReader: start');

    try {
      await ctrl.init(this.abilityContext!);
      console.info('[Reader] controller.init succeeded');
    } catch (e) {
      console.error('[Reader] controller.init failed:', JSON.stringify(e));
      return;
    }

    ctrl.registerBookParser(this.bookParserHandler!);
    console.info('[Reader] registerBookParser done');

    ctrl.on('pageShow', (pageData: readerCore.PageDataInfo) => {
      console.info('[Reader] pageShow: state=' + pageData.state +
        ' spine=' + pageData.resourceIndex +
        ' footer=' + pageData.pageFooterContent +
        ' startDomPos=' + pageData.startDomPos +
        ' endDomPos=' + pageData.endDomPos);
      if (pageData.state === readerCore.PageState.PAGE_ON_SHOW) {
        this.lastStartDomPos = pageData.startDomPos;
        this.lastSpineIndex = pageData.resourceIndex;
        this.currentPageInfo = pageData.pageFooterContent || '';
      } else if (pageData.state === readerCore.PageState.OPEN_BOOK_FAIL) {
        console.error('[Reader] OPEN_BOOK_FAIL');
      }
    });

    const progress = this.profileManager!.getReadingProgress(this.bookId);
    let startSpine = 0;
    let startDomPos = '';
    if (progress && progress.spineIndex !== undefined) {
      startSpine = progress.spineIndex;
      startDomPos = progress.startDomPos || '';
    }

    try {
      console.info('[Reader] startPlay: spine=' + startSpine + ' domPos="' + startDomPos + '"');
      await ctrl.startPlay(startSpine, startDomPos);
      console.info('[Reader] startPlay succeeded');
      this.readerSetupDone = true;
    } catch (err) {
      console.error('[Reader] startPlay failed:', JSON.stringify(err));
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
        SymbolGlyph($r('sys.symbol.moon'))
          .fontSize(24)
          .fontColor([Color.Black])
        Text(this.nightMode ? '日间模式' : '夜间模式')
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(8)
      .onClick(() => {
        this.nightMode = !this.nightMode;
        try {
          this.controller.setPageConfig({
            fontName: 'system',
            fontSize: 18,
            fontWeight: 400,
            fontColor: this.nightMode ? '#CCCCCC' : '#181818',
            fontPath: '',
            lineHeight: 1.9,
            nightMode: this.nightMode,
            themeColor: this.nightMode ? 'rgba(26, 26, 26, 1)' : 'rgba(248, 249, 250, 1)',
            themeBgImg: '',
            flipMode: this.flipMode,
            scaledDensity: 1.0,
            viewPortWidth: 0,
            viewPortHeight: 0
          });
        } catch (e) {
          console.error('[Reader] nightMode setPageConfig error:', JSON.stringify(e));
        }
        this.showMenu = false;
      })

      Column() {
        SymbolGlyph($r('sys.symbol.book'))
          .fontSize(24)
          .fontColor([Color.Black])
        Text(this.flipMode === '0' ? '滑动翻页' : '仿真翻页')
          .fontSize(12)
          .fontColor('#333333')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(8)
      .onClick(() => {
        this.flipMode = this.flipMode === '0' ? '1' : '0';
        try {
          this.controller.setPageConfig({
            fontName: 'system',
            fontSize: 18,
            fontWeight: 400,
            fontColor: this.nightMode ? '#CCCCCC' : '#181818',
            fontPath: '',
            lineHeight: 1.9,
            nightMode: this.nightMode,
            themeColor: this.nightMode ? 'rgba(26, 26, 26, 1)' : 'rgba(248, 249, 250, 1)',
            themeBgImg: '',
            flipMode: this.flipMode,
            scaledDensity: 1.0,
            viewPortWidth: 0,
            viewPortHeight: 0
          });
        } catch (e) {
          console.error('[Reader] flipMode setPageConfig error:', JSON.stringify(e));
        }
        this.showMenu = false;
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#E5E5E5' })
  }

  build() {
    Stack() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#FF8C00')
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#FFF9F0')
        .justifyContent(FlexAlign.Center)
      } else {
        Stack() {
          ReadPageComponent({
            controller: this.controller,
            readerCallback: (err: BusinessError | undefined, ctrl: readerCore.ReaderComponentController) => {
              if (err) {
                console.error('[Reader] readerCallback error: code=' + err.code + ' msg=' + err.message);
                return;
              }
              this.setupReader(ctrl);
            }
          })

          if (!this.showMenu) {
            Column() {}
              .width('100%')
              .height('100%')
              .hitTestBehavior(HitTestMode.Transparent)
              .onClick(() => {
                this.toggleMenu();
              })
          }
        }
        .width('100%')
        .height('100%')
      }

      if (!this.showMenu && this.currentPageInfo) {
        Text(this.currentPageInfo)
          .fontSize(12)
          .fontColor('#000000')
          .backgroundColor('#80000000')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(10)
          .position({ x: '100%', y: '100%' })
          .translate({ x: '-100%', y: '-100%' })
          .margin({ right: 12, bottom: 12 })
      }

      if (this.showMenu) {
        Column() {
          this.topMenu()

          Column() {}
            .layoutWeight(1)
            .width('100%')
            .onClick(() => {
              this.showMenu = false;
            })

          this.bottomMenu()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#40000000')
      }
    }
    .width('100%')
    .height('100%')
  }
}

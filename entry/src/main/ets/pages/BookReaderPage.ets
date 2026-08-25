import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { router, window, display } from '@kit.ArkUI';
import { bookParser } from '@hms.core.readerservice.bookParser';
import { ReadPageComponent, readerCore } from '@hms.core.readerservice.readerComponent';
import { UserProfileManager, ParagraphComment } from '../model/UserProfileManager';

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
  @State showModalBanner: boolean = false;
  @State bookId: string = '';
  @State isInBookshelf: boolean = false;
  @State nightMode: boolean = false;
  @State currentIndex: number = -1;
  @State catalogItemList: bookParser.CatalogItem[] = [];
  @State showCommentInput: boolean = false;
  @State commentInputText: string = '';
  @State currentParagraphComments: ParagraphComment[] = [];
  @State showCommentList: boolean = false;
  @State commentDotPositions: number[] = [];

  private controller: readerCore.ReaderComponentController = new readerCore.ReaderComponentController();
  private profileManager: UserProfileManager | null = null;
  private bookParserHandler: bookParser.BookParserHandler | null = null;
  private sandboxEpubPath: string = '';
  private abilityContext: common.UIAbilityContext | null = null;
  private currentData: readerCore.PageDataInfo | null = null;
  private mainWindow: window.Window | null = null;

  @State private readerSetting: readerCore.ReaderSetting = {
    fontName: 'system',
    fontPath: '',
    fontSize: 22,
    fontColor: '#000000',
    fontWeight: 200,
    lineHeight: 1.7,
    nightMode: false,
    themeColor: 'rgba(248, 249, 250, 1)',
    themeBgImg: '',
    flipMode: '0',
    scaledDensity: 1,
    viewPortWidth: 0,
    viewPortHeight: 0
  };

  @State statusBarHeight: number = 0;
  @State navBarHeight: number = 0;

  async aboutToAppear() {
    this.mainWindow = await window.getLastWindow(getContext());
    this.mainWindow.setWindowLayoutFullScreen(true);
    this.mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      statusBarContentColor: '#333333'
    });

    const systemArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const navArea = this.mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    const scaledDensity = display.getDefaultDisplaySync().scaledDensity;
    this.statusBarHeight = systemArea.topRect.height / (scaledDensity > 0 ? scaledDensity : 1);
    this.navBarHeight = navArea.bottomRect.height / (scaledDensity > 0 ? scaledDensity : 1);

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

      const windowProp = this.mainWindow.getWindowProperties();
      const displayInfo = display.getDefaultDisplaySync();
      this.readerSetting.scaledDensity = displayInfo.scaledDensity > 0 ? displayInfo.scaledDensity : 1;
      this.readerSetting.viewPortWidth = windowProp.windowRect.width;
      this.readerSetting.viewPortHeight = windowProp.windowRect.height;

      this.registerListeners();
      this.registerWindowSizeChange();
      await this.startPlay();
    } catch (error) {
      console.error('[Reader] Failed to prepare:', JSON.stringify(error));
      this.isLoading = false;
      return;
    }
  }

  private registerWindowSizeChange() {
    if (!this.mainWindow) {
      return;
    }
    this.mainWindow.on('windowSizeChange', (size: window.Size) => {
      if (this.readerSetting.viewPortWidth !== size.width ||
        this.readerSetting.viewPortHeight !== size.height) {
        this.readerSetting.viewPortWidth = size.width;
        this.readerSetting.viewPortHeight = size.height;
        try {
          this.controller.setPageConfig(this.readerSetting);
        } catch (e) {
          console.error('[Reader] windowSizeChange setPageConfig failed: ' + JSON.stringify(e));
        }
      }
    });
  }

  private registerListeners() {
    this.controller.on('resourceRequest', (filePath: string): ArrayBuffer => {
      if (filePath.length === 0) {
        return new ArrayBuffer(0);
      }
      try {
        const context = this.abilityContext!;
        const value: Uint8Array = context.resourceManager.getRawFileContentSync(filePath);
        return value.buffer as ArrayBuffer;
      } catch (e) {
        console.error('[Reader] resourceRequest failed for: ' + filePath);
      }
      return this.loadFileFromPath(filePath);
    });

    this.controller.on('pageShow', (data: readerCore.PageDataInfo) => {
      this.currentData = data;
      if (data.state === readerCore.PageState.PAGE_ON_SHOW) {
        this.isLoading = false;
        this.updateCommentDots();
      }
    });
  }

  private updateCommentDots() {
    this.commentDotPositions = [];
    if (!this.profileManager || !this.currentData) {
      return;
    }
    const resourceIndex = this.currentData.resourceIndex;
    const startDomPos = this.currentData.startDomPos || '0';
    const baseIndex = resourceIndex * 10000 + Math.floor(parseInt(startDomPos) || 0);
    for (let i = 0; i < 30; i++) {
      const pIndex = baseIndex + i;
      if (this.profileManager.hasParagraphComments(this.bookId, pIndex)) {
        const comments = this.profileManager.getParagraphComments(this.bookId, pIndex);
        if (comments.length > 0) {
          this.commentDotPositions.push(i);
        }
      }
    }
  }

  private getParagraphIndexFromPage(offset: number): number {
    if (!this.currentData) {
      return 0;
    }
    const resourceIndex = this.currentData.resourceIndex;
    const startDomPos = this.currentData.startDomPos || '0';
    const baseIndex = resourceIndex * 10000 + Math.floor(parseInt(startDomPos) || 0);
    return baseIndex + offset;
  }

  private loadFileFromPath(filePath: string): ArrayBuffer {
    try {
      const stats = fs.statSync(filePath);
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const buffer = new ArrayBuffer(stats.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      return buffer;
    } catch (e) {
      return new ArrayBuffer(0);
    }
  }

  private async startPlay() {
    try {
      const context = this.abilityContext!;
      const initPromise = this.controller.init(context);
      const handlerPromise = bookParser.getDefaultHandler(this.sandboxEpubPath);
      const result = await Promise.all([handlerPromise, initPromise]);
      this.bookParserHandler = result[0];
      this.controller.registerBookParser(this.bookParserHandler!);
      this.controller.setPageConfig(this.readerSetting);

      const progress = this.profileManager!.getReadingProgress(this.bookId);
      const resourceIndex = progress?.spineIndex || 0;
      const domPos = progress?.startDomPos || '';
      this.controller.startPlay(resourceIndex, domPos);
    } catch (error) {
      console.error('[Reader] startPlay failed: ' + JSON.stringify(error));
    }
  }

  async aboutToDisappear() {
    if (this.profileManager && this.bookId && this.currentData) {
      await this.profileManager.saveReadingProgressDomPos(
        this.bookId, this.currentData.resourceIndex, this.currentData.startDomPos
      );
    }
    this.controller.off('pageShow');
    this.controller.off('resourceRequest');
    this.controller.releaseBook();
    if (this.mainWindow) {
      this.mainWindow.off('windowSizeChange');
      this.mainWindow.setWindowLayoutFullScreen(false);
      this.mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#F5F5F5',
        statusBarContentColor: '#000000'
      });
    }
  }

  async toggleBookshelf() {
    const manager = await UserProfileManager.getInstance();
    this.isInBookshelf = await manager.toggleBookshelf(this.bookId);
  }

  private showModal() {
    this.showModalBanner = true;
  }

  private closeModal() {
    this.showModalBanner = false;
    this.currentIndex = -1;
  }

  private jumpToCatalogList() {
    this.currentIndex = 0;
    try {
      this.catalogItemList = this.bookParserHandler?.getCatalogList() || [];
    } catch (e) {
      console.error('[Reader] getCatalogList failed: ' + JSON.stringify(e));
    }
  }

  private jumpToSetting() {
    this.currentIndex = 1;
  }

  private async jumpToCatalogItem(catalogItem: bookParser.CatalogItem) {
    try {
      const domPos = this.bookParserHandler?.getDomPosByCatalogHref(catalogItem.href || '') || '';
      const spineList = this.bookParserHandler?.getSpineList() || [];
      let resourceIndex = 0;
      const resourceFile = catalogItem.resourceFile || '';
      const matched = spineList.filter(item => item.href === resourceFile);
      if (matched.length > 0) {
        resourceIndex = matched[0].index;
      }
      this.controller.startPlay(resourceIndex, domPos).catch(() => {});
      this.closeModal();
    } catch (e) {
      console.error('[Reader] jumpToCatalogItem failed: ' + JSON.stringify(e));
    }
  }

  private async openCommentForOffset(offset: number) {
    const pIndex = this.getParagraphIndexFromPage(offset);
    this.currentParagraphComments = this.profileManager?.getParagraphComments(this.bookId, pIndex) || [];
    this.showCommentList = true;
    this.commentInputText = '';
  }

  private async submitComment(offset: number) {
    if (this.commentInputText.trim().length === 0) {
      return;
    }
    const pIndex = this.getParagraphIndexFromPage(offset);
    await this.profileManager?.addParagraphComment(this.bookId, pIndex, this.commentInputText.trim());
    this.commentInputText = '';
    this.currentParagraphComments = this.profileManager?.getParagraphComments(this.bookId, pIndex) || [];
    this.updateCommentDots();
  }

  @Builder
  private buildCatalogItemList() {
    List() {
      ForEach(this.catalogItemList, (item: bookParser.CatalogItem) => {
        ListItem() {
          Column() {
            Row() {
              Text(' \u00B7 ')
                .fontSize(14)
                .fontColor('#E6000000')
              Text(item.catalogName)
                .fontSize(14)
                .fontColor('#E6000000')
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .padding({ top: 8, bottom: 8 })
                .maxLines(2)
                .layoutWeight(1)
            }
            .width('100%')
            .height(48)
            .alignItems(VerticalAlign.Center)

            Divider()
          }
          .padding({
            left: item.catalogLevel ? item.catalogLevel * 26 : 16,
            right: 16,
            top: 6,
            bottom: 6
          })
          .onClick(() => {
            this.jumpToCatalogItem(item);
          })
        }
      })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private buildSetting() {
    Scroll() {
      Column() {
        Row({ space: 20 }) {
          Column() {
            Radio({ value: 'flipMode0', group: 'flipRadioGroup' })
              .height(20)
              .width(20)
              .checked(this.readerSetting.flipMode === '0')
              .radioStyle({ checkedBackgroundColor: '#FF8C00' })
              .onChange(() => {
                this.readerSetting.flipMode = '0';
                try {
                  this.controller.setPageConfig(this.readerSetting);
                } catch (e) {}
              })
            Text('仿真翻页')
              .fontSize(14)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Center)

          Column() {
            Radio({ value: 'flipMode1', group: 'flipRadioGroup' })
              .height(20)
              .width(20)
              .checked(this.readerSetting.flipMode === '1')
              .radioStyle({ checkedBackgroundColor: '#FF8C00' })
              .onChange(() => {
                this.readerSetting.flipMode = '1';
                try {
                  this.controller.setPageConfig(this.readerSetting);
                } catch (e) {}
              })
            Text('横向滑动')
              .fontSize(14)
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 16, bottom: 16 })

        Divider().margin({ left: 16, right: 16 })

        Row() {
          Text('字体')
            .fontSize(14)
            .width(36)

          Button('-')
            .width(36)
            .height(36)
            .fontSize(18)
            .fontColor('#333333')
            .backgroundColor('#F0F0F0')
            .borderRadius(18)
            .onClick(() => {
              if (this.readerSetting.fontSize > 8) {
                this.readerSetting.fontSize -= 2;
                try {
                  this.controller.setPageConfig(this.readerSetting);
                } catch (e) {}
              }
            })

          Text(`${this.readerSetting.fontSize}`)
            .fontSize(14)
            .width(40)
            .textAlign(TextAlign.Center)

          Button('+')
            .width(36)
            .height(36)
            .fontSize(18)
            .fontColor('#333333')
            .backgroundColor('#F0F0F0')
            .borderRadius(18)
            .onClick(() => {
              if (this.readerSetting.fontSize < 40) {
                this.readerSetting.fontSize += 2;
                try {
                  this.controller.setPageConfig(this.readerSetting);
                } catch (e) {}
              }
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .padding({ top: 16, bottom: 8 })

        Row() {
          Text('行距')
            .fontSize(14)
            .width(36)

          Slider({
            value: (this.readerSetting.lineHeight - 1.0) * 100 / 2.0,
            min: 0,
            max: 100,
            step: 10,
            style: SliderStyle.InSet
          })
            .width('50%')
            .trackColor('#E0E0E0')
            .selectedColor('#FF8C00')
            .blockColor('#FF8C00')
            .onChange((value: number) => {
              this.readerSetting.lineHeight = 1.0 + value * 2.0 / 100;
              try {
                this.controller.setPageConfig(this.readerSetting);
              } catch (e) {}
            })

          Text(`${this.readerSetting.lineHeight.toFixed(1)}`)
            .fontSize(14)
            .width(36)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .padding({ top: 8, bottom: 16 })

        Divider().margin({ left: 16, right: 16 })

        Row({ space: 12 }) {
          ForEach(['#FFFFFF', '#BD9063', '#FFE4E5', '#C5E7CE', '#202224'], (color: string, index: number) => {
            Column() {}
              .width(40)
              .height(40)
              .borderRadius(20)
              .backgroundColor(color)
              .border({
                width: this.readerSetting.themeColor === color ? 2 : 1,
                color: this.readerSetting.themeColor === color ? '#FF8C00' : '#CCCCCC'
              })
              .onClick(() => {
                this.readerSetting.themeColor = color;
                this.readerSetting.themeBgImg = '';
                this.readerSetting.nightMode = color === '#202224';
                this.readerSetting.fontColor = color === '#202224' ? '#ffffff' : '#000000';
                try {
                  this.controller.setPageConfig(this.readerSetting);
                } catch (e) {}
              })
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 16, bottom: 16 })
      }
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private buildMenuBar() {
    Column() {
      if (this.currentIndex === 0) {
        Column() {
          this.buildCatalogItemList()
        }
        .backgroundColor(Color.White)
        .borderRadius({ topRight: 16, topLeft: 16 })
        .width('100%')
        .height(360)
      } else if (this.currentIndex === 1) {
        Column() {
          this.buildSetting()
        }
        .backgroundColor(Color.White)
        .borderRadius({ topRight: 16, topLeft: 16 })
        .width('100%')
        .height(380)
      }

      Row() {
        Column() {
          Text('目录')
            .fontSize(16)
            .fontColor(this.currentIndex === 0 ? '#FF8C00' : '#000000')
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.jumpToCatalogList();
        })

        Column() {
          Text('设置')
            .fontSize(16)
            .fontColor(this.currentIndex === 1 ? '#FF8C00' : '#000000')
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.jumpToSetting();
        })
      }
      .width('100%')
      .height(56)
      .backgroundColor(Color.White)
      .border({ width: { top: 1 }, color: '#E5E5E5' })
    }
    .width('100%')
  }

  @Builder
  private buildCommentDots() {
    Column() {
      ForEach(this.commentDotPositions, (offset: number) => {
        Row() {
          Column() {}
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor('#FF8C00')
            .onClick(() => {
              this.openCommentForOffset(offset);
            })
        }
        .height(36)
        .justifyContent(FlexAlign.Center)
      })
    }
    .width(20)
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .padding({ top: 40 })
  }

  @Builder
  private buildCommentPanel() {
    Column() {
      Column() {
        Row() {
          Text('段评')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)

          Text('关闭')
            .fontSize(14)
            .fontColor('#FF8C00')
            .onClick(() => {
              this.showCommentList = false;
              this.showCommentInput = false;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        if (this.currentParagraphComments.length > 0) {
          List() {
            ForEach(this.currentParagraphComments, (comment: ParagraphComment) => {
              ListItem() {
                Column() {
                  Row() {
                    Column() {
                      Text(comment.content)
                        .fontSize(14)
                        .fontColor('#333333')
                        .width('100%')
                      Text(new Date(comment.createTime).toLocaleString())
                        .fontSize(12)
                        .fontColor('#999999')
                        .margin({ top: 4 })
                    }
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 8, bottom: 8 })

                  Divider().margin({ left: 16, right: 16 })
                }
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          Column() {
            Text('暂无段评，点击下方添加')
              .fontSize(14)
              .fontColor('#999999')
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }

        Row() {
          TextInput({ text: this.commentInputText, placeholder: '写下你的段评...' })
            .type(InputType.Normal)
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#F5F5F5')
            .borderRadius(20)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.commentInputText = value;
            })

          Button('发送')
            .height(40)
            .backgroundColor('#FF8C00')
            .fontColor(Color.White)
            .fontSize(14)
            .margin({ left: 8 })
            .onClick(() => {
              this.submitComment(this.commentDotPositions.length > 0 ? this.commentDotPositions[0] : 0);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      }
      .width('100%')
      .height(300)
      .backgroundColor(Color.White)
      .borderRadius({ topLeft: 16, topRight: 16 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.End)
  }

  build() {
    Stack() {
      ReadPageComponent({
        controller: this.controller,
        readerCallback: (err: BusinessError | undefined, ctrl: readerCore.ReaderComponentController) => {
          if (err) {
            console.error('[Reader] readerCallback error: code=' + err.code + ' msg=' + err.message);
          }
        }
      }).zIndex(1)
        .margin({ top: this.statusBarHeight, bottom: this.navBarHeight })

      Row() {
        Text('加载中...')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.White)
      .zIndex(3)
      .visibility(this.isLoading ? Visibility.Visible : Visibility.None)

      if (this.commentDotPositions.length > 0 && !this.showModalBanner && !this.showCommentList) {
        this.buildCommentDots()
      }

      if (this.showCommentList) {
        Column() {
          Column() {}
            .width('100%')
            .layoutWeight(1)
            .onClick(() => {
              this.showCommentList = false;
            })

          this.buildCommentPanel()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#40000000')
        .zIndex(2)
      }

      if (this.showModalBanner) {
        Column() {
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
          }
          .width('100%')
          .height(50)
          .backgroundColor('#FF8C00')
          .padding({ left: 12, right: 12 })

          Column() {}
            .layoutWeight(1)
            .width('100%')
            .onClick(() => {
              this.closeModal();
            })

          this.buildMenuBar()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#40000000')
        .zIndex(2)
        .padding({ top: this.statusBarHeight, bottom: this.navBarHeight })
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      if (!this.showModalBanner && !this.showCommentList) {
        this.showModal();
      }
    })
  }
}

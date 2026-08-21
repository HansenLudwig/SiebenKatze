import { util } from '@kit.ArkTS';
import { router, window } from '@kit.ArkUI';

interface ReaderParams {
  fileName: string;
  title: string;
}

@Entry
@Component
struct BookReaderPage {
  @State content: string = '';
  @State title: string = '';
  @State isLoading: boolean = true;
  @State scrollOffset: number = 0;

  private scroller: Scroller = new Scroller();

  async aboutToAppear() {
    const mainWindow = await window.getLastWindow(getContext());
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#FF8C00',
      statusBarContentColor: '#FFFFFF'
    });

    const params = router.getParams() as ReaderParams;
    this.title = params.title || '阅读';
    
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
  }

  build() {
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
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank().width(40)
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FF8C00')
      .padding({ left: 16, right: 16 })

      if (this.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#FF8C00')
      } else {
        Scroll(this.scroller) {
          Column() {
            Text(this.content)
              .fontSize(16)
              .fontColor('#333333')
              .lineHeight(28)
              .padding(20)
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFF9F0')
  }
}
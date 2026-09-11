import { FunctionComponent, FunctionController, ButtonType } from '@kit.AgentFrameworkKit';
import { common } from '@kit.AbilityKit';

const TAG: string = '[AgentButton]';

@Component
export struct AgentButton {
  @Prop queryText: string;
  @Prop iconColor: string = '#FFFFFF';
  @Prop buttonSize: number = 36;
  onDialogClosed: () => void = (): void => {};

  private readonly AGENT_ID: string = 'agentf0c9eddc463447e290513ec174eb57cd';
  private functionController: FunctionController = new FunctionController();
  @State agentSupported: boolean = false;

  aboutToAppear() {
    try {
      const uiContext = getContext(this) as common.UIAbilityContext;
      this.functionController.isAgentSupport(uiContext, this.AGENT_ID).then((supported: boolean) => {
        this.agentSupported = supported;
        console.info(TAG + ' isAgentSupport result: ' + supported);
      }).catch((err: BusinessError) => {
        this.agentSupported = false;
        console.error(TAG + ' isAgentSupport failed: code=' + err.code + ' msg=' + err.message);
      });
    } catch (e) {
      console.error(TAG + ' isAgentSupport exception: ' + e);
    }
    this.functionController.on('agentDialogOpened', () => {
      console.info(TAG + ' dialog opened');
    });
    this.functionController.on('agentDialogClosed', () => {
      console.info(TAG + ' dialog closed');
      this.onDialogClosed();
    });
  }

  build() {
    FunctionComponent({
      agentId: this.AGENT_ID,
      onError: (err: BusinessError) => {
        console.error(TAG + ' error: code=' + err.code + ' msg=' + err.message);
      },
      options: {
        title: '',
        buttonType: ButtonType.CIRCLE,
        isShowShadow: false,
        backgroundColor: '#00000000',
        iconColors: [this.iconColor],
        titleColors: [this.iconColor],
        queryText: this.queryText,
      },
      controller: this.functionController
    })
      .width(this.buttonSize)
      .height(this.buttonSize)
  }
}

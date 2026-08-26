import { util } from '@kit.ArkTS';

export class EpubParser {
  static async toBase64(context: Context, fileName: string): Promise<string> {
    const fileData: Uint8Array = await context.resourceManager.getRawFileContent(fileName);
    const base64Helper: util.Base64Helper = new util.Base64Helper();
    const result: string = base64Helper.encodeToStringSync(fileData);
    return result;
  }
}

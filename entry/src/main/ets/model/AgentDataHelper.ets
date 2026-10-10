import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

const TAG: string = '[AgentDataHelper]';

const FILE_BOOK_LIST: string = 'agent_book_list.json';
const FILE_BOOK_CONTEXT: string = 'agent_book_context.json';
const FILE_LAST_BOOK: string = 'agent_last_book.json';
const FILE_READING_HISTORY: string = 'agent_reading_history.json';
const FILE_READING_STATE: string = 'agent_reading_state.json';

export class AgentDataHelper {
  static writeBookList(context: common.Context, jsonStr: string): void {
    AgentDataHelper.writeToFile(context, FILE_BOOK_LIST, jsonStr);
  }

  static writeBookContext(context: common.Context, jsonStr: string): void {
    AgentDataHelper.writeToFile(context, FILE_BOOK_CONTEXT, jsonStr);
  }

  static writeLastBook(context: common.Context, jsonStr: string): void {
    AgentDataHelper.writeToFile(context, FILE_LAST_BOOK, jsonStr);
  }

  static writeReadingHistory(context: common.Context, jsonStr: string): void {
    AgentDataHelper.writeToFile(context, FILE_READING_HISTORY, jsonStr);
  }

  static writeReadingState(context: common.Context, jsonStr: string): void {
    AgentDataHelper.writeToFile(context, FILE_READING_STATE, jsonStr);
  }

  static readBookList(context: common.Context): string {
    return AgentDataHelper.readFromFile(context, FILE_BOOK_LIST);
  }

  static readBookContext(context: common.Context): string {
    return AgentDataHelper.readFromFile(context, FILE_BOOK_CONTEXT);
  }

  static readLastBook(context: common.Context): string {
    return AgentDataHelper.readFromFile(context, FILE_LAST_BOOK);
  }

  static readReadingHistory(context: common.Context): string {
    return AgentDataHelper.readFromFile(context, FILE_READING_HISTORY);
  }

  static readReadingState(context: common.Context): string {
    return AgentDataHelper.readFromFile(context, FILE_READING_STATE);
  }

  private static writeToFile(context: common.Context, fileName: string, data: string): void {
    try {
      const filePath: string = context.filesDir + '/' + fileName;
      const file: fileIo.File = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file.fd);
      console.info(TAG + ' wrote ' + fileName + ', length=' + data.length);
    } catch (e) {
      console.error(TAG + ' writeToFile failed: ' + e);
    }
  }

  private static readFromFile(context: common.Context, fileName: string): string {
    try {
      const filePath: string = context.filesDir + '/' + fileName;
      return fileIo.readTextSync(filePath);
    } catch (e) {
      console.error(TAG + ' readFromFile failed: ' + e);
      return '';
    }
  }
}

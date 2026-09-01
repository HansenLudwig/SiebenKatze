import { ExtensionAbility, Want } from '@kit.AbilityKit';

const TAG: string = '[AgentExt]';

const SKILL_RECOMMEND_BOOKS: string = 'recommend_books';
const SKILL_SUMMARIZE_CONTENT: string = 'summarize_content';

interface AgentHostProxyLike {
  sendData(data: string): void;
  authorize(handshakeData: string): void;
}

interface A2ARequest {
  skillId: string;
  query: string;
}

interface A2AResponse {
  skillId: string;
  success: boolean;
  data: Record<string, Object>;
  message: string;
}

interface BookEntry {
  id: string;
  title: string;
  author: string;
  description: string;
  hashtags: string[];
}

export default class AgentExtAbility extends ExtensionAbility {
  private comProxy: AgentHostProxyLike | null = null;

  onCreate(want: Want): void {
    console.info(TAG + ' onCreate, want action=' + (want.action || ''));
  }

  onConnect(want: Want): void {
    console.info(TAG + ' onConnect, want action=' + (want.action || ''));
  }

  onDisconnect(want: Want): void {
    console.info(TAG + ' onDisconnect');
    this.comProxy = null;
  }

  onData(proxy: AgentHostProxyLike, data: string): void {
    console.info(TAG + ' onData: ' + data);
    this.comProxy = proxy;
    try {
      const contextJson: string = AppStorage.get<string>('agent_book_context') || '{}';
      const response: A2AResponse = this.handleRequest(data, contextJson);
      proxy.sendData(JSON.stringify(response as Object));
    } catch (err) {
      const error = err as BusinessError;
      console.error(TAG + ' onData failed: code=' + error.code + ' msg=' + error.message);
    }
  }

  onAuth(proxy: AgentHostProxyLike, handshakeData: string): void {
    console.info(TAG + ' onAuth');
    try {
      proxy.authorize('auth_success');
    } catch (err) {
      const error = err as BusinessError;
      console.error(TAG + ' authorize failed: code=' + error.code + ' msg=' + error.message);
    }
  }

  onDestroy(): void {
    console.info(TAG + ' onDestroy');
    this.comProxy = null;
  }

  private handleRequest(data: string, contextJson: string): A2AResponse {
    let request: A2ARequest = { skillId: '', query: '' };
    try {
      request = JSON.parse(data) as A2ARequest;
    } catch (e) {
      console.warn(TAG + ' parse request failed, treating as plain query');
      request = { skillId: '', query: data };
    }

    const skillId: string = this.detectSkill(request);

    if (skillId === SKILL_RECOMMEND_BOOKS) {
      return this.handleRecommendBooks(contextJson);
    }
    return this.handleSummarizeContent(contextJson);
  }

  private detectSkill(request: A2ARequest): string {
    if (request.skillId.length > 0) {
      return request.skillId;
    }
    const query: string = request.query.toLowerCase();
    if (query.length === 0) {
      return SKILL_SUMMARIZE_CONTENT;
    }
    if (query.includes('推荐') || query.includes('书单') || query.includes('好书') ||
      query.includes('找书') || query.includes('看什么书') || query.includes('类似的书')) {
      return SKILL_RECOMMEND_BOOKS;
    }
    if (query.includes('总结') || query.includes('摘要') || query.includes('概括') ||
      query.includes('讲了什么') || query.includes('什么内容') || query.includes('理解')) {
      return SKILL_SUMMARIZE_CONTENT;
    }
    return SKILL_SUMMARIZE_CONTENT;
  }

  private parseContext(contextJson: string): Record<string, Object> {
    try {
      return JSON.parse(contextJson) as Record<string, Object>;
    } catch (e) {
      console.error(TAG + ' parse context failed: ' + e);
      return {};
    }
  }

  private getContextField(ctx: Record<string, Object>, key: string, defaultVal: string): string {
    const val: Object | undefined = ctx[key];
    if (val !== undefined && val !== null && typeof val === 'string') {
      return val as string;
    }
    return defaultVal;
  }

  private getContextNumber(ctx: Record<string, Object>, key: string, defaultVal: number): number {
    const val: Object | undefined = ctx[key];
    if (val !== undefined && val !== null && typeof val === 'number') {
      return val as number;
    }
    return defaultVal;
  }

  private getBookList(): BookEntry[] {
    try {
      const bookListJson: string = AppStorage.get<string>('agent_book_list') || '';
      if (bookListJson.length === 0) {
        console.warn(TAG + ' book list not in AppStorage');
        return [];
      }
      const books: BookEntry[] = JSON.parse(bookListJson) as BookEntry[];
      return books;
    } catch (e) {
      console.error(TAG + ' getBookList failed: ' + e);
      return [];
    }
  }

  private handleRecommendBooks(contextJson: string): A2AResponse {
    const ctx: Record<string, Object> = this.parseContext(contextJson);
    const currentTitle: string = this.getContextField(ctx, 'title', '');

    const books: BookEntry[] = this.getBookList();
    if (books.length === 0) {
      return {
        skillId: SKILL_RECOMMEND_BOOKS,
        success: false,
        data: {},
        message: '无法获取书库信息。'
      };
    }

    const bookList: Record<string, Object>[] = [];
    for (const book of books) {
      const entry: Record<string, Object> = {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'description': book.description,
        'hashtags': book.hashtags
      };
      bookList.push(entry);
    }

    const dataMap: Record<string, Object> = {
      'currentBookTitle': currentTitle,
      'totalBooks': books.length,
      'books': bookList
    };

    let message: string = '';
    if (currentTitle.length > 0) {
      message = `用户当前正在阅读《${currentTitle}》。`;
    }
    message += `书库共${books.length}本书，列表如下：\n`;
    for (const book of books) {
      const tags: string = book.hashtags.join('、');
      message += `\n《${book.title}》- ${book.author}（${tags}）\n${book.description}\n`;
    }

    return {
      skillId: SKILL_RECOMMEND_BOOKS,
      success: true,
      data: dataMap,
      message: message
    };
  }

  private handleSummarizeContent(contextJson: string): A2AResponse {
    const ctx: Record<string, Object> = this.parseContext(contextJson);
    const title: string = this.getContextField(ctx, 'title', '');
    const format: string = this.getContextField(ctx, 'format', '');
    const currentPage: number = this.getContextNumber(ctx, 'currentPage', 0);
    const totalPages: number = this.getContextNumber(ctx, 'totalPages', 0);
    const progressPercent: number = this.getContextNumber(ctx, 'progressPercent', 0);
    const currentContent: string = this.getContextField(ctx, 'currentContent', '');
    const prevContent: string = this.getContextField(ctx, 'prevContent', '');
    const nextContent: string = this.getContextField(ctx, 'nextContent', '');

    if (title.length === 0) {
      return {
        skillId: SKILL_SUMMARIZE_CONTENT,
        success: true,
        data: {},
        message: '用户当前没有正在阅读的书籍，无法进行内容总结。'
      };
    }

    const dataMap: Record<string, Object> = {
      'title': title,
      'format': format,
      'currentPage': currentPage + 1,
      'totalPages': totalPages,
      'progressPercent': progressPercent,
      'currentContent': currentContent,
      'prevContent': prevContent,
      'nextContent': nextContent
    };

    let message: string = `用户正在阅读《${title}》（${format}格式），当前在第${currentPage + 1}页，共${totalPages}页，阅读进度${progressPercent}%。`;
    if (prevContent.length > 0) {
      message += `\n\n上一页末尾内容：\n${prevContent}`;
    }
    if (currentContent.length > 0) {
      message += `\n\n当前页面内容：\n${currentContent}`;
    }
    if (nextContent.length > 0) {
      message += `\n\n下一页开头内容：\n${nextContent}`;
    }
    if (currentContent.length === 0 && prevContent.length === 0 && nextContent.length === 0) {
      message += '\n\n当前页面内容为空。';
    }

    return {
      skillId: SKILL_SUMMARIZE_CONTENT,
      success: true,
      data: dataMap,
      message: message
    };
  }
}

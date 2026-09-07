import { AgentExtensionAbility, Want, common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import {
  A2ARequest, A2AResponse, TaskState, PartForText,
  ArtifactsOfAll, StatusOfTask, StatusForUpdate, TaskForResult,
  ArtifactUpdateForResult, StatusUpdateForResult,
  ResultWithTask, ResultWithArtifactUpdate, ResultWithStatusUpdate,
  MetadataFromAgent
} from './A2AInterfaces';

const TAG: string = '[AgentExt]';

let managedContextId: string = '';

function getContextId(): string {
  if (managedContextId.length === 0) {
    managedContextId = 'ctx-' + util.generateRandomUUID(false);
  }
  return managedContextId;
}

enum AgentSkillEnum {
  SKILL_RECOMMEND_BOOKS = 'recommend_books',
  SKILL_SUMMARIZE_CONTENT = 'summarize_content',
  SKILL_NULL = 'unrecognized_skill',
}

interface BookEntry {
  id: string;
  title: string;
  author: string;
  description: string;
  hashtags: string[];
}

export default class AgentExtAbility extends AgentExtensionAbility {
  private proxy: common.AgentHostProxy | null = null;

  onCreate(want: Want): void {
    console.info(TAG + ' onCreate, want action=' + (want.action || ''));
  }

  onConnect(want: Want, proxy: common.AgentHostProxy): void {
    console.info(TAG + ' onConnect, want action=' + (want.action || ''));
    this.proxy = proxy;
  }

  onDisconnect(want: Want, proxy: common.AgentHostProxy): void {
    console.info(TAG + ' onDisconnect');
    this.proxy = null;
  }

  onData(proxy: common.AgentHostProxy, data: string): void {
    console.info(TAG + ' onData: ' + data);
    this.proxy = proxy;

    let request: A2ARequest;
    try {
      request = JSON.parse(data) as A2ARequest;
    } catch (e) {
      console.error(TAG + ' parse request failed: ' + e);
      proxy.sendData(this.buildErrorResponse('', '请求解析失败'));
      return;
    }

    const isStreaming: boolean = request.method === 'SendStreamingMessage'
      && request.params.configuration !== undefined
      && request.params.configuration.returnImmediately === true;

    if (isStreaming) {
      this.handleStreamingResponse(proxy, request);
    } else {
      this.handleSingleResponse(proxy, request);
    }
  }

  private handleStreamingResponse(proxy: common.AgentHostProxy, request: A2ARequest): void {
    const taskId: string = util.generateRandomUUID(false);
    const contextId: string = getContextId();
    const metadata: MetadataFromAgent = this.buildMetadata(request);

    // 1. Send first frame (SUBMITTED)
    proxy.sendData(this.buildFirstFrame(request.id, taskId, contextId, metadata));

    try {
      const replyText: string = this.processSkill(request);

      // 2. Send artifact update (content)
      proxy.sendData(this.buildArtifactFrame(request.id, taskId, contextId, replyText, metadata, true));

      // 3. Send close frame (COMPLETED)
      proxy.sendData(this.buildCloseFrame(request.id, taskId, contextId, metadata));

    } catch (err) {
      const error = err as BusinessError;
      console.error(TAG + ' streaming response failed: code=' + error.code + ' msg=' + error.message);
      proxy.sendData(this.buildErrorResponse(request.id, error.message || '内部错误', taskId, contextId, metadata));
    }
  }

  private handleSingleResponse(proxy: common.AgentHostProxy, request: A2ARequest): void {
    const taskId: string = util.generateRandomUUID(false);
    const contextId: string = getContextId();
    const metadata: MetadataFromAgent = this.buildMetadata(request);

    try {
      const replyText: string = this.processSkill(request);

      const part: PartForText = { mediaType: 'text/plain', text: replyText };
      const artifact: ArtifactsOfAll = { artifactId: 'artifact-001', parts: [part as object] };
      const status: StatusOfTask = { state: TaskState.COMPLETED, timestamp: this.getTimestamp() };
      const task: TaskForResult = {
        id: taskId,
        contextId: contextId,
        status: status,
        artifacts: [artifact]
      };
      const result: ResultWithTask = { task: task, metadata: metadata };
      const response: A2AResponse = { jsonrpc: '2.0', id: request.id, result: result };
      proxy.sendData(JSON.stringify(response as Object));

    } catch (err) {
      const error = err as BusinessError;
      console.error(TAG + ' single response failed: code=' + error.code + ' msg=' + error.message);
      proxy.sendData(this.buildErrorResponse(request.id, error.message || '内部错误', taskId, contextId, metadata));
    }
  }

  private processSkill(request: A2ARequest): string {
    const userText: string = this.extractUserText(request);
    console.info(TAG + ' userText: ' + userText);

    const skillId: string = this.detectSkill(userText);
    const contextJson: string = AppStorage.get<string>('agent_book_context') || '{}';
    const ctx: Record<string, Object> = this.parseContext(contextJson);

    if (skillId === AgentSkillEnum.SKILL_RECOMMEND_BOOKS) {
      return this.handleRecommendBooks(ctx);
    } else if (skillId === AgentSkillEnum.SKILL_SUMMARIZE_CONTENT) {
      return this.handleSummarizeContent(ctx);
    } else {
      return '抱歉，我暂时无法理解您的请求。目前我可以为您推荐书籍或总结当前阅读内容，请试试这些功能。';
    }
  }

  onAuth(proxy: common.AgentHostProxy, handshakeData: string): void {
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
    this.proxy = null;
  }

  private buildFirstFrame(requestId: string, taskId: string, contextId: string,
    metadata: MetadataFromAgent): string {
    const status: StatusOfTask = { state: TaskState.SUBMITTED, timestamp: this.getTimestamp() };
    const task: TaskForResult = {
      id: taskId,
      contextId: contextId,
      status: status
    };
    const result: ResultWithTask = { task: task, metadata: metadata };
    const response: A2AResponse = { jsonrpc: '2.0', id: requestId, result: result };
    return JSON.stringify(response as Object);
  }

  private buildArtifactFrame(requestId: string, taskId: string, contextId: string,
    replyText: string, metadata: MetadataFromAgent, lastChunk: boolean): string {
    const part: PartForText = { mediaType: 'text/plain', text: replyText };
    const artifact: ArtifactsOfAll = { artifactId: 'artifact-001', parts: [part as object] };
    const update: ArtifactUpdateForResult = {
      taskId: taskId,
      contextId: contextId,
      artifact: artifact,
      append: false,
      lastChunk: lastChunk
    };
    const result: ResultWithArtifactUpdate = { artifactUpdate: update, metadata: metadata };
    const response: A2AResponse = { jsonrpc: '2.0', id: requestId, result: result };
    return JSON.stringify(response as Object);
  }

  private buildCloseFrame(requestId: string, taskId: string, contextId: string,
    metadata: MetadataFromAgent): string {
    const status: StatusForUpdate = { state: TaskState.COMPLETED, timestamp: this.getTimestamp() };
    const update: StatusUpdateForResult = {
      taskId: taskId,
      contextId: contextId,
      status: status
    };
    const result: ResultWithStatusUpdate = { statusUpdate: update, metadata: metadata };
    const response: A2AResponse = { jsonrpc: '2.0', id: requestId, result: result };
    return JSON.stringify(response as Object);
  }

  private buildErrorResponse(requestId: string, errorMessage: string,
    taskId: string = '', contextId: string = '',
    metadata: MetadataFromAgent | null = null): string {
    const errPart: PartForText = { mediaType: 'text/plain', text: errorMessage };
    const errArtifact: ArtifactsOfAll = { artifactId: 'artifact-err', parts: [errPart as object] };
    const errStatus: StatusOfTask = { state: TaskState.FAILED, timestamp: this.getTimestamp() };
    const errTask: TaskForResult = {
      id: taskId,
      contextId: contextId,
      status: errStatus,
      artifacts: [errArtifact]
    };
    const errMeta: MetadataFromAgent = metadata !== null ? metadata : { traceId: '', agentId: '', agentVersion: '1.0.0' };
    const errResult: ResultWithTask = { task: errTask, metadata: errMeta };
    const errResponse: A2AResponse = { jsonrpc: '2.0', id: requestId, result: errResult };
    return JSON.stringify(errResponse as Object);
  }

  private getTimestamp(): string {
    const date: Date = new Date();
    return date.toISOString();
  }

  private buildMetadata(request: A2ARequest): MetadataFromAgent {
    let traceId: string = '';
    let agentId: string = '';
    if (request.params.metadata) {
      traceId = request.params.metadata.traceId || '';
      agentId = request.params.metadata.agentId || '';
    }
    return { traceId: traceId, agentId: agentId, agentVersion: '1.0.0' };
  }

  private extractUserText(request: A2ARequest): string {
    const parts: PartForText[] = request.params.message.parts;
    for (const part of parts) {
      if (part.text && part.text.length > 0) {
        return part.text;
      }
    }
    return '';
  }

  private detectSkill(userText: string): string {
    const query: string = userText.toLowerCase();
    if (query.length === 0) {
      return AgentSkillEnum.SKILL_SUMMARIZE_CONTENT;
    }
    if (query.includes('推荐') || query.includes('书单') || query.includes('好书') ||
      query.includes('找书') || query.includes('看什么书') || query.includes('类似的书')) {
      return AgentSkillEnum.SKILL_RECOMMEND_BOOKS;
    }
    if (query.includes('总结') || query.includes('摘要') || query.includes('概括') ||
      query.includes('讲了什么') || query.includes('什么内容') || query.includes('理解')) {
      return AgentSkillEnum.SKILL_SUMMARIZE_CONTENT;
    }
    return AgentSkillEnum.SKILL_NULL;
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
      return JSON.parse(bookListJson) as BookEntry[];
    } catch (e) {
      console.error(TAG + ' getBookList failed: ' + e);
      return [];
    }
  }

  private handleRecommendBooks(ctx: Record<string, Object>): string {
    const currentTitle: string = this.getContextField(ctx, 'title', '');
    const books: BookEntry[] = this.getBookList();

    if (books.length === 0) {
      return '暂时无法获取书库信息。';
    }

    let message: string = '';
    if (currentTitle.length > 0) {
      message = `用户当前正在阅读《${currentTitle}》。`;
    }
    message += `书库共${books.length}本书，列表如下：\n`;
    for (const book of books) {
      const tags: string = book.hashtags.join('、');
      message += `\n《${book.title}》- ${book.author}（${tags}）\n${book.description}\n`;
    }
    return message;
  }

  private handleSummarizeContent(ctx: Record<string, Object>): string {
    const title: string = this.getContextField(ctx, 'title', '');
    const format: string = this.getContextField(ctx, 'format', '');
    const currentPage: number = this.getContextNumber(ctx, 'currentPage', 0);
    const totalPages: number = this.getContextNumber(ctx, 'totalPages', 0);
    const progressPercent: number = this.getContextNumber(ctx, 'progressPercent', 0);
    const currentContent: string = this.getContextField(ctx, 'currentContent', '');
    const prevContent: string = this.getContextField(ctx, 'prevContent', '');
    const nextContent: string = this.getContextField(ctx, 'nextContent', '');

    if (title.length === 0) {
      return '用户当前没有正在阅读的书籍，无法进行内容总结。';
    }

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
    return message;
  }
}

// agent2agent_response.ets

/**
 * 任务状态枚举
 */
export enum TaskState {
  SUBMITTED = "TASK_STATE_SUBMITTED",
  WORKING = "TASK_STATE_WORKING",
  INPUT_REQUIRED = "TASK_STATE_INPUT_REQUIRED",
  COMPLETED = "TASK_STATE_COMPLETED",
  FAILED = "TASK_STATE_FAILED",
  CANCELLED = "TASK_STATE_CANCELLED"
}

/**
 * 产物部件类型枚举
 */
export enum ArtifactPartType {
  TEXT = "text",
  THINKING = "thinking",
  IMAGE = "image",
  UI_CARD = "uiExtensionCard",
  FILE = "file"
}

enum RoleOfMessage {
  USER = 'ROLE_USER',
  AGENT = 'ROLE_AGENT'
}

interface PartsInGeneral {
  mediaType: string;
}

interface PartsForData {
  data: object
}

export interface PartsForText extends PartsInGeneral {
  text: string;
}

export interface PartsForFile extends PartsInGeneral {
  url: string;
  filename: string;
}

export interface ArtifactsOfAll {
  artifactId: string;
  parts: object[]
}

/** Status */
export interface MessageOfStatus {
  messageId: string;
  role: RoleOfMessage;
  parts: PartsForText;
}

export interface StatusForUpdate extends StatusInGeneral{
  message?: MessageOfStatus
}

export interface StatusOfTask extends StatusInGeneral {
}

export interface StatusInGeneral {
  state: TaskState
  timestamp: string;
}

/** Metadata */
interface MetadataInGeneral {
  traceId: string;
  agentId: string;
}

export interface MetadataFromAgent extends MetadataInGeneral {
  agentVersion: string;
}

export interface MetadataFromRequest extends MetadataInGeneral {
  appVersion: string;
}

/** Result */
export interface StatusUpdateForResult {
  taskId: string;
  contextId: string;
  status: StatusForUpdate;
}

export interface ArtifactUpdateForResult {
  taskId: string;
  contextId: string;
  artifact: ArtifactsOfAll;
  append: boolean;
  lastChunk: boolean;
}

export interface TaskForResult {
  id: string;
  contextId: string;
  status: StatusOfTask;
  artifacts?: ArtifactsOfAll;
}

export interface ResultWithStatusUpdate extends ResultInGeneral {
  statusUpdate: StatusUpdateForResult
}

export interface ResultWithArtifactUpdate extends ResultInGeneral {
  artifactUpdata: ArtifactUpdateForResult
}

export interface ResultWithTask extends ResultInGeneral {
  task: TaskForResult
}

export interface ResultInGeneral {
  metadata: MetadataFromAgent | MetadataFromRequest;
}
/** Params for Request from Xiaoyi */
export interface MessageOfParams extends MessageOfStatus {
  contextId: string;   // 单轮回答时有
  taskId?: string;
}

export interface ParamsOfRequest {
  message: MessageOfParams
  metadata: MetadataFromRequest
}

/** A2A JSON */
interface A2APackage {
  jsonrpc: string;
  id: string;
}

export interface A2AResponse extends A2APackage {
  result: ArtifactUpdateForResult | TaskForResult | StatusUpdateForResult;
}

export interface A2ARequest extends A2APackage {
  params: ParamsOfRequest;
}
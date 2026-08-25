import { preferences } from '@kit.ArkData';

interface ReadingHistoryEntry {
  bookId: string;
  currentPage?: number;
  scrollOffset?: number;
  spineIndex?: number;
  startDomPos?: string;
  lastReadTime: number;
}

export interface ParagraphComment {
  id: string;
  content: string;
  createTime: number;
}

interface UserProfileData {
  pageMode: boolean;
  bookshelf: string[];
  readingHistory: Record<string, ReadingHistoryEntry>;
  paragraphComments: Record<string, ParagraphComment[]>;
}

export class UserProfileManager {
  private static INSTANCE: UserProfileManager;
  private data: UserProfileData;
  private prefs: preferences.Preferences | null = null;
  private static readonly KEY = 'user_profile';
  private version: number = 0;

  static async getInstance(): Promise<UserProfileManager> {
    if (!UserProfileManager.INSTANCE) {
      UserProfileManager.INSTANCE = new UserProfileManager();
      await UserProfileManager.INSTANCE.init();
    }
    return UserProfileManager.INSTANCE;
  }

  private constructor() {
    this.data = {
      pageMode: false,
      bookshelf: [],
      readingHistory: {},
      paragraphComments: {}
    };
  }

  private async init(): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(getContext(), 'user_profile_store');
      const savedData = await this.prefs.get(UserProfileManager.KEY, '') as string;
      if (savedData) {
        const parsed = JSON.parse(savedData) as UserProfileData;
        this.data.pageMode = parsed.pageMode ?? false;
        this.data.bookshelf = parsed.bookshelf ?? [];
        this.data.readingHistory = parsed.readingHistory ?? {};
        this.data.paragraphComments = parsed.paragraphComments ?? {};
      }
    } catch (error) {
      console.error('Failed to initialize UserProfileManager:', error);
    }
  }

  getVersion(): number {
    return this.version;
  }

  getPageMode(): boolean {
    return this.data.pageMode;
  }

  async setPageMode(pageMode: boolean): Promise<void> {
    this.data.pageMode = pageMode;
    await this.persist();
  }

  isInBookshelf(bookId: string): boolean {
    return this.data.bookshelf.includes(bookId);
  }

  getAllBookIds(): string[] {
    return this.data.bookshelf;
  }

  async addToBookshelf(bookId: string): Promise<void> {
    if (!this.data.bookshelf.includes(bookId)) {
      this.data.bookshelf.push(bookId);
      await this.persist();
    }
  }

  async removeFromBookshelf(bookId: string): Promise<void> {
    this.data.bookshelf = this.data.bookshelf.filter(id => id !== bookId);
    await this.persist();
  }

  async toggleBookshelf(bookId: string): Promise<boolean> {
    if (this.isInBookshelf(bookId)) {
      await this.removeFromBookshelf(bookId);
      return false;
    } else {
      await this.addToBookshelf(bookId);
      return true;
    }
  }

  getReadingProgress(bookId: string): ReadingHistoryEntry | null {
    return this.data.readingHistory[bookId] || null;
  }

  async saveReadingProgress(bookId: string, currentPage: number, scrollOffset: number): Promise<void> {
    this.data.readingHistory[bookId] = {
      bookId,
      currentPage,
      scrollOffset,
      lastReadTime: Date.now()
    };
    await this.persist();
  }

  async saveReadingProgressDomPos(bookId: string, spineIndex: number, startDomPos: string): Promise<void> {
    this.data.readingHistory[bookId] = {
      bookId,
      spineIndex,
      startDomPos,
      lastReadTime: Date.now()
    };
    await this.persist();
  }

  getReadingHistoryBookIds(): string[] {
    const entries = Object.values(this.data.readingHistory);
    entries.sort((a, b) => b.lastReadTime - a.lastReadTime);
    return entries.map(e => e.bookId);
  }

  private commentKey(bookId: string, paragraphIndex: number): string {
    return `${bookId}_${paragraphIndex}`;
  }

  getParagraphComments(bookId: string, paragraphIndex: number): ParagraphComment[] {
    const key = this.commentKey(bookId, paragraphIndex);
    return this.data.paragraphComments[key] || [];
  }

  hasParagraphComments(bookId: string, paragraphIndex: number): boolean {
    const key = this.commentKey(bookId, paragraphIndex);
    const comments = this.data.paragraphComments[key];
    return comments !== undefined && comments.length > 0;
  }

  async addParagraphComment(bookId: string, paragraphIndex: number, content: string): Promise<void> {
    const key = this.commentKey(bookId, paragraphIndex);
    if (!this.data.paragraphComments[key]) {
      this.data.paragraphComments[key] = [];
    }
    this.data.paragraphComments[key].push({
      id: `${Date.now()}_${Math.random().toString(36).substring(2, 8)}`,
      content,
      createTime: Date.now()
    });
    await this.persist();
  }

  private async persist(): Promise<void> {
    if (this.prefs) {
      await this.prefs.put(UserProfileManager.KEY, JSON.stringify(this.data));
      await this.prefs.flush();
      this.version++;
    }
  }
}

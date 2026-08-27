import { preferences } from '@kit.ArkData';

interface ReadingHistoryEntry {
  bookId: string;
  currentPage: number;
  scrollOffset: number;
  lastReadTime: number;
  progressPercent: number;
}

interface UserProfileData {
  pageMode: boolean;
  bookshelf: string[];
  readingHistory: Record<string, ReadingHistoryEntry>;
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
      readingHistory: {}
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

  async saveReadingProgress(bookId: string, currentPage: number, scrollOffset: number, progressPercent: number): Promise<void> {
    this.data.readingHistory[bookId] = {
      bookId,
      currentPage,
      scrollOffset,
      lastReadTime: Date.now(),
      progressPercent
    };
    await this.persist();
  }

  getProgressPercent(bookId: string): number {
    const entry = this.data.readingHistory[bookId];
    return entry ? entry.progressPercent : 0;
  }

  getReadingHistoryBookIds(): string[] {
    const entries = Object.values(this.data.readingHistory);
    entries.sort((a, b) => b.lastReadTime - a.lastReadTime);
    return entries.map(e => e.bookId);
  }

  private async persist(): Promise<void> {
    if (this.prefs) {
      await this.prefs.put(UserProfileManager.KEY, JSON.stringify(this.data));
      await this.prefs.flush();
      this.version++;
    }
  }
}

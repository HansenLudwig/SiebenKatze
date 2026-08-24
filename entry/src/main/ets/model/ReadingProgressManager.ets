import { preferences } from '@kit.ArkData';

interface ProgressData {
  pageMode: boolean;
  currentPage: number;
  scrollOffset: number;
}

export class ReadingProgressManager {
  private static INSTANCE: ReadingProgressManager;
  private data: Map<string, ProgressData> = new Map();
  private prefs: preferences.Preferences | null = null;
  private static readonly KEY = 'reading_progress';

  static async getInstance(): Promise<ReadingProgressManager> {
    if (!ReadingProgressManager.INSTANCE) {
      ReadingProgressManager.INSTANCE = new ReadingProgressManager();
      await ReadingProgressManager.INSTANCE.init();
    }
    return ReadingProgressManager.INSTANCE;
  }

  private async init(): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(getContext(), 'reading_progress_store');
      const savedData = await this.prefs.get(ReadingProgressManager.KEY, '') as string;
      if (savedData) {
        const entries = JSON.parse(savedData) as Record<string, ProgressData>;
        Object.keys(entries).forEach(key => {
          this.data.set(key, entries[key]);
        });
      }
    } catch (error) {
      console.error('Failed to initialize ReadingProgressManager:', error);
    }
  }

  getProgress(bookId: string): ProgressData | null {
    return this.data.get(bookId) || null;
  }

  async saveProgress(bookId: string, pageMode: boolean, currentPage: number, scrollOffset: number): Promise<void> {
    this.data.set(bookId, { pageMode, currentPage, scrollOffset });
    await this.persist();
  }

  private async persist(): Promise<void> {
    if (this.prefs) {
      const entries: Record<string, ProgressData> = {};
      this.data.forEach((value, key) => {
        entries[key] = value;
      });
      await this.prefs.put(ReadingProgressManager.KEY, JSON.stringify(entries));
      await this.prefs.flush();
    }
  }
}

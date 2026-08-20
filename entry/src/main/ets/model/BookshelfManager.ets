import { preferences } from '@kit.ArkData';

export class BookshelfManager {
  private static INSTANCE: BookshelfManager;
  private data: Map<string, boolean> = new Map();
  private preferences: preferences.Preferences | null = null;
  private static readonly KEY = 'bookshelf';

  static async getInstance(): Promise<BookshelfManager> {
    if (!BookshelfManager.INSTANCE) {
      BookshelfManager.INSTANCE = new BookshelfManager();
      await BookshelfManager.INSTANCE.init();
    }
    return BookshelfManager.INSTANCE;
  }

  private async init(): Promise<void> {
    try {
      this.preferences = await preferences.getPreferences(getContext(), 'bookshelf_store');
      const savedData = await this.preferences.get(BookshelfManager.KEY, '') as string;
      if (savedData) {
        const books = JSON.parse(savedData) as string[];
        books.forEach(id => this.data.set(id, true));
      }
    } catch (error) {
      console.error('Failed to initialize BookshelfManager:', error);
    }
  }

  isInBookshelf(bookId: string): boolean {
    return this.data.has(bookId);
  }

  async addToBookshelf(bookId: string): Promise<void> {
    this.data.set(bookId, true);
    await this.save();
  }

  async removeFromBookshelf(bookId: string): Promise<void> {
    this.data.delete(bookId);
    await this.save();
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

  getAllBookIds(): string[] {
    return Array.from(this.data.keys());
  }

  private async save(): Promise<void> {
    if (this.preferences) {
      const books = Array.from(this.data.keys());
      await this.preferences.put(BookshelfManager.KEY, JSON.stringify(books));
      await this.preferences.flush();
    }
  }
}
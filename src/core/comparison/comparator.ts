/**
 * Word-by-Word Comparator
 *
 * Compares spoken words against target text in real-time.
 * Handles normalization, punctuation, and common variations.
 */

export interface ComparisonResult {
  isMatch: boolean;
  expectedWord: string;
  spokenWord: string;
  normalizedExpected: string;
  normalizedSpoken: string;
  position: number;
}

export interface ComparatorOptions {
  caseSensitive?: boolean;
  ignorePunctuation?: boolean;
  ignoreFillerWords?: boolean;
}

// Common filler words to ignore
const FILLER_WORDS = new Set(['um', 'uh', 'er', 'ah', 'like', 'you know', 'so', 'well']);

// Punctuation regex - remove these for comparison
const PUNCTUATION_REGEX = /[.,!?;:'"()\[\]{}\-—–]/g;

export class WordComparator {
  private targetWords: string[] = [];
  private normalizedTargetWords: string[] = [];
  private currentPosition = 0;
  private options: Required<ComparatorOptions>;

  constructor(options: ComparatorOptions = {}) {
    this.options = {
      caseSensitive: options.caseSensitive ?? false,
      ignorePunctuation: options.ignorePunctuation ?? true,
      ignoreFillerWords: options.ignoreFillerWords ?? true,
    };
  }

  /**
   * Set the target text that the user is trying to recite
   */
  setTargetText(text: string): void {
    this.targetWords = text.split(/\s+/).filter(w => w.length > 0);
    this.normalizedTargetWords = this.targetWords.map(w => this.normalize(w));
    this.currentPosition = 0;
  }

  /**
   * Normalize a word for comparison
   */
  private normalize(word: string): string {
    let normalized = word;

    if (this.options.ignorePunctuation) {
      normalized = normalized.replace(PUNCTUATION_REGEX, '');
    }

    if (!this.options.caseSensitive) {
      normalized = normalized.toLowerCase();
    }

    return normalized.trim();
  }

  /**
   * Check if a word is a filler word that should be ignored
   */
  private isFillerWord(word: string): boolean {
    if (!this.options.ignoreFillerWords) return false;
    return FILLER_WORDS.has(word.toLowerCase());
  }

  /**
   * Compare a spoken word against the expected word at current position
   * Returns null if the word is a filler word (should be ignored)
   */
  compareWord(spokenWord: string): ComparisonResult | null {
    const normalizedSpoken = this.normalize(spokenWord);

    // Skip filler words
    if (this.isFillerWord(normalizedSpoken)) {
      return null;
    }

    // Check if we've reached the end
    if (this.currentPosition >= this.targetWords.length) {
      return {
        isMatch: false,
        expectedWord: '[END]',
        spokenWord,
        normalizedExpected: '',
        normalizedSpoken,
        position: this.currentPosition,
      };
    }

    const expectedWord = this.targetWords[this.currentPosition];
    const normalizedExpected = this.normalizedTargetWords[this.currentPosition];

    const isMatch = normalizedSpoken === normalizedExpected;

    const result: ComparisonResult = {
      isMatch,
      expectedWord,
      spokenWord,
      normalizedExpected,
      normalizedSpoken,
      position: this.currentPosition,
    };

    // Advance position regardless of match
    // (User needs to continue from where they are, not repeat)
    this.currentPosition++;

    return result;
  }

  /**
   * Reset to start of text
   */
  reset(): void {
    this.currentPosition = 0;
  }

  /**
   * Get current position in the text
   */
  getPosition(): number {
    return this.currentPosition;
  }

  /**
   * Get total word count
   */
  getTotalWords(): number {
    return this.targetWords.length;
  }

  /**
   * Check if recitation is complete
   */
  isComplete(): boolean {
    return this.currentPosition >= this.targetWords.length;
  }

  /**
   * Get the next expected word (for hints)
   */
  getNextExpectedWord(): string | null {
    if (this.currentPosition >= this.targetWords.length) {
      return null;
    }
    return this.targetWords[this.currentPosition];
  }

  /**
   * Get all target words (for display)
   */
  getTargetWords(): string[] {
    return [...this.targetWords];
  }
}

/**
 * Streaming Speech Recognition using Web Speech API
 *
 * Key features:
 * - Real-time interim results (words as they're spoken)
 * - Continuous listening mode
 * - Word-by-word callback for immediate processing
 */

// Web Speech API type definitions
interface SpeechRecognitionEvent extends Event {
  results: SpeechRecognitionResultList;
  resultIndex: number;
}

interface SpeechRecognitionResultList {
  length: number;
  item(index: number): SpeechRecognitionResult;
  [index: number]: SpeechRecognitionResult;
}

interface SpeechRecognitionResult {
  length: number;
  item(index: number): SpeechRecognitionAlternative;
  [index: number]: SpeechRecognitionAlternative;
  isFinal: boolean;
}

interface SpeechRecognitionAlternative {
  transcript: string;
  confidence: number;
}

interface SpeechRecognitionErrorEvent extends Event {
  error: string;
  message: string;
}

interface SpeechRecognitionInstance extends EventTarget {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  maxAlternatives: number;
  onresult: ((event: SpeechRecognitionEvent) => void) | null;
  onerror: ((event: SpeechRecognitionErrorEvent) => void) | null;
  onend: (() => void) | null;
  start(): void;
  stop(): void;
  abort(): void;
}

interface SpeechRecognitionConstructor {
  new (): SpeechRecognitionInstance;
}

declare global {
  interface Window {
    SpeechRecognition?: SpeechRecognitionConstructor;
    webkitSpeechRecognition?: SpeechRecognitionConstructor;
  }
}

export interface SpeechCallbacks {
  onWord: (word: string, isFinal: boolean) => void;
  onError: (error: string) => void;
  onEnd: () => void;
}

export class StreamingSpeechRecognition {
  private recognition: SpeechRecognitionInstance | null = null;
  private isListening = false;
  private lastProcessedIndex = 0;
  private callbacks: SpeechCallbacks | null = null;

  constructor() {
    // Check for browser support
    const SpeechRecognitionAPI = window.SpeechRecognition || window.webkitSpeechRecognition;

    if (!SpeechRecognitionAPI) {
      throw new Error('Speech recognition not supported in this browser. Try Chrome or Edge.');
    }

    this.recognition = new SpeechRecognitionAPI();
    this.configureRecognition();
  }

  private configureRecognition(): void {
    if (!this.recognition) return;

    // Critical settings for real-time word-by-word detection
    this.recognition.continuous = true;        // Don't stop after first result
    this.recognition.interimResults = true;    // Get results as user speaks (KEY!)
    this.recognition.lang = 'en-US';
    this.recognition.maxAlternatives = 1;

    this.recognition.onresult = (event: SpeechRecognitionEvent) => {
      this.handleResult(event);
    };

    this.recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
      console.error('Speech recognition error:', event.error);
      this.callbacks?.onError(event.error);
    };

    this.recognition.onend = () => {
      // Auto-restart if we're still supposed to be listening
      // (Web Speech API stops after silence)
      if (this.isListening && this.recognition) {
        this.recognition.start();
      } else {
        this.callbacks?.onEnd();
      }
    };
  }

  private handleResult(event: SpeechRecognitionEvent): void {
    if (!this.callbacks) return;

    // Process only the latest result
    const result = event.results[event.results.length - 1];
    const transcript = result[0].transcript.trim();
    const resultIsFinal = result.isFinal;

    // Split into words and process new ones
    const words = transcript.split(/\s+/).filter((w: string) => w.length > 0);

    // For interim results, we need to track which words we've already processed
    // to avoid alerting multiple times for the same word
    if (resultIsFinal) {
      // Final result - process all words from where we left off
      for (let i = this.lastProcessedIndex; i < words.length; i++) {
        this.callbacks.onWord(words[i], true);
      }
      this.lastProcessedIndex = 0; // Reset for next utterance
    } else {
      // Interim result - only process new words, but mark them as non-final
      // This is where the magic happens for real-time detection
      for (let i = this.lastProcessedIndex; i < words.length; i++) {
        this.callbacks.onWord(words[i], false);
      }
      // Update the index, but be careful - interim results can change
      // So we only advance for words that seem "stable"
      if (words.length > 1) {
        // Consider all but the last word as stable enough to process
        this.lastProcessedIndex = Math.max(this.lastProcessedIndex, words.length - 1);
      }
    }
  }

  start(callbacks: SpeechCallbacks): void {
    if (!this.recognition) {
      callbacks.onError('Speech recognition not initialized');
      return;
    }

    this.callbacks = callbacks;
    this.lastProcessedIndex = 0;
    this.isListening = true;

    try {
      this.recognition.start();
    } catch (e) {
      // May already be started
      console.warn('Recognition start warning:', e);
    }
  }

  stop(): void {
    this.isListening = false;
    this.recognition?.stop();
  }

  isActive(): boolean {
    return this.isListening;
  }
}

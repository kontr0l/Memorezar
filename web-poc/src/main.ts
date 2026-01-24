/**
 * Memorezar - Real-time Memorization Assistant
 *
 * Main entry point that orchestrates:
 * - Speech recognition
 * - Word comparison
 * - Alert triggering
 * - UI updates
 */

import { StreamingSpeechRecognition } from './core/speech/streaming';
import { WordComparator } from './core/comparison/comparator';
import { AudioAlert } from './core/alert/audio';

// State
let speechRecognition: StreamingSpeechRecognition | null = null;
let comparator: WordComparator | null = null;
let audioAlert: AudioAlert | null = null;
let isReciting = false;

// Stats for this session
let correctCount = 0;
let errorCount = 0;

// DOM Elements
const quoteInput = document.getElementById('quote-input') as HTMLTextAreaElement;
const startBtn = document.getElementById('start-btn') as HTMLButtonElement;
const stopBtn = document.getElementById('stop-btn') as HTMLButtonElement;
const resetBtn = document.getElementById('reset-btn') as HTMLButtonElement;
const statusEl = document.getElementById('status') as HTMLDivElement;
const wordDisplayEl = document.getElementById('word-display') as HTMLDivElement;
const progressEl = document.getElementById('progress') as HTMLDivElement;
const lastWordEl = document.getElementById('last-word') as HTMLSpanElement;
const expectedWordEl = document.getElementById('expected-word') as HTMLSpanElement;
const statsEl = document.getElementById('stats') as HTMLDivElement;

/**
 * Detect if we're on iOS
 */
function isIOS(): boolean {
  return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
}

/**
 * Check if Speech Recognition is supported
 */
function isSpeechRecognitionSupported(): boolean {
  return !!(window.SpeechRecognition || window.webkitSpeechRecognition);
}

/**
 * Initialize the application
 */
async function init(): Promise<void> {
  // Check browser support first
  if (!isSpeechRecognitionSupported()) {
    if (isIOS()) {
      setStatus('⚠️ iOS Safari doesn\'t support speech recognition. For iPhone testing, we need to build the native app. Try on Chrome desktop for now!');
      statusEl.style.background = '#fff3cd';
      statusEl.style.color = '#856404';
    } else {
      setStatus('⚠️ Your browser doesn\'t support speech recognition. Please use Chrome or Edge.');
    }
    startBtn.disabled = true;
    return;
  }

  try {
    speechRecognition = new StreamingSpeechRecognition();
    comparator = new WordComparator({
      caseSensitive: false,
      ignorePunctuation: true,
      ignoreFillerWords: true,
    });
    audioAlert = new AudioAlert({
      frequency: 440,
      duration: 100,
      volume: 0.3,
    });

    // Pre-initialize audio (will fully init on first user interaction)
    await audioAlert.init();

    setStatus('Ready. Enter a quote and click Start.');
    enableControls(true);
  } catch (error) {
    const msg = error instanceof Error ? error.message : 'Unknown error';
    if (isIOS()) {
      setStatus('⚠️ iOS Safari doesn\'t support speech recognition. For iPhone, we need the native app. Try Chrome desktop!');
      statusEl.style.background = '#fff3cd';
      statusEl.style.color = '#856404';
    } else {
      setStatus(`Error: ${msg}`);
    }
    console.error('Init error:', error);
  }
}

/**
 * Start recitation mode
 */
async function startRecitation(): Promise<void> {
  if (!speechRecognition || !comparator || !audioAlert) {
    setStatus('Error: App not initialized');
    return;
  }

  const quoteText = quoteInput.value.trim();
  if (!quoteText) {
    setStatus('Please enter a quote to memorize');
    return;
  }

  // Reset state
  comparator.setTargetText(quoteText);
  correctCount = 0;
  errorCount = 0;
  isReciting = true;

  // Update UI
  renderWordDisplay();
  updateStats();
  enableControls(false);
  setStatus('Listening... Recite the quote from memory');

  // Initialize audio context (requires user interaction)
  await audioAlert.init();

  // Start listening
  speechRecognition.start({
    onWord: handleWord,
    onError: handleError,
    onEnd: handleEnd,
  });
}

/**
 * Handle each word as it's recognized
 */
function handleWord(word: string, _isFinal: boolean): void {
  if (!comparator || !audioAlert || !isReciting) return;

  // Compare the word
  const result = comparator.compareWord(word);

  // null means filler word - ignore
  if (result === null) {
    console.log('Filler word ignored:', word);
    return;
  }

  // Update UI with what was spoken
  lastWordEl.textContent = word;
  expectedWordEl.textContent = result.expectedWord;

  if (result.isMatch) {
    // Correct word
    correctCount++;
    highlightWord(result.position, 'correct');
    console.log(`✓ Correct: "${word}" (position ${result.position})`);
  } else {
    // Wrong word - ALERT!
    errorCount++;
    highlightWord(result.position, 'error');
    audioAlert.playErrorBeep();
    console.log(`✗ Error: said "${word}", expected "${result.expectedWord}" (position ${result.position})`);
  }

  updateStats();
  updateProgress();

  // Check if complete
  if (comparator.isComplete()) {
    stopRecitation();
    if (errorCount === 0) {
      setStatus('Perfect! You recited the entire quote correctly!');
      audioAlert.playSuccessBeep();
    } else {
      setStatus(`Complete! ${correctCount} correct, ${errorCount} errors.`);
    }
  }
}

/**
 * Render the word display with all target words
 */
function renderWordDisplay(): void {
  if (!comparator) return;

  const words = comparator.getTargetWords();
  wordDisplayEl.innerHTML = words
    .map((word, i) => `<span class="word" data-index="${i}">${escapeHtml(word)}</span>`)
    .join(' ');
}

/**
 * Highlight a word in the display
 */
function highlightWord(index: number, status: 'correct' | 'error' | 'current'): void {
  const wordEl = wordDisplayEl.querySelector(`[data-index="${index}"]`);
  if (wordEl) {
    wordEl.classList.remove('correct', 'error', 'current');
    wordEl.classList.add(status);
  }
}

/**
 * Update progress indicator
 */
function updateProgress(): void {
  if (!comparator) return;

  const current = comparator.getPosition();
  const total = comparator.getTotalWords();
  const percent = total > 0 ? Math.round((current / total) * 100) : 0;

  progressEl.textContent = `${current} / ${total} words (${percent}%)`;
}

/**
 * Update stats display
 */
function updateStats(): void {
  statsEl.textContent = `Correct: ${correctCount} | Errors: ${errorCount}`;
}

/**
 * Handle speech recognition errors
 */
function handleError(error: string): void {
  console.error('Speech error:', error);

  if (error === 'not-allowed') {
    setStatus('Microphone access denied. Please allow microphone access and refresh.');
  } else if (error === 'no-speech') {
    // This is normal - just means silence was detected
    // Don't stop, just keep listening
  } else {
    setStatus(`Speech error: ${error}`);
  }
}

/**
 * Handle speech recognition ending
 */
function handleEnd(): void {
  if (isReciting) {
    // Unexpected end - speech recognition auto-restarts in the streaming module
    console.log('Speech recognition ended, should auto-restart');
  }
}

/**
 * Stop recitation mode
 */
function stopRecitation(): void {
  isReciting = false;
  speechRecognition?.stop();
  enableControls(true);

  if (comparator && !comparator.isComplete()) {
    setStatus('Stopped. Click Start to try again.');
  }
}

/**
 * Reset everything
 */
function resetRecitation(): void {
  stopRecitation();
  comparator?.reset();
  correctCount = 0;
  errorCount = 0;

  // Clear UI
  wordDisplayEl.innerHTML = '';
  progressEl.textContent = '0 / 0 words';
  lastWordEl.textContent = '-';
  expectedWordEl.textContent = '-';
  updateStats();
  setStatus('Ready. Enter a quote and click Start.');
}

/**
 * Set status message
 */
function setStatus(message: string): void {
  statusEl.textContent = message;
}

/**
 * Enable/disable controls
 */
function enableControls(canStart: boolean): void {
  startBtn.disabled = !canStart;
  stopBtn.disabled = canStart;
  quoteInput.disabled = !canStart;
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Event listeners
startBtn.addEventListener('click', startRecitation);
stopBtn.addEventListener('click', stopRecitation);
resetBtn.addEventListener('click', resetRecitation);

// Initialize on load
init();

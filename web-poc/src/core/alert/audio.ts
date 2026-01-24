/**
 * Audio Alert System
 *
 * Plays a short beep/tone when the user says the wrong word.
 * Uses Web Audio API for minimal latency.
 */

export interface AlertOptions {
  frequency?: number;    // Hz - pitch of the beep
  duration?: number;     // ms - how long the beep lasts
  volume?: number;       // 0-1 - loudness
  type?: OscillatorType; // sine, square, sawtooth, triangle
}

const DEFAULT_OPTIONS: Required<AlertOptions> = {
  frequency: 440,    // A4 note - easily audible
  duration: 100,     // Short but noticeable
  volume: 0.3,       // Not too loud
  type: 'sine',      // Clean tone
};

export class AudioAlert {
  private audioContext: AudioContext | null = null;
  private options: Required<AlertOptions>;

  constructor(options: AlertOptions = {}) {
    this.options = { ...DEFAULT_OPTIONS, ...options };
  }

  /**
   * Initialize the audio context (must be called after user interaction)
   */
  async init(): Promise<void> {
    if (this.audioContext) return;

    this.audioContext = new AudioContext();

    // Resume if suspended (browsers require user interaction)
    if (this.audioContext.state === 'suspended') {
      await this.audioContext.resume();
    }
  }

  /**
   * Play the error beep
   */
  async playErrorBeep(): Promise<void> {
    if (!this.audioContext) {
      await this.init();
    }

    const ctx = this.audioContext!;

    // Ensure context is running
    if (ctx.state === 'suspended') {
      await ctx.resume();
    }

    // Create oscillator for the tone
    const oscillator = ctx.createOscillator();
    oscillator.type = this.options.type;
    oscillator.frequency.setValueAtTime(this.options.frequency, ctx.currentTime);

    // Create gain node for volume control and smooth envelope
    const gainNode = ctx.createGain();
    gainNode.gain.setValueAtTime(0, ctx.currentTime);

    // Quick attack
    gainNode.gain.linearRampToValueAtTime(
      this.options.volume,
      ctx.currentTime + 0.01
    );

    // Quick decay to avoid harsh cutoff
    const endTime = ctx.currentTime + this.options.duration / 1000;
    gainNode.gain.linearRampToValueAtTime(0, endTime);

    // Connect: oscillator -> gain -> output
    oscillator.connect(gainNode);
    gainNode.connect(ctx.destination);

    // Play the tone
    oscillator.start(ctx.currentTime);
    oscillator.stop(endTime + 0.01);
  }

  /**
   * Play a success sound (optional, for end of recitation)
   */
  async playSuccessBeep(): Promise<void> {
    if (!this.audioContext) {
      await this.init();
    }

    const ctx = this.audioContext!;

    if (ctx.state === 'suspended') {
      await ctx.resume();
    }

    // Two-tone success sound
    const frequencies = [523.25, 659.25]; // C5, E5 - happy interval
    const duration = 0.15;

    for (let i = 0; i < frequencies.length; i++) {
      const oscillator = ctx.createOscillator();
      oscillator.type = 'sine';
      oscillator.frequency.setValueAtTime(frequencies[i], ctx.currentTime);

      const gainNode = ctx.createGain();
      const startTime = ctx.currentTime + i * duration;
      gainNode.gain.setValueAtTime(0, startTime);
      gainNode.gain.linearRampToValueAtTime(this.options.volume * 0.5, startTime + 0.01);
      gainNode.gain.linearRampToValueAtTime(0, startTime + duration);

      oscillator.connect(gainNode);
      gainNode.connect(ctx.destination);

      oscillator.start(startTime);
      oscillator.stop(startTime + duration + 0.01);
    }
  }

  /**
   * Update alert options
   */
  setOptions(options: Partial<AlertOptions>): void {
    this.options = { ...this.options, ...options };
  }
}

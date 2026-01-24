import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StyleSheet,
  Alert,
  Platform,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import * as Haptics from 'expo-haptics';
import { Audio } from 'expo-av';
import Voice, {
  SpeechResultsEvent,
  SpeechErrorEvent,
} from '@react-native-voice/voice';
import { WordComparator, ComparisonResult } from '@/src/core/comparator';

// Word status for highlighting
type WordStatus = 'pending' | 'correct' | 'error';

interface WordState {
  word: string;
  status: WordStatus;
}

export default function HomeScreen() {
  // State
  const [quoteText, setQuoteText] = useState(
    'Four score and seven years ago our fathers brought forth on this continent a new nation'
  );
  const [isListening, setIsListening] = useState(false);
  const [words, setWords] = useState<WordState[]>([]);
  const [currentPosition, setCurrentPosition] = useState(0);
  const [lastSpoken, setLastSpoken] = useState('-');
  const [stats, setStats] = useState({ correct: 0, errors: 0 });
  const [statusMessage, setStatusMessage] = useState('Enter a quote and tap Start');

  // Refs
  const comparatorRef = useRef<WordComparator | null>(null);
  const lastProcessedIndexRef = useRef(0);
  const soundRef = useRef<Audio.Sound | null>(null);

  // Initialize
  useEffect(() => {
    comparatorRef.current = new WordComparator();
    setupVoice();
    loadSound();

    return () => {
      Voice.destroy().then(Voice.removeAllListeners);
      soundRef.current?.unloadAsync();
    };
  }, []);

  // Setup voice recognition handlers
  const setupVoice = async () => {
    Voice.onSpeechResults = onSpeechResults;
    Voice.onSpeechPartialResults = onSpeechPartialResults;
    Voice.onSpeechError = onSpeechError;
    Voice.onSpeechEnd = onSpeechEnd;
  };

  // Load error beep sound
  const loadSound = async () => {
    try {
      // Create a simple beep using Audio API
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });
    } catch (error) {
      console.log('Audio setup error:', error);
    }
  };

  // Play error feedback (haptic + visual flash handled in UI)
  const playErrorFeedback = useCallback(async () => {
    // Haptic feedback - strong vibration
    if (Platform.OS !== 'web') {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    }
  }, []);

  // Play success feedback
  const playSuccessFeedback = useCallback(async () => {
    if (Platform.OS !== 'web') {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    }
  }, []);

  // Handle partial speech results (real-time, as user speaks)
  const onSpeechPartialResults = (event: SpeechResultsEvent) => {
    if (!event.value || !comparatorRef.current) return;

    const transcript = event.value[0] || '';
    const spokenWords = transcript.split(/\s+/).filter((w) => w.length > 0);

    // Process only new words
    processNewWords(spokenWords, false);
  };

  // Handle final speech results
  const onSpeechResults = (event: SpeechResultsEvent) => {
    if (!event.value || !comparatorRef.current) return;

    const transcript = event.value[0] || '';
    const spokenWords = transcript.split(/\s+/).filter((w) => w.length > 0);

    // Process remaining words as final
    processNewWords(spokenWords, true);

    // Reset for next utterance
    lastProcessedIndexRef.current = 0;
  };

  // Process new words from speech recognition
  const processNewWords = (spokenWords: string[], isFinal: boolean) => {
    const comparator = comparatorRef.current;
    if (!comparator) return;

    // For partial results, only process words we haven't seen
    const startIndex = lastProcessedIndexRef.current;
    const endIndex = isFinal ? spokenWords.length : Math.max(0, spokenWords.length - 1);

    for (let i = startIndex; i < endIndex; i++) {
      const word = spokenWords[i];
      const result = comparator.compareWord(word);

      if (result === null) {
        // Filler word, ignore
        continue;
      }

      setLastSpoken(word);
      updateWordStatus(result);

      if (!result.isMatch) {
        playErrorFeedback();
      }

      // Check completion
      if (comparator.isComplete()) {
        stopListening();
        if (stats.errors === 0) {
          setStatusMessage('Perfect! You did it!');
          playSuccessFeedback();
        } else {
          setStatusMessage(`Done! ${stats.correct} correct, ${stats.errors} errors`);
        }
      }
    }

    // Update processed index
    if (!isFinal && spokenWords.length > 1) {
      lastProcessedIndexRef.current = Math.max(lastProcessedIndexRef.current, endIndex);
    }
  };

  // Update word status in UI
  const updateWordStatus = (result: ComparisonResult) => {
    setWords((prev) => {
      const updated = [...prev];
      if (result.position < updated.length) {
        updated[result.position] = {
          ...updated[result.position],
          status: result.isMatch ? 'correct' : 'error',
        };
      }
      return updated;
    });

    setCurrentPosition(result.position + 1);

    setStats((prev) => ({
      correct: prev.correct + (result.isMatch ? 1 : 0),
      errors: prev.errors + (result.isMatch ? 0 : 1),
    }));
  };

  // Handle speech errors
  const onSpeechError = (event: SpeechErrorEvent) => {
    console.log('Speech error:', event.error);
    if (event.error?.code === 'no-speech') {
      // No speech detected, just continue listening
      return;
    }
    setStatusMessage(`Error: ${event.error?.message || 'Unknown error'}`);
  };

  // Handle speech end (auto-restart if still listening)
  const onSpeechEnd = () => {
    if (isListening && !comparatorRef.current?.isComplete()) {
      // Restart listening
      Voice.start('en-US').catch(console.error);
    }
  };

  // Start listening
  const startListening = async () => {
    if (!quoteText.trim()) {
      Alert.alert('Error', 'Please enter a quote first');
      return;
    }

    // Reset state
    const comparator = comparatorRef.current;
    if (!comparator) return;

    comparator.setTargetText(quoteText);
    lastProcessedIndexRef.current = 0;

    const targetWords = comparator.getTargetWords();
    setWords(targetWords.map((word) => ({ word, status: 'pending' })));
    setCurrentPosition(0);
    setStats({ correct: 0, errors: 0 });
    setLastSpoken('-');
    setStatusMessage('Listening... Recite the quote');

    try {
      await Voice.start('en-US');
      setIsListening(true);
    } catch (error) {
      console.error('Voice start error:', error);
      setStatusMessage('Failed to start speech recognition');
    }
  };

  // Stop listening
  const stopListening = async () => {
    try {
      await Voice.stop();
      setIsListening(false);
      if (!comparatorRef.current?.isComplete()) {
        setStatusMessage('Stopped. Tap Start to try again.');
      }
    } catch (error) {
      console.error('Voice stop error:', error);
    }
  };

  // Reset everything
  const resetAll = () => {
    stopListening();
    comparatorRef.current?.reset();
    setWords([]);
    setCurrentPosition(0);
    setStats({ correct: 0, errors: 0 });
    setLastSpoken('-');
    setStatusMessage('Enter a quote and tap Start');
  };

  return (
    <View style={styles.container}>
      <StatusBar style="dark" />

      <Text style={styles.title}>Memorezar</Text>
      <Text style={styles.subtitle}>Real-time memorization feedback</Text>

      {/* Quote Input */}
      <View style={styles.card}>
        <Text style={styles.label}>Quote to memorize:</Text>
        <TextInput
          style={styles.input}
          multiline
          value={quoteText}
          onChangeText={setQuoteText}
          editable={!isListening}
          placeholder="Enter the text you want to memorize..."
        />
      </View>

      {/* Controls */}
      <View style={styles.controls}>
        <TouchableOpacity
          style={[styles.button, styles.startButton, isListening && styles.buttonDisabled]}
          onPress={startListening}
          disabled={isListening}
        >
          <Text style={styles.buttonText}>Start</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, styles.stopButton, !isListening && styles.buttonDisabled]}
          onPress={stopListening}
          disabled={!isListening}
        >
          <Text style={styles.buttonText}>Stop</Text>
        </TouchableOpacity>

        <TouchableOpacity style={[styles.button, styles.resetButton]} onPress={resetAll}>
          <Text style={styles.buttonText}>Reset</Text>
        </TouchableOpacity>
      </View>

      {/* Status */}
      <View style={styles.statusCard}>
        <Text style={styles.statusText}>{statusMessage}</Text>
      </View>

      {/* Word Display */}
      <ScrollView style={styles.wordContainer} contentContainerStyle={styles.wordContent}>
        <View style={styles.wordWrap}>
          {words.map((w, i) => (
            <Text
              key={i}
              style={[
                styles.word,
                w.status === 'correct' && styles.wordCorrect,
                w.status === 'error' && styles.wordError,
              ]}
            >
              {w.word}
            </Text>
          ))}
        </View>
      </ScrollView>

      {/* Stats */}
      <View style={styles.statsRow}>
        <View style={styles.statItem}>
          <Text style={styles.statLabel}>Progress</Text>
          <Text style={styles.statValue}>
            {currentPosition} / {words.length}
          </Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statLabel}>Last Word</Text>
          <Text style={styles.statValue}>{lastSpoken}</Text>
        </View>
        <View style={styles.statItem}>
          <Text style={styles.statLabel}>Score</Text>
          <Text style={styles.statValue}>
            {stats.correct}✓ {stats.errors}✗
          </Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    paddingTop: 60,
    paddingHorizontal: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    color: '#2c3e50',
  },
  subtitle: {
    fontSize: 14,
    textAlign: 'center',
    color: '#7f8c8d',
    marginBottom: 20,
  },
  card: {
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#2c3e50',
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: '#e0e0e0',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    minHeight: 80,
    textAlignVertical: 'top',
  },
  controls: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 16,
  },
  button: {
    flex: 1,
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
  },
  startButton: {
    backgroundColor: '#27ae60',
  },
  stopButton: {
    backgroundColor: '#e74c3c',
  },
  resetButton: {
    backgroundColor: '#95a5a6',
  },
  buttonDisabled: {
    opacity: 0.5,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  statusCard: {
    backgroundColor: '#ecf0f1',
    borderRadius: 8,
    padding: 12,
    marginBottom: 16,
  },
  statusText: {
    textAlign: 'center',
    fontSize: 14,
    color: '#2c3e50',
    fontWeight: '500',
  },
  wordContainer: {
    flex: 1,
    backgroundColor: 'white',
    borderRadius: 12,
    marginBottom: 16,
  },
  wordContent: {
    padding: 16,
  },
  wordWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  word: {
    fontSize: 18,
    padding: 4,
    marginRight: 6,
    marginBottom: 6,
    color: '#2c3e50',
  },
  wordCorrect: {
    backgroundColor: '#d5f4e6',
    color: '#27ae60',
    borderRadius: 4,
  },
  wordError: {
    backgroundColor: '#fde8e8',
    color: '#e74c3c',
    borderRadius: 4,
    textDecorationLine: 'line-through',
  },
  statsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: 'white',
    borderRadius: 12,
    padding: 16,
    marginBottom: 20,
  },
  statItem: {
    alignItems: 'center',
  },
  statLabel: {
    fontSize: 11,
    color: '#95a5a6',
    textTransform: 'uppercase',
    marginBottom: 4,
  },
  statValue: {
    fontSize: 14,
    fontWeight: '600',
    color: '#2c3e50',
  },
});

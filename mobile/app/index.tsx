import React, { useState, useRef, useCallback } from 'react';
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
import {
  ExpoSpeechRecognitionModule,
  useSpeechRecognitionEvent,
} from 'expo-speech-recognition';
import { WordComparator, ComparisonResult } from '../src/core/comparator';

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
  const comparatorRef = useRef<WordComparator>(new WordComparator());
  const lastProcessedIndexRef = useRef(0);

  // Speech recognition lifecycle events
  useSpeechRecognitionEvent('start', () => {
    setIsListening(true);
    setStatusMessage('Listening... Recite the quote');
  });

  useSpeechRecognitionEvent('end', () => {
    setIsListening(false);
  });

  // Handle both partial and final results
  useSpeechRecognitionEvent('result', (event) => {
    const transcript = event.results[0]?.transcript ?? '';
    const spokenWords = transcript.split(/\s+/).filter((w: string) => w.length > 0);
    const isFinal = event.isFinal;

    processNewWords(spokenWords, isFinal);

    if (isFinal) {
      // Reset index for next utterance
      lastProcessedIndexRef.current = 0;

      // Auto-restart if not complete
      const comparator = comparatorRef.current;
      if (comparator && !comparator.isComplete()) {
        ExpoSpeechRecognitionModule.start({
          lang: 'en-US',
          interimResults: true,
          continuous: true,
          maxAlternatives: 1,
        });
      }
    }
  });

  useSpeechRecognitionEvent('error', (event) => {
    console.log('Speech error:', event.error, event.message);
    if (event.error === 'no-speech') {
      return;
    }
    setStatusMessage(`Error: ${event.message || event.error || 'Unknown error'}`);
  });

  // Play error feedback (haptic)
  const playErrorFeedback = useCallback(async () => {
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

  // Process new words from speech recognition
  const processNewWords = (spokenWords: string[], isFinal: boolean) => {
    const comparator = comparatorRef.current;
    if (!comparator) return;

    const startIndex = lastProcessedIndexRef.current;
    const endIndex = isFinal ? spokenWords.length : Math.max(0, spokenWords.length - 1);

    for (let i = startIndex; i < endIndex; i++) {
      const word = spokenWords[i];
      const result = comparator.compareWord(word);

      if (result === null) {
        continue;
      }

      setLastSpoken(word);
      updateWordStatus(result);

      if (!result.isMatch) {
        playErrorFeedback();
      }

      if (comparator.isComplete()) {
        ExpoSpeechRecognitionModule.stop();
        setStats((prev) => {
          const finalStats = {
            correct: prev.correct + (result.isMatch ? 1 : 0),
            errors: prev.errors + (result.isMatch ? 0 : 1),
          };
          if (finalStats.errors === 0) {
            setStatusMessage('Perfect! You did it!');
            playSuccessFeedback();
          } else {
            setStatusMessage(`Done! ${finalStats.correct} correct, ${finalStats.errors} errors`);
          }
          return finalStats;
        });
        return;
      }
    }

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

  // Start listening
  const startListening = async () => {
    if (!quoteText.trim()) {
      Alert.alert('Error', 'Please enter a quote first');
      return;
    }

    // Check availability
    const available = ExpoSpeechRecognitionModule.isRecognitionAvailable();
    if (!available) {
      Alert.alert('Error', 'Speech recognition is not available on this device');
      return;
    }

    // Request permissions
    const permResult = await ExpoSpeechRecognitionModule.requestPermissionsAsync();
    if (!permResult.granted) {
      Alert.alert('Error', 'Microphone and speech recognition permissions are required');
      return;
    }

    // Reset state
    const comparator = comparatorRef.current;
    comparator.setTargetText(quoteText);
    lastProcessedIndexRef.current = 0;

    const targetWords = comparator.getTargetWords();
    setWords(targetWords.map((word) => ({ word, status: 'pending' })));
    setCurrentPosition(0);
    setStats({ correct: 0, errors: 0 });
    setLastSpoken('-');

    // Configure audio for recording
    try {
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });
    } catch (e) {
      console.log('Audio mode setup error:', e);
    }

    // Start speech recognition
    ExpoSpeechRecognitionModule.start({
      lang: 'en-US',
      interimResults: true,
      continuous: true,
      maxAlternatives: 1,
    });
  };

  // Stop listening
  const stopListening = () => {
    ExpoSpeechRecognitionModule.stop();
    if (!comparatorRef.current?.isComplete()) {
      setStatusMessage('Stopped. Tap Start to try again.');
    }
  };

  // Reset everything
  const resetAll = () => {
    if (isListening) {
      ExpoSpeechRecognitionModule.abort();
    }
    comparatorRef.current.reset();
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

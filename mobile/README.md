# Memorezar Mobile App

Real-time memorization assistant with instant feedback - mobile version.

## Features

- **Instant feedback**: Vibrates immediately when you say the wrong word
- **Word-by-word tracking**: See your progress in real-time
- **Haptic feedback**: Feel the error, don't just see it
- **On-device speech recognition**: Lower latency than cloud-based solutions

## Testing on Your Phone

### Option 1: EAS Build (Recommended)

This builds a native app you can install directly on your phone.

**Prerequisites:**
- Node.js 18+
- An Expo account (free): https://expo.dev/signup

**Steps:**

```bash
# 1. Install dependencies
cd mobile
npm install

# 2. Install EAS CLI
npm install -g eas-cli

# 3. Login to Expo
eas login

# 4. Configure the project (first time only)
eas build:configure

# 5. Build for your platform

# For Android (generates APK you can install):
eas build -p android --profile preview

# For iOS (requires Apple Developer account for device, or use simulator):
eas build -p ios --profile preview
```

After the build completes (~10-15 minutes), you'll get a download link.
- **Android**: Download the APK and install it (enable "Install from unknown sources")
- **iOS**: Requires TestFlight or an Apple Developer account

### Option 2: Development Build with Expo Dev Client

For faster iteration during development:

```bash
# Build a development client
eas build --profile development --platform android
# or
eas build --profile development --platform ios

# After installing the dev client, start the dev server:
npx expo start --dev-client
```

### Option 3: Run on Simulator/Emulator

```bash
# iOS Simulator (Mac only)
npx expo run:ios

# Android Emulator
npx expo run:android
```

## Project Structure

```
mobile/
├── app/                    # Expo Router screens
│   ├── _layout.tsx         # Root layout
│   └── index.tsx           # Main recitation screen
├── src/
│   └── core/
│       └── comparator.ts   # Word comparison logic
├── app.json                # Expo configuration
├── eas.json                # EAS Build configuration
└── package.json
```

## Why Native vs Web?

| Factor | Native (This App) | Web |
|--------|------------------|-----|
| Speech Recognition | On-device | Cloud (higher latency) |
| Haptic Feedback | Native vibration | None |
| Latency | 50-150ms | 200-500ms |

## Permissions Required

- **Microphone**: To hear you recite
- **Speech Recognition**: To convert speech to text

## Troubleshooting

### "Speech recognition not available"
- Make sure you've granted microphone permissions
- On iOS, speech recognition requires iOS 10+
- On Android, requires Google app installed

### Build fails
- Run `eas build:configure` to set up the project
- Make sure you're logged in: `eas whoami`
- Check the Expo dashboard for build logs: https://expo.dev

### High latency
- Make sure you're using on-device recognition (not cloud)
- Close other apps that might be using the microphone
- Try in a quieter environment

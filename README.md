# Backwords

An ad-free reverse-audio app for iOS and Android. Record up to 30 seconds, hear
it backwards, tweak speed and pitch, and share it. Challenge mode has you
imitate the reversed sound and then flips your imitation back to compare.

No ad SDKs and no analytics.

## Run it

Requires Flutter 3.47+ (Dart 3.13+).

```bash
flutter pub get
flutter run                 # on a booted iOS simulator, Android emulator or device
```

```bash
flutter analyze
flutter test
```

Notes:

- **Android**: needs a JDK 17 and Android SDK platform 37 (`compileSdk = 37` is
  required by `permission_handler_android`). minSdk is 23 (required by `record`). `RECORD_AUDIO` is declared in
  `android/app/src/main/AndroidManifest.xml`.
- **iOS**: `NSMicrophoneUsageDescription` is set in `ios/Runner/Info.plist`. The
  project uses Swift Package Manager, so `permission_handler` enables its
  microphone code from that key and no Podfile macro is needed.
- **iOS Simulator microphone**: the simulator uses the Mac's microphone. If
  recording never starts, check System Settings > Privacy & Security >
  Microphone for Simulator/Xcode, or test on a real device.

## How it works

1. `record` captures 16-bit PCM WAV (44.1 kHz mono) into a scratch directory.
2. `core/audio/wav_codec.dart` (pure Dart) parses the WAV chunks, reads the PCM
   as `Int16List`, reverses it **by frame** so stereo channels don't swap, and
   writes a canonical 44-byte-header WAV.
3. `core/audio/audio_reverser.dart` runs that in `Isolate.run`, so the UI never
   stutters, and also computes waveform peaks.
4. `just_audio` plays either file; `share_plus` shares the reversed WAV.

Temp files live in `<temp>/backwords/`. Each screen deletes the clips it owns
when it closes, and everything left over is purged at launch.

## Structure

```
lib/
  main.dart, app.dart
  core/
    audio/      wav_codec (pure), audio_reverser (isolate), recorder_service,
                temp_files, audio_clip
    theme/      dark-first theme
    widgets/    record button, waveforms
  record/       home screen, recorder controller + pad (30 s cap, live waveform)
  playback/     player panel, controller, share
  challenge/    4-step flow
test/core/audio/wav_codec_test.dart
```

State management is Riverpod (`flutter_riverpod` 3, `Notifier`s).

## Known limitations

- **Pitch on iOS is rendered, not live.** just_audio's `setPitch` is Android-only,
  so on iOS a pitch-shifted copy of the clip is rendered natively
  (`ios/Runner/PitchShifter.swift`, `AVAudioUnitTimePitch`) about a quarter
  second after the slider settles, and playback briefly pauses while it loads.
- **WAV only.** Export is WAV for v1. See the `TODO(m4a-export)` in
  `lib/playback/share_clip.dart` for the planned platform-channel m4a export.
- Portrait only.

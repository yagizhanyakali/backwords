import AVFoundation
import Flutter

/// Renders a pitch-shifted copy of a WAV file offline with AVAudioUnitTimePitch.
///
/// just_audio cannot change pitch on iOS, so Dart asks for a shifted file and
/// plays that instead. Rate stays 1.0, so the duration is unchanged.
enum PitchShifter {
  static let channelName = "com.backwords/pitch"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "shift",
            let args = call.arguments as? [String: Any],
            let input = args["input"] as? String,
            let output = args["output"] as? String,
            let pitch = args["pitch"] as? Double, pitch > 0
      else {
        result(FlutterError(code: "pitch", message: "Bad arguments.", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try shift(input: input, output: output, pitch: pitch)
          DispatchQueue.main.async { result(nil) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "pitch", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  /// [pitch] is a frequency multiplier (2.0 = one octave up).
  static func shift(input: String, output: String, pitch: Double) throws {
    let inFile = try AVAudioFile(forReading: URL(fileURLWithPath: input))
    let format = inFile.processingFormat

    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let timePitch = AVAudioUnitTimePitch()
    timePitch.pitch = Float(1200 * log2(pitch)) // cents
    timePitch.rate = 1

    engine.attach(player)
    engine.attach(timePitch)
    engine.connect(player, to: timePitch, format: format)
    engine.connect(timePitch, to: engine.outputNode, format: format)
    try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)

    player.scheduleFile(inFile, at: nil)
    try engine.start()
    player.play()

    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: format.sampleRate,
      AVNumberOfChannelsKey: format.channelCount,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
    ]
    let outFile = try AVAudioFile(forWriting: URL(fileURLWithPath: output), settings: settings)
    guard let buffer = AVAudioPCMBuffer(
      pcmFormat: engine.manualRenderingFormat,
      frameCapacity: engine.manualRenderingMaximumFrameCount
    ) else {
      throw NSError(domain: "pitch", code: 1, userInfo: [NSLocalizedDescriptionKey: "No render buffer."])
    }

    while engine.manualRenderingSampleTime < inFile.length {
      let remaining = inFile.length - engine.manualRenderingSampleTime
      let frames = AVAudioFrameCount(min(Int64(buffer.frameCapacity), remaining))
      switch try engine.renderOffline(frames, to: buffer) {
      case .success:
        try outFile.write(from: buffer)
      case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
        continue
      case .error:
        throw NSError(domain: "pitch", code: 2, userInfo: [NSLocalizedDescriptionKey: "Render failed."])
      @unknown default:
        throw NSError(domain: "pitch", code: 3, userInfo: [NSLocalizedDescriptionKey: "Render failed."])
      }
    }

    player.stop()
    engine.stop()
  }
}

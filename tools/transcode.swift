import AVFoundation; import Foundation
// Web copy of a film: transcode <source> <output.mp4> <video bits per second>. 3400000 gives about 13 MB for 30 s.
// Build with swiftc -O. Output is 1920x824, H.264, with AAC audio.
let a = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
let out = URL(fileURLWithPath: CommandLine.arguments[2]); try? FileManager.default.removeItem(at: out)
let W = 1920, H = 824, bitrate = Int(CommandLine.arguments[3])!
let vt = a.tracks(withMediaType: .video)[0]; let at = a.tracks(withMediaType: .audio).first
let r = try! AVAssetReader(asset: a); let w = try! AVAssetWriter(outputURL: out, fileType: .mp4); w.shouldOptimizeForNetworkUse = true
let vo = AVAssetReaderTrackOutput(track: vt, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]); r.add(vo)
let vi = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H, AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel, AVVideoMaxKeyFrameIntervalKey: 60]])
vi.expectsMediaDataInRealTime = false; w.add(vi)
var ao: AVAssetReaderTrackOutput?; var ai: AVAssetWriterInput?
if let at { let o = AVAssetReaderTrackOutput(track: at, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM]); r.add(o); ao = o
  let i = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 2, AVSampleRateKey: 44100, AVEncoderBitRateKey: 128000]); i.expectsMediaDataInRealTime = false; w.add(i); ai = i }
r.startReading(); w.startWriting(); w.startSession(atSourceTime: .zero)
let group = DispatchGroup()
func pump(_ o: AVAssetReaderTrackOutput, _ i: AVAssetWriterInput, _ q: String) { group.enter(); i.requestMediaDataWhenReady(on: DispatchQueue(label: q)) {
  while i.isReadyForMoreMediaData { if let s = o.copyNextSampleBuffer() { i.append(s) } else { i.markAsFinished(); group.leave(); return } } } }
pump(vo, vi, "v"); if let ao, let ai { pump(ao, ai, "a") }
group.wait()
let done = DispatchSemaphore(value: 0); w.finishWriting { done.signal() }; done.wait()
print("status", w.status.rawValue, w.error?.localizedDescription ?? "", r.error?.localizedDescription ?? "")

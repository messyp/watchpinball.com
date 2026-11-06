import AVFoundation
import CoreVideo
import ImageIO
import SwiftUI

// Gameplay clips for the site, rendered offline from the real game engine.
// Copy into the game repo's tools/headless, add it to the swiftc line in build.sh, and add this
// near the top of main.swift:
//   if let dir = ProcessInfo.processInfo.environment["CLIPS"] { MainActor.assumeIsolated { runClips(dir: dir) }; exit(0) }
// Then: CLIPS=dir RUNSECS=150 CLIPSECS=9 CLOCK=10:09:50 ./pinsim x 0 -autoplay
// The bot plays each table, the busiest stretch of real play is picked, and it's written as a
// silent H.264 loop whose last frames dissolve into its first, with a poster frame.
@MainActor func runClips(dir: String) {
    let makers: [(String, () -> Table)] = [("cosmic", Tables.cosmic), ("clockwork", Tables.clockwork), ("sugar", Tables.sugar), ("haunted", Tables.haunted), ("treasure", Tables.treasure)]
    let env = ProcessInfo.processInfo.environment
    let only = env["ONLY"]
    let fps = 30, seconds = Int(env["CLIPSECS"] ?? "9") ?? 9, runSeconds = Int(env["RUNSECS"] ?? "100") ?? 100
    let size = CGSize(width: 211, height: 257)
    for (name, make) in makers where only == nil || only == name {
        let sim = PinballSim(table: make())
        sim.adoptSkin(TableSkin(table: make()))
        var date = Date()
        var frames: [Data] = []
        var interest: [Double] = []
        var last = sim.score
        for _ in 0..<(runSeconds * fps) {
            autoreleasepool {
                date += 1.0 / 60; sim.step(to: date, in: size)
                date += 1.0 / 60; sim.step(to: date, in: size)
                let view = Canvas(rendersAsynchronously: false) { ctx, s in sim.draw(in: &ctx, size: s) }
                    .frame(width: size.width, height: size.height)
                    .environment(\.displayScale, 2)
                let r = ImageRenderer(content: view)
                r.scale = 2
                guard let cg = r.cgImage else { return }
                let d = NSMutableData()
                let dest = CGImageDestinationCreateWithData(d, "public.jpeg" as CFString, 1, nil)!
                CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
                CGImageDestinationFinalize(dest)
                frames.append(d as Data)
                var v = -40.0
                if case .play = sim.phase, !sim.balls.isEmpty, sim.balls.contains(where: { !$0.inPlunger }) {
                    v = 1 + Double(max(0, sim.balls.count - 1)) * 2.5
                    if sim.score != last { v += 3 }
                    if sim.message != nil { v += 1 }
                }
                last = sim.score
                interest.append(v)
            }
        }
        let w = seconds * fps
        var sum = interest[0..<w].reduce(0, +), best = sum, at = 0
        for i in 1..<(interest.count - w) {
            sum += interest[i + w - 1] - interest[i - 1]
            if sum > best { best = sum; at = i }
        }
        print("\(name): \(frames.count) frames, window at \(Double(at) / Double(fps))s, interest \(Int(best)) of \(w)")
        write(frames: Array(frames[at..<(at + w)]), fps: fps, name: name, dir: dir)
    }
}

private func cgImage(_ d: Data) -> CGImage {
    CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(d as CFData, nil)!, 0, nil)!
}

private func write(frames: [Data], fps: Int, name: String, dir: String) {
    let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).mp4")
    try? FileManager.default.removeItem(at: url)
    let writer = try! AVAssetWriter(outputURL: url, fileType: .mp4)
    writer.shouldOptimizeForNetworkUse = true
    let first = cgImage(frames[0])
    let w = first.width, h = first.height
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
        AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel, AVVideoExpectedSourceFrameRateKey: fps],
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
    ])
    writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
    let fade = fps / 3
    // A seamless loop: the last frames dissolve into the opening ones, which are then skipped.
    for i in fade..<frames.count {
        let f = frames[i]
        autoreleasepool {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
            CVPixelBufferLockBaseAddress(pb!, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb!),
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
            ctx.draw(cgImage(f), in: CGRect(x: 0, y: 0, width: w, height: h))
            let into = i - (frames.count - fade)
            if into >= 0 {
                ctx.setAlpha(CGFloat(into + 1) / CGFloat(fade))
                ctx.draw(cgImage(frames[into]), in: CGRect(x: 0, y: 0, width: w, height: h))
                ctx.setAlpha(1)
            }
            CVPixelBufferUnlockBaseAddress(pb!, [])
            adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(i - fade), timescale: CMTimeScale(fps)))
        }
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    try? frames[frames.count / 2].write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).jpg"))
    print("wrote \(name).mp4, status \(writer.status.rawValue) \(writer.error?.localizedDescription ?? "")")
}

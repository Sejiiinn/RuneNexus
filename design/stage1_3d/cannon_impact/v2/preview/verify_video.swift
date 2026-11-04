import Foundation
import AVFoundation
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let asset = AVURLAsset(url: root.appendingPathComponent("effect-preview.mp4"))
let semaphore = DispatchSemaphore(value: 0)
Task {
    do {
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else { fatalError("Video track missing") }
        let size = try await track.load(.naturalSize)
        let fps = try await track.load(.nominalFrameRate)
        print("duration=\(CMTimeGetSeconds(duration)) size=\(size) fps=\(fps)")
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        for (i, seconds) in [0.85, 2.95, 5.1].enumerated() {
            let frame = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
            let bitmap = NSBitmapImageRep(cgImage: frame.image)
            let data = bitmap.representation(using: .png, properties: [:])!
            try data.write(to: root.appendingPathComponent("video-check-\(i).png"))
        }
        print("PASS: H264 video decoded at three timestamps")
    } catch {
        print("FAIL: \(error)")
        exit(1)
    }
    semaphore.signal()
}
semaphore.wait()

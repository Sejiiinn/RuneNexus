import Foundation
import AVFoundation
import AppKit

struct Frame: Decodable { let file: String; let time: Double }
let root = URL(fileURLWithPath: CommandLine.arguments[1])
// CDP 콜백 수신 순서가 역전되어도 실제 프레임 시각을 보존.
let frames = try JSONDecoder().decode([Frame].self, from: Data(contentsOf: root.appendingPathComponent("frames.json"))).sorted { $0.time < $1.time }
let output = root.appendingPathComponent("shell-two-views.mp4")
if FileManager.default.fileExists(atPath: output.path) { try FileManager.default.removeItem(at: output) }
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let width = 800, height = 1000
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height, AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000]])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height, kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
writer.add(input)
writer.startWriting(); writer.startSession(atSourceTime: .zero)
for (index, frame) in frames.enumerated() {
 autoreleasepool {
 while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
 var pixel: CVPixelBuffer?
 CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, adaptor.pixelBufferPool!, &pixel)
 let buffer = pixel!
 CVPixelBufferLockBaseAddress(buffer, [])
 let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
 let source = CGImageSourceCreateWithURL(root.appendingPathComponent(frame.file) as CFURL, nil)!
 context.draw(CGImageSourceCreateImageAtIndex(source, 0, nil)!, in: CGRect(x: 0, y: 0, width: width, height: height))
 CVPixelBufferUnlockBaseAddress(buffer, [])
 guard adaptor.append(buffer, withPresentationTime: CMTime(seconds: frame.time, preferredTimescale: 60000)) else { fatalError("비디오 프레임 \(index) 기록 실패: \(String(describing: writer.error))") }
 }
}
input.markAsFinished()
let semaphore = DispatchSemaphore(value: 0)
writer.finishWriting { semaphore.signal() }; semaphore.wait()
guard writer.status == .completed else { fatalError("비디오 생성 실패: \(String(describing: writer.error))") }
print(output.path)

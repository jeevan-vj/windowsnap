import CoreImage
import CoreMedia
import CoreMediaIO
import CoreVideo
import Foundation
import IOSurface

private let defaultAppGroupIdentifier = "group.com.jeevanwijerathna.windowsnap"
private let appGroupIdentifier = Bundle.main.object(
    forInfoDictionaryKey: "WindowSnapCameraAppGroupIdentifier"
) as? String ?? defaultAppGroupIdentifier
private let deviceID = UUID(uuidString: "8E4497EC-78D8-4D04-9D6D-6B7FB8D43ED5")!
private let streamID = UUID(uuidString: "2947FE84-7E31-47BF-AB16-C81D0B9737F4")!

final class WindowSnapVirtualCameraProviderSource: NSObject, CMIOExtensionProviderSource {
    weak var provider: CMIOExtensionProvider? {
        didSet { addDeviceIfNeeded() }
    }

    private let deviceSource = WindowSnapVirtualCameraDeviceSource()
    private lazy var device = CMIOExtensionDevice(
        localizedName: "WindowSnap Virtual Camera",
        deviceID: deviceID,
        legacyDeviceID: nil,
        source: deviceSource
    )

    var availableProperties: Set<CMIOExtensionProperty> {
        [.providerName, .providerManufacturer]
    }

    func connect(to client: CMIOExtensionClient) throws {}
    func disconnect(from client: CMIOExtensionClient) {}

    func providerProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionProviderProperties {
        let providerProperties = CMIOExtensionProviderProperties(dictionary: [:])
        if properties.contains(.providerName) {
            providerProperties.name = "WindowSnap"
        }
        if properties.contains(.providerManufacturer) {
            providerProperties.manufacturer = "WindowSnap"
        }
        return providerProperties
    }

    func setProviderProperties(_ providerProperties: CMIOExtensionProviderProperties) throws {}

    private func addDeviceIfNeeded() {
        guard let provider, provider.devices.isEmpty else { return }
        do {
            try device.addStream(deviceSource.stream)
            try provider.addDevice(device)
        } catch {
            NSLog("WindowSnap virtual camera failed to add device: \(error)")
        }
    }
}

final class WindowSnapVirtualCameraDeviceSource: NSObject, CMIOExtensionDeviceSource {
    let streamSource = WindowSnapVirtualCameraStreamSource()
    lazy var stream = CMIOExtensionStream(
        localizedName: "WindowSnap Region Stream",
        streamID: streamID,
        direction: .source,
        clockType: .hostTime,
        source: streamSource
    )

    override init() {
        super.init()
        streamSource.stream = stream
    }

    var availableProperties: Set<CMIOExtensionProperty> {
        [.deviceModel, .deviceTransportType]
    }

    func deviceProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionDeviceProperties {
        let deviceProperties = CMIOExtensionDeviceProperties(dictionary: [:])
        if properties.contains(.deviceModel) {
            deviceProperties.model = "WindowSnap Virtual Camera"
        }
        if properties.contains(.deviceTransportType) {
            deviceProperties.transportType = 0
        }
        return deviceProperties
    }

    func setDeviceProperties(_ deviceProperties: CMIOExtensionDeviceProperties) throws {}
}

final class WindowSnapVirtualCameraStreamSource: NSObject, CMIOExtensionStreamSource {
    weak var stream: CMIOExtensionStream?

    private let frameReader = SharedRegionFrameReader()
    private let frameDuration = CMTime(value: 1, timescale: 30)
    private let stateLock = NSLock()
    private var timer: DispatchSourceTimer?
    private var activeFormatIndex = 0

    lazy var formats: [CMIOExtensionStreamFormat] = [
        Self.makeFormat(width: 1280, height: 720, frameDuration: frameDuration),
        Self.makeFormat(width: 1920, height: 1080, frameDuration: frameDuration)
    ].compactMap { $0 }

    var availableProperties: Set<CMIOExtensionProperty> {
        [.streamActiveFormatIndex, .streamFrameDuration, .streamMaxFrameDuration]
    }

    func streamProperties(forProperties properties: Set<CMIOExtensionProperty>) throws -> CMIOExtensionStreamProperties {
        let streamProperties = CMIOExtensionStreamProperties(dictionary: [:])
        if properties.contains(.streamActiveFormatIndex) {
            stateLock.lock()
            streamProperties.activeFormatIndex = activeFormatIndex
            stateLock.unlock()
        }
        if properties.contains(.streamFrameDuration) {
            streamProperties.frameDuration = frameDuration
        }
        if properties.contains(.streamMaxFrameDuration) {
            streamProperties.maxFrameDuration = frameDuration
        }
        return streamProperties
    }

    func setStreamProperties(_ streamProperties: CMIOExtensionStreamProperties) throws {
        if let requestedIndex = streamProperties.activeFormatIndex,
           formats.indices.contains(requestedIndex) {
            stateLock.lock()
            activeFormatIndex = requestedIndex
            stateLock.unlock()
        }
    }

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool { true }

    func startStream() throws {
        stateLock.lock()
        guard timer == nil else {
            stateLock.unlock()
            return
        }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "com.windowsnap.virtual-camera.stream"))
        timer.schedule(deadline: .now(), repeating: .milliseconds(33), leeway: .milliseconds(4))
        timer.setEventHandler { [weak self] in
            self?.sendNextFrame()
        }
        self.timer = timer
        stateLock.unlock()
        timer.resume()
    }

    func stopStream() throws {
        stateLock.lock()
        let timerToCancel = timer
        self.timer = nil
        stateLock.unlock()
        timerToCancel?.cancel()
    }

    private func sendNextFrame() {
        guard let stream else { return }
        let size = activeOutputSize
        guard let pixelBuffer = frameReader.copyLatestFrame(outputWidth: size.width, outputHeight: size.height),
              let sampleBuffer = Self.makeSampleBuffer(pixelBuffer: pixelBuffer, frameDuration: frameDuration) else {
            return
        }

        stream.send(
            sampleBuffer,
            discontinuity: [],
            hostTimeInNanoseconds: DispatchTime.now().uptimeNanoseconds
        )
    }

    private var activeOutputSize: (width: Int, height: Int) {
        stateLock.lock()
        let index = activeFormatIndex
        stateLock.unlock()
        guard formats.indices.contains(index) else { return (1280, 720) }
        let description = formats[index].formatDescription
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        return (Int(dimensions.width), Int(dimensions.height))
    }

    private static func makeFormat(width: Int, height: Int, frameDuration: CMTime) -> CMIOExtensionStreamFormat? {
        var description: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCVPixelFormatType_32BGRA,
            width: Int32(width),
            height: Int32(height),
            extensions: nil,
            formatDescriptionOut: &description
        )
        guard status == noErr, let description else { return nil }

        return CMIOExtensionStreamFormat(
            formatDescription: description,
            maxFrameDuration: frameDuration,
            minFrameDuration: frameDuration,
            validFrameDurations: [frameDuration]
        )
    }

    private static func makeSampleBuffer(pixelBuffer: CVPixelBuffer, frameDuration: CMTime) -> CMSampleBuffer? {
        var formatDescription: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        ) == noErr, let formatDescription else {
            return nil
        }

        var timing = CMSampleTimingInfo(
            duration: frameDuration,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr else { return nil }
        return sampleBuffer
    }
}

private final class SharedRegionFrameReader {
    private let metadataURL: URL
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var pools: [String: CVPixelBufferPool] = [:]
    private var cachedSequence: UInt64 = 0
    private var cachedOutputs: [String: CVPixelBuffer] = [:]
    private var placeholders: [String: CVPixelBuffer] = [:]

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("RegionFrameHub", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("WindowSnap/RegionFrameHub", isDirectory: true)
        metadataURL = baseURL.appendingPathComponent("metadata.json")
    }

    func copyLatestFrame(outputWidth: Int, outputHeight: Int) -> CVPixelBuffer? {
        guard let metadataData = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(SharedRegionFrameMetadata.self, from: metadataData),
              metadata.pixelFormat == kCVPixelFormatType_32BGRA,
              metadata.width > 0,
              metadata.height > 0,
              metadata.sequence >= cachedSequence,
              Date().timeIntervalSince(metadata.updatedAt) < 2.0,
              let surface = IOSurfaceLookup(metadata.surfaceID) else {
            return makePlaceholder(width: outputWidth, height: outputHeight)
        }

        let outputKey = "\(outputWidth)x\(outputHeight)"
        if metadata.sequence == cachedSequence, let cached = cachedOutputs[outputKey] {
            return cached
        }

        var unmanagedSourceBuffer: Unmanaged<CVPixelBuffer>?
        guard CVPixelBufferCreateWithIOSurface(
            kCFAllocatorDefault,
            surface,
            nil,
            &unmanagedSourceBuffer
        ) == kCVReturnSuccess, let unmanagedSourceBuffer else {
            return makePlaceholder(width: outputWidth, height: outputHeight)
        }
        let sourceBuffer = unmanagedSourceBuffer.takeRetainedValue()
        guard
              CVPixelBufferGetWidth(sourceBuffer) == metadata.width,
              CVPixelBufferGetHeight(sourceBuffer) == metadata.height else {
            return makePlaceholder(width: outputWidth, height: outputHeight)
        }

        if metadata.sequence > cachedSequence {
            cachedSequence = metadata.sequence
            cachedOutputs.removeAll(keepingCapacity: true)
        }

        let output = makePixelBuffer(
            sourceBuffer: sourceBuffer,
            outputWidth: outputWidth,
            outputHeight: outputHeight
        )
        if let output {
            cachedOutputs[outputKey] = output
        }
        return output
    }

    private func makePlaceholder(width: Int, height: Int) -> CVPixelBuffer? {
        let key = "\(width)x\(height)"
        if let existing = placeholders[key] { return existing }
        guard let pixelBuffer = makeEmptyPixelBuffer(width: width, height: height) else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(base, 28, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        placeholders[key] = pixelBuffer
        return pixelBuffer
    }

    private func makePixelBuffer(
        sourceBuffer: CVPixelBuffer,
        outputWidth: Int,
        outputHeight: Int
    ) -> CVPixelBuffer? {
        if CVPixelBufferGetWidth(sourceBuffer) == outputWidth,
           CVPixelBufferGetHeight(sourceBuffer) == outputHeight {
            return sourceBuffer
        }

        guard let pixelBuffer = makeEmptyPixelBuffer(width: outputWidth, height: outputHeight) else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let destination = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(destination, 0, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        let sourceWidth = CVPixelBufferGetWidth(sourceBuffer)
        let sourceHeight = CVPixelBufferGetHeight(sourceBuffer)
        let scale = min(Double(outputWidth) / Double(sourceWidth), Double(outputHeight) / Double(sourceHeight))
        let scaledWidth = Double(sourceWidth) * scale
        let scaledHeight = Double(sourceHeight) * scale
        let xOffset = (Double(outputWidth) - scaledWidth) / 2
        let yOffset = (Double(outputHeight) - scaledHeight) / 2
        let image = CIImage(cvPixelBuffer: sourceBuffer)
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: xOffset, y: yOffset))
        context.render(
            image,
            to: pixelBuffer,
            bounds: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return pixelBuffer
    }

    private func makeEmptyPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let key = "\(width)x\(height)"
        let pool: CVPixelBufferPool
        if let existing = pools[key] {
            pool = existing
        } else {
            var createdPool: CVPixelBufferPool?
            let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey: 3] as CFDictionary
            let pixelAttributes = [
                kCVPixelBufferWidthKey: width,
                kCVPixelBufferHeightKey: height,
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ] as CFDictionary
            guard CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                poolAttributes,
                pixelAttributes,
                &createdPool
            ) == kCVReturnSuccess, let createdPool else {
                return nil
            }
            pools[key] = createdPool
            pool = createdPool
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pool,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess else { return nil }
        return pixelBuffer
    }
}

private struct SharedRegionFrameMetadata: Codable {
    let width: Int
    let height: Int
    let frameRate: Int
    let pixelFormat: UInt32
    let presentationTimeSeconds: Double
    let updatedAt: Date
    let isPlaceholder: Bool
    let surfaceID: UInt32
    let sequence: UInt64
}

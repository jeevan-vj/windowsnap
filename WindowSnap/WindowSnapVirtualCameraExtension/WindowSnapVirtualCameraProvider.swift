import CoreMedia
import CoreMediaIO
import CoreVideo
import Foundation

private let appGroupIdentifier = "group.com.jeevanwijerathna.windowsnap"
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
            streamProperties.activeFormatIndex = activeFormatIndex
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
            activeFormatIndex = requestedIndex
        }
    }

    func authorizedToStartStream(for client: CMIOExtensionClient) -> Bool { true }

    func startStream() throws {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "com.windowsnap.virtual-camera.stream"))
        timer.schedule(deadline: .now(), repeating: .milliseconds(33), leeway: .milliseconds(4))
        timer.setEventHandler { [weak self] in
            self?.sendNextFrame()
        }
        timer.resume()
        self.timer = timer
    }

    func stopStream() throws {
        timer?.cancel()
        timer = nil
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
        guard formats.indices.contains(activeFormatIndex) else { return (1280, 720) }
        let description = formats[activeFormatIndex].formatDescription
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
    private let frameURL: URL

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("RegionFrameHub", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("WindowSnap/RegionFrameHub", isDirectory: true)
        metadataURL = baseURL.appendingPathComponent("metadata.json")
        frameURL = baseURL.appendingPathComponent("latest.bgra")
    }

    func copyLatestFrame(outputWidth: Int, outputHeight: Int) -> CVPixelBuffer? {
        guard let metadataData = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(SharedRegionFrameMetadata.self, from: metadataData),
              let frameData = try? Data(contentsOf: frameURL),
              metadata.pixelFormat == kCVPixelFormatType_32BGRA else {
            return makePlaceholder(width: outputWidth, height: outputHeight)
        }

        return makePixelBuffer(
            sourceData: frameData,
            sourceWidth: metadata.width,
            sourceHeight: metadata.height,
            outputWidth: outputWidth,
            outputHeight: outputHeight
        )
    }

    private func makePlaceholder(width: Int, height: Int) -> CVPixelBuffer? {
        guard let pixelBuffer = makeEmptyPixelBuffer(width: width, height: height) else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(base, 28, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }

    private func makePixelBuffer(
        sourceData: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        outputWidth: Int,
        outputHeight: Int
    ) -> CVPixelBuffer? {
        guard let pixelBuffer = makeEmptyPixelBuffer(width: outputWidth, height: outputHeight) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let destination = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        memset(destination, 0, CVPixelBufferGetDataSize(pixelBuffer))

        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let sourceBytesPerRow = sourceWidth * 4
        let scale = min(Double(outputWidth) / Double(sourceWidth), Double(outputHeight) / Double(sourceHeight))
        let scaledWidth = max(1, Int(Double(sourceWidth) * scale))
        let scaledHeight = max(1, Int(Double(sourceHeight) * scale))
        let xOffset = (outputWidth - scaledWidth) / 2
        let yOffset = (outputHeight - scaledHeight) / 2

        sourceData.withUnsafeBytes { sourceRawBuffer in
            guard let sourceBase = sourceRawBuffer.baseAddress else { return }
            for y in 0..<scaledHeight {
                let sourceY = min(sourceHeight - 1, Int(Double(y) / scale))
                let destinationRow = destination.advanced(by: (y + yOffset) * outputBytesPerRow + xOffset * 4)
                for x in 0..<scaledWidth {
                    let sourceX = min(sourceWidth - 1, Int(Double(x) / scale))
                    let sourcePixel = sourceBase.advanced(by: sourceY * sourceBytesPerRow + sourceX * 4)
                    memcpy(destinationRow.advanced(by: x * 4), sourcePixel, 4)
                }
            }
        }

        return pixelBuffer
    }

    private func makeEmptyPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes,
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
}

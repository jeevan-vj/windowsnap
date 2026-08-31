import CoreMedia
import CoreVideo

protocol RegionFrameSink: AnyObject {
    func regionCaptureDidOutputFrame(_ frame: CVPixelBuffer, presentationTime: CMTime)
}

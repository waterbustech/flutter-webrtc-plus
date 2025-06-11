//
//  RTCVideoPipe.swift
//  flutter_webrtc
//
//  Created by lambiengcode on 06/03/2024.
//

import Foundation
import WebRTC

@objc public class RTCVideoPipe: NSObject, RTCVideoCapturerDelegate {
    var beautyFilter: RTCBeautyFilter?
    var videoSource: RTCVideoSource?
    var virtualBackground: RTCVirtualBackground?
    var backgroundImage: CIImage?
    var lastFrameTimestamp: Int64 = 0
    let targetFrameDurationNs: Int64 = Int64(1_000_000_000 / 15) // 15fps
    weak var rtcVideoCapturer: RTCVideoCapturer?
    
    @objc public init(videoSource: RTCVideoSource, virtualBackground: RTCVirtualBackground) {
        super.init()
        self.videoSource = videoSource
        self.virtualBackground = virtualBackground
        self.beautyFilter = RTCBeautyFilter()
    }
    
    deinit {
        self.beautyFilter?.releaseInstance()
        self.beautyFilter = nil
        self.videoSource = nil
        self.virtualBackground = nil
        self.backgroundImage = nil
        self.rtcVideoCapturer = nil
    }
    
    @objc public func setBackgroundImage(image: CIImage?) {
        self.backgroundImage = image
    }
    
    @objc public func capturer(_ capturer: RTCVideoCapturer, didCapture frame: RTCVideoFrame) {
        self.rtcVideoCapturer = capturer
        
        // Frame rate limiting
        let timestampNew = Int64(DispatchTime.now().uptimeNanoseconds)
        let frameDuration = timestampNew - lastFrameTimestamp
        
        if frameDuration < targetFrameDurationNs {
            return
        }
        
        lastFrameTimestamp = timestampNew
        
        guard let pixelBuffer = self.convertRTCVideoFrameToPixelBuffer(frame) else {
            print("Failed to convert RTCVideoFrame to CVPixelBuffer")
            return
        }
        
        // Process the frame with beauty filter
        guard let processedPixelBufferUnmanaged = self.beautyFilter?.processVideoFrame(pixelBuffer) else {
            print("Failed to process video frame with beauty filter")
            // If beauty filter fails, use original buffer
            self.handleProcessedFrame(pixelBuffer, capturer: capturer)
            return
        }
        
        // Take ownership of the returned pixel buffer
        let processedPixelBuffer = processedPixelBufferUnmanaged.takeRetainedValue()
        
        // Handle the processed frame
        self.handleProcessedFrame(processedPixelBuffer, capturer: capturer)
        
        // No need to manually release - ARC handles this automatically
        // CVPixelBufferRelease(processedPixelBuffer) // Remove this line
    }
    
    private func handleProcessedFrame(_ pixelBuffer: CVPixelBuffer, capturer: RTCVideoCapturer) {
        if backgroundImage == nil {
            // No background image, send frame directly
            let timestampNs = DispatchTime.now().uptimeNanoseconds
            
            guard let frame: RTCVideoFrame = pixelBuffer.convertPixelBufferToRTCVideoFrame(rotation: RTCVideoRotation._0, timeStampNs: Int64(timestampNs)) else {
                return
            }
            
            self.videoSource?.capturer(capturer, didCapture: frame)
            return
        }
        
        // Process with virtual background
        virtualBackground?.processForegroundMask(from: pixelBuffer, backgroundImage: backgroundImage!) { bufferProcessed, error in
            if let error = error {
                // Handle error
                print("Error processing foreground mask: \(error.localizedDescription)")
            } else if let bufferProcessed = bufferProcessed {
                let timestampNs = DispatchTime.now().uptimeNanoseconds
                
                guard let frame: RTCVideoFrame = bufferProcessed.convertPixelBufferToRTCVideoFrame(rotation: RTCVideoRotation._0, timeStampNs: Int64(timestampNs)) else {
                    return
                }
                
                self.videoSource?.capturer(capturer, didCapture: frame)
            }
        }
    }
    
    @objc public func setThinFaceValue(value: CGFloat) {
        self.beautyFilter?.thinFaceValue = value
    }
    
    @objc public func setLipstickValue(value: CGFloat) {
        self.beautyFilter?.lipstickValue = value
    }
    
    @objc public func setBlusherValue(value: CGFloat) {
        self.beautyFilter?.blusherValue = value
    }
    
    @objc public func setBigEyeValue(value: CGFloat) {
        self.beautyFilter?.eyeValue = value
    }
    
    @objc public func setSmoothValue(value: CGFloat) {
        self.beautyFilter?.beautyValue = value
    }
    
    @objc public func setWhiteValue(value: CGFloat) {
        self.beautyFilter?.whithValue = value
    }
}

extension RTCVideoPipe {
    func convertRTCVideoFrameToPixelBuffer(_ rtcVideoFrame: RTCVideoFrame) -> CVPixelBuffer? {
        if let remotePixelBuffer = rtcVideoFrame.buffer as? RTCCVPixelBuffer {
            let pixelBuffer = remotePixelBuffer.pixelBuffer
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
#if os(iOS)
            let rotatedCIImage = ciImage.oriented(.right)
            let rotatedPixelBuffer = rotatedCIImage.convertCIImageToCVPixelBuffer()
            return rotatedPixelBuffer
#elseif os(macOS)
            return ciImage.convertCIImageToCVPixelBuffer()
#endif
        } else {
            print("Error: RTCVideoFrame buffer is not of type RTCCVPixelBuffer")
            return nil
        }
    }
}

extension CVPixelBuffer {
    func convertPixelBufferToRTCVideoFrame(rotation: RTCVideoRotation, timeStampNs: Int64) -> RTCVideoFrame? {
        let ciImage = CIImage(cvPixelBuffer: self)
        guard let formatedBuffer = ciImage.convertCIImageToCVPixelBuffer(pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) else { return nil }
        
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: formatedBuffer)
        
        let rtcVideoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: rotation, timeStampNs: timeStampNs)
        
        return rtcVideoFrame
    }
}

extension CIImage {
    func convertCIImageToCVPixelBuffer(pixelFormatType: OSType = kCVPixelFormatType_32BGRA) -> CVPixelBuffer? {
        // Create a CIContext with hardware acceleration
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false
        ]
        let ciContext = CIContext(options: options)

        // Define the width and height from the CIImage's extent
        let width = Int(self.extent.width)
        let height = Int(self.extent.height)

        // Define pixel buffer attributes
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormatType
        ]

        // Create a pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         pixelFormatType, // Use the parameter here as well
                                         pixelBufferAttributes as CFDictionary,
                                         &pixelBuffer)
        
        // Ensure pixelBuffer was created successfully
        guard status == kCVReturnSuccess, let finalPixelBuffer = pixelBuffer else {
            return nil
        }

        // Render the CIImage to the pixel buffer
        ciContext.render(self, to: finalPixelBuffer)

        return finalPixelBuffer
    }
}

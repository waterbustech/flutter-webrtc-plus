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
    var beautyFilterDelegate: BeautyFilterDelegate?
    var videoSource: RTCVideoSource?
    
    @objc public init(videoSource: RTCVideoSource) {
        self.beautyFilterDelegate = BeautyFilterDelegate(videoSource: videoSource)
        self.beautyFilter = RTCBeautyFilter.init(delegate: self.beautyFilterDelegate)
        self.videoSource = videoSource
        
        self.beautyFilter?.thinFaceValue = 0.02
        self.beautyFilter?.lipstickValue = 0.5
        self.beautyFilter?.blusherValue = 0.5
        self.beautyFilter?.eyeValue = 0.2
        
        super.init()
    }
    
    @objc public func setBackgroundImage(image: CIImage?) {
        self.beautyFilterDelegate?.setBackgroundImage(image: image)
    }
    
    @objc public func capturer(_ capturer: RTCVideoCapturer, didCapture frame: RTCVideoFrame) {
        self.beautyFilterDelegate?.setCapturer(capturer: capturer)
        self.beautyFilterDelegate?.setRotation(rotation: frame.rotation)
        
        guard let pixelBuffer = self.convertRTCVideoFrameToPixelBuffer(frame) else {
            print("Failed to convert RTCVideoFrame to CVPixelBuffer")
            return
        }

        
        self.beautyFilter?.processVideoFrame(pixelBuffer)
    }
}

extension RTCVideoPipe {
    func convertRTCVideoFrameToPixelBuffer(_ rtcVideoFrame: RTCVideoFrame) -> CVPixelBuffer? {
        if let remotePixelBuffer = rtcVideoFrame.buffer as? RTCCVPixelBuffer {
            let pixelBuffer = remotePixelBuffer.pixelBuffer
            // Now you have access to 'pixelBuffer' for further use
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            return ciImage.convertCIImageToCVPixelBuffer()
        } else {
            print("Error: RTCVideoFrame buffer is not of type RTCCVPixelBuffer")
            return nil
        }
    }
}

class BeautyFilterDelegate: NSObject, RTCBeautyFilterDelegate {
    var latestTimestampNs: Int64 = 0
    var frameCount: Int = 0
    var lastProcessedTimestamp: Int64 = 0
    var fpsInterval: Int64 = 1000000000 / 24 // 24 fps to ensure VNGen can proccess
    
    var videoSource: RTCVideoSource?
    var virtualBackground: RTCVirtualBackground?
    var backgroundImage: CIImage?
    var rotate: RTCVideoRotation = RTCVideoRotation._180
    var rtcVideoCapturer: RTCVideoCapturer?
    
    init(videoSource: RTCVideoSource? = nil) {
        self.videoSource = videoSource
        self.virtualBackground = RTCVirtualBackground()
    }
    
    func didReceive(_ pixelBuffer: CVPixelBuffer!, width: Int32, height: Int32, timestamp: Int64) {
        let timestampNs = DispatchTime.now().uptimeNanoseconds
        
        guard let frame: RTCVideoFrame = pixelBuffer.convertPixelBufferToRTCVideoFrame(rotation: rotate, timeStampNs: Int64(timestampNs)) else {
            return
        }
        
        guard let capturer = rtcVideoCapturer else {
            return
        }
        
        if backgroundImage == nil {
            self.videoSource?.capturer(capturer, didCapture: frame)
            return
        }
        
        virtualBackground?.processForegroundMask(from: frame, backgroundImage: backgroundImage!) { processedFrame, error in
            if let error = error {
                // Handle error
                print("Error processing foreground mask: \(error.localizedDescription)")
            } else if let processedFrame = processedFrame {
                let currentTimestamp = frame.timeStampNs
                
                // Calculate the time since the last processed frame
                let elapsedTimeSinceLastProcessedFrame = currentTimestamp - self.lastProcessedTimestamp
                
                if elapsedTimeSinceLastProcessedFrame < self.fpsInterval {
                    // Skip processing the frame if it's too soon
                    return
                }
                
                self.lastProcessedTimestamp = currentTimestamp
                
                if processedFrame.timeStampNs <= self.latestTimestampNs {
                    // Skip emitting frame if its timestamp is not newer than the latest one
                    return
                }
                
                self.latestTimestampNs = processedFrame.timeStampNs
                
                self.videoSource?.capturer(capturer, didCapture: processedFrame)
            }
        }
    }
    
    public func setBackgroundImage(image: CIImage?) {
        backgroundImage = image
    }
    
    public func setCapturer(capturer: RTCVideoCapturer) {
        rtcVideoCapturer = capturer
    }
    
    public func setRotation(rotation: RTCVideoRotation) {
        self.rotate = rotation
    }
}


extension CVPixelBuffer {
    func convertPixelBufferToRTCVideoFrame(rotation: RTCVideoRotation, timeStampNs: Int64) -> RTCVideoFrame? {
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: self)
        
        let rtcVideoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: rotation, timeStampNs: timeStampNs)
        
        return rtcVideoFrame
    }
    
    public func getPixelFormatName() -> String {
        let p = CVPixelBufferGetPixelFormatType(self)
        switch p {
        case kCVPixelFormatType_1Monochrome:                   return "kCVPixelFormatType_1Monochrome"
        case kCVPixelFormatType_2Indexed:                      return "kCVPixelFormatType_2Indexed"
        case kCVPixelFormatType_4Indexed:                      return "kCVPixelFormatType_4Indexed"
        case kCVPixelFormatType_8Indexed:                      return "kCVPixelFormatType_8Indexed"
        case kCVPixelFormatType_1IndexedGray_WhiteIsZero:      return "kCVPixelFormatType_1IndexedGray_WhiteIsZero"
        case kCVPixelFormatType_2IndexedGray_WhiteIsZero:      return "kCVPixelFormatType_2IndexedGray_WhiteIsZero"
        case kCVPixelFormatType_4IndexedGray_WhiteIsZero:      return "kCVPixelFormatType_4IndexedGray_WhiteIsZero"
        case kCVPixelFormatType_8IndexedGray_WhiteIsZero:      return "kCVPixelFormatType_8IndexedGray_WhiteIsZero"
        case kCVPixelFormatType_16BE555:                       return "kCVPixelFormatType_16BE555"
        case kCVPixelFormatType_16LE555:                       return "kCVPixelFormatType_16LE555"
        case kCVPixelFormatType_16LE5551:                      return "kCVPixelFormatType_16LE5551"
        case kCVPixelFormatType_16BE565:                       return "kCVPixelFormatType_16BE565"
        case kCVPixelFormatType_16LE565:                       return "kCVPixelFormatType_16LE565"
        case kCVPixelFormatType_24RGB:                         return "kCVPixelFormatType_24RGB"
        case kCVPixelFormatType_24BGR:                         return "kCVPixelFormatType_24BGR"
        case kCVPixelFormatType_32ARGB:                        return "kCVPixelFormatType_32ARGB"
        case kCVPixelFormatType_32BGRA:                        return "kCVPixelFormatType_32BGRA"
        case kCVPixelFormatType_32ABGR:                        return "kCVPixelFormatType_32ABGR"
        case kCVPixelFormatType_32RGBA:                        return "kCVPixelFormatType_32RGBA"
        case kCVPixelFormatType_64ARGB:                        return "kCVPixelFormatType_64ARGB"
        case kCVPixelFormatType_48RGB:                         return "kCVPixelFormatType_48RGB"
        case kCVPixelFormatType_32AlphaGray:                   return "kCVPixelFormatType_32AlphaGray"
        case kCVPixelFormatType_16Gray:                        return "kCVPixelFormatType_16Gray"
        case kCVPixelFormatType_30RGB:                         return "kCVPixelFormatType_30RGB"
        case kCVPixelFormatType_422YpCbCr8:                    return "kCVPixelFormatType_422YpCbCr8"
        case kCVPixelFormatType_4444YpCbCrA8:                  return "kCVPixelFormatType_4444YpCbCrA8"
        case kCVPixelFormatType_4444YpCbCrA8R:                 return "kCVPixelFormatType_4444YpCbCrA8R"
        case kCVPixelFormatType_4444AYpCbCr8:                  return "kCVPixelFormatType_4444AYpCbCr8"
        case kCVPixelFormatType_4444AYpCbCr16:                 return "kCVPixelFormatType_4444AYpCbCr16"
        case kCVPixelFormatType_444YpCbCr8:                    return "kCVPixelFormatType_444YpCbCr8"
        case kCVPixelFormatType_422YpCbCr16:                   return "kCVPixelFormatType_422YpCbCr16"
        case kCVPixelFormatType_422YpCbCr10:                   return "kCVPixelFormatType_422YpCbCr10"
        case kCVPixelFormatType_444YpCbCr10:                   return "kCVPixelFormatType_444YpCbCr10"
        case kCVPixelFormatType_420YpCbCr8Planar:              return "kCVPixelFormatType_420YpCbCr8Planar"
        case kCVPixelFormatType_420YpCbCr8PlanarFullRange:     return "kCVPixelFormatType_420YpCbCr8PlanarFullRange"
        case kCVPixelFormatType_422YpCbCr_4A_8BiPlanar:        return "kCVPixelFormatType_422YpCbCr_4A_8BiPlanar"
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:  return "kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange"
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:   return "kCVPixelFormatType_420YpCbCr8BiPlanarFullRange"
        case kCVPixelFormatType_422YpCbCr8_yuvs:               return "kCVPixelFormatType_422YpCbCr8_yuvs"
        case kCVPixelFormatType_422YpCbCr8FullRange:           return "kCVPixelFormatType_422YpCbCr8FullRange"
        case kCVPixelFormatType_OneComponent8:                 return "kCVPixelFormatType_OneComponent8"
        case kCVPixelFormatType_TwoComponent8:                 return "kCVPixelFormatType_TwoComponent8"
        case kCVPixelFormatType_30RGBLEPackedWideGamut:        return "kCVPixelFormatType_30RGBLEPackedWideGamut"
        case kCVPixelFormatType_OneComponent16Half:            return "kCVPixelFormatType_OneComponent16Half"
        case kCVPixelFormatType_OneComponent32Float:           return "kCVPixelFormatType_OneComponent32Float"
        case kCVPixelFormatType_TwoComponent16Half:            return "kCVPixelFormatType_TwoComponent16Half"
        case kCVPixelFormatType_TwoComponent32Float:           return "kCVPixelFormatType_TwoComponent32Float"
        case kCVPixelFormatType_64RGBAHalf:                    return "kCVPixelFormatType_64RGBAHalf"
        case kCVPixelFormatType_128RGBAFloat:                  return "kCVPixelFormatType_128RGBAFloat"
        case kCVPixelFormatType_14Bayer_GRBG:                  return "kCVPixelFormatType_14Bayer_GRBG"
        case kCVPixelFormatType_14Bayer_RGGB:                  return "kCVPixelFormatType_14Bayer_RGGB"
        case kCVPixelFormatType_14Bayer_BGGR:                  return "kCVPixelFormatType_14Bayer_BGGR"
        case kCVPixelFormatType_14Bayer_GBRG:                  return "kCVPixelFormatType_14Bayer_GBRG"
        default: return "UNKNOWN"
        }
    }
}

extension CIImage {
    func convertCIImageToCVPixelBuffer() -> CVPixelBuffer? {
        // Tạo một context bitmap mới với thuộc tính tùy chỉnh
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false // Sử dụng GPU renderer
        ]
        let ciContext = CIContext(options: options)
        
        // Lấy kích thước của CIImage
        let width = Int(self.extent.width)
        let height = Int(self.extent.height)
        
        // Tạo pixel buffer attributes
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        // Tạo CVPixelBuffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         pixelBufferAttributes as CFDictionary,
                                         &pixelBuffer)
        guard status == kCVReturnSuccess, let finalPixelBuffer = pixelBuffer else {
            return nil
        }
        
        // Render CIImage vào CVPixelBuffer
        ciContext.render(self, to: finalPixelBuffer)
        
        return finalPixelBuffer
    }
}

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
    
    @objc public init(videoSource: RTCVideoSource, virtualBackground: RTCVirtualBackground) {
        super.init()
        print("init BeautyFilterDelegate with virtualBackground: \(virtualBackground == nil)")
        self.beautyFilterDelegate = BeautyFilterDelegate(videoSource: videoSource, virtualBackground: virtualBackground)
        self.beautyFilter = RTCBeautyFilter(delegate: self.beautyFilterDelegate)
    }
    
    deinit {
        self.beautyFilter?.releaseInstance()
        self.beautyFilter = nil
        self.beautyFilterDelegate = nil
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

class BeautyFilterDelegate: NSObject, RTCBeautyFilterDelegate {
    var lastFrameTimestamp: Int64 = 0
    let targetFrameDurationNs: Int64 = Int64(1_000_000_000 / 24) // 24fps
    
    var videoSource: RTCVideoSource?
    var virtualBackground: RTCVirtualBackground?
    var backgroundImage: CIImage?
    var rotate: RTCVideoRotation = RTCVideoRotation._180
    weak var rtcVideoCapturer: RTCVideoCapturer?
    
    init(videoSource: RTCVideoSource? = nil, virtualBackground: RTCVirtualBackground) {
        self.videoSource = videoSource
        self.virtualBackground = virtualBackground
    }
    
    deinit {
        print("RTCVirtualBackground deinit called")
        self.videoSource = nil
        self.virtualBackground = nil
        self.backgroundImage = nil
        self.rtcVideoCapturer = nil
    }
    
    func didReceive(_ pixelBuffer: CVPixelBuffer!, width: Int32, height: Int32, timestamp: Int64) {
        let timestampNew = Int64( DispatchTime.now().uptimeNanoseconds)
        let frameDuration = timestampNew - lastFrameTimestamp
        
        if frameDuration < targetFrameDurationNs {
            return
        }

        lastFrameTimestamp = timestampNew
        
        if backgroundImage == nil {
            let timestampNs = DispatchTime.now().uptimeNanoseconds
            
            guard let frame: RTCVideoFrame = pixelBuffer.convertPixelBufferToRTCVideoFrame(rotation: RTCVideoRotation._0, timeStampNs: Int64(timestampNs)) else {
                return
            }
            
            guard let capturer = rtcVideoCapturer else {
                return
            }
            
            self.videoSource?.capturer(capturer, didCapture: frame)
            return
        }
        
        virtualBackground?.processForegroundMask(from: pixelBuffer, backgroundImage: backgroundImage!) { bufferProcessed, error in
            if let error = error {
                // Handle error
                print("Error processing foreground mask: \(error.localizedDescription)")
            } else if let bufferProcessed = bufferProcessed {
                let timestampNs = DispatchTime.now().uptimeNanoseconds
                
                guard let frame: RTCVideoFrame = bufferProcessed.convertPixelBufferToRTCVideoFrame(rotation: RTCVideoRotation._0, timeStampNs: Int64(timestampNs)) else {
                    return
                }
                
                guard let capturer = self.rtcVideoCapturer else {
                    return
                }
                
                self.videoSource?.capturer(capturer, didCapture: frame)
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
        let ciImage = CIImage(cvPixelBuffer: self)
        guard let formatedBuffer = ciImage.convertCIImageToCVPixelBuffer(pixelFormatType: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) else { return nil }
        
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: formatedBuffer)
        
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
    
    // func saveCIImageToDisk(fileName: String) -> Bool {
    //     guard let cgImage = CIContext().createCGImage(self, from: self.extent) else {
    //         print("Failed to create CGImage from CIImage")
    //         return false
    //     }
    
    //     guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 1.0) else {
    //         print("Failed to convert CGImage to JPEG data")
    //         return false
    //     }
    
    //     do {
    //         let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    //         let fileURL = documentsURL.appendingPathComponent(fileName)
    //         try data.write(to: fileURL)
    //         print("CIImage saved successfully to: \(fileURL.path)")
    //         return true
    //     } catch {
    //         print("Failed to write data to file: \(error.localizedDescription)")
    //         return false
    //     }
    // }
}

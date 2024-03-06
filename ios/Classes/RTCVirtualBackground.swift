//
//  RTCVirtualBackground.swift
//  flutter_webrtc
//
//  Created by lambiengcode on 06/03/2024.
//

import Foundation
import AVFoundation
import Vision
import VisionKit
import OpenGLES

@available(iOS 17.0, *)
var maskRequest: VNGeneratePersonInstanceMaskRequest?

@objc public class RTCVirtualBackground: NSObject {
    
    public typealias ForegroundMaskCompletion = (RTCVideoFrame?, Error?) -> Void
    
    public override init() {
        if #available(iOS 17.0, *) {
            DispatchQueue.main.async {
                maskRequest = VNGeneratePersonInstanceMaskRequest()
            }
        }
    }
    
    public func processForegroundMask(from videoFrame: RTCVideoFrame, backgroundImage: UIImage, completion: @escaping ForegroundMaskCompletion) {
        guard let pixelBuffer = convertRTCVideoFrameToPixelBuffer(videoFrame) else {
            print("Failed to convert RTCVideoFrame to CVPixelBuffer")
            return
        }
        DispatchQueue.main.async(execute: {
            if #available(iOS 17.0, *) {
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                do {
                    try handler.perform([maskRequest!])
                    if let observation = maskRequest!.results?.first {
                        let allInstances = observation.allInstances
                        do {
                            let maskedImage = try observation.generateMaskedImage(ofInstances: allInstances, from: handler, croppedToInstancesExtent: false)
                            
                            self.applyForegroundMask(to: maskedImage, backgroundImage: backgroundImage) { maskedPixelBuffer, error in
                                if let maskedPixelBuffer = maskedPixelBuffer {
                                    let frameProcessed = self.convertPixelBufferToRTCVideoFrame(maskedPixelBuffer, rotation: videoFrame.rotation, timeStampNs: videoFrame.timeStampNs)
                                    completion(frameProcessed, nil)
                                } else {
                                    completion(nil, error)
                                }
                            }
                        } catch {
                            print("Error: \(error.localizedDescription)")
                            completion(nil, error)
                        }
                    }
                } catch {
                    print("Failed to perform Vision request: \(error)")
                    completion(nil, error)
                }
            }
        })
        
    }
    
}

extension RTCVirtualBackground {
    func convertPixelBufferToRTCVideoFrame(_ pixelBuffer: CVPixelBuffer, rotation: RTCVideoRotation, timeStampNs: Int64) -> RTCVideoFrame? {
        let rtcPixelBuffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        
        let rtcVideoFrame = RTCVideoFrame(buffer: rtcPixelBuffer, rotation: rotation, timeStampNs: timeStampNs)
        
        return rtcVideoFrame
    }
    
    func convertRTCVideoFrameToPixelBuffer(_ rtcVideoFrame: RTCVideoFrame) -> CVPixelBuffer? {
        if let remotePixelBuffer = rtcVideoFrame.buffer as? RTCCVPixelBuffer {
            let pixelBuffer = remotePixelBuffer.pixelBuffer
            // Now you have access to 'pixelBuffer' for further use
            return pixelBuffer
        } else {
            print("Error: RTCVideoFrame buffer is not of type RTCCVPixelBuffer")
            return nil
        }
    }
    
    func pixelBufferFromImage(image: UIImage) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        return buffer
    }
    
    func applyForegroundMask(to pixelBuffer: CVPixelBuffer, backgroundImage: UIImage, completion: @escaping (CVPixelBuffer?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let maskedUIImage = UIImage(ciImage: CIImage(cvPixelBuffer: pixelBuffer))
            
            let size = CGSize(width: CGFloat(CVPixelBufferGetWidth(pixelBuffer)), height: CGFloat(CVPixelBufferGetHeight(pixelBuffer)))
            
            let rotatedBackgroundImage = backgroundImage.rotateImage(orientation: UIImage.Orientation.up)
            
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            rotatedBackgroundImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            maskedUIImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            let composedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            DispatchQueue.main.async {
                if let composedImage = composedImage {
                    guard let composedPixelBuffer = self.pixelBufferFromImage(image: composedImage) else {
                        completion(nil, nil)
                        return
                    }
                    
                    completion(composedPixelBuffer, nil)
                }
            }
        }
    }
}

extension UIImage {
 
    /// Rotate the UIImage
    /// - Parameter orientation: Define the rotation orientation
    /// - Returns: Get the rotated image
   func rotateImage(orientation: UIImage.Orientation) -> UIImage {
      guard let cgImage = self.cgImage else { return UIImage() }
      switch orientation {
           case .right:
               return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
           case .down:
               return UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
           case .left:
               return UIImage(cgImage: cgImage, scale: 1.0, orientation: .down)
           default:
               return UIImage(cgImage: cgImage, scale: 1.0, orientation: .left)
       }
   }
}


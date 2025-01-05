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

@available(iOS 17.0, macOS 14.0, *)
var maskRequest: VNGeneratePersonInstanceMaskRequest?

@objc public class RTCVirtualBackground: NSObject {
    
    public typealias ForegroundMaskCompletion = (CVPixelBuffer?, Error?) -> Void
    
    public override init() {
        if #available(iOS 17.0, macOS 14.0, *) {
            print("init virtual background")
            DispatchQueue.main.async {
                maskRequest = VNGeneratePersonInstanceMaskRequest()
                maskRequest?.preferBackgroundProcessing = true
                maskRequest?.revision = VNGeneratePersonInstanceMaskRequestRevision1
            }
        }
    }
    
    deinit {
        if #available(iOS 17.0, macOS 14.0, *) {
            maskRequest = nil
        }
    }
    
    public func processForegroundMask(from pixelBuffer: CVPixelBuffer, backgroundImage: CIImage, completion: @escaping ForegroundMaskCompletion) {
        DispatchQueue.global(qos: .userInitiated).async {
            if #available(iOS 17.0, macOS 14.0, *) {
                guard let inputFrameImage = CIImage(cvPixelBuffer: pixelBuffer).resize() else {
                    return
                }
                let handler = VNImageRequestHandler(ciImage: inputFrameImage, options: [:])
                do {
                    try handler.perform([maskRequest!])
                    if let observation = maskRequest!.results?.first {
                        let allInstances = observation.allInstances
                        do {
                            let maskedImage = try observation.generateMaskedImage(ofInstances: allInstances, from: handler, croppedToInstancesExtent: false)
                            
                            self.applyForegroundMask(to: maskedImage, backgroundImage: backgroundImage) { maskedPixelBuffer, error in
                                if let maskedPixelBuffer = maskedPixelBuffer {
                                    
                                    completion(maskedPixelBuffer, nil)
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
        }
    }
    
}

extension RTCVirtualBackground {
    func applyForegroundMask(to pixelBuffer: CVPixelBuffer, backgroundImage: CIImage, completion: @escaping (CVPixelBuffer?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let ciContext = CIContext()
            
            // Resize background image if necessary
#if os(macOS)
            let size = CGSize(width: 1920, height: 1080)
            
            let rotateBackground = backgroundImage.oriented(.upMirrored)
#elseif os(iOS)
            let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            
            let rotateBackground = backgroundImage.oriented(.upMirrored)
#endif
            
            let resizedBackground = rotateBackground.transformed(by: CGAffineTransform(scaleX: size.width / rotateBackground.extent.width, y: size.height / rotateBackground.extent.height))
            
            // Create CIImage from pixelBuffer
            let maskedCIImage = CIImage(cvPixelBuffer: pixelBuffer)
            let resizedMasked = maskedCIImage.transformed(by: CGAffineTransform(scaleX: size.width / maskedCIImage.extent.width, y: size.height / maskedCIImage.extent.height))
            
            // Composite images
            guard let resultImage = ciContext.createCGImage(resizedMasked.composited(over: resizedBackground), from: CGRect(origin: .zero, size: size)) else {
                completion(nil, nil)
                return
            }
            
            // Convert CGImage to CVPixelBuffer
            var composedPixelBuffer: CVPixelBuffer?
            CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, nil, &composedPixelBuffer)
            guard let composedBuffer = composedPixelBuffer else {
                completion(nil, nil)
                return
            }
            
            CVPixelBufferLockBaseAddress(composedBuffer, CVPixelBufferLockFlags(rawValue: 0))
            let bufferAddress = CVPixelBufferGetBaseAddress(composedBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(composedBuffer)
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: bufferAddress, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
            
            context?.draw(resultImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            
            CVPixelBufferUnlockBaseAddress(composedBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            completion(composedBuffer, nil)
        }
    }
}

extension CIImage {
    func resize() -> CIImage? {
#if os(macOS)
        let scale = 1.0
#elseif os(iOS)
        let scale = 720 / self.extent.width
#endif
        
        let transformation = CGAffineTransform(scaleX: scale, y: scale)
        let transformedImage = self.transformed(by: transformation)
        
        return transformedImage
    }
}

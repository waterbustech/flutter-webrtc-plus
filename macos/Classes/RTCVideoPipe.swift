//
//  RTCVideoPipe.swift
//  flutter_webrtc
//
//  Created by lambiengcode on 06/03/2024.
//

import Foundation
import WebRTC

@objc public class RTCVideoPipe: NSObject, RTCVideoCapturerDelegate {
    var virtualBackground: RTCVirtualBackground?
    var videoSource: RTCVideoSource?
    var latestTimestampNs: Int64 = 0
    var frameCount: Int = 0
    var lastProcessedTimestamp: Int64 = 0
    var fpsInterval: Int64 = 1000000000 / 15 // 15 fps to ensure VNGen can proccess
    var backgroundImage: CIImage?

    @objc public init(videoSource: RTCVideoSource) {
        self.videoSource = videoSource
        self.virtualBackground = RTCVirtualBackground()
        super.init()
    }
    
    @objc public func setBackgroundImage(image: CIImage?) {
        backgroundImage = image
    }

    @objc public func capturer(_ capturer: RTCVideoCapturer, didCapture frame: RTCVideoFrame) {
        let currentTimestamp = frame.timeStampNs

        // Calculate the time since the last processed frame
        let elapsedTimeSinceLastProcessedFrame = currentTimestamp - lastProcessedTimestamp

        if elapsedTimeSinceLastProcessedFrame < fpsInterval {
            // Skip processing the frame if it's too soon
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
}


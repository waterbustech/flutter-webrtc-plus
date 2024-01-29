package com.cloudwebrtc.webrtc.models

import android.graphics.Bitmap
import org.webrtc.VideoFrame

data class CacheFrame(
    val originalBitmap: Bitmap,
    val originalFrame: VideoFrame,
)
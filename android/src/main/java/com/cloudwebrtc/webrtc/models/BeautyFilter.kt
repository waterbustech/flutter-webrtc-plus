package com.cloudwebrtc.webrtc.models

data class BeautyFilter(
    val contrast: Double = 1.0,
    val brightness: Double = 1.0,
    val saturation: Double = 1.0,
    val blurRadius: Double = 0.0,
    val noiseReduction: Double = 0.0
)
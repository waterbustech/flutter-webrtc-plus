package com.cloudwebrtc.webrtc.models

enum class StyleEffect(val value: Int) {
    NORMAL(0),
    CLASSIC(1),
    VINTAGE(2),
    CINEMA(3),
    POP_ART(4),
    HDR(5),
}

fun Int.toStyleEffect(): StyleEffect {
    return StyleEffect.entries.firstOrNull { it.value == this } ?: StyleEffect.NORMAL
}
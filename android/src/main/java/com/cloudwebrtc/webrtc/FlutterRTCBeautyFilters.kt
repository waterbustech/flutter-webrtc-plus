package com.cloudwebrtc.webrtc

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import com.pixpark.gpupixel.FaceDetector
import com.pixpark.gpupixel.GPUPixel
import com.pixpark.gpupixel.GPUPixelFilter
import com.pixpark.gpupixel.GPUPixelSinkRawData
import com.pixpark.gpupixel.GPUPixelSourceRawData
import java.util.concurrent.atomic.AtomicBoolean


class FlutterRTCBeautyFilters(context: Context) {
    private val tag = "FlutterRTCBeautyFilters"
    private var mSourceRawData: GPUPixelSourceRawData? = null
    private var mBeautyFilter: GPUPixelFilter? = null
    private var mFaceReshapeFilter: GPUPixelFilter? = null
    private var mLipstickFilter: GPUPixelFilter? = null
    private var mFaceDetector: FaceDetector? = null
    private var mSinkRawData: GPUPixelSinkRawData? = null

    // Performance optimization variables
    private var cachedLandmarks: FloatArray? = null
    private val isProcessing = AtomicBoolean(false)

    // Reusable objects to avoid allocation
    private var pixelBuffer: ByteArray? = null
    private var argbPixels: IntArray? = null

    init {
        try {
            GPUPixel.Init(context)

            // Create GPUPixel processing chain
            mSourceRawData = GPUPixelSourceRawData.Create()

            // Create filters
            mBeautyFilter = GPUPixelFilter.Create(GPUPixelFilter.BEAUTY_FACE_FILTER)
            mFaceReshapeFilter = GPUPixelFilter.Create(GPUPixelFilter.FACE_RESHAPE_FILTER)
            mLipstickFilter = GPUPixelFilter.Create(GPUPixelFilter.LIPSTICK_FILTER)

            // Create output sink
            mSinkRawData = GPUPixelSinkRawData.Create()

            // Initialize face detection
            mFaceDetector = FaceDetector.Create()

            mSourceRawData!!.AddSink(mLipstickFilter)
            mLipstickFilter!!.AddSink(mBeautyFilter)
            mBeautyFilter!!.AddSink(mFaceReshapeFilter)
            mFaceReshapeFilter!!.AddSink(mSinkRawData)
        } catch (error: Exception) {
            Log.e(tag, error.message.toString())
        }
    }

    private fun convertPixelsToBitmap(pixels: ByteArray, width: Int, height: Int): Bitmap {
        // Reuse ARGB array if possible
        val pixelCount = width * height
        if (argbPixels == null || argbPixels!!.size != pixelCount) {
            argbPixels = IntArray(pixelCount)
        }

        // Direct conversion from RGBA to ARGB
        var pixelIndex = 0
        for (i in argbPixels!!.indices) {
            val r = pixels[pixelIndex++].toInt() and 0xFF
            val g = pixels[pixelIndex++].toInt() and 0xFF
            val b = pixels[pixelIndex++].toInt() and 0xFF
            val a = pixels[pixelIndex++].toInt() and 0xFF

            argbPixels!![i] = (a shl 24) or (r shl 16) or (g shl 8) or b
        }

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.setPixels(argbPixels, 0, width, 0, 0, width, height)
        return bitmap
    }

    fun processBitmap(originalBitmap: Bitmap, rotation: Int): Bitmap {
        // Skip if already processing to avoid queue buildup
        if (!isProcessing.compareAndSet(false, true)) {
            Log.d(tag, "Skipping frame - already processing")
            return originalBitmap
        }

        try {
            if (mSourceRawData == null) {
                Log.d(tag, "mSourceRawData is null")
                return originalBitmap
            }

            // Skip rotation if not needed
            val bitmap = if (rotation != 0) {
                val bitmapRotation = if (rotation == 90) 90f else -90f
                rotateBitmap(originalBitmap, bitmapRotation)
            } else {
                originalBitmap
            }

            val width: Int = bitmap.width
            val height: Int = bitmap.height
            val stride: Int = width * 4

            val pixels = bitmapToRGBAByteArrayOptimized(bitmap)

            val landmarks = if (mFaceDetector != null) {
                try {
                    val detectedLandmarks = mFaceDetector!!.detect(
                        pixels, width, height,
                        stride, FaceDetector.GPUPIXEL_MODE_FMT_VIDEO,
                        FaceDetector.GPUPIXEL_FRAME_TYPE_RGBA
                    )
                    if (detectedLandmarks != null && detectedLandmarks.isNotEmpty()) {
                        cachedLandmarks = detectedLandmarks
                    }
                    detectedLandmarks
                } catch (e: Exception) {
                    Log.w(tag, "Face detection failed, using cached landmarks")
                    cachedLandmarks
                }
            } else {
                cachedLandmarks // Use cached landmarks
            }

            // Only set landmarks if they exist
            if (landmarks != null && landmarks.isNotEmpty()) {
                mFaceReshapeFilter?.SetProperty("face_landmark", landmarks)
                mLipstickFilter?.SetProperty("face_landmark", landmarks)
            }

            mSourceRawData!!.ProcessData(pixels, width, height, stride, GPUPixelSourceRawData.FRAME_TYPE_RGBA)

            val processedRgba = mSinkRawData!!.GetRgbaBuffer()

            return convertPixelsToBitmap(processedRgba, width, height)

        } catch (error: Exception) {
            Log.e(tag, "Processing error: ${error.message}")
            return originalBitmap
        } finally {
            isProcessing.set(false)
        }
    }

    /**
     * Optimized version - reuse buffer and avoid unnecessary allocations
     */
    fun bitmapToRGBAByteArrayOptimized(bitmap: Bitmap): ByteArray {
        val width = bitmap.width
        val height = bitmap.height
        val pixelCount = width * height

        // Reuse pixel buffer if possible
        val requiredSize = pixelCount * 4
        if (pixelBuffer == null || pixelBuffer!!.size != requiredSize) {
            pixelBuffer = ByteArray(requiredSize)
        }

        // Reuse ARGB array if possible
        if (argbPixels == null || argbPixels!!.size != pixelCount) {
            argbPixels = IntArray(pixelCount)
        }

        // Get pixels directly without copying bitmap
        if (bitmap.config == Bitmap.Config.ARGB_8888) {
            bitmap.getPixels(argbPixels, 0, width, 0, 0, width, height)
        } else {
            // Only copy if format is different
            val argbBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, false)
            argbBitmap.getPixels(argbPixels, 0, width, 0, 0, width, height)
        }

        // Convert ARGB to RGBA in place
        var bufferIndex = 0
        for (pixel in argbPixels!!) {
            pixelBuffer!![bufferIndex++] = ((pixel shr 16) and 0xFF).toByte() // R
            pixelBuffer!![bufferIndex++] = ((pixel shr 8) and 0xFF).toByte()  // G
            pixelBuffer!![bufferIndex++] = (pixel and 0xFF).toByte()          // B
            pixelBuffer!![bufferIndex++] = ((pixel shr 24) and 0xFF).toByte() // A
        }

        return pixelBuffer!!
    }

    // Optimize filter property setting - only set if value actually changed
    private var lastBeautyValue = -1f
    private var lastWhiteValue = -1f
    private var lastThinValue = -1f
    private var lastBigEyesValue = -1f
    private var lastLipstickValue = -1f

    fun setBeautyValue(value: Float) {
        if (value != lastBeautyValue) {
            mBeautyFilter?.SetProperty("skin_smoothing", value)
            lastBeautyValue = value
        }
    }

    fun setWhiteValue(value: Float) {
        if (value != lastWhiteValue) {
            mBeautyFilter?.SetProperty("whiteness", value)
            lastWhiteValue = value
        }
    }

    fun setThinValue(value: Float) {
        if (value != lastThinValue) {
            mFaceReshapeFilter?.SetProperty("thin_face", value)
            lastThinValue = value
        }
    }

    fun setBigEyesValue(value: Float) {
        if (value != lastBigEyesValue) {
            mFaceReshapeFilter?.SetProperty("big_eye", value)
            lastBigEyesValue = value
        }
    }

    fun setLipstickValue(value: Float) {
        if (value != lastLipstickValue) {
            mLipstickFilter?.SetProperty("blend_level", value)
            lastLipstickValue = value
        }
    }

    // Cache rotation matrix
    private var lastRotationDegrees = 0f
    private var cachedMatrix: Matrix? = null

    private fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        if (degrees == 0f) return bitmap

        // Reuse matrix if same rotation
        if (cachedMatrix == null || lastRotationDegrees != degrees) {
            cachedMatrix = Matrix()
            cachedMatrix!!.postRotate(degrees)
            lastRotationDegrees = degrees
        }

        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, cachedMatrix, true)
    }

    // Cleanup resources
    fun release() {
        try {
            // Clear cached data
            pixelBuffer = null
            argbPixels = null
            cachedLandmarks = null
            cachedMatrix = null

            Log.d(tag, "Resources released")
        } catch (e: Exception) {
            Log.e(tag, "Release error: ${e.message}")
        }
    }
}
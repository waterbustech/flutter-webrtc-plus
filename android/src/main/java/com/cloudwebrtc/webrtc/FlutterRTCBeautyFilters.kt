package com.cloudwebrtc.webrtc

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import com.pixpark.gpupixel.GPUPixel
import com.pixpark.gpupixel.GPUPixelSource.ProcessedFrameDataCallback
import com.pixpark.gpupixel.GPUPixelSourceCamera
import com.pixpark.gpupixel.filter.BeautyFaceFilter
import com.pixpark.gpupixel.filter.FaceReshapeFilter
import com.pixpark.gpupixel.filter.LipstickFilter
import java.nio.ByteBuffer
import java.nio.ByteOrder


class FlutterRTCBeautyFilters(context: Context) {
    private val tag = "FlutterRTCBeautyFilters"
    private var sourceRawInput: GPUPixelSourceCamera? = null
    private var beautyFaceFilter: BeautyFaceFilter? = null
    private var faceReshapeFilter: FaceReshapeFilter? = null
    private var lipstickFilter: LipstickFilter? = null
    private var resultCallback: ProcessedFrameDataCallback? = null

    companion object {
        private var isInitialized: Boolean = false

        fun initialize() {
            isInitialized = true
        }
    }

    init {
        try {
            beautyFaceFilter = BeautyFaceFilter()
            faceReshapeFilter = FaceReshapeFilter()
            lipstickFilter = LipstickFilter()
            sourceRawInput = GPUPixelSourceCamera(context)

            GPUPixel.getInstance().runOnDraw {
                sourceRawInput!!.addTarget(lipstickFilter)
                lipstickFilter!!.addTarget(faceReshapeFilter)
                faceReshapeFilter!!.addTarget(beautyFaceFilter)

                sourceRawInput?.setLandmarkCallbck(GPUPixel.GPUPixelLandmarkCallback {
                    faceReshapeFilter?.faceLandmark = it
                    lipstickFilter?.faceLandmark = it
                })
            }
        } catch (error: Exception) {
            Log.e(tag, error.message.toString())
        }
    }

    fun setCallback(callback: ProcessedFrameDataCallback) {
        this.resultCallback = callback

        val cbResult = GPUPixel.RawOutputCallback { bytes, width, height, ts ->
            val bmp = convertPixelsToBitmap(bytes, width, height)
            resultCallback?.onResult(bmp)
        }

        beautyFaceFilter!!.addTargetCallback(cbResult)
    }

    private fun convertPixelsToBitmap(pixels: ByteArray, width: Int, height: Int): Bitmap {
        val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bmp.copyPixelsFromBuffer(ByteBuffer.wrap(pixels))
        return bmp
    }

    fun processBitmap(originalBitmap: Bitmap, rotation: Int) {
        if (sourceRawInput == null) return

        val bitmapRotation = if (rotation == 90) 90f else -90f

        val bitmap = rotateBitmap(originalBitmap, bitmapRotation)

        if (isInitialized) {
            val width: Int = bitmap.width
            val height: Int = bitmap.height

            val pixels = getPixelsFromBitmap(bitmap)
            sourceRawInput?.setFrameByBuffer(pixels, width, height)
        } else {
            this.resultCallback?.onResult(bitmap)
        }
    }

    private fun getPixelsFromBitmap(bitmap: Bitmap): ByteBuffer {
        val width = bitmap.width
        val height = bitmap.height

        // Allocate a ByteBuffer to hold the pixel data
        val buffer = ByteBuffer.allocateDirect(width * height * 4)
        buffer.order(ByteOrder.nativeOrder())

        // Copy pixel data from the Bitmap into the ByteBuffer
        bitmap.copyPixelsToBuffer(buffer)
        buffer.position(0)

        return buffer
    }

    fun setBeautyValue(value: Float) {
        beautyFaceFilter?.smoothLevel = value
    }

    fun setWhiteValue(value: Float) {
        beautyFaceFilter?.whiteLevel = value
    }

    fun setThinValue(value: Float) {
        faceReshapeFilter?.thinLevel = value
    }

    fun setBigEyesValue(value: Float) {
        faceReshapeFilter?.bigeyeLevel = value
    }

    fun setLipstickValue(value: Float) {
        lipstickFilter?.blendLevel = value
    }

    private fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        val matrix = Matrix()
        matrix.postRotate(degrees)
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
}
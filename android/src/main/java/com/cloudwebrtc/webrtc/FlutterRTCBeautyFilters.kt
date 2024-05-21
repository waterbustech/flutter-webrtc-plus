package com.cloudwebrtc.webrtc

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import com.pixpark.gpupixel.GPUPixel
import com.pixpark.gpupixel.GPUPixelSource.ProcessedFrameDataCallback
import com.pixpark.gpupixel.filter.WaterbusGPUPixel
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream

class FlutterRTCBeautyFilters {
    private val tag = "FlutterRTCBeautyFilters"

    private var context: Context? = null
    private var waterbusGPUPixel: WaterbusGPUPixel? = null
    private var resultCallback: ProcessedFrameDataCallback? = null
    private var rotation: Int = 0

    fun initialize(resultCallback: ProcessedFrameDataCallback, context: Context) {
        try {
            this.context = context
            this.resultCallback = resultCallback

            GPUPixel.setContext(context)

            val callback = GPUPixel.RawOutputCallback { y, u, v, width, height ->
//                val bitmap = convertI420ToBitmap(y, u, v, width, height)
//
//                if (bitmap != null) {
//                    resultCallback.onResult(bitmap)
//                }
            }

            waterbusGPUPixel = WaterbusGPUPixel(callback)
        } catch (error: Exception) {
            Log.e(tag, error.message.toString())
        }
    }

    private fun bitmapToRgba(bitmap: Bitmap): IntArray {
        require(bitmap.config == Bitmap.Config.ARGB_8888) { "Bitmap must be in ARGB_8888 format" }
        val size = bitmap.width * bitmap.height
        val pixels = IntArray(size * 4)
        bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)

        return pixels
    }

    fun processBitmap(originalBitmap: Bitmap) {
        val bitmap = rotateBitmap(originalBitmap, -90f)

        val width: Int = bitmap.width
        val height: Int = bitmap.height
        val stride: Int = bitmap.rowBytes / 4 // 4 bytes per pixel (ARGB_8888)

        if (width <= 0 || height <= 0) return

        val rgba = bitmapToRgba(bitmap)

        waterbusGPUPixel?.uploadBytes(rgba, width, height, stride)
    }


//    fun setBeautyValue(value: Float) {
//        beautyFaceFilter?.smoothLevel = value
//    }
//
//    fun setWhiteValue(value: Float) {
//        beautyFaceFilter?.whiteLevel = value
//    }
//
//    fun setThinValue(value: Float) {
//        faceReshapFilter?.thinLevel = value
//    }
//
//    fun setBigEyesValue(value: Float) {
//        faceReshapFilter?.bigeyeLevel = value
//    }
//
//    fun setLipstickValue(value: Float) {
//        lipstickFilter?.blendLevel = value
//    }

    private fun rotateBitmap(bitmap: Bitmap, degrees: Float): Bitmap {
        val matrix = Matrix()
        matrix.postRotate(degrees)
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun saveBitmapToPhone(context: Context, bitmap: Bitmap, filename: String): Boolean {
        val outputStream: OutputStream?
        try {
            val folder = File(context.getExternalFilesDir(null), "WaterbusFolder")
            if (!folder.exists()) {
                folder.mkdirs()
            }
            val file = File(folder, filename)
            outputStream = FileOutputStream(file)
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            outputStream.flush()
            outputStream.close()
            Log.d(tag, "Image saved: ${file.absolutePath}")
            return true
        } catch (e: Exception) {
            Log.e(tag, e.message.toString())
        }
        return false
    }
}
package com.cloudwebrtc.webrtc

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import com.pixpark.gpupixel.GPUPixel
import com.pixpark.gpupixel.GPUPixelSource.ProcessedFrameDataCallback
import com.pixpark.gpupixel.GPUPixelSourceRawInput
import com.pixpark.gpupixel.GPUPixelTargetRawOutput
import com.pixpark.gpupixel.RawOutputCallback
import com.pixpark.gpupixel.filter.BeautyFaceFilter
import com.pixpark.gpupixel.filter.FaceReshapeFilter
import com.pixpark.gpupixel.filter.LipstickFilter
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream


class FlutterRTCBeautyFilters {
    private val TAG = "FlutterRTCBeautyFilters"

    private var sourceRawInput: GPUPixelSourceRawInput? = null
    private var beautyFaceFilter: BeautyFaceFilter? = null
    private var faceReshapFilter: FaceReshapeFilter? = null
    private var lipstickFilter: LipstickFilter? = null
    private var resultCallback: ProcessedFrameDataCallback? = null
    private var targetRawOutput: GPUPixelTargetRawOutput? = null
    private var rotation: Int = 0

    private var context: Context? = null

    fun initialize(resultCallback: ProcessedFrameDataCallback, context: Context) {
        try {
            GPUPixel.setContext(context)

            sourceRawInput = GPUPixelSourceRawInput()

            this.context = context
            this.resultCallback = resultCallback

            val callback =
                RawOutputCallback { var1, var2, var3, var4 ->
                    Log.d(TAG, "===>>> done")
                }

            beautyFaceFilter = BeautyFaceFilter()
            faceReshapFilter = FaceReshapeFilter()
            lipstickFilter = LipstickFilter()
            targetRawOutput = GPUPixelTargetRawOutput()

            targetRawOutput?.setCallBack(callback)

            sourceRawInput?.addTarget(lipstickFilter)
                ?.addTarget(faceReshapFilter)
                ?.addTarget(beautyFaceFilter)
                ?.addTarget(targetRawOutput)

            sourceRawInput?.setLandmarkCallbck(faceReshapFilter!!.nativeClassID, lipstickFilter!!.nativeClassID)

            sourceRawInput?.SetRotation(rotation)

            lipstickFilter?.blendLevel = 0.5f
            faceReshapFilter?.thinLevel = 0.01f
            beautyFaceFilter?.whiteLevel = 0.1f
            beautyFaceFilter?.smoothLevel = 0.2f
        } catch (error: Exception) {
            Log.e(TAG, error.message.toString())
        }
    }

    fun processVideoFrame(originalBitmap: Bitmap, rotate: Int) {
        val bitmap = rotateBitmap(originalBitmap, -90f)

//        saveBitmapToPhone(this.context!!, bitmap, "frame00.png")

        if (sourceRawInput?.nativeClassID == 0L) return

        val width: Int = bitmap.width
        val height: Int = bitmap.height

        if (width <= 0 || height <= 0) return

        val pixels = IntArray(width * height)
        val stride: Int = bitmap.rowBytes / 4 // 4 bytes per pixel (ARGB_8888)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        Log.d(TAG, "Processing...")

        if (rotate != rotation) {
            rotation = rotate
            sourceRawInput?.SetRotation(rotate)
        }

        sourceRawInput?.uploadBytes(pixels, width, height, stride)
    }

    fun setBeautyValue(value: Float) {
        beautyFaceFilter?.smoothLevel = value
    }

    fun setWhiteValue(value: Float) {
        beautyFaceFilter?.whiteLevel = value
    }

    fun setThinValue(value: Float) {
        faceReshapFilter?.thinLevel = value
    }

    fun setBigEyesValue(value: Float) {
        faceReshapFilter?.bigeyeLevel = value
    }

    fun setLipstickValue(value: Float) {
        lipstickFilter?.blendLevel = value
    }

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
            Log.d(TAG, "Image saved: ${file.absolutePath}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, e.message.toString())
        }
        return false
    }
}
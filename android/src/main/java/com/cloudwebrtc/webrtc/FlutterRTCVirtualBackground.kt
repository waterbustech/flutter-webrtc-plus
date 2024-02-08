package com.cloudwebrtc.webrtc

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import org.opencv.android.Utils
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import java.nio.ByteBuffer
import java.nio.FloatBuffer

class FlutterRTCVirtualBackground {
    private val tag: String = "[FlutterRTC-Background]"
    /**
     * Resize the given bitmap while maintaining its original aspect ratio.
     *
     * @param bitmap The bitmap to be resized.
     * @param maxSize The maximum size (width or height) of the resized bitmap.
     * @return The resized bitmap while keeping its original aspect ratio.
     */
    fun resizeBitmapKeepAspectRatio(bitmap: Bitmap, maxSize: Int): Bitmap {
        val originalWidth = bitmap.width
        val originalHeight = bitmap.height

        // Check the current size of the image and return if it doesn't exceed the maxSize
        if (originalWidth <= maxSize && originalHeight <= maxSize) {
            return bitmap
        }

        // Determine whether to maintain width or height to keep the original aspect ratio
        val scaleFactor: Float = if (originalWidth >= originalHeight) {
            maxSize.toFloat() / originalWidth
        } else {
            maxSize.toFloat() / originalHeight
        }

        // Calculate the new size of the image while maintaining the original aspect ratio
        val newWidth = (originalWidth * scaleFactor).toInt()
        val newHeight = (originalHeight * scaleFactor).toInt()

        // Create a new bitmap with the scaled size while preserving the aspect ratio
        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }

    fun convertFloatBufferToByteBuffer(floatBuffer: FloatBuffer): ByteBuffer {
        // Calculate the number of bytes needed for the ByteBuffer
        val bufferSize = floatBuffer.remaining() * 4 // 4 bytes per float

        // Create a new ByteBuffer with the calculated size
        val byteBuffer = ByteBuffer.allocateDirect(bufferSize)

        // Transfer the data from the FloatBuffer to the ByteBuffer
        byteBuffer.asFloatBuffer().put(floatBuffer)

        // Reset the position of the ByteBuffer to 0
        byteBuffer.position(0)

        return byteBuffer
    }

    /**
     * Convert the mask buffer to an array of colors representing the segmented regions.
     *
     * @param mask The mask buffer obtained from the AI segmenter.
     * @param maskWidth The width of the mask.
     * @param maskHeight The height of the mask.
     * @param originalBitmap The original input bitmap used for color extraction.
     * @return An array of colors representing the segmented regions.
     */
    fun maskColorsFromByteBuffer(
        mask: ByteBuffer,
        maskWidth: Int,
        maskHeight: Int,
        originalBitmap: Bitmap,
        expectConfidence: Double
    ): IntArray {
        val colors = IntArray(maskWidth * maskHeight)
        val scaleX = originalBitmap.width.toFloat() / maskWidth
        val scaleY = originalBitmap.height.toFloat() / maskHeight

        for (i in 0 until maskWidth * maskHeight) {
            val humanLikelihood = 1 - mask.float

            if (humanLikelihood >= expectConfidence) {
                val x = (i % maskWidth * scaleX).toInt()
                val y = (i / maskWidth * scaleY).toInt()
                val originalPixel = originalBitmap.getPixel(x, y)

                colors[i] = Color.argb(
                    Color.alpha(originalPixel),
                    Color.red(originalPixel),
                    Color.green(originalPixel),
                    Color.blue(originalPixel)
                )
            } else {
                // Pixel is likely to be background, make it transparent
                colors[i] =  Color.argb(0, 0, 0, 0)
            }
        }

        return colors
    }

    /**
     * Draw the segmentedBitmap on top of the backgroundBitmap with the background rotated by the specified angle (in degrees)
     * and both background and segmentedBitmap flipped vertically to match the same orientation.
     *
     * @param segmentedBitmap The bitmap representing the segmented foreground with transparency.
     * @param backgroundBitmap The bitmap representing the background image to be used as the base.
     * @param rotationAngle The angle in degrees to rotate both the backgroundBitmap and segmentedBitmap.
     * @return The resulting bitmap with the segmented foreground overlaid on the rotated and vertically flipped background.
     *         Returns null if either of the input bitmaps is null.
     */
    fun drawSegmentedBackground(
        segmentedBitmap: Bitmap?,
        backgroundBitmap: Bitmap?,
        rotationAngle: Int?
    ): Bitmap? {
        if (segmentedBitmap == null || backgroundBitmap == null) {
            return null
        }

        val isHorizontalFrame = rotationAngle == 0 || rotationAngle == 180

        val outputBitmap = Bitmap.createBitmap(
            segmentedBitmap.width,
            segmentedBitmap.height,
            Bitmap.Config.ARGB_8888
        )

        val canvas = Canvas(outputBitmap)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        val matrix = Matrix()
        matrix.postRotate((rotationAngle?.toFloat() ?: 0f) - 180)

        if (isHorizontalFrame) {
            val scaleFitContain = Math.min(
                segmentedBitmap.width.toFloat() / backgroundBitmap.width,
                segmentedBitmap.height.toFloat() / backgroundBitmap.height
            )

            val scaledWidthFitContain = (backgroundBitmap.width * scaleFitContain).toInt()
            val scaledHeightFitContain = (backgroundBitmap.height * scaleFitContain).toInt()

            val rotatedBackgroundBitmap = Bitmap.createBitmap(
                backgroundBitmap,
                0,
                0,
                backgroundBitmap.width,
                backgroundBitmap.height,
                matrix,
                true
            )

            val backgroundRect = Rect(
                (segmentedBitmap.width - scaledWidthFitContain) / 2,
                (segmentedBitmap.height - scaledHeightFitContain) / 2,
                (segmentedBitmap.width + scaledWidthFitContain) / 2,
                (segmentedBitmap.height + scaledHeightFitContain) / 2
            )

            canvas.drawBitmap(
                rotatedBackgroundBitmap,
                null,
                backgroundRect,
                paint
            )
        } else {
            val newBackgroundWidth = Math.min(segmentedBitmap.width.toFloat(), segmentedBitmap.height.toFloat()).toInt()
            val scaleFactor = (newBackgroundWidth.toFloat() / backgroundBitmap.width.toFloat())
            val newBackgroundHeight = (backgroundBitmap.height * scaleFactor).toInt()

            val scaledBackground = scaleBitmap(backgroundBitmap, newBackgroundWidth, newBackgroundHeight)

            val rotatedBackgroundBitmap = Bitmap.createBitmap(
                scaledBackground,
                0,
                0,
                scaledBackground.width,
                scaledBackground.height,
                matrix,
                true
            )

            canvas.drawBitmap(
                rotatedBackgroundBitmap,
                0f,
                0f,
                paint
            )
        }

        canvas.drawBitmap(segmentedBitmap, 0f, 0f, paint)

        return outputBitmap
    }

    fun scaleBitmap(bitmap: Bitmap, newWidth: Int, newHeight: Int): Bitmap {
        val mat = Mat(bitmap.height, bitmap.width, CvType.CV_8UC4)
        Utils.bitmapToMat(bitmap, mat)

        val resizedMat = Mat(newHeight, newWidth, CvType.CV_8UC4)

        Imgproc.resize(mat, resizedMat, Size(newWidth.toDouble(), newHeight.toDouble()), 0.0, 0.0, Imgproc.INTER_LINEAR)

        val resizedBitmap = Bitmap.createBitmap(newWidth, newHeight, Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(resizedMat, resizedBitmap)

        return resizedBitmap
    }


    /**
     * Creates a bitmap from an array of colors with the specified width and height.
     *
     * @param colors The array of colors representing the pixel values of the bitmap.
     * @param width The width of the bitmap.
     * @param height The height of the bitmap.
     * @return The resulting bitmap created from the array of colors.
     */
    fun createBitmapFromColors(colors: IntArray, width: Int, height: Int): Bitmap {
        return Bitmap.createBitmap(colors, width, height, Bitmap.Config.ARGB_8888)
    }
}
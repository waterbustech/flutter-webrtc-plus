package com.cloudwebrtc.webrtc

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.cloudwebrtc.webrtc.utils.ImageSegmenterHelper
import java.nio.ByteBuffer
import java.nio.FloatBuffer
import kotlin.math.max

class FlutterRTCVirtualBackground {
    private val tag: String = "[FlutterRTC-Background]"
    private val frameSizeProcessing = 480
    private var expectConfidence = 0.7
    private var imageSegmentationHelper: ImageSegmenterHelper? = null

    /**
     * Process the segmentation of the input bitmap using the AI segmenter.
     * The resulting segmented bitmap is then combined with the provided background bitmap,
     * and the final output frame is sent to the video sink.
     *
     * @param bitmap The input bitmap to be segmented.
     * @param original The original video frame for metadata reference (rotation, timestamp, etc.).
     * @param sink The VideoSink to receive the processed video frame.
     */
    @RequiresApi(Build.VERSION_CODES.N)
    fun processSegmentation(bitmap: Bitmap, frameTime: Long) {
        val resizeBitmap = resizeBitmapKeepAspectRatio(bitmap, frameSizeProcessing)

        imageSegmentationHelper?.segmentLiveStreamFrame(resizeBitmap, frameTime)
    }

    /**
     * Resize the given bitmap while maintaining its original aspect ratio.
     *
     * @param bitmap The bitmap to be resized.
     * @param maxSize The maximum size (width or height) of the resized bitmap.
     * @return The resized bitmap while keeping its original aspect ratio.
     */
    private fun resizeBitmapKeepAspectRatio(bitmap: Bitmap, maxSize: Int): Bitmap {
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
     * @param scaledWidth The width of the scaled bitmap.
     * @param scaledHeight The height of the scaled bitmap.
     * @return An array of colors representing the segmented regions.
     */
    fun maskColorsFromByteBuffer(
        mask: ByteBuffer,
        maskWidth: Int,
        maskHeight: Int,
        originalBitmap: Bitmap,
        scaledWidth: Int,
        scaledHeight: Int
    ): IntArray {
        val colors = IntArray(scaledWidth * scaledHeight)
        var count = 0
        val scaleX = scaledWidth.toFloat() / maskWidth
        val scaleY = scaledHeight.toFloat() / maskHeight
        for (y in 0 until scaledHeight) {
            for (x in 0 until scaledWidth) {
                val maskX: Int = (x / scaleX).toInt()
                val maskY: Int = (y / scaleY).toInt()
                if (maskX in 0 until maskWidth && maskY >= 0 && maskY < maskHeight) {
                    val position = (maskY * maskWidth + maskX) * 4
                    mask.position(position)

                    // Get the confidence of the (x,y) pixel in the mask being in the foreground.
                    val foregroundConfidence = mask.float
                    val pixelColor = originalBitmap.getPixel(x, y)

                    // Extract the color channels from the original pixel
                    val alpha = Color.alpha(pixelColor)
                    val red = Color.red(pixelColor)
                    val green = Color.green(pixelColor)
                    val blue = Color.blue(pixelColor)

                    // Calculate the new alpha and color for the foreground and background
                    var newAlpha: Int
                    var newRed: Int
                    var newGreen: Int
                    var newBlue: Int
                    if (foregroundConfidence >= expectConfidence) {
                        // Foreground uses color from the original bitmap
                        newAlpha = alpha
                        newRed = red
                        newGreen = green
                        newBlue = blue
                    } else {
                        // Background is black with alpha 0
                        newAlpha = 0
                        newRed = 0
                        newGreen = 0
                        newBlue = 0
                    }

                    // Create a new color with the adjusted alpha and RGB channels
                    val newColor = Color.argb(newAlpha, newRed, newGreen, newBlue)
                    colors[count] = newColor
                } else {
                    // Pixels outside the original mask size are considered background (black with alpha 0)
                    colors[count] = Color.argb(0, 0, 0, 0)
                }
                count++
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
        rotationAngle: Int
    ): Bitmap? {
        if (segmentedBitmap == null || backgroundBitmap == null) {
            // Handle invalid bitmaps
            return null
        }

        // Create a new bitmap with dimensions matching the segmentedBitmap
        val outputBitmap = Bitmap.createBitmap(
            segmentedBitmap.width,
            segmentedBitmap.height,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(outputBitmap)

        // Create a matrix to apply transformations to the background and segmentedBitmap
        val matrix = Matrix()

        // Calculate the scale factor for the backgroundBitmap to be larger or equal to the segmentedBitmap
        val scaleX = segmentedBitmap.width.toFloat() / backgroundBitmap.width
        val scaleY = segmentedBitmap.height.toFloat() / backgroundBitmap.height
        val scale = max(scaleX, scaleY)

        // Calculate the new dimensions of the backgroundBitmap after scaling
        val newBackgroundWidth = (backgroundBitmap.width * scale).toInt()
        val newBackgroundHeight = (backgroundBitmap.height * scale).toInt()

        // Calculate the offset to center the backgroundBitmap in the outputBitmap
        val offsetX = (segmentedBitmap.width - newBackgroundWidth) / 2
        val offsetY = (segmentedBitmap.height - newBackgroundHeight) / 2

        // Apply scale and translate to center the backgroundBitmap and segmentedBitmap
        matrix.postScale(scale, scale)
        matrix.postTranslate(offsetX.toFloat(), offsetY.toFloat())

        // Rotate the backgroundBitmap and segmentedBitmap by the specified angle around the center of the image
        matrix.postRotate(rotationAngle.toFloat(), segmentedBitmap.width / 2f, segmentedBitmap.height / 2f)

        // Draw the backgroundBitmap on the canvas with the specified transformations
        canvas.drawBitmap(backgroundBitmap, matrix, null)

        // Draw the segmentedBitmap on the canvas with the same transformations
        canvas.drawBitmap(segmentedBitmap, matrix, null)

        Log.d(tag, "Drawed the segment on of the background")

        return outputBitmap
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
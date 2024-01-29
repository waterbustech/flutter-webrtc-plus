package com.cloudwebrtc.webrtc

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.renderscript.Allocation
import android.renderscript.Element
import android.renderscript.RenderScript
import android.renderscript.ScriptIntrinsicBlur
import com.cloudwebrtc.webrtc.models.BeautyFilter

class CameraFilters {

    fun applyBeautyFilter(context: Context, originalBitmap: Bitmap, beautyFilter: BeautyFilter): Bitmap {
        // Create a copy of the original bitmap
        var filteredBitmap = originalBitmap.copy(originalBitmap.config, true)

        // Apply filter
        for (y in 0 until filteredBitmap.height) {
            for (x in 0 until filteredBitmap.width) {
                val pixel = filteredBitmap.getPixel(x, y)

                // Extract RGB components
                var red = Color.red(pixel)
                var green = Color.green(pixel)
                var blue = Color.blue(pixel)

                // Apply contrast
                red = (red * beautyFilter.contrast).toInt().coerceIn(0, 255)
                green = (green * beautyFilter.contrast).toInt().coerceIn(0, 255)
                blue = (blue * beautyFilter.contrast).toInt().coerceIn(0, 255)

                // Apply brightness
                red = (red * beautyFilter.brightness).toInt().coerceIn(0, 255)
                green = (green * beautyFilter.brightness).toInt().coerceIn(0, 255)
                blue = (blue * beautyFilter.brightness).toInt().coerceIn(0, 255)

                // Apply saturation
                val hsv = FloatArray(3)
                Color.RGBToHSV(red, green, blue, hsv)
                hsv[1] = (hsv[1] * beautyFilter.saturation).coerceIn(0.0, 1.0).toFloat()
                val newColor = Color.HSVToColor(hsv)
                red = Color.red(newColor)
                green = Color.green(newColor)
                blue = Color.blue(newColor)

                // Update pixel
                filteredBitmap.setPixel(x, y, Color.rgb(red, green, blue))
            }
        }

        // Apply blur
        if (beautyFilter.blurRadius > 0.0) {
            filteredBitmap = applyBlur(context, filteredBitmap, beautyFilter.blurRadius.toFloat())
        }

        // Apply noise reduction
        if (beautyFilter.noiseReduction > 0.0) {
            filteredBitmap = applyNoiseReduction(filteredBitmap, beautyFilter.noiseReduction.toFloat())
        }


        return filteredBitmap
    }

    private fun applyBlur(context: Context, bitmap: Bitmap, radius: Float): Bitmap {
        // Create a RenderScript context
        val rs = RenderScript.create(context)

        // Allocate memory for input and output bitmaps
        val input = Allocation.createFromBitmap(rs, bitmap)
        val output = Allocation.createTyped(rs, input.type)

        // Create a Gaussian blur script
        val blurScript = ScriptIntrinsicBlur.create(rs, Element.U8_4(rs))
        blurScript.setRadius(radius)

        // Run the script
        blurScript.setInput(input)
        blurScript.forEach(output)

        // Copy the output bitmap back to the original
        output.copyTo(bitmap)

        // Release resources
        rs.destroy()

        return bitmap
    }

    private fun applyNoiseReduction(bitmap: Bitmap, strength: Float): Bitmap {
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        // Apply a basic averaging filter for noise reduction
        val newPixels = applyAveragingFilter(pixels, width, height, strength)

        val resultBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        resultBitmap.setPixels(newPixels, 0, width, 0, 0, width, height)

        return resultBitmap
    }

    private fun applyAveragingFilter(
        pixels: IntArray,
        width: Int,
        height: Int,
        strength: Float
    ): IntArray {
        val resultPixels = IntArray(pixels.size)

        for (y in 0 until height) {
            for (x in 0 until width) {
                val index = y * width + x
                val newPixel = applyAveragingToPixel(pixels, width, height, x, y, strength)
                resultPixels[index] = newPixel
            }
        }

        return resultPixels
    }

    private fun applyAveragingToPixel(
        pixels: IntArray,
        width: Int,
        height: Int,
        x: Int,
        y: Int,
        strength: Float
    ): Int {
        val sumRed = intArrayOf(0)
        val sumGreen = intArrayOf(0)
        val sumBlue = intArrayOf(0)
        val count = intArrayOf(0)

        for (i in -1..1) {
            for (j in -1..1) {
                val neighborX = x + i
                val neighborY = y + j

                if (neighborX >= 0 && neighborX < width && neighborY >= 0 && neighborY < height) {
                    val neighborIndex = neighborY * width + neighborX
                    val neighborColor = pixels[neighborIndex]

                    sumRed[0] += Color.red(neighborColor)
                    sumGreen[0] += Color.green(neighborColor)
                    sumBlue[0] += Color.blue(neighborColor)

                    count[0]++
                }
            }
        }

        val averageRed = (sumRed[0] / count[0]).coerceIn(0, 255)
        val averageGreen = (sumGreen[0] / count[0]).coerceIn(0, 255)
        val averageBlue = (sumBlue[0] / count[0]).coerceIn(0, 255)

        return Color.rgb(averageRed, averageGreen, averageBlue)
    }

}
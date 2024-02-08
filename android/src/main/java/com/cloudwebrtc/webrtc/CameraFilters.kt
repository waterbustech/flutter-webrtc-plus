package com.cloudwebrtc.webrtc

import android.graphics.Bitmap
import android.util.Log
import com.cloudwebrtc.webrtc.models.StyleEffect
import kotlinx.coroutines.coroutineScope
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.CvType.CV_8UC1
import org.opencv.core.Mat
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

class CameraFilters {
    suspend fun applyPhotoFilter(originalBitmap: Bitmap, effect: StyleEffect): Bitmap = coroutineScope {
        when (effect) {
            StyleEffect.NORMAL -> {
                // No additional adjustments needed for the NORMAL style effect
            }
            StyleEffect.CLASSIC -> {
                return@coroutineScope applyClassicEffect(originalBitmap)
            }
            StyleEffect.VINTAGE -> {
                return@coroutineScope applyVintageEffect(originalBitmap)
            }
            StyleEffect.CINEMA -> {
                return@coroutineScope applyCinemaEffect(originalBitmap)
            }
            StyleEffect.POP_ART -> {
                return@coroutineScope applyPopArtEffect(originalBitmap)
            }
            StyleEffect.HDR -> {
                return@coroutineScope applyHDREffect(originalBitmap)
            }
        }

        return@coroutineScope originalBitmap
    }

    private fun applyCinemaEffect(bitmap: Bitmap): Bitmap {
        val mat = Mat()
        Utils.bitmapToMat(bitmap, mat)

        // Apply Cinema effect using OpenCV functions
        // Example: Convert to grayscale
        Imgproc.cvtColor(mat, mat, Imgproc.COLOR_RGBA2GRAY)

        // Example: Apply Gaussian blur
        Imgproc.GaussianBlur(mat, mat, Size(5.0, 5.0), 0.0)

        // Example: Increase contrast
        mat.convertTo(mat, CV_8UC1, 1.5, 0.0)

        // Example: Increase brightness
        mat.convertTo(mat, -1, 1.0, 50.0)

        // Convert back to Bitmap
        val resultBitmap = Bitmap.createBitmap(mat.cols(), mat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(mat, resultBitmap)

        return resultBitmap
    }

    private fun applyClassicEffect(bitmap: Bitmap): Bitmap {
        val mat = Mat()
        Utils.bitmapToMat(bitmap, mat)

        // Apply Classic effect using OpenCV functions
        // Example: Convert to grayscale
        Imgproc.cvtColor(mat, mat, Imgproc.COLOR_RGBA2GRAY)

        // Example: Apply Sepia tone
        applySepiaTone(mat)

        // Example: Increase contrast
        mat.convertTo(mat, CV_8UC1, 1.2, 0.0)

        // Example: Apply Gaussian blur
        Imgproc.GaussianBlur(mat, mat, Size(3.0, 3.0), 0.0)

        // Convert back to Bitmap
        val resultBitmap = Bitmap.createBitmap(mat.cols(), mat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(mat, resultBitmap)

        return resultBitmap
    }

    private fun applyPopArtEffect(bitmap: Bitmap): Bitmap {
        val mat = Mat()
        Utils.bitmapToMat(bitmap, mat)

        // Apply Pop Art effect using OpenCV functions
        // Example: Increase saturation
        applyColorOverlay(mat, Scalar(1.5, 1.5, 1.5, 1.0))

        // Example: Increase contrast
        mat.convertTo(mat, CV_8UC1, 1.5, 0.0)

        // Convert back to Bitmap
        val resultBitmap = Bitmap.createBitmap(mat.cols(), mat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(mat, resultBitmap)

        return resultBitmap
    }

    private fun applyVintageEffect(bitmap: Bitmap): Bitmap {
        val mat = Mat()
        Utils.bitmapToMat(bitmap, mat)

        // Apply Vintage effect using OpenCV functions
        // Example: Apply Sepia tone
        applySepiaTone(mat)

        // Example: Apply Vignette
        applyVignette(mat)

        // Example: Add film grain
        applyFilmGrain(mat)

        // Convert back to Bitmap
        val resultBitmap = Bitmap.createBitmap(mat.cols(), mat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(mat, resultBitmap)

        return resultBitmap
    }

    private fun applyHDREffect(bitmap: Bitmap): Bitmap {
        val mat = Mat()
        Utils.bitmapToMat(bitmap, mat)

        // Apply HDR effect using OpenCV functions
        // Example: Increase image contrast using CLAHE (Contrast Limited Adaptive Histogram Equalization)
        applyCLAHE(mat)

        // Convert back to Bitmap
        val resultBitmap = Bitmap.createBitmap(mat.cols(), mat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(mat, resultBitmap)

        return resultBitmap
    }

    private fun applyCLAHE(mat: Mat) {
        // Convert to grayscale
        Imgproc.cvtColor(mat, mat, Imgproc.COLOR_RGBA2GRAY)

        // Apply CLAHE
        val clahe = Imgproc.createCLAHE()
        clahe.apply(mat, mat)

        // Convert back to 4 channels (RGBA)
        Imgproc.cvtColor(mat, mat, Imgproc.COLOR_GRAY2RGBA)
    }

    private fun applyColorOverlay(mat: Mat, overlayColor: Scalar) {
        Core.addWeighted(mat, 1.0, Mat(mat.size(), CvType.CV_8UC4, overlayColor), -0.5, 0.0, mat)
    }

    private fun applySepiaTone(mat: Mat) {
        val sepiaMatrix = Mat(4, 4, CvType.CV_32F)
        sepiaMatrix.put(0, 0, 0.393, 0.769, 0.189, 0.0)
        sepiaMatrix.put(1, 0, 0.349, 0.686, 0.168, 0.0)
        sepiaMatrix.put(2, 0, 0.272, 0.534, 0.131, 0.0)
        sepiaMatrix.put(3, 0, 0.0, 0.0, 0.0, 1.0)

        Core.transform(mat, mat, sepiaMatrix)
    }

    private fun applyVignette(mat: Mat) {
        val rows = mat.rows()
        val cols = mat.cols()
        val centerX = (cols / 2).toDouble()
        val centerY = (rows / 2).toDouble()
        val radius = min(centerX, centerY) * 0.7

        for (y in 0 until rows) {
            for (x in 0 until cols) {
                val distance = sqrt((x - centerX).pow(2.0) + (y - centerY).pow(2.0))
                val vignetteValue = 1.0 - (distance / radius).pow(2.0)

                // Corrected line: Multiply each channel by the vignetteValue
                for (c in 0 until mat.channels()) {
                    mat.put(y, x, mat.get(y, x)[c] * vignetteValue)
                }
            }
        }
    }

    private fun applyFilmGrain(mat: Mat) {
        // Example: Add random noise (film grain)
        val noise = Mat(mat.size(), CvType.CV_8UC4)
        Core.randu(noise, 0.0, 255.0)
        Core.addWeighted(mat, 0.9, noise, 0.1, 0.0, mat)
    }
}

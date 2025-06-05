package com.cloudwebrtc.webrtc

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.annotation.RequiresApi
import com.cloudwebrtc.webrtc.models.CacheFrame
import com.cloudwebrtc.webrtc.utils.ImageSegmenterHelper
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import com.google.android.gms.tflite.client.TfLiteInitializationOptions
import com.google.android.gms.tflite.gpu.support.TfLiteGpu
import com.google.android.gms.tflite.java.TfLite
import com.google.mediapipe.tasks.vision.core.RunningMode
import org.webrtc.JavaI420Buffer
import org.webrtc.VideoFrame
import org.webrtc.VideoProcessor
import org.webrtc.VideoSink
import org.webrtc.VideoSource
import org.webrtc.YuvHelper
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class FlutterRTCVideoPipe: LocalVideoTrack.ExternalVideoFrameProcessing {
    var isGpuSupported = false
    private val tag: String = "[FlutterRTC-VideoPipe]"
    private var backgroundBitmap: Bitmap? = null
    private var expectConfidence = 0.7
    private var imageSegmentationHelper: ImageSegmenterHelper? = null
    private var sink: VideoSink? = null
    private val bitmapMap = HashMap<Long, CacheFrame>()
    private var lastProcessedFrameTime: Long = 0
    private val targetFrameInterval: Long = 1000 / 30 // 30 FPS
    private var virtualBackground: FlutterRTCVirtualBackground? = null
    private var beautyFilters: FlutterRTCBeautyFilters? = null

    fun initialize(context: Context) {
        Log.d(tag, "Initialized")
//        this.videoSource = videoSource
        this.virtualBackground = FlutterRTCVirtualBackground()

        if (this.beautyFilters == null) {
            this.beautyFilters = FlutterRTCBeautyFilters(context)
        }

        // Enable GPU
        val useGpuTask = TfLiteGpu.isGpuDelegateAvailable(context)

        useGpuTask.continueWith { resultUseGpu ->
            if (resultUseGpu.result) {
                isGpuSupported = true
                TfLite.initialize(context,
                    TfLiteInitializationOptions.builder()
                        .setEnableGpuDelegateSupport(resultUseGpu.result)
                        .build())
            }
        }

        this.imageSegmentationHelper = ImageSegmenterHelper(
            context = context,
            runningMode = RunningMode.LIVE_STREAM,
            imageSegmenterListener = object : ImageSegmenterHelper.SegmenterListener {
                override fun onError(error: String, errorCode: Int) {
                    // no-op
                }

                override fun onResults(resultBundle: ImageSegmenterHelper.ResultBundle) {
                    val timestampMS = resultBundle.frameTime
                    val cacheFrame: CacheFrame = bitmapMap[timestampMS] ?: return

                    val maskFloat = resultBundle.results
                    val maskWidth = resultBundle.width
                    val maskHeight = resultBundle.height

                    val bitmap = cacheFrame.originalBitmap
                    val mask = virtualBackground?.convertFloatBufferToByteBuffer(maskFloat)

                    // Convert the buffer to an array of colors
                    val colors = virtualBackground?.maskColorsFromByteBuffer(
                        mask!!,
                        maskWidth,
                        maskHeight,
                        bitmap,
                        expectConfidence,
                    )

                    // Create the segmented bitmap from the color array
                    val segmentedBitmap = virtualBackground?.createBitmapFromColors(colors!!, bitmap.width, bitmap.height)

                    if (backgroundBitmap == null) {
                        // If the background bitmap is null, return without further processing
                        return
                    }

                    // Draw the segmented bitmap on top of the background for human segments
                    val outputBitmap = virtualBackground?.drawSegmentedBackground(segmentedBitmap, backgroundBitmap)

                    if (outputBitmap != null) {
                        emitBitmapOnFrame(outputBitmap)
                    }

                    bitmapMap.remove(timestampMS)
                }
            })
    }

    fun dispose() {
        this.expectConfidence = 0.7
        this.sink = null
        this.bitmapMap.clear()
        this.backgroundBitmap = null
        this.imageSegmentationHelper = null
        this.backgroundBitmap = null
        this.virtualBackground = null
        resetBackground()
    }

    fun resetBackground() {
        this.backgroundBitmap = null
    }

    fun configurationVirtualBackground(bgBitmap: Bitmap, confidence: Double) {
        backgroundBitmap = bgBitmap
        expectConfidence = confidence
    }

    /**
     * Convert a VideoFrame to a Bitmap for further processing.
     *
     * @param videoFrame The input VideoFrame to be converted.
     * @return The corresponding Bitmap representation of the VideoFrame.
     */
    private fun videoFrameToBitmap(videoFrame: VideoFrame): Bitmap? {
        try {
            // Retain the VideoFrame to prevent it from being garbage collected
            videoFrame.retain()

            // Convert the VideoFrame to I420 format
            val buffer = videoFrame.buffer
            val i420Buffer = buffer.toI420() ?: return null // Handle null case
            val y = i420Buffer.dataY
            val u = i420Buffer.dataU
            val v = i420Buffer.dataV
            val width = i420Buffer.width
            val height = i420Buffer.height
            val strides = intArrayOf(
                i420Buffer.strideY,
                i420Buffer.strideU,
                i420Buffer.strideV
            )

            // Convert I420 format to NV12 format as required by YuvImage
            val yuvBuffer = ByteBuffer.allocateDirect(width * height * 3 / 2)
            YuvHelper.I420ToNV12(
                y,
                strides[0],
                v,
                strides[2],
                u,
                strides[1],
                yuvBuffer,
                width,
                height
            )

            // Convert YuvImage to Bitmap
            val yuvImage = YuvImage(
                yuvBuffer.array(),
                ImageFormat.NV21,  // NV21 is compatible with NV12 for BitmapFactory
                width,
                height,
                null
            )

            val outputStream = ByteArrayOutputStream()
            yuvImage.compressToJpeg(
                Rect(0, 0, width, height),
                85,
                outputStream
            )
            val jpegData = outputStream.toByteArray()

            // Release resources
            i420Buffer.release()
            videoFrame.release()

            // Convert byte array to Bitmap
            return BitmapFactory.decodeByteArray(jpegData, 0, jpegData.size)
        } catch (e: Exception) {
            // Handle any exceptions and return null
            e.printStackTrace()
            return null
        }
    }

    private fun emitBitmapOnFrame(bitmap: Bitmap) {
        // Reduce the resolution of the bitmap
        var outputBitmap = bitmap.copy(bitmap.config, true)

        val matrix = Matrix()
        outputBitmap = Bitmap.createBitmap(outputBitmap, 0, 0, outputBitmap.width, outputBitmap.height, matrix, true)

        val frame = convertBitmapToVideoFrame(outputBitmap)

        sink?.onFrame(frame)
    }

    private fun convertBitmapToVideoFrame(bitmap: Bitmap): VideoFrame? {
        // Create the buffer for the video frame
        val width = bitmap.width
        val height = bitmap.height

        // Calculate the size of the Y, U, and V buffers
        val ySize = width * height
        val uvSize = ySize / 4

        // Allocate buffers for Y, U, and V planes
        val yBuffer = ByteBuffer.allocateDirect(ySize)
        val uBuffer = ByteBuffer.allocateDirect(uvSize)
        val vBuffer = ByteBuffer.allocateDirect(uvSize)

        // Lock the bitmap to get the pixel data
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        // Fill the Y, U, and V buffers with the pixel data
        for (i in pixels.indices) {
            val color = pixels[i]

            // Extract the R, G, and B components
            val r = (color shr 16) and 0xFF
            val g = (color shr 8) and 0xFF
            val b = color and 0xFF

            // Calculate Y, U, and V values
            val y = (0.299 * r + 0.587 * g + 0.114 * b).toInt()
            val u = (-0.169 * r - 0.331 * g + 0.5 * b + 128).toInt()
            val v = (0.5 * r - 0.419 * g - 0.081 * b + 128).toInt()

            // Fill the Y buffer
            yBuffer.put(y.toByte())

            // Fill the U and V buffers (4:2:0 subsampling)
            if (i % 2 == 0 && (i / width) % 2 == 0) {
                uBuffer.put(u.toByte())
                vBuffer.put(v.toByte())
            }
        }

        // Rewind the buffers to prepare for reading
        yBuffer.rewind()
        uBuffer.rewind()
        vBuffer.rewind()

        // Create the I420 buffer
        val i420Buffer = JavaI420Buffer.wrap(
            width, height,
            yBuffer, width,
            uBuffer, width / 2,
            vBuffer, width / 2,
            null
        )

        // Create the video frame
        return VideoFrame(i420Buffer, 0, System.nanoTime())
    }

    fun setThinValue(value: Float) {
        this.beautyFilters?.setThinValue(value)
    }

    fun setBigEyesValue(value: Float) {
        this.beautyFilters?.setBigEyesValue(value)
    }

    fun setBeautyValue(value: Float) {
        this.beautyFilters?.setBeautyValue(value)
    }

    fun setLipstickValue(value: Float) {
        this.beautyFilters?.setLipstickValue(value)
    }

    fun setWhiteValue(value: Float) {
        this.beautyFilters?.setWhiteValue(value)
    }

    override fun onFrame(frame: VideoFrame) {
        if (sink == null) return

        val currentTime = System.currentTimeMillis()
        val elapsedSinceLastProcessedFrame = currentTime - lastProcessedFrameTime

        // Check if the elapsed time since the last processed frame is greater than the target interval
        if (elapsedSinceLastProcessedFrame >= targetFrameInterval) {
            // Process the current frame
            lastProcessedFrameTime = currentTime

            // Otherwise, perform segmentation on the captured frame and replace the background
            val inputFrameBitmap: Bitmap? = videoFrameToBitmap(frame)
            if (inputFrameBitmap != null) {
                val frameFiltered = beautyFilters?.processBitmap(inputFrameBitmap, frame.rotation)

                if (frameFiltered != null) {
                    if (backgroundBitmap != null) {
                        val frameTimeMs: Long = SystemClock.uptimeMillis()
                        bitmapMap[frameTimeMs] = CacheFrame(originalBitmap = frameFiltered)
                        imageSegmentationHelper?.segmentLiveStreamFrame(frameFiltered, frameTimeMs)
                    } else {
                        emitBitmapOnFrame(frameFiltered)
                    }
                }
            } else {
                Log.d(tag, "Convert video frame to bitmap failure")
            }
        }
    }

    override fun setSink(videoSink: VideoSink) {
        sink = videoSink
    }
}
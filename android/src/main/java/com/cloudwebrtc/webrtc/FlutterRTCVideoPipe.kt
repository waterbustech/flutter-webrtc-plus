package com.cloudwebrtc.webrtc

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.opengl.GLES20
import android.opengl.GLUtils
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.annotation.RequiresApi
import com.cloudwebrtc.webrtc.models.CacheFrame
import com.cloudwebrtc.webrtc.utils.ImageSegmenterHelper
import com.google.android.gms.tflite.client.TfLiteInitializationOptions
import com.google.android.gms.tflite.gpu.support.TfLiteGpu
import com.google.android.gms.tflite.java.TfLite
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.pixpark.gpupixel.GPUPixelSource.ProcessedFrameDataCallback
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.webrtc.EglBase
import org.webrtc.SurfaceTextureHelper
import org.webrtc.TextureBufferImpl
import org.webrtc.VideoFrame
import org.webrtc.VideoProcessor
import org.webrtc.VideoSink
import org.webrtc.VideoSource
import org.webrtc.YuvConverter
import org.webrtc.YuvHelper
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.Arrays

class FlutterRTCVideoPipe {
    var isGpuSupported = false
    private val tag: String = "[FlutterRTC-VideoPipe]"
    private var videoSource: VideoSource? = null
    private var textureHelper: SurfaceTextureHelper? = null
    private var backgroundBitmap: Bitmap? = null
    private var expectConfidence = 0.7
    private var imageSegmentationHelper: ImageSegmenterHelper? = null
    private var sink: VideoSink? = null
    private val bitmapMap = HashMap<Long, CacheFrame>()
    private var lastProcessedFrameTime: Long = 0
    private val targetFrameInterval: Long = 1000 / 24 // 1000 milliseconds divided by 24 FPS
    private var virtualBackground: FlutterRTCVirtualBackground? = null
    private var beautyFilters: FlutterRTCBeautyFilters? = null
    private var textureId: Int = 0

    fun initialize(context: Context, videoSource: VideoSource) {
        this.videoSource = videoSource
        this.virtualBackground = FlutterRTCVirtualBackground()

        if (this.beautyFilters == null) {
            this.beautyFilters = FlutterRTCBeautyFilters(context)

            val beautyFiltersCallBack: ProcessedFrameDataCallback = ProcessedFrameDataCallback {
                if (backgroundBitmap != null) {
                    // Segment the input bitmap using the ImageSegmentationHelper
                    val frameTimeMs: Long = SystemClock.uptimeMillis()
                    bitmapMap[frameTimeMs] = CacheFrame(originalBitmap = it)

                    imageSegmentationHelper?.segmentLiveStreamFrame(it, frameTimeMs)
                } else {
                    this.emitBitmapOnFrame(it)
                }
            }

            beautyFilters?.setCallback(beautyFiltersCallBack)
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
        processFrame()
    }

    fun dispose() {
        this.videoSource = null
        this.expectConfidence = 0.7
        this.sink = null
        this.bitmapMap.clear()
        this.backgroundBitmap = null
        this.imageSegmentationHelper = null
        this.backgroundBitmap = null
        this.virtualBackground = null
        this.textureHelper?.dispose()
        this.textureHelper = null
        resetBackground()
        releaseTexture()
    }

    fun resetBackground() {
        this.backgroundBitmap = null
    }

    fun configurationVirtualBackground(bgBitmap: Bitmap, confidence: Double) {
        backgroundBitmap = bgBitmap
        expectConfidence = confidence
    }

    private fun processFrame() {
        val eglBase = EglBase.create()
        textureHelper = SurfaceTextureHelper.create("SurfaceTextureThread", eglBase.eglBaseContext)
        videoSource?.setVideoProcessor(object : VideoProcessor {
            override fun onCapturerStarted(success: Boolean) {
                // Handle video capture start event
            }

            override fun onCapturerStopped() {
                // Handle video capture stop event
            }

            @SuppressLint("LongLogTag")
            @RequiresApi(Build.VERSION_CODES.N)
            override fun onFrameCaptured(frame: VideoFrame) {
                if (sink != null) {
                    val currentTime = System.currentTimeMillis()
                    val elapsedSinceLastProcessedFrame = currentTime - lastProcessedFrameTime

                    // Check if the elapsed time since the last processed frame is greater than the target interval
                    if (elapsedSinceLastProcessedFrame >= targetFrameInterval) {
                        // Process the current frame
                        lastProcessedFrameTime = currentTime

                        // Otherwise, perform segmentation on the captured frame and replace the background
                        val inputFrameBitmap: Bitmap? = videoFrameToBitmap(frame)
                        if (inputFrameBitmap != null) {
                            beautyFilters?.processBitmap(inputFrameBitmap)
                        } else {
                            Log.d(tag, "Convert video frame to bitmap failure")
                        }
                    }
                }
            }

            override fun setSink(videoSink: VideoSink?) {
                // Store the VideoSink to send the processed frame back to WebRTC
                // The sink will be used after segmentation processing
                sink = videoSink
            }
        })
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
        textureHelper?.handler?.post {
            // Launch a coroutine in the IO context for bitmap processing
            CoroutineScope(Dispatchers.IO).launch {
                // Reduce the resolution of the bitmap
                val scaledBitmap = Bitmap.createScaledBitmap(bitmap, bitmap.width / 2, bitmap.height / 2, true)
                var outputBitmap = scaledBitmap.copy(scaledBitmap.config, true)

                val matrix = Matrix()
                matrix.postScale(1f, -1f) // Flip vertically
                outputBitmap = Bitmap.createBitmap(outputBitmap, 0, 0, outputBitmap.width, outputBitmap.height, matrix, true)

                val textureId = if (textureId == 0) {
                    createTexture(outputBitmap)
                } else {
                    GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
                    GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, outputBitmap, 0)
                    textureId
                }

                var i420Buf: VideoFrame.I420Buffer? = null
                var buffer: TextureBufferImpl? = null

                try {
                    val yuvConverter = YuvConverter()

                    buffer = TextureBufferImpl(
                        outputBitmap.width,
                        outputBitmap.height,
                        VideoFrame.TextureBuffer.Type.RGB,
                        textureId,
                        Matrix(),
                        textureHelper!!.handler,
                        yuvConverter,
                        null
                    )

                    i420Buf = yuvConverter.convert(buffer)

                    if (i420Buf != null) {
                        val frameTimeMs: Long = SystemClock.uptimeMillis()
                        val outputVideoFrame = VideoFrame(i420Buf, 0, frameTimeMs * 1000)

                        withContext(Dispatchers.Main) {
                            sink?.onFrame(outputVideoFrame)
                        }

                        // Release I420 buffer after use
                        i420Buf.release()
                    }

                    yuvConverter.release()
                } finally {
                    // Ensure the buffer is released even in case of exceptions
                    buffer?.release()
                    outputBitmap.recycle()
                }
            }
        }
    }

    private fun createTexture(bitmap: Bitmap): Int {
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[0])

        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)

        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        return textures[0]
    }

    private fun releaseTexture() {
        if (textureId != 0) {
            val textures = intArrayOf(textureId)
            GLES20.glDeleteTextures(1, textures, 0)
            textureId = 0
        }
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
}
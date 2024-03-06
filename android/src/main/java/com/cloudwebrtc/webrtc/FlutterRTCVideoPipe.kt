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
import com.cloudwebrtc.webrtc.models.StyleEffect
import com.cloudwebrtc.webrtc.utils.ImageSegmenterHelper
import com.google.android.gms.tflite.client.TfLiteInitializationOptions
import com.google.android.gms.tflite.gpu.support.TfLiteGpu
import com.google.android.gms.tflite.java.TfLite
import com.google.mediapipe.tasks.vision.core.RunningMode
import kotlinx.coroutines.runBlocking
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
import java.util.concurrent.Executors

class FlutterRTCVideoPipe {
    var isGpuSupported = false
    private val tag: String = "[FlutterRTC-VideoPipe]"
    private var videoSource: VideoSource? = null
    private var textureHelper: SurfaceTextureHelper? = null
    private var backgroundBitmap: Bitmap? = null
    private var photoEffect: StyleEffect = StyleEffect.NORMAL
    private var expectConfidence = 0.7
    private var imageSegmentationHelper: ImageSegmenterHelper? = null
    private var sink: VideoSink? = null
    private val bitmapMap = HashMap<Long, CacheFrame>()
    private var lastProcessedFrameTime: Long = 0
    private val targetFrameInterval: Long = 1000 / 24 // 1000 milliseconds divided by 24 FPS
    private val virtualBackground: FlutterRTCVirtualBackground = FlutterRTCVirtualBackground()

    // Executor for background segmentation
    private val executor = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors())

    fun initialize(context: Context, videoSource: VideoSource) {
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

        this.videoSource = videoSource
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
                    val mask = virtualBackground.convertFloatBufferToByteBuffer(maskFloat)

                    // Convert the buffer to an array of colors
                    val colors = virtualBackground.maskColorsFromByteBuffer(
                        mask,
                        maskWidth,
                        maskHeight,
                        bitmap,
                        expectConfidence,
                    )

                    // Create the segmented bitmap from the color array
                    val segmentedBitmap = virtualBackground.createBitmapFromColors(colors, bitmap.width, bitmap.height)

                    if (backgroundBitmap == null) {
                        // If the background bitmap is null, return without further processing
                        return
                    }

                    // Draw the segmented bitmap on top of the background for human segments
                    val outputBitmap = virtualBackground.drawSegmentedBackground(segmentedBitmap, backgroundBitmap, cacheFrame.originalFrame.rotation)

                    if (outputBitmap != null) {
                        emitBitmapOnFrame(outputBitmap, cacheFrame)
                    }

                    bitmapMap.remove(timestampMS)
                }
            })
        processFrame()
    }

    fun dispose() {
        this.videoSource = null
        this.expectConfidence = 0.7
        resetBackground()
    }

    fun resetBackground() {
        this.backgroundBitmap = null
    }

    fun configurationVirtualBackground(bgBitmap: Bitmap, confidence: Double) {
        backgroundBitmap = bgBitmap
        expectConfidence = confidence
    }

    fun setBeautyFilter(effect: StyleEffect) {
        photoEffect = effect
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
                            runBlocking {
                                if (backgroundBitmap != null) {
                                    // Run segmentation in the background
                                    val resizeBitmap = virtualBackground.resizeBitmapKeepAspectRatio(inputFrameBitmap, 512)

                                    // Segment the input bitmap using the ImageSegmentationHelper
                                    val frameTimeMs: Long = SystemClock.uptimeMillis()
                                    bitmapMap[frameTimeMs] = CacheFrame(originalBitmap = resizeBitmap, originalFrame = frame)

                                    imageSegmentationHelper?.segmentLiveStreamFrame(resizeBitmap, frameTimeMs)
                                } else {
                                    val cacheFrame = CacheFrame(originalBitmap = inputFrameBitmap, originalFrame = frame)
                                    bitmapMap[lastProcessedFrameTime] = cacheFrame
                                    emitBitmapOnFrame(inputFrameBitmap, cacheFrame)
                                    bitmapMap.remove(lastProcessedFrameTime)
                                }
                            }
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
        // Retain the VideoFrame to prevent it from being garbage collected
        videoFrame.retain()

        // Convert the VideoFrame to I420 format
        val buffer = videoFrame.buffer
        val i420Buffer = buffer.toI420()
        val y = i420Buffer!!.dataY
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
        val chromaWidth = (width + 1) / 2
        val chromaHeight = (height + 1) / 2
        val minSize = width * height + chromaWidth * chromaHeight * 2
        val yuvBuffer = ByteBuffer.allocateDirect(minSize)
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
        // Remove leading 0 from the ByteBuffer
        val cleanedArray =
            Arrays.copyOfRange(yuvBuffer.array(), yuvBuffer.arrayOffset(), minSize)
        val yuvImage = YuvImage(
            cleanedArray,
            ImageFormat.NV21,
            width,
            height,
            null
        )
        i420Buffer.release()
        videoFrame.release()

        // Convert YuvImage to byte array
        val outputStream = ByteArrayOutputStream()
        yuvImage.compressToJpeg(
            Rect(0, 0, yuvImage.width, yuvImage.height),
            85,
            outputStream
        )
        val jpegData = outputStream.toByteArray()

        // Convert byte array to Bitmap
        return BitmapFactory.decodeByteArray(jpegData, 0, jpegData.size)
    }

    private fun emitBitmapOnFrame(originalBitmap: Bitmap, cacheFrame: CacheFrame) {
        // Create a new VideoFrame from the processed bitmap
        val yuvConverter = YuvConverter()
        textureHelper?.handler?.post {
            val textures = IntArray(1)
            GLES20.glGenTextures(1, textures, 0)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[0])

            // Adjust texture coordinates if needed
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D,
                GLES20.GL_TEXTURE_MIN_FILTER,
                GLES20.GL_NEAREST
            )
            GLES20.glTexParameteri(
                GLES20.GL_TEXTURE_2D,
                GLES20.GL_TEXTURE_MAG_FILTER,
                GLES20.GL_NEAREST
            )

            // Create a copy of the original bitmap
            var outputBitmap = originalBitmap.copy(originalBitmap.config, true)

            // Check and adjust bitmap orientation if needed
            val matrix = Matrix()
            matrix.postScale(1f, -1f) // Flip vertically
            outputBitmap = Bitmap.createBitmap(outputBitmap, 0, 0, outputBitmap.width, outputBitmap.height, matrix, true)

            // Update texture with adjusted bitmap
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, outputBitmap, 0)

            val buffer = TextureBufferImpl(
                outputBitmap.width,
                outputBitmap.height,
                VideoFrame.TextureBuffer.Type.RGB,
                textures[0],
                Matrix(),
                textureHelper!!.handler,
                yuvConverter,
                null
            )
            val i420Buf = yuvConverter.convert(buffer)

            if (i420Buf != null) {
                // Create the output VideoFrame and send it to the sink
                val outputVideoFrame =
                    VideoFrame(i420Buf, cacheFrame.originalFrame.rotation, cacheFrame.originalFrame.timestampNs)
                sink?.onFrame(outputVideoFrame)
            } else {
                // If the conversion fails, send the original frame to the sink
                sink?.onFrame(cacheFrame.originalFrame)
            }
        }
    }
}
//
//  RTCBeautyFilter.mm
//  flutter_webrtc
//
//  Created by lambiengcode on 19/03/2024.
//

#import "RTCBeautyFilter.h"
#import "gpupixel/gpupixel.h"

using namespace gpupixel;

static void releaseBGRAData(void *releaseRefCon, const void *baseAddress) {
    free((void*)baseAddress);
}

@interface RTCBeautyFilter () {
    std::shared_ptr<SourceRawData> sourceRawData;
    std::shared_ptr<BeautyFaceFilter> beautyFaceFilter;
    std::shared_ptr<SinkRawData> sinkRawData;
    std::shared_ptr<FaceReshapeFilter> faceReshapeFilter;
    std::shared_ptr<gpupixel::FaceMakeupFilter> lipstickFilter;
    std::shared_ptr<gpupixel::FaceMakeupFilter> blusherFilter;
    std::shared_ptr<gpupixel::FaceDetector> faceDetector;
}

@end

@implementation RTCBeautyFilter

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)releaseInstance {
    NSLog(@"RTCBeautyFilter deallocated");
    
    // Clean up resources
    sourceRawData.reset();
    beautyFaceFilter.reset();
    sinkRawData.reset();
    faceReshapeFilter.reset();
    lipstickFilter.reset();
    blusherFilter.reset();
    faceDetector.reset();
}

- (void)setup {
    // Init video filter
    [self initVideoFilter];
}

- (void)initVideoFilter {
    sourceRawData = SourceRawData::Create();
    
    // Create filters
    lipstickFilter = LipstickFilter::Create();
    blusherFilter = BlusherFilter::Create();
    faceReshapeFilter = FaceReshapeFilter::Create();
    faceDetector = FaceDetector::Create();
    beautyFaceFilter = BeautyFaceFilter::Create();
    
    // Create result handler
    sinkRawData = SinkRawData::Create();
    
    sourceRawData->AddSink(lipstickFilter)
    ->AddSink(blusherFilter)
    ->AddSink(faceReshapeFilter)
    ->AddSink(beautyFaceFilter)
    ->AddSink(sinkRawData);
}

#pragma mark - Property assignment

- (void)setBeautyValue:(CGFloat)value {
    _beautyValue = value;
    beautyFaceFilter->SetBlurAlpha(value);
}

- (void)setWhithValue:(CGFloat)value {
    _whithValue = value;
    beautyFaceFilter->SetWhite(value);
}

- (void)setThinFaceValue:(CGFloat)value {
    _thinFaceValue = value;
    faceReshapeFilter->SetFaceSlimLevel(value);
}

- (void)setEyeValue:(CGFloat)value {
    _eyeValue = value;
    faceReshapeFilter->SetEyeZoomLevel(value);
}

- (void)setLipstickValue:(CGFloat)value {
    _lipstickValue = value;
    lipstickFilter->SetBlendLevel(value);
}

- (void)setBlusherValue:(CGFloat)value {
    _blusherValue = value;
    blusherFilter->SetBlendLevel(value);
}

- (CVPixelBufferRef)processVideoFrame:(CVPixelBufferRef)imageBuffer {
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    auto width = CVPixelBufferGetWidth(imageBuffer);
    auto height = CVPixelBufferGetHeight(imageBuffer);
    auto stride = CVPixelBufferGetBytesPerRow(imageBuffer);
    auto pixels = (const uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    std::vector<float> landmarks =
    faceDetector->Detect(pixels, width, height, stride,
                         GPUPIXEL_MODE_FMT_VIDEO, GPUPIXEL_FRAME_TYPE_BGRA);
    
    if (!landmarks.empty()) {
        lipstickFilter->SetFaceLandmarks(landmarks);
        blusherFilter->SetFaceLandmarks(landmarks);
        faceReshapeFilter->SetFaceLandmarks(landmarks);
    }
    
    sourceRawData->ProcessData(pixels, width, height, stride, GPUPIXEL_FRAME_TYPE_BGRA);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    // Get processed result
    const uint8_t* processedData = sinkRawData->GetRgbaBuffer();
    
    // Process and return the filtered pixel buffer
    if (processedData) {
        return [self createPixelBufferFromData:processedData
                                         width:(int)width
                                        height:(int)height];
    }
    
    // Return nil if processing failed
    return nil;
}

- (CVPixelBufferRef)createPixelBufferFromData:(const uint8_t*)data width:(int)width height:(int)height {
    CVPixelBufferRef pixelBuffer = NULL;
    
    size_t stride = width * 4;
    
    uint8_t* bgraData = (uint8_t*)malloc(stride * height);
    if (!bgraData) {
        NSLog(@"Error: Unable to allocate memory for BGRA pixel data");
        return nil;
    }
    
    // Convert RGBA to BGRA
    for (int i = 0; i < width * height; ++i) {
        bgraData[i * 4 + 0] = data[i * 4 + 2];  // Blue
        bgraData[i * 4 + 1] = data[i * 4 + 1];  // Green
        bgraData[i * 4 + 2] = data[i * 4 + 0];  // Red
        bgraData[i * 4 + 3] = data[i * 4 + 3];  // Alpha
    }
    
    // Create pixel buffer attributes
    NSDictionary *options = @{
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    
    // Create pixel buffer with a release callback to free bgraData
    CVReturn result = CVPixelBufferCreateWithBytes(
                                                   kCFAllocatorDefault,
                                                   width,
                                                   height,
                                                   kCVPixelFormatType_32BGRA,
                                                   (void *)bgraData,
                                                   stride,
                                                   releaseBGRAData,  // Custom deallocator
                                                   NULL,  // No reference context needed
                                                   (__bridge CFDictionaryRef)options,
                                                   &pixelBuffer
                                                   );
    
    if (result != kCVReturnSuccess) {
        NSLog(@"Error: Unable to create pixel buffer");
        free(bgraData);  // Free the buffer manually in case of failure
        return nil;
    }
    
    return pixelBuffer;  // Caller is responsible for releasing this
}

size_t getBufferSizeFromPixelBuffer(CVPixelBufferRef pixelBuffer) {
    // Get the bytes per row and height of the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    // Calculate the buffer size
    size_t bufferSize = bytesPerRow * height;
    
    return bufferSize;
}

NSString* getPixelFormatName(CVPixelBufferRef pixelBuffer) {
    OSType p = CVPixelBufferGetPixelFormatType(pixelBuffer);
    switch (p) {
        case kCVPixelFormatType_1Monochrome:                   return @"kCVPixelFormatType_1Monochrome";
        case kCVPixelFormatType_2Indexed:                      return @"kCVPixelFormatType_2Indexed";
        case kCVPixelFormatType_4Indexed:                      return @"kCVPixelFormatType_4Indexed";
        case kCVPixelFormatType_8Indexed:                      return @"kCVPixelFormatType_8Indexed";
        case kCVPixelFormatType_1IndexedGray_WhiteIsZero:      return @"kCVPixelFormatType_1IndexedGray_WhiteIsZero";
        case kCVPixelFormatType_2IndexedGray_WhiteIsZero:      return @"kCVPixelFormatType_2IndexedGray_WhiteIsZero";
        case kCVPixelFormatType_4IndexedGray_WhiteIsZero:      return @"kCVPixelFormatType_4IndexedGray_WhiteIsZero";
        case kCVPixelFormatType_8IndexedGray_WhiteIsZero:      return @"kCVPixelFormatType_8IndexedGray_WhiteIsZero";
        case kCVPixelFormatType_16BE555:                       return @"kCVPixelFormatType_16BE555";
        case kCVPixelFormatType_16LE555:                       return @"kCVPixelFormatType_16LE555";
        case kCVPixelFormatType_16LE5551:                      return @"kCVPixelFormatType_16LE5551";
        case kCVPixelFormatType_16BE565:                       return @"kCVPixelFormatType_16BE565";
        case kCVPixelFormatType_16LE565:                       return @"kCVPixelFormatType_16LE565";
        case kCVPixelFormatType_24RGB:                         return @"kCVPixelFormatType_24RGB";
        case kCVPixelFormatType_24BGR:                         return @"kCVPixelFormatType_24BGR";
        case kCVPixelFormatType_32ARGB:                        return @"kCVPixelFormatType_32ARGB";
        case kCVPixelFormatType_32BGRA:                        return @"kCVPixelFormatType_32BGRA";
        case kCVPixelFormatType_32ABGR:                        return @"kCVPixelFormatType_32ABGR";
        case kCVPixelFormatType_32RGBA:                        return @"kCVPixelFormatType_32RGBA";
        case kCVPixelFormatType_64ARGB:                        return @"kCVPixelFormatType_64ARGB";
        case kCVPixelFormatType_48RGB:                         return @"kCVPixelFormatType_48RGB";
        case kCVPixelFormatType_32AlphaGray:                   return @"kCVPixelFormatType_32AlphaGray";
        case kCVPixelFormatType_16Gray:                        return @"kCVPixelFormatType_16Gray";
        case kCVPixelFormatType_30RGB:                         return @"kCVPixelFormatType_30RGB";
        case kCVPixelFormatType_422YpCbCr8:                    return @"kCVPixelFormatType_422YpCbCr8";
        case kCVPixelFormatType_4444YpCbCrA8:                  return @"kCVPixelFormatType_4444YpCbCrA8";
        case kCVPixelFormatType_4444YpCbCrA8R:                 return @"kCVPixelFormatType_4444YpCbCrA8R";
        case kCVPixelFormatType_4444AYpCbCr8:                  return @"kCVPixelFormatType_4444AYpCbCr8";
        case kCVPixelFormatType_4444AYpCbCr16:                 return @"kCVPixelFormatType_4444AYpCbCr16";
        case kCVPixelFormatType_444YpCbCr8:                    return @"kCVPixelFormatType_444YpCbCr8";
        case kCVPixelFormatType_422YpCbCr16:                   return @"kCVPixelFormatType_422YpCbCr16";
        case kCVPixelFormatType_422YpCbCr10:                   return @"kCVPixelFormatType_422YpCbCr10";
        case kCVPixelFormatType_444YpCbCr10:                   return @"kCVPixelFormatType_444YpCbCr10";
        case kCVPixelFormatType_420YpCbCr8Planar:              return @"kCVPixelFormatType_420YpCbCr8Planar";
        case kCVPixelFormatType_420YpCbCr8PlanarFullRange:     return @"kCVPixelFormatType_420YpCbCr8PlanarFullRange";
        case kCVPixelFormatType_422YpCbCr_4A_8BiPlanar:        return @"kCVPixelFormatType_422YpCbCr_4A_8BiPlanar";
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:  return @"kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange";
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:   return @"kCVPixelFormatType_420YpCbCr8BiPlanarFullRange";
        case kCVPixelFormatType_422YpCbCr8_yuvs:               return @"kCVPixelFormatType_422YpCbCr8_yuvs";
        case kCVPixelFormatType_422YpCbCr8FullRange:           return @"kCVPixelFormatType_422YpCbCr8FullRange";
        case kCVPixelFormatType_OneComponent8:                 return @"kCVPixelFormatType_OneComponent8";
        case kCVPixelFormatType_TwoComponent8:                 return @"kCVPixelFormatType_TwoComponent8";
        case kCVPixelFormatType_30RGBLEPackedWideGamut: return @"kCVPixelFormatType_30RGBLEPackedWideGamut";
        case kCVPixelFormatType_OneComponent16Half: return @"kCVPixelFormatType_OneComponent16Half";
        case kCVPixelFormatType_OneComponent32Float: return @"kCVPixelFormatType_OneComponent32Float";
        case kCVPixelFormatType_TwoComponent16Half: return @"kCVPixelFormatType_TwoComponent16Half";
        case kCVPixelFormatType_TwoComponent32Float: return @"kCVPixelFormatType_TwoComponent32Float";
        case kCVPixelFormatType_64RGBAHalf: return @"kCVPixelFormatType_64RGBAHalf";
        case kCVPixelFormatType_128RGBAFloat: return @"kCVPixelFormatType_128RGBAFloat";
        case kCVPixelFormatType_14Bayer_GRBG: return @"kCVPixelFormatType_14Bayer_GRBG";
        case kCVPixelFormatType_14Bayer_RGGB: return @"kCVPixelFormatType_14Bayer_RGGB";
        case kCVPixelFormatType_14Bayer_BGGR: return @"kCVPixelFormatType_14Bayer_BGGR";
        case kCVPixelFormatType_14Bayer_GBRG: return @"kCVPixelFormatType_14Bayer_GBRG";
        default: return @"UNKNOWN";
    }
}

@end

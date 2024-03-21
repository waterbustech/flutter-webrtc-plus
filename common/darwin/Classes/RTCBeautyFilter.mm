//
//  RTCBeautyFilter.mm
//  SimpleVideoFilter
//
//  Created by PixPark on 2021/8/25.
//

#import "RTCBeautyFilter.h"
#import "gpupixel/gpupixel.h"

using namespace gpupixel;

@interface RTCBeautyFilter () {
    std::shared_ptr<SourceRawDataInput> gpuPixelRawInput;
    std::shared_ptr<BeautyFaceFilter> beauty_face_filter_;
    std::shared_ptr<TargetRawDataOutput> targetRawOutput_;
    std::shared_ptr<FaceReshapeFilter> face_reshape_filter_;
    std::shared_ptr<gpupixel::FaceMakeupFilter> lipstick_filter_;
    std::shared_ptr<gpupixel::FaceMakeupFilter> blusher_filter_;
}

@end

@implementation RTCBeautyFilter

@synthesize delegate = _delegate;

- (instancetype)initWithDelegate:(id<RTCBeautyFilterDelegate>)delegate {
    self = [super init];
    if (self) {
        self.delegate = delegate;
        [self setup];
    }
    return self;
}

- (void)setup {
    // Init video filter
    [self initVideoFilter];
}

- (void)initVideoFilter {
    gpupixel::GPUPixelContext::getInstance()->runSync([&] {
        gpuPixelRawInput = SourceRawDataInput::create();
        
        // Create filters
        lipstick_filter_ = LipstickFilter::create();
        blusher_filter_ = BlusherFilter::create();
        face_reshape_filter_ = FaceReshapeFilter::create();
        
        gpuPixelRawInput->RegLandmarkCallback([=](std::vector<float> landmarks) {
            lipstick_filter_->SetFaceLandmarks(landmarks);
            blusher_filter_->SetFaceLandmarks(landmarks);
            face_reshape_filter_->SetFaceLandmarks(landmarks);
        });
        
        // Create filter
        targetRawOutput_ = TargetRawDataOutput::create();
        beauty_face_filter_ = BeautyFaceFilter::create();
        
        id<RTCBeautyFilterDelegate> delegatePtr = _delegate;
        
        RawOutputCallback callback = [delegatePtr](const uint8_t* data, int width, int height, int64_t ts) {
            CVPixelBufferRef pixelBuffer = NULL;
            
            size_t stride = width * 4;
            
            // Create a new buffer to store ARGB pixel data
            uint8_t* argbData = (uint8_t*)malloc(stride * height);
            if (!argbData) {
                NSLog(@"Error: Unable to allocate memory for ARGB pixel data");
                return;
            }
            
            // Convert ABGR or BGRA to ARGB
            for (int i = 0; i < width * height; ++i) {
                argbData[i * 4 + 0] = data[i * 4 + 3];  // Alpha
                argbData[i * 4 + 1] = data[i * 4 + 0];  // Red
                argbData[i * 4 + 2] = data[i * 4 + 1];  // Green
                argbData[i * 4 + 3] = data[i * 4 + 2];  // Blue
            }
            
            // Create pixel buffer attributes
            NSDictionary *options = @{
                (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
                (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
            };
            
            // Create pixel buffer
            CVReturn result = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                                           width,
                                                           height,
                                                           kCVPixelFormatType_32ARGB,
                                                           (void *)argbData,
                                                           stride,
                                                           NULL,
                                                           NULL,
                                                           (__bridge CFDictionaryRef)options,
                                                           &pixelBuffer);
            
            free(argbData);  // Free the memory allocated for ARGB data
            
            if (result != kCVReturnSuccess) {
                NSLog(@"Error: Unable to create CVPixelBuffer");
                return;
            }
            
            if (delegatePtr) {
                [delegatePtr didReceivePixelBuffer:pixelBuffer width:width height:height timestamp:ts];
            }
            
            CVPixelBufferRelease(pixelBuffer);
        };
        
        
        // Truyền biến lambda vào hàm setPixelsCallbck
        targetRawOutput_->setPixelsCallbck(callback);
        
        
        gpuPixelRawInput->addTarget(lipstick_filter_)
        ->addTarget(blusher_filter_)
        ->addTarget(face_reshape_filter_)
        ->addTarget(beauty_face_filter_)
        ->addTarget(targetRawOutput_);
    });
}

#pragma mark - Property assignment

- (void)setBeautyValue:(CGFloat)value {
    _beautyValue = value;
    beauty_face_filter_->setBlurAlpha(value);
}

- (void)setWhithValue:(CGFloat)value {
    _whithValue = value;
    beauty_face_filter_->setWhite(value);
}

- (void)setThinFaceValue:(CGFloat)value {
    _thinFaceValue = value;
    face_reshape_filter_->setFaceSlimLevel(value);
}

- (void)setEyeValue:(CGFloat)value {
    _eyeValue = value;
    face_reshape_filter_->setEyeZoomLevel(value);
}

- (void)setLipstickValue:(CGFloat)value {
    _lipstickValue = value;
    lipstick_filter_->setBlendLevel(value);
}

- (void)setBlusherValue:(CGFloat)value {
    _blusherValue = value;
    blusher_filter_->setBlendLevel(value);
}

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer {
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    auto width = CVPixelBufferGetWidth(imageBuffer);
    auto height = CVPixelBufferGetHeight(imageBuffer);
    auto stride = CVPixelBufferGetBytesPerRow(imageBuffer)/4;
    auto pixels = (const uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    gpuPixelRawInput->uploadBytes(pixels, width, height, stride);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
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

//
//  HPImageOperation.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPCacheManager.h"
#import "HPImageOperation.h"
#import "UIScreen+HPScaleAdditions.h"


static inline double radians (double degrees) {return degrees * M_PI/180;}

NSString * const HPImageOperationCacheMetaOrientationKey = @"HPOrientation";



@interface HPImageOperation (PrivateMethods)
- (void)sendProcessedImageToBlocks:(id)image;
- (void)sendProcessedImageToBlocks:(id)image withError:(NSError *)error;
@end


@implementation HPImageOperation

@synthesize indexPath = _indexPath;
@synthesize storageKey = _storageKey;
@synthesize outputFormat = _outputFormat;
@synthesize storePermanently = _storePermanently;
@synthesize identifier = _identifier;

+ (NSString *)cacheKeyWithHash:(NSString *)hash 
                    targetSize:(CGSize)targetSize 
                   contentMode:(UIViewContentMode)contentMode 
                   imageFormat:(HPImageFormat)format {
	NSString *extension;
	
	switch (format) {
		case HPImageFormatPNG:
			extension = @"png";
			break;
		default:
			extension = @"jpg";
			break;
	}
	
	return [NSString stringWithFormat:@"%@_%1.0f_%1.0f_%d.%@", 
			hash, targetSize.width, targetSize.height, contentMode, extension];
}

- (id)initWithImage:(UIImage *)image 
         targetSize:(CGSize)targetSize 
        contentMode:(UIViewContentMode)contentMode 
           cacheKey:(NSString *)cacheKey 
        imageFormat:(HPImageFormat)format {
    self = [super init];
    
	if (self) {
		CGFloat screenScaleRatio = [[UIScreen mainScreen] scaleRatio];
		
        _indexPath = nil;
		_imageFormat = format;
		_sourceImage = [image retain];
		_completionBlocks = [[NSMutableSet alloc] init];
		_contentMode = contentMode;
        _storePermanently = NO;
		_outputFormat = HPImageOperationOutputFormatImage;
		_targetSize = CGSizeMake(targetSize.width * screenScaleRatio, 
								 targetSize.height * screenScaleRatio);
		
		if (cacheKey != nil) {
			_cacheKey = [[HPImageOperation cacheKeyWithHash:cacheKey 
												 targetSize:targetSize 
												contentMode:_contentMode 
												imageFormat:_imageFormat] copy];
		}
	}
	
	return self;
}

- (void)main {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    CGFloat screenScaleRatio = [[UIScreen mainScreen] scaleRatio];
    
    if ((_sourceImage != nil || _cacheKey != nil) && ![self isCancelled]) {
        UIImage *finalImage = nil;
        BOOL alreadyCached = NO;
        
        if (_storageKey != nil && _sourceImage == nil) {
            HPCacheItem *storedItem = [[HPCacheManager sharedManager] storedItemForStorageKey:_storageKey];

            if (storedItem != nil) {
                CGDataProviderRef storageProvider = CGDataProviderCreateWithCFData((CFDataRef)storedItem.cacheData);
                CGImageRef storageImage = NULL;
                
                if ([storedItem.MIMEType isEqualToString:@"image/png"]) {
                    storageImage = CGImageCreateWithPNGDataProvider(storageProvider, NULL, YES, kCGRenderingIntentDefault);
                } else if ([storedItem.MIMEType isEqualToString:@"image/jpeg"]) {
                    storageImage = CGImageCreateWithJPEGDataProvider(storageProvider, NULL, YES, kCGRenderingIntentDefault);
                }
                
                if (storageImage != NULL) {
                    UIImageOrientation orientation = UIImageOrientationUp;
                    
                    if (storedItem.metaData != nil) {
                        NSNumber *orientationData = [storedItem.metaData objectForKey:HPImageOperationCacheMetaOrientationKey];
                        
                        if (orientationData != nil) {
                            orientation = [orientationData integerValue];
                        }
                    }
                    
                    _sourceImage = [[UIImage alloc] initWithCGImage:storageImage
                                                              scale:screenScaleRatio 
                                                        orientation:orientation];
                    
                    CFRelease(storageImage);
                }
                
                CFRelease(storageProvider);
            }
        }
        
        if (_cacheKey != nil && !_storePermanently) {
            HPCacheItem *cachedItem = [[HPCacheManager sharedManager] cachedItemForCacheKey:_cacheKey];
            
            if (cachedItem != nil) {
                CGDataProviderRef imageProvider = CGDataProviderCreateWithCFData((CFDataRef)cachedItem.cacheData);
                CGImageRef cacheImage = NULL;
                
                if ([cachedItem.MIMEType isEqualToString:@"image/png"]) {
                    cacheImage = CGImageCreateWithPNGDataProvider(imageProvider, NULL, YES, kCGRenderingIntentDefault);
                } else if ([cachedItem.MIMEType isEqualToString:@"image/jpeg"]) {
                    cacheImage = CGImageCreateWithJPEGDataProvider(imageProvider, NULL, YES, kCGRenderingIntentDefault);
                }
                
                if (cacheImage != NULL) {
                    alreadyCached = YES;
                    
                    UIImageOrientation orientation = UIImageOrientationUp;
                    
                    if (cachedItem.metaData != nil) {
                        NSNumber *orientationData = [cachedItem.metaData objectForKey:HPImageOperationCacheMetaOrientationKey];
                        
                        if (orientationData != nil) {
                            orientation = [orientationData integerValue];
                        }
                    }
                    
                    finalImage = [[UIImage alloc] initWithCGImage:cacheImage
                                                            scale:screenScaleRatio
                                                      orientation:orientation];
                    
                    CFRelease(cacheImage);
                }
                
                CFRelease(imageProvider);
            }
        }
        
        if (_sourceImage != nil && finalImage == nil) {
            CGSize imageSize;
            
            switch (_sourceImage.imageOrientation) {
                case UIImageOrientationLeft:
                case UIImageOrientationRight:
                    imageSize = CGSizeMake(_sourceImage.size.height, _sourceImage.size.width);
                    
                    break;
                default:
                    imageSize = _sourceImage.size;
                    
                    break;
            }
            
            if (_targetSize.width > 0.0 && _targetSize.height > 0.0 && 
                (_targetSize.width != imageSize.width || _targetSize.height != imageSize.height)) {
                CGImageRef cgImage = NULL;
                
                double scale;
                
                switch (_contentMode) {
                    case UIViewContentModeTop:
                    case UIViewContentModeScaleAspectFill:
                        scale = MAX(_targetSize.width / imageSize.width, _targetSize.height / imageSize.height);
                        break;
                    case UIViewContentModeCenter:
                        scale = 1.0;
                        break;
                    default:
                        scale = MIN(_targetSize.width / imageSize.width, _targetSize.height / imageSize.height);
                        break;
                }
                
                imageSize.width = ceil(imageSize.width * scale);
                imageSize.height = ceil(imageSize.height * scale);
                
                if (![self isCancelled]) {
                    CGRect targetRect;
                    CGSize targetSize;
                    
                    switch (_contentMode) {
                        case UIViewContentModeTop:
                            targetSize = _targetSize;
                            targetRect = CGRectMake(_targetSize.width - imageSize.width,
                                                    _targetSize.height - imageSize.height,
                                                    imageSize.width, imageSize.height);
                            
                            break;
                        case UIViewContentModeScaleAspectFill:
                            targetSize = _targetSize;
                            targetRect = CGRectMake(floor((_targetSize.width - imageSize.width) / 2), 
                                                    floor((_targetSize.height - imageSize.height) / 2), 
                                                    imageSize.width, imageSize.height);
                            
                            break;
                        case UIViewContentModeCenter:
                            targetSize = _targetSize;
                            targetRect = CGRectMake(floor((_targetSize.width - imageSize.width) / 2),
                                                    floor((_targetSize.height - imageSize.height) / 2),
                                                    imageSize.width, imageSize.height);
                            
                            break;
                        default:
                            targetSize = imageSize;
                            targetRect = CGRectMake(0.0, 0.0, imageSize.width, imageSize.height);
                            break;
                    }

                    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
                    CGSize contextSize;
                    
                    switch (_sourceImage.imageOrientation) {
                        case UIImageOrientationLeft:
                        case UIImageOrientationRight:
                            contextSize = CGSizeMake(targetSize.height, targetSize.width);
                            
                            break;
                        default:
                            contextSize = targetSize;
                            
                            break;
                    }
                    
                    CGContextRef context = CGBitmapContextCreate(NULL, // Image data
                                                                 contextSize.width, // Width
                                                                 contextSize.height, // Height
                                                                 8, // Bits per component
                                                                 4 * contextSize.width, // Bits per row
                                                                 colorSpace, // Color space
                                                                 kCGImageAlphaPremultipliedLast // Alpha mode
                                                                 );
                    
                    switch (_sourceImage.imageOrientation) {
                        case UIImageOrientationLeft: {
                            CGContextRotateCTM(context, radians(90.0));
                            CGContextTranslateCTM(context, 0.0, -1.0 * targetSize.height);
                            
                            break;
                        }
                        case UIImageOrientationRight: {
                            CGContextRotateCTM(context, radians(-90.0));
                            CGContextTranslateCTM(context, -1.0 * targetSize.width, 0.0);
                            
                            break;
                        }
                        case UIImageOrientationDown: {
                            CGContextTranslateCTM(context, targetSize.width, targetSize.height);
                            CGContextRotateCTM(context, radians(-180.0));
                            
                            break;
                        }
                        default:
                            break;
                    }
                    
                    if (context != nil) {
                        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
                        CGContextSetBlendMode(context, kCGBlendModeCopy);
                        
                        if (![self isCancelled]) {
                            CGContextDrawImage(context, targetRect, [_sourceImage CGImage]);
                        }
                        
                        if (![self isCancelled]) {
                            cgImage = CGBitmapContextCreateImage(context);
                        }
                        
                        CGContextRelease(context);
                    }
                    
                    CGColorSpaceRelease(colorSpace);
                    
                    if (cgImage != NULL) {
                        if (screenScaleRatio > 1.0) {
                            finalImage = [[UIImage alloc] initWithCGImage:cgImage 
                                                                    scale:screenScaleRatio 
                                                              orientation:UIImageOrientationUp];
                        } else {
                            finalImage = [[UIImage alloc] initWithCGImage:cgImage];
                        }
                        
                        CGImageRelease(cgImage);
                    }
                }
            } else {
                if (![self isCancelled]) {
                    finalImage = [[UIImage alloc] initWithCGImage:[_sourceImage CGImage]
                                                            scale:screenScaleRatio
                                                      orientation:_sourceImage.imageOrientation];
                }
            }
        }
        
        if (finalImage != nil && ![self isCancelled]) {
            if (_outputFormat == HPImageOperationOutputFormatImage) {
                [self sendProcessedImageToBlocks:finalImage];
            }
            
            if (!alreadyCached || _outputFormat == HPImageOperationOutputFormatRawData) {
                NSData *imageData;
                NSString *MIMEType;
                
                switch (_imageFormat) {
                    case HPImageFormatPNG:
                        imageData = UIImagePNGRepresentation(finalImage);
                        MIMEType = @"image/png";
                        break;
                    default:
                        imageData = UIImageJPEGRepresentation(finalImage, 1.0);
                        MIMEType = @"image/jpeg";
                        break;
                }
                
                if (imageData != nil) {
                    if (_storePermanently) {
                        [[HPCacheManager sharedManager] storeData:imageData 
                                                    forStorageKey:_storageKey 
                                                     withMIMEType:MIMEType];
                    }

                    [[HPCacheManager sharedManager] cacheData:imageData 
                                                  forCacheKey:_cacheKey 
                                                 withMIMEType:MIMEType];
                }
                
                if (_outputFormat == HPImageOperationOutputFormatRawData) {
                    [self sendProcessedImageToBlocks:imageData];
                }
            }
            
            [finalImage release];
        }
    }
    
    [pool drain];
}

- (void)addCompletionBlock:(void(^)(id resources, NSError *error))block {
    [_completionBlocks addObject:[[block copy] autorelease]];
}

- (void)sendProcessedImageToBlocks:(id)image {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd 
							   withObject:image 
							waitUntilDone:NO];
		
		return;
	}
    
	[self sendProcessedImageToBlocks:image withError:nil];
}

- (void)sendProcessedImageToBlocks:(id)image withError:(NSError *)error {
    for (void(^blk)(id resources, NSError *error) in _completionBlocks) {
        blk(image, error);
	}
}

- (void)dealloc {
	[_cacheKey release], _cacheKey = nil;
    [_indexPath release], _indexPath = nil;
	[_sourceImage release], _sourceImage = nil;
	[_completionBlocks release], _completionBlocks = nil;
    [_storageKey release], _storageKey = nil;
    [_identifier release], _identifier = nil;
	
	[super dealloc];
}

@end

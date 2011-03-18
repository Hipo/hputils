//
//  HPImageOperation.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//


typedef enum {
	HPImageFormatPNG,
	HPImageFormatJPEG,
} HPImageFormat;

typedef enum {
	HPImageOperationOutputFormatImage,
	HPImageOperationOutputFormatRawData,
} HPImageOperationOutputFormat;


@interface HPImageOperation : NSOperation {
@private
	CGSize _targetSize;
	NSString *_cacheKey;
	UIImage *_sourceImage;
	NSIndexPath *_indexPath;
	HPImageFormat _imageFormat;
	UIViewContentMode _contentMode;
	NSMutableSet *_completionBlocks;	
	HPImageOperationOutputFormat _outputFormat;
}

@property (nonatomic, copy) NSIndexPath *indexPath;
@property (nonatomic, assign) HPImageOperationOutputFormat outputFormat;

+ (NSString *)cacheKeyWithHash:(NSString *)hash 
                    targetSize:(CGSize)targetSize 
                   contentMode:(UIViewContentMode)contentMode 
                   imageFormat:(HPImageFormat)format;

- (id)initWithImage:(UIImage *)image 
         targetSize:(CGSize)targetSize 
        contentMode:(UIViewContentMode)contentMode 
           cacheKey:(NSString *)cacheKey 
        imageFormat:(HPImageFormat)format;

- (void)addCompletionBlock:(void(^)(id resources, NSError *error))block;

@end

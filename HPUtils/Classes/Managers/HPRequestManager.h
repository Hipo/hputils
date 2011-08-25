//
//  HPAPIManager.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPImageOperation.h"
#import "HPRequestOperation.h"
#import "HPS3UploadOperation.h"


extern NSString * const HPNetworkStatusChangeNotification;


@class HPReachabilityManager;

@interface HPRequestManager : NSObject {
@private
    NSOperationQueue *_requestQueue;
    NSOperationQueue *_processQueue;
    
    HPReachabilityManager *_reachabilityManager;
    
    BOOL _networkConnectionAvailable;
}

+ (HPRequestManager *)sharedManager;

- (BOOL)isNetworkConnectionAvailable;

- (void)cancelAllOperations;

- (NSArray *)activeRequestOperations;
- (NSArray *)activeProcessOperations;

- (void)loadImageAtURL:(NSString *)imageURL 
		 withIndexPath:(NSIndexPath *)indexPath 
	   completionBlock:(void (^)(id, NSError *))block 
			scaleToFit:(CGSize)targetSize 
		   contentMode:(UIViewContentMode)contentMode;

- (void)loadStoredImageWithKey:(NSString *)storageKey 
                     indexPath:(NSIndexPath *)indexPath 
               completionBlock:(void (^)(id, NSError *))block 
                    scaleToFit:(CGSize)targetSize 
                   contentMode:(UIViewContentMode)contentMode;

- (void)loadStoredImageWithKey:(NSString *)storageKey 
                     indexPath:(NSIndexPath *)indexPath 
               completionBlock:(void (^)(id, NSError *))block 
                  outputFormat:(HPImageOperationOutputFormat)outputFormat 
                    scaleToFit:(CGSize)targetSize 
                   contentMode:(UIViewContentMode)contentMode;

- (void)resizeImage:(UIImage *)sourceImage 
	   toTargetSize:(CGSize)targetSize 
	   withCacheKey:(NSString *)cacheKey 
	completionBlock:(void (^)(id, NSError *))block;

- (void)resizeImage:(UIImage *)sourceImage 
	   toTargetSize:(CGSize)targetSize 
	   withCacheKey:(NSString *)cacheKey 
       outputFormat:(HPImageOperationOutputFormat)outputFormat 
	completionBlock:(void (^)(id, NSError *))block;

- (void)resizeImage:(UIImage *)sourceImage 
	   toTargetSize:(CGSize)targetSize 
	   withCacheKey:(NSString *)cacheKey 
       outputFormat:(HPImageOperationOutputFormat)outputFormat 
   storePermanently:(BOOL)storePermanently 
	completionBlock:(void (^)(id, NSError *))block;

- (void)uploadImageToS3:(UIImage *)image 
               toBucket:(NSString *)bucket 
                 atPath:(NSString *)path 
          withAccessKey:(NSString *)accessKey 
                 secret:(NSString *)secret 
        completionBlock:(void (^)(id, NSError *))block;

- (id)parseJSONData:(NSData *)loadedData;
- (id)parseImageData:(NSData *)loadedData;
- (id)parseStringData:(NSData *)loadedData;

- (NSString *)encodeURL:(NSString *)string;

- (NSData *)dataFromDict:(NSDictionary *)dict;
- (NSData *)multiPartDataFromDict:(NSDictionary *)dict 
                      withFileKey:(NSString *)fileKey 
                  fileContentType:(NSString *)contentType;

- (NSData *)dataFromArray:(NSArray *)array 
                  withKey:(NSString *)key;

- (NSString *)pathFromBasePath:(NSString *)basePath 
                   withOptions:(NSDictionary *)options;

- (void)enqueueRequest:(HPRequestOperation *)request;

- (HPRequestOperation *)imageRequestForURL:(NSString *)urlString;
- (HPRequestOperation *)requestForPath:(NSString *)path 
                           withBaseURL:(NSString *)baseURL 
                              withData:(NSData *)data 
                                method:(HPRequestMethod)method 
                                cached:(BOOL)cached;

- (HPRequestOperation *)requestForURL:(NSURL *)path 
                             withData:(NSData *)data 
                               method:(HPRequestMethod)method 
                               cached:(BOOL)cached;

- (HPS3UploadOperation *)S3UploadOperationWithData:(NSData *)fileData 
                                          MIMEType:(NSString *)MIMEType 
                                         forBucket:(NSString *)bucket 
                                              path:(NSString *)path 
                                     withAccessKey:(NSString *)accessKey 
                                            secret:(NSString *)secret;

@end

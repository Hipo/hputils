//
//  HPAPIManager.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPRequestOperation.h"


extern NSString * const kHPNetworkStatusChangeNotification;


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

- (void)resizeImage:(UIImage *)sourceImage 
	   toTargetSize:(CGSize)targetSize 
	   withCacheKey:(NSString *)cacheKey 
	completionBlock:(void (^)(id, NSError *))block;

- (id)parseJSONData:(NSData *)loadedData;
- (id)parseImageData:(NSData *)loadedData;

- (NSString *)encodeURL:(NSString *)string;
- (NSData *)dataFromDict:(NSDictionary *)dict;
- (NSData *)dataFromArray:(NSArray *)array withKey:(NSString *)key;
- (NSString *)pathFromBasePath:(NSString *)basePath withOptions:(NSDictionary *)options;

- (HPRequestOperation *)imageRequestForURL:(NSString *)urlString;
- (HPRequestOperation *)requestForPath:(NSString *)path 
                           withBaseURL:(NSString *)baseURL 
                              withData:(NSData *)data 
                                method:(HPRequestMethod)method 
                                cached:(BOOL)cached;

@end

//
//  HPAPIManager.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "JSONKit.h"

#import "HPCacheManager.h"
#import "HPErrors.h"
#import "HPRequestManager.h"
#import "HPRequestOperation.h"
#import "NSString+HPHashAdditions.h"
#import "UIDevice+HPCapabilityAdditions.h"


NSString * const HPNetworkStatusChangeNotification = @"networkStatusChange";

static NSTimeInterval const kNetworkActivityCheckInterval = 30.0;
static NSTimeInterval const kNetworkConnectivityCheckInterval = 8.0;
static NSString * const kHPReleasesAPIBaseURL = @"http://releases.hippofoundry.com/api";
static NSString * const kHPReleasesAPICrashReportPath = @"/crash-logs/";


@interface HPRequestManager (PrivateMethods)

- (void)checkNetworkActivity;
- (void)checkNetworkConnectivity;

- (void)didReceiveReachabilityNotification:(NSNotification *)notification;

@end


@implementation HPRequestManager

#pragma mark - Singleton and init management

@synthesize loggingEnabled = _loggingEnabled;

static HPRequestManager *_sharedManager = nil;

+ (HPRequestManager *)sharedManager {
    if (_sharedManager == nil) {
        _sharedManager = [[super allocWithZone:NULL] init];
    }
    
	return _sharedManager;
}

+ (id)allocWithZone:(NSZone *)zone {
    return [[self sharedManager] retain];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax;
}

- (oneway void)release {
    
}

- (id)autorelease {
    return self;
}

- (id)init {
    self = [super init];
    
	if (self) {
        _loggingEnabled = NO;
		_networkConnectionAvailable = YES;
		_requestQueue = [[NSOperationQueue alloc] init];
		_processQueue = [[NSOperationQueue alloc] init];
		
		[_requestQueue setMaxConcurrentOperationCount:[[NSProcessInfo processInfo] activeProcessorCount] + 1];
		[_processQueue setMaxConcurrentOperationCount:[[NSProcessInfo processInfo] activeProcessorCount] + 1];
		
		_reachabilityManager = [[HPReachabilityManager reachabilityForInternetConnection] retain];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(didReceiveReachabilityNotification:) 
													 name:kReachabilityChangedNotification 
												   object:_reachabilityManager];
		
		[_reachabilityManager startNotifier];
        
        [self checkNetworkConnectivity];
        
        [self performSelector:@selector(checkNetworkActivity) 
                   withObject:nil 
                   afterDelay:kNetworkActivityCheckInterval];
	}
	
	return self;
}

#pragma mark - Operations management

- (void)cancelAllOperations {
	[_requestQueue cancelAllOperations];
	[_processQueue cancelAllOperations];
}

- (void)cancelOperationsWithIdentifier:(NSString *)identifier {
	for (HPRequestOperation *request in [self activeRequestOperations]) {
		if ([request.identifier isEqualToString:identifier]) {
			[request cancel];
            
            return;
		}
	}

	for (HPImageOperation *request in [self activeProcessOperations]) {
		if ([request.identifier isEqualToString:identifier]) {
			[request cancel];
            
            return;
		}
	}
}

- (NSArray *)activeRequestOperations {
	return [_requestQueue operations];
}

- (NSArray *)activeProcessOperations {
	return [_processQueue operations];
}

#pragma mark - Parsers

- (id)parseJSONData:(NSData *)loadedData {
	return [loadedData objectFromJSONData];
}

- (id)parseImageData:(NSData *)loadedData {
    UIImage *image = [UIImage imageWithData:loadedData];
    
    return image;
}

- (id)parseStringData:(NSData *)loadedData {
	NSString *resource = [[NSString alloc] initWithBytesNoCopy:(void *)[loadedData bytes]
														length:[loadedData length]
													  encoding:NSUTF8StringEncoding
												  freeWhenDone:NO];
    
    return [resource autorelease];
}

#pragma mark - Request creation and management

- (HPRequestOperation *)requestForPath:(NSString *)path 
                           withBaseURL:(NSString *)baseURL 
                              withData:(NSData *)data 
                                method:(HPRequestMethod)method 
                                cached:(BOOL)cached {
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", baseURL, path]];
    
    return [self requestForURL:url withData:data method:method cached:cached];
}

- (HPRequestOperation *)requestForURL:(NSURL *)url 
                             withData:(NSData *)data 
                               method:(HPRequestMethod)method 
                               cached:(BOOL)cached {
	HPRequestOperation *request = [HPRequestOperation requestForURL:url 
                                                           withData:data 
                                                             method:method 
                                                             cached:cached];
	
	[request setParserBlock:^ id (NSData *loadedData, NSString *MIMEType) {
		return [self parseJSONData:loadedData];
	}];
    
    [request setLoggingEnabled:_loggingEnabled];
	
	return request;
}

- (HPRequestOperation *)imageRequestForURL:(NSString *)urlString {
	NSURL *url = [NSURL URLWithString:urlString];
	HPRequestOperation *request = [HPRequestOperation requestForURL:url 
                                                           withData:nil 
                                                             method:HPRequestMethodGet 
                                                             cached:YES];
	
	[request setParserBlock:^ id (NSData *loadedData, NSString *MIMEType) {
        return [self parseImageData:loadedData];
	}];
	
	return request;
}

- (HPS3UploadOperation *)S3UploadOperationWithData:(NSData *)fileData 
                                          MIMEType:(NSString *)MIMEType 
                                         forBucket:(NSString *)bucket 
                                              path:(NSString *)path 
                                     withAccessKey:(NSString *)accessKey 
                                            secret:(NSString *)secret {
    HPS3UploadOperation *request = [HPS3UploadOperation uploadOperationWithData:fileData 
                                                                       MIMEType:MIMEType 
                                                                      forBucket:bucket 
                                                                           path:path 
                                                                  withAccessKey:accessKey 
                                                                         secret:secret];
    
	[request setParserBlock:^ id (NSData *loadedData, NSString *contentType) {
		return [self parseStringData:loadedData];
	}];
    
    return request;
}

- (void)enqueueRequest:(HPRequestOperation *)request {
	if (![request isExecuting]
        && ![request isFinished]
        && ![[_requestQueue operations] containsObject:request]) {

        // If request is cachable and there is a cache available, complete it immediately
        if (![request completeRequestWithCachedResponse]) {
            // Either the request is not cached or no cache is available, go ahead
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            
            [request addCompletionBlock:^(id resources, NSError *error) {
                if (error != nil && [error code] == kHPNetworkErrorCode) {
                    if (_networkConnectionAvailable) {
                        _networkConnectionAvailable = NO;
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:HPNetworkStatusChangeNotification
                                                                            object:self];
                        
                        [self performSelector:@selector(checkNetworkConnectivity)
                                   withObject:nil
                                   afterDelay:kNetworkConnectivityCheckInterval];
                    }
                } else if (!_networkConnectionAvailable) {
                    _networkConnectionAvailable = YES;
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:HPNetworkStatusChangeNotification
                                                                        object:self];
                }
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:([_requestQueue operationCount] - 1 > 0)];
            }];

            [_requestQueue addOperation:request];
        }
	}
}

- (void)checkNetworkActivity {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:([_requestQueue operationCount] > 0)];

    [self performSelector:@selector(checkNetworkActivity) 
               withObject:nil 
               afterDelay:kNetworkActivityCheckInterval];
}

#pragma mark - URL creation and encoding

- (NSString*)encodeURL:(NSString *)string {
	NSString *newString = [(NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
																			   (CFStringRef)string, 
																			   NULL, 
																			   CFSTR(":/?#[]@!$ &'()*+;=\"<>%{}|\\^~`"), 
																			   CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)) autorelease];
	
	if (newString) {
		return newString;
	}
	
	return @"";
}

- (NSData *)dataFromDict:(NSDictionary *)dict {
	NSMutableString *dataString = [NSMutableString string];
	
	for (NSString *key in [dict allKeys]) {
        id value = [dict objectForKey:key];
        
        if ((NSNull *)value == [NSNull null]) {
            value = @"";
        }
        
        if ([value respondsToSelector:@selector(stringValue)]) {
            [dataString appendFormat:@"%@=%@&", key, [value stringValue]];
        } else {
            [dataString appendFormat:@"%@=%@&", key, [self encodeURL:(NSString *)value]];
        }
	}
    
	return [dataString dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)multiPartDataFromDict:(NSDictionary *)dict 
                      withFileKey:(NSString *)fileKey 
                  fileContentType:(NSString *)contentType {
    NSMutableData *postData = [NSMutableData data];
    NSInteger keyIndex = 0;
	
	[postData appendData:[[NSString stringWithFormat:@"--%@\r\n", 
                           HPRequestOperationMultiPartFormBoundary] 
                          dataUsingEncoding:NSASCIIStringEncoding 
                          allowLossyConversion:NO]];

	for (NSString *key in [dict allKeys]) {
		NSRange keyLookup = [key rangeOfString:fileKey];
		
        if (keyIndex > 0) {
            [postData appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", 
                                   HPRequestOperationMultiPartFormBoundary] 
                                  dataUsingEncoding:NSASCIIStringEncoding 
                                  allowLossyConversion:NO]];
        }
		
		if (keyLookup.location == NSNotFound) {
			[postData appendData:[[NSString stringWithFormat:
                                   @"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] 
                                  dataUsingEncoding:NSASCIIStringEncoding]];

			[postData appendData:[[dict objectForKey:key] 
                                  dataUsingEncoding:NSASCIIStringEncoding]];
		} else {
			NSData *fileData = [dict objectForKey:key];

			[postData appendData:[[NSString stringWithFormat:
                                   @"Content-Disposition: form-data; name=\"%@\"; filename=\"%@.jpg\"\r\n", key, key] 
                                  dataUsingEncoding:NSASCIIStringEncoding]];

			[postData appendData:[[NSString stringWithFormat:
                                   @"Content-Type: %@\r\n", contentType] 
                                  dataUsingEncoding:NSASCIIStringEncoding]];
            
			[postData appendData:[@"Content-Transfer-Encoding: binary\r\n\r\n" 
                                  dataUsingEncoding:NSASCIIStringEncoding]];

			[postData appendData:fileData];
		}
        
        keyIndex += 1;
	}
	
	[postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", 
                           HPRequestOperationMultiPartFormBoundary] 
                          dataUsingEncoding:NSASCIIStringEncoding 
                          allowLossyConversion:NO]];
    
	return postData;
}

- (NSData *)dataFromArray:(NSArray *)array withKey:(NSString *)key {
	NSMutableString *dataString = [NSMutableString string];
	
	for (NSString *value in array) {
		[dataString appendFormat:@"%@=%@&", key, [self encodeURL:value]];
	}
    
	return [dataString dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)pathFromBasePath:(NSString *)basePath 
                   withOptions:(NSDictionary *)options 
                   specialKeys:(NSArray *)specialKeys {
	NSMutableString *requestPath = [NSMutableString stringWithString:basePath];
    NSString *lastCharacter = [requestPath substringFromIndex:([requestPath length] - 1)];
	
    if (![lastCharacter isEqualToString:@"&"]) {
        [requestPath appendString:@"?"];
    }
    
	if (options != nil) {
		for (NSString *key in [options allKeys]) {
            id value = [options objectForKey:key];
            
            if ((NSNull *)value == [NSNull null]) {
                value = @"";
            }
            
            if ([value respondsToSelector:@selector(stringValue)]) {
                [requestPath appendFormat:@"%@=%@&", key, [value stringValue]];
            } else {
                if ([specialKeys containsObject:key]) {
                    [requestPath appendFormat:@"%@=%@&", key, (NSString *)value];
                    
                } else {
                    [requestPath appendFormat:@"%@=%@&", key, [self encodeURL:(NSString *)value]];
                }
            }
		}
	}
    
    if ([requestPath hasSuffix:@"&"]) {
        return [requestPath substringToIndex:[requestPath length] - 1];
    }
	
	return requestPath;
}

- (NSString *)pathFromBasePath:(NSString *)basePath 
                   withOptions:(NSDictionary *)options {
    return [self pathFromBasePath:basePath 
                      withOptions:options 
                      specialKeys:[NSArray array]];
}

#pragma mark - Reachability

- (BOOL)isNetworkConnectionAvailable {
	return _networkConnectionAvailable;
}

- (void)didReceiveReachabilityNotification:(NSNotification *)notification {
	_networkConnectionAvailable = ([_reachabilityManager currentReachabilityStatus] != NotReachable);

	[[NSNotificationCenter defaultCenter] postNotificationName:HPNetworkStatusChangeNotification
														object:self];
}

- (void)checkNetworkConnectivity {
    [self enqueueRequest:[HPRequestOperation requestForURL:[NSURL URLWithString:@"http://www.apple.com"] 
                                                  withData:nil 
                                                    method:HPRequestMethodGet 
                                                    cached:NO]];
}

#pragma mark - Image loaders

- (void)loadImageAtURL:(NSString *)imageURL
         withIndexPath:(NSIndexPath *)indexPath
            identifier:(NSString *)identifier
            scaleToFit:(CGSize)targetSize
           contentMode:(UIViewContentMode)contentMode
       completionBlock:(void (^)(id, NSError *))block
         progressBlock:(void (^)(float))progressBlock {

    HPRequestOperation *request = [self imageRequestForURL:imageURL];
	
	[request setIndexPath:indexPath];
    [request setIdentifier:identifier];
    [request setQueuePriority:NSOperationQueuePriorityLow];
    
	if (CGSizeEqualToSize(targetSize, CGSizeZero)) {
		[request addCompletionBlock:block];
	} else {
		[request addCompletionBlock:^ void (id resources, NSError *error) {
			if (resources != nil) {
                UIImage *sourceImage = (UIImage *)resources;
                CGBitmapInfo imageInfo = CGImageGetBitmapInfo([sourceImage CGImage]);
                HPImageFormat imageFormat = HPImageFormatJPEG;
                
                if (imageInfo & kCGBitmapAlphaInfoMask) {
                    imageFormat = HPImageFormatPNG;
                }
                
				HPImageOperation *operation = [[HPImageOperation alloc] initWithImage:sourceImage
                                                                           targetSize:targetSize
                                                                          contentMode:contentMode
                                                                             cacheKey:[imageURL SHA1Hash]
                                                                          imageFormat:imageFormat];
				
                [operation setIdentifier:identifier];
				[operation setIndexPath:indexPath];
				[operation addCompletionBlock:block];
                [operation setQueuePriority:NSOperationQueuePriorityLow];
				
				[_processQueue addOperation:operation];
				
				[operation release];
			} else {
				block(resources, error);
			}
		}];
        
        if (progressBlock != nil) {
            [request setProgressBlock:progressBlock];
        }
	}
    
	[self enqueueRequest:request];

}

- (void)loadImageAtURL:(NSString *)imageURL 
         withIndexPath:(NSIndexPath *)indexPath 
            identifier:(NSString *)identifier 
            scaleToFit:(CGSize)targetSize 
           contentMode:(UIViewContentMode)contentMode 
       completionBlock:(void (^)(id, NSError *))block {
    [self loadImageAtURL:imageURL
           withIndexPath:indexPath
              identifier:identifier
              scaleToFit:targetSize
             contentMode:contentMode
         completionBlock:block
           progressBlock:nil];
}

- (void)loadImageAtURL:(NSString *)imageURL 
		 withIndexPath:(NSIndexPath *)indexPath 
	   completionBlock:(void (^)(id, NSError *))block 
			scaleToFit:(CGSize)targetSize 
		   contentMode:(UIViewContentMode)contentMode {
	[self loadImageAtURL:imageURL 
           withIndexPath:indexPath 
              identifier:nil 
              scaleToFit:targetSize 
             contentMode:contentMode 
         completionBlock:block];
}

- (void)loadImageAtURL:(NSString *)imageURL 
         withIndexPath:(NSIndexPath *)indexPath 
            scaleToFit:(CGSize)targetSize 
           contentMode:(UIViewContentMode)contentMode 
       completionBlock:(void (^)(id, NSError *))block {
    [self loadImageAtURL:imageURL 
           withIndexPath:indexPath 
              identifier:nil 
              scaleToFit:targetSize 
             contentMode:contentMode 
         completionBlock:block];
}

- (void)loadStoredImageWithKey:(NSString *)storageKey 
                     indexPath:(NSIndexPath *)indexPath 
                  outputFormat:(HPImageOperationOutputFormat)outputFormat 
                    scaleToFit:(CGSize)targetSize 
                   contentMode:(UIViewContentMode)contentMode 
               completionBlock:(void (^)(id, NSError *))block {
    HPImageOperation *operation = [[HPImageOperation alloc] initWithImage:nil 
                                                               targetSize:targetSize 
                                                              contentMode:contentMode 
                                                                 cacheKey:storageKey 
                                                              imageFormat:HPImageFormatJPEG];
    
    [operation setIndexPath:indexPath];
    [operation addCompletionBlock:block];
    [operation setStorageKey:storageKey];
    [operation setOutputFormat:outputFormat];
    [operation setQueuePriority:NSOperationQueuePriorityLow];
    
    [_processQueue addOperation:operation];
    
    [operation release];
}

- (void)loadStoredImageWithKey:(NSString *)storageKey 
                     indexPath:(NSIndexPath *)indexPath 
               completionBlock:(void (^)(id, NSError *))block 
                  outputFormat:(HPImageOperationOutputFormat)outputFormat 
                    scaleToFit:(CGSize)targetSize 
                   contentMode:(UIViewContentMode)contentMode {
    [self loadStoredImageWithKey:storageKey 
                       indexPath:indexPath 
                    outputFormat:outputFormat 
                      scaleToFit:targetSize 
                     contentMode:contentMode 
                 completionBlock:block];
}

- (void)loadStoredImageWithKey:(NSString *)storageKey 
                     indexPath:(NSIndexPath *)indexPath 
               completionBlock:(void (^)(id, NSError *))block 
                    scaleToFit:(CGSize)targetSize 
                   contentMode:(UIViewContentMode)contentMode {
    [self loadStoredImageWithKey:storageKey 
                       indexPath:indexPath 
                 completionBlock:block 
                    outputFormat:HPImageOperationOutputFormatImage 
                      scaleToFit:targetSize 
                     contentMode:contentMode];
}

- (void)resizeImage:(UIImage *)sourceImage 
	   toTargetSize:(CGSize)targetSize 
	   withCacheKey:(NSString *)cacheKey 
	completionBlock:(void (^)(id, NSError *))block {
	[self resizeImage:sourceImage 
         toTargetSize:targetSize 
         withCacheKey:cacheKey 
         outputFormat:HPImageOperationOutputFormatImage 
      completionBlock:block];
}

- (void)resizeImage:(UIImage *)sourceImage 
       toTargetSize:(CGSize)targetSize 
       withCacheKey:(NSString *)cacheKey 
       outputFormat:(HPImageOperationOutputFormat)outputFormat 
    completionBlock:(void (^)(id, NSError *))block {
    [self resizeImage:sourceImage 
         toTargetSize:targetSize 
         withCacheKey:cacheKey 
         outputFormat:outputFormat 
     storePermanently:NO 
      completionBlock:block];
}

- (void)resizeImage:(UIImage *)sourceImage 
       toTargetSize:(CGSize)targetSize 
       withCacheKey:(NSString *)cacheKey 
       outputFormat:(HPImageOperationOutputFormat)outputFormat 
   storePermanently:(BOOL)storePermanently 
    completionBlock:(void (^)(id, NSError *))block {
    [self resizeImage:sourceImage 
         toTargetSize:targetSize 
         withCacheKey:cacheKey 
         outputFormat:outputFormat 
          contentMode:UIViewContentModeScaleAspectFill 
     storePermanently:storePermanently 
      completionBlock:block];
}

- (void)resizeImage:(UIImage *)sourceImage 
       toTargetSize:(CGSize)targetSize 
       withCacheKey:(NSString *)cacheKey 
       outputFormat:(HPImageOperationOutputFormat)outputFormat 
        contentMode:(UIViewContentMode)contentMode 
   storePermanently:(BOOL)storePermanently 
    completionBlock:(void (^)(id, NSError *))block {
    HPImageOperation *operation = [[HPImageOperation alloc] initWithImage:sourceImage 
                                                               targetSize:targetSize 
                                                              contentMode:contentMode 
                                                                 cacheKey:cacheKey 
                                                              imageFormat:HPImageFormatJPEG];
	
	[operation addCompletionBlock:block];
    [operation setOutputFormat:outputFormat];
    [operation setStorePermanently:storePermanently];
    
    if (storePermanently) {
        [operation setStorageKey:cacheKey];
    }
    
    [operation setQueuePriority:NSOperationQueuePriorityVeryHigh];
	
	[_processQueue addOperation:operation];
	
	[operation release];
}

- (void)uploadImageToS3:(UIImage *)image 
               toBucket:(NSString *)bucket 
                 atPath:(NSString *)path 
          withAccessKey:(NSString *)accessKey 
                 secret:(NSString *)secret 
        completionBlock:(void (^)(id, NSError *))block {
    HPImageOperation *operation = [[HPImageOperation alloc] initWithImage:image 
                                                               targetSize:CGSizeZero 
                                                              contentMode:UIViewContentModeScaleAspectFill 
                                                                 cacheKey:nil 
                                                              imageFormat:HPImageFormatJPEG];
	
	[operation addCompletionBlock:^(id resources, NSError *error) {
        if (error == nil) {
            HPS3UploadOperation *request = [self S3UploadOperationWithData:(NSData *)resources 
                                                                  MIMEType:@"image/jpeg" 
                                                                 forBucket:bucket 
                                                                      path:path 
                                                             withAccessKey:accessKey 
                                                                    secret:secret];
            
            [request addCompletionBlock:block];
            [request setQueuePriority:NSOperationQueuePriorityHigh];
            
            [_requestQueue addOperation:request];
        } else {
            block(nil, [NSError errorWithDomain:kHPErrorDomain 
                                           code:kHPRequestParserFailureErrorCode 
                                       userInfo:nil]);
        }
    }];
    
    [operation setOutputFormat:HPImageOperationOutputFormatRawData];
    [operation setQueuePriority:NSOperationQueuePriorityHigh];
	
	[_processQueue addOperation:operation];
	
	[operation release];
}

#pragma mark - Memory management

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[_requestQueue cancelAllOperations];
	[_processQueue cancelAllOperations];
	[_reachabilityManager release];
	[_requestQueue release];
	[_processQueue release];
	
	[super dealloc];
}

@end

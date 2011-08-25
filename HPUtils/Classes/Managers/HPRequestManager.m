//
//  HPAPIManager.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "JSON.h"

#import "HPCacheManager.h"
#import "HPErrors.h"
#import "HPReachabilityManager.h"
#import "HPRequestManager.h"
#import "HPRequestOperation.h"
#import "NSString+HPHashAdditions.h"


NSString * const HPNetworkStatusChangeNotification = @"networkStatusChange";

NSTimeInterval const kNetworkActivityCheckInterval = 30.0;


@interface HPRequestManager (PrivateMethods)
- (void)checkNetworkActivity;
- (void)didReceiveReachabilityNotification:(NSNotification *)notification;
@end


@implementation HPRequestManager

#pragma mark - Singleton and init management

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

- (void)release {
    
}

- (id)autorelease {
    return self;
}

- (id)init {
    self = [super init];
    
	if (self) {
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

- (NSArray *)activeRequestOperations {
	return [_requestQueue operations];
}

- (NSArray *)activeProcessOperations {
	return [_processQueue operations];
}

#pragma mark - Parsers

- (id)parseJSONData:(NSData *)loadedData {
	NSString *resource = [[NSString alloc] initWithBytesNoCopy:(void *)[loadedData bytes]
														length:[loadedData length]
													  encoding:NSUTF8StringEncoding
												  freeWhenDone:NO];
	
	id ret = [resource JSONValue];
    
	if (ret == nil) {
		NSLog(@"FAILED TO PARSE: %@", resource);
	}
	
	[resource release];
	
	return ret;
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
	NSURL *url = [NSURL URLWithString:[[NSString stringWithFormat:@"%@%@", baseURL, path] 
                                       stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
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
	if (![request isExecuting] && ![request isFinished] && ![[_requestQueue operations] containsObject:request]) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        
		[request addCompletionBlock:^(id resources, NSError *error) {
			if (error != nil && [error code] == kHPNetworkErrorCode) {
				_networkConnectionAvailable = NO;
			} else {
				_networkConnectionAvailable = YES;
			}
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:([_requestQueue operationCount] - 1 > 0)];
		}];
		
		[_requestQueue addOperation:request];
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

- (NSString *)pathFromBasePath:(NSString *)basePath withOptions:(NSDictionary *)options {
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
                [requestPath appendFormat:@"%@=%@&", key, [self encodeURL:(NSString *)value]];
            }
		}
	}
	
	return requestPath;
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

#pragma mark - Image loaders

- (void)loadImageAtURL:(NSString *)imageURL 
		 withIndexPath:(NSIndexPath *)indexPath 
	   completionBlock:(void (^)(id, NSError *))block 
			scaleToFit:(CGSize)targetSize 
		   contentMode:(UIViewContentMode)contentMode {
	HPRequestOperation *request = [self imageRequestForURL:imageURL];
	
	[request setIndexPath:indexPath];
    [request setQueuePriority:NSOperationQueuePriorityLow];
    
	if (CGSizeEqualToSize(targetSize, CGSizeZero)) {
		[request addCompletionBlock:block];
	} else {
		[request addCompletionBlock:^ void (id resources, NSError *error) {
			if (resources != nil) {
				HPImageOperation *operation = [[HPImageOperation alloc] initWithImage:(UIImage *)resources 
                                                                           targetSize:targetSize 
                                                                          contentMode:contentMode 
                                                                             cacheKey:[imageURL SHA1Hash] 
                                                                          imageFormat:HPImageFormatJPEG];
				
				[operation setIndexPath:indexPath];
				[operation addCompletionBlock:block];
                [operation setQueuePriority:NSOperationQueuePriorityLow];
				
				[_processQueue addOperation:operation];
				
				[operation release];
			} else {
				block(resources, error);
			}
		}];
	}
    
	[self enqueueRequest:request];
}

- (void)loadStoredImageWithKey:(NSString *)storageKey 
                     indexPath:(NSIndexPath *)indexPath 
               completionBlock:(void (^)(id, NSError *))block 
                  outputFormat:(HPImageOperationOutputFormat)outputFormat 
                    scaleToFit:(CGSize)targetSize 
                   contentMode:(UIViewContentMode)contentMode {
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
    HPImageOperation *operation = [[HPImageOperation alloc] initWithImage:sourceImage 
                                                               targetSize:targetSize 
                                                              contentMode:UIViewContentModeScaleAspectFill 
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

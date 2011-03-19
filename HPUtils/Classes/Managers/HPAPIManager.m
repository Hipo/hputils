//
//  HPAPIManager.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "JSON.h"

#import "HPErrors.h"
#import "HPAPIManager.h"
#import "HPCacheManager.h"
#import "HPImageOperation.h"
#import "HPRequestOperation.h"
#import "HPReachabilityManager.h"
#import "NSString+HPHashAdditions.h"


NSString * const kHPNetworkStatusChangeNotification = @"networkStatusChange";


@interface HPAPIManager (PrivateMethods)
- (void)didReceiveReachabilityNotification:(NSNotification *)notification;
@end


@implementation HPAPIManager

static HPAPIManager *_sharedManager = nil;

+ (void)initialize {
	if (self == [HPAPIManager class]) {
		_sharedManager = [[HPAPIManager alloc] init];
	}
}

+ (HPAPIManager *)sharedManager {
	return _sharedManager;
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
	}
	
	return self;
}

- (void)cancelAllOperations {
	[_requestQueue cancelAllOperations];
	[_processQueue cancelAllOperations];
}

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

- (HPRequestOperation *)requestForPath:(NSString *)path 
                           withBaseURL:(NSString *)baseURL 
                              withData:(NSData *)data 
                                method:(HPRequestMethod)method 
                                cached:(BOOL)cached {
	NSURL *url = [NSURL URLWithString:[[NSString stringWithFormat:baseURL, path] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
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
		UIImage *image = [UIImage imageWithData:loadedData];
		
		return image;
	}];
	
	return request;
}

- (void)enqueueRequest:(HPRequestOperation *)request {
	if (![request isExecuting] && ![request isFinished] && ![[_requestQueue operations] containsObject:request]) {
		[request addCompletionBlock:^(id resources, NSError *error) {
			if (error != nil && [error code] == kHPNetworkErrorCode) {
				_networkConnectionAvailable = NO;
			} else {
				_networkConnectionAvailable = YES;
			}
		}];
		
		[_requestQueue addOperation:request];
	}
}

- (NSString*)encodeURL:(NSString *)string {
	NSString *newString = [(NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
																			   (CFStringRef)string, 
																			   NULL, 
																			   CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"), 
																			   CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)) autorelease];
	
	if (newString) {
		return newString;
	}
	
	return @"";
}

- (NSData *)dataFromDict:(NSDictionary *)dict {
	NSMutableString *dataString = [NSMutableString string];
	
	for (NSString *key in [dict allKeys]) {
		[dataString appendFormat:@"%@=%@&", key, [self encodeURL:[dict objectForKey:key]]];
	}
    
	return [dataString dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)dataFromArray:(NSArray *)array withKey:(NSString *)key {
	NSMutableString *dataString = [NSMutableString string];
	
	for (NSString *value in array) {
		[dataString appendFormat:@"%@=%@&", key, [self encodeURL:value]];
	}
    
	return [dataString dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)pathFromBasePath:(NSString *)basePath withOptions:(NSDictionary *)options {
	NSMutableString *requestPath = [NSMutableString stringWithFormat:@"%@?", basePath];
	
	if (options != nil) {
		for (NSString *key in [options allKeys]) {
			[requestPath appendFormat:@"&%@=%@", key, [self encodeURL:[options objectForKey:key]]];
		}
	}
	
	return requestPath;
}

- (BOOL)isNetworkConnectionAvailable {
	return _networkConnectionAvailable;
}

- (NSArray *)activeRequestOperations {
	return [_requestQueue operations];
}

- (NSArray *)activeProcessOperations {
	return [_processQueue operations];
}

- (void)didReceiveReachabilityNotification:(NSNotification *)notification {
	_networkConnectionAvailable = ([_reachabilityManager currentReachabilityStatus] != NotReachable);
    
	[[NSNotificationCenter defaultCenter] postNotificationName:kHPNetworkStatusChangeNotification 
														object:self];
}

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

- (void)resizeImage:(UIImage *)sourceImage 
	   toTargetSize:(CGSize)targetSize 
	   withCacheKey:(NSString *)cacheKey 
	completionBlock:(void (^)(id, NSError *))block {
	HPImageOperation *operation = [[HPImageOperation alloc] initWithImage:sourceImage 
                                                               targetSize:targetSize 
                                                              contentMode:UIViewContentModeScaleAspectFill 
                                                                 cacheKey:cacheKey 
                                                              imageFormat:HPImageFormatJPEG];
	
	[operation addCompletionBlock:block];
    [operation setQueuePriority:NSOperationQueuePriorityLow];
	[operation setOutputFormat:HPImageOperationOutputFormatRawData];
	
	[_processQueue addOperation:operation];
	
	[operation release];
}

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

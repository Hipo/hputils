//
//  HPAPIManager.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import <CrashReporter/CrashReporter.h>

#import "JSONKit.h"

#import "HPCacheManager.h"
#import "HPErrors.h"
#import "HPReachabilityManager.h"
#import "HPRequestManager.h"
#import "HPRequestOperation.h"
#import "NSString+HPHashAdditions.h"
#import "UIDevice+HPCapabilityAdditions.h"


NSString * const HPNetworkStatusChangeNotification = @"networkStatusChange";

static NSTimeInterval const kNetworkActivityCheckInterval = 30.0;
static NSString * const kHPReleasesAPIBaseURL = @"http://releases.hippofoundry.com/api";
static NSString * const kHPReleasesAPICrashReportPath = @"/crash-logs/";


@interface HPRequestManager (PrivateMethods)
- (void)checkNetworkActivity;
- (void)didReceiveReachabilityNotification:(NSNotification *)notification;
- (void)handleCrashReport;
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

- (oneway void)release {
    
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
        
        [self enqueueRequest:[HPRequestOperation requestForURL:[NSURL URLWithString:@"http://www.apple.com"] 
                                                      withData:nil 
                                                        method:HPRequestMethodGet 
                                                        cached:NO]];
        
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

#pragma mark - Image loaders

- (void)loadImageAtURL:(NSString *)imageURL 
         withIndexPath:(NSIndexPath *)indexPath 
            identifier:(NSString *)identifier 
            scaleToFit:(CGSize)targetSize 
           contentMode:(UIViewContentMode)contentMode 
       completionBlock:(void (^)(id, NSError *))block {
    HPRequestOperation *request = [self imageRequestForURL:imageURL];
	
	[request setIndexPath:indexPath];
    [request setIdentifier:identifier];
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

#pragma mark - Crash reports

- (void)sendAvailableCrashReports {
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSError *error;
    
    if ([crashReporter hasPendingCrashReport]) {
        [self handleCrashReport];
    }
    
    if (![crashReporter enableCrashReporterAndReturnError:&error]) {
        NSLog(@"COULD NOT ENABLE CRASH REPORTER: %@", error);
    }
}

- (void)handleCrashReport {
    PLCrashReporter *crashReporter = [PLCrashReporter sharedReporter];
    NSData *crashData;
    NSError *error;
    
    crashData = [crashReporter loadPendingCrashReportDataAndReturnError:&error];
    
    if (crashData == nil) {
        [crashReporter purgePendingCrashReport];
        
        return;
    }
    
    PLCrashReport *report = [[PLCrashReport alloc] initWithData:crashData error:&error];
    
    if (report == nil) {
        [crashReporter purgePendingCrashReport];
        
        return;
    }
    
    NSMutableString *reportString = [NSMutableString string];
	
	/* Header */
    boolean_t lp64;
	
	/* Map to apple style OS nane */
	const char *osName;
	switch (report.systemInfo.operatingSystem) {
		case PLCrashReportOperatingSystemiPhoneOS:
			osName = "iPhone OS";
			break;
		case PLCrashReportOperatingSystemiPhoneSimulator:
			osName = "Mac OS X";
			break;
		default:
			osName = "iPhone OS";
			break;
	}
	
	/* Map to Apple-style code type */
	NSString *codeType;
	switch (report.systemInfo.architecture) {
		case PLCrashReportArchitectureARM:
			codeType = @"ARM (Native)";
            lp64 = false;
			break;
        case PLCrashReportArchitectureX86_32:
            codeType = @"X86";
            lp64 = false;
            break;
        case PLCrashReportArchitectureX86_64:
            codeType = @"X86-64";
            lp64 = true;
            break;
        case PLCrashReportArchitecturePPC:
            codeType = @"PPC";
            lp64 = false;
            break;
		default:
			codeType = @"ARM (Native)";
            lp64 = false;
			break;
	}
	
    /* Application and process info */
    {
        NSString *unknownString = @"???";
        
        NSString *processName = unknownString;
        NSString *processId = unknownString;
        NSString *processPath = unknownString;
        NSString *parentProcessName = unknownString;
        NSString *parentProcessId = unknownString;
        
        /* Process information was not available in earlier crash report versions */
        if (report.hasProcessInfo) {
            /* Process Name */
            if (report.processInfo.processName != nil)
                processName = report.processInfo.processName;
            
            /* PID */
            processId = [[NSNumber numberWithUnsignedInteger: report.processInfo.processID] stringValue];
            
            /* Process Path */
            if (report.processInfo.processPath != nil)
                processPath = report.processInfo.processPath;
            
            /* Parent Process Name */
            if (report.processInfo.parentProcessName != nil)
                parentProcessName = report.processInfo.parentProcessName;
            
            /* Parent Process ID */
            parentProcessId = [[NSNumber numberWithUnsignedInteger: report.processInfo.parentProcessID] stringValue];
        }
        
        [reportString appendFormat: @"Process:         %@ [%@]\n", processName, processId];
        [reportString appendFormat: @"Path:            %@\n", processPath];
        [reportString appendFormat: @"Identifier:      %@\n", report.applicationInfo.applicationIdentifier];
        [reportString appendFormat: @"Version:         %@\n", report.applicationInfo.applicationVersion];
        [reportString appendFormat: @"Code Type:       %@\n", codeType];
        [reportString appendFormat: @"Parent Process:  %@ [%@]\n", parentProcessName, parentProcessId];
    }
    
	[reportString appendString:@"\n"];
	
	/* System info */
	[reportString appendFormat:@"Date/Time:       %s\n", [[report.systemInfo.timestamp description] UTF8String]];
    
    NSString *buildNumber = [[UIDevice currentDevice] platformCode];
    
    if (buildNumber) {
        [reportString appendFormat:@"OS Version:      %s %s (%s)\n", osName, [report.systemInfo.operatingSystemVersion UTF8String], [buildNumber UTF8String]];
    } else {
        [reportString appendFormat:@"OS Version:      %s %s\n", osName, [report.systemInfo.operatingSystemVersion UTF8String]];
    }
	
    [reportString appendString:@"Report Version:  104\n"];
	[reportString appendString:@"\n"];
	
	/* Exception code */
	[reportString appendFormat:@"Exception Type:  %s\n", [report.signalInfo.name UTF8String]];
    [reportString appendFormat:@"Exception Codes: %@ at 0x%" PRIx64 "\n", report.signalInfo.code, report.signalInfo.address];
	
    for (PLCrashReportThreadInfo *thread in report.threads) {
        if (thread.crashed) {
            [reportString appendFormat: @"Crashed Thread:  %ld\n", (long) thread.threadNumber];
            break;
        }
    }
	
	[reportString appendString:@"\n"];
	
    if (report.hasExceptionInfo) {
        [reportString appendString:@"Application Specific Information:\n"];
        [reportString appendFormat: @"*** Terminating app due to uncaught exception '%@', reason: '%@'\n",
         report.exceptionInfo.exceptionName, report.exceptionInfo.exceptionReason];
        [reportString appendString:@"\n"];
    }
    
	/* Threads */
    PLCrashReportThreadInfo *crashed_thread = nil;
    for (PLCrashReportThreadInfo *thread in report.threads) {
        if (thread.crashed) {
            [reportString appendFormat: @"Thread %ld Crashed:\n", (long) thread.threadNumber];
            crashed_thread = thread;
        } else {
            [reportString appendFormat: @"Thread %ld:\n", (long) thread.threadNumber];
        }
        for (NSUInteger frame_idx = 0; frame_idx < [thread.stackFrames count]; frame_idx++) {
            PLCrashReportStackFrameInfo *frameInfo = [thread.stackFrames objectAtIndex: frame_idx];
            PLCrashReportBinaryImageInfo *imageInfo;
            
            /* Base image address containing instrumention pointer, offset of the IP from that base
             * address, and the associated image name */
            uint64_t baseAddress = 0x0;
            uint64_t pcOffset = 0x0;
            NSString *imageName = @"\?\?\?";
            
            imageInfo = [report imageForAddress: frameInfo.instructionPointer];
            if (imageInfo != nil) {
                imageName = [imageInfo.imageName lastPathComponent];
                baseAddress = imageInfo.imageBaseAddress;
                pcOffset = frameInfo.instructionPointer - imageInfo.imageBaseAddress;
            }
            
            [reportString appendFormat: @"%-4ld%-36s0x%08" PRIx64 " 0x%" PRIx64 " + %" PRId64 "\n", 
             (long) frame_idx, [imageName UTF8String], frameInfo.instructionPointer, baseAddress, pcOffset];
        }
        [reportString appendString: @"\n"];
    }
    
    /* Registers */
    if (crashed_thread != nil) {
        [reportString appendFormat: @"Thread %ld crashed with %@ Thread State:\n", (long) crashed_thread.threadNumber, codeType];
        
        int regColumn = 1;
        for (PLCrashReportRegisterInfo *reg in crashed_thread.registers) {
            NSString *reg_fmt;
            
            /* Use 32-bit or 64-bit fixed width format for the register values */
            if (lp64)
                reg_fmt = @"%6s:\t0x%016" PRIx64 " ";
            else
                reg_fmt = @"%6s:\t0x%08" PRIx64 " ";
            
            [reportString appendFormat: reg_fmt, [reg.registerName UTF8String], reg.registerValue];
            
            if (regColumn % 4 == 0)
                [reportString appendString: @"\n"];
            regColumn++;
        }
        
        if (regColumn % 3 != 0)
            [reportString appendString: @"\n"];
        
        [reportString appendString: @"\n"];
    }
	
	/* Images */
	[reportString appendFormat:@"Binary Images:\n"];
	
    for (PLCrashReportBinaryImageInfo *imageInfo in report.images) {
		NSString *uuid;
		/* Fetch the UUID if it exists */
		if (imageInfo.hasImageUUID)
			uuid = imageInfo.imageUUID;
		else
			uuid = @"???";
		
        NSString *device = @"\?\?\? (\?\?\?)";
        
#ifdef _ARM_ARCH_7 
        device = @"armv7";
#else
        device = @"armv6";
#endif
        
		/* base_address - terminating_address file_name identifier (<version>) <uuid> file_path */
		[reportString appendFormat:@"0x%" PRIx64 " - 0x%" PRIx64 "  %@ %@ <%@> %@\n",
		 imageInfo.imageBaseAddress,
		 imageInfo.imageBaseAddress + imageInfo.imageSize,
		 [imageInfo.imageName lastPathComponent],
		 device,
		 uuid,
		 imageInfo.imageName];
	}
    
    UIDevice *device = [UIDevice currentDevice];
    NSData *requestData = [self multiPartDataFromDict:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       report.applicationInfo.applicationIdentifier, @"identifier", 
                                                       report.applicationInfo.applicationVersion, @"version", 
                                                       device.systemName, @"system_name", 
                                                       device.systemVersion, @"system_version", 
                                                       device.model, @"device_model", 
                                                       crashData, @"log_file", 
                                                       reportString, @"report", nil] 
                                          withFileKey:@"log_file" 
                                      fileContentType:@"application/octet-stream"];
    
    HPRequestOperation *requestOperation = [self requestForPath:kHPReleasesAPICrashReportPath 
                                                    withBaseURL:kHPReleasesAPIBaseURL 
                                                       withData:requestData 
                                                         method:HPRequestMethodPost 
                                                         cached:NO];
    
    [requestOperation setPostType:HPRequestOperationPostTypeFile];
    
    [self enqueueRequest:requestOperation];
    
    [crashReporter purgePendingCrashReport];
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

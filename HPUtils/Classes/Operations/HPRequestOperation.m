//
//  HPRequestOperation.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPAuthenticationManager.h"
#import "HPCacheManager.h"
#import "HPErrors.h"
#import "HPRequestOperation.h"


NSString * const HPRequestOperationMultiPartFormBoundary = @"0xKhTmLbOuNdArY";

static NSUInteger const HPRequestOperationDataLoggingLimit = 50 * 1024;


@interface HPRequestOperation (PrivateMethods)
- (void)sendErrorToBlocks:(NSError *)error;
- (void)sendResourcesToBlocks:(id)resources;
- (void)callUploadProgressBlockWithPercentage:(NSNumber *)percentage;
- (void)callProgressBlockWithPercentage:(NSNumber *)percentage;
- (void)callParserBlockWithData:(NSData *)data error:(NSError *)error;
- (void)sendResourcesToBlocks:(id)resources withError:(NSError *)error;
@end


@implementation HPRequestOperation

@synthesize indexPath = _indexPath;
@synthesize identifier = _identifier;
@synthesize parserBlock = _parserBlock;
@synthesize progressBlock = _progressBlock;
@synthesize uploadProgressBlock = _uploadProgressBlock;
@synthesize postType = _postType;
@synthesize loggingEnabled = _loggingEnabled;
@synthesize startTime = _startTime;
@synthesize username = _username;
@synthesize password = _password;
@synthesize requestURL = _requestURL;

+ (HPRequestOperation *)requestForURL:(NSURL *)url 
                             withData:(NSData *)data 
                               method:(HPRequestMethod)method 
                               cached:(BOOL)cached {
	return [[[HPRequestOperation alloc] initWithURL:url 
                                               data:data 
                                             method:method 
                                             cached:cached] autorelease];
}

- (id)initWithURL:(NSURL *)url 
             data:(NSData *)data 
           method:(HPRequestMethod)method 
           cached:(BOOL)cached {
    self = [super init];
    
	if (self) {
		_indexPath = nil;
		_isCached = cached;
		_requestMethod = method;
		_requestURL = [url copy];
		_requestData = [data copy];
		_completionBlocks = [[NSMutableSet alloc] init];
        _cookies = [[NSMutableSet alloc] init];
        _loggingEnabled = NO;
        _username = nil;
        _password = nil;
		
		_isCancelled = NO;
		_isExecuting = NO;
		_isFinished = NO;
	}
	
	return self;
}

#pragma mark - Operation handling

- (void)start {
	if ([self isCancelled]) {
        [self callParserBlockWithData:nil 
                                error:[NSError errorWithDomain:kHPErrorDomain 
                                                          code:kHPRequestConnectionCancelledErrorCode 
                                                      userInfo:nil]];
		return;
	} else if ([self isFinished]) {
        return;
    }
	
	[self willChangeValueForKey:@"isExecuting"];
	_isExecuting = YES;
	[self didChangeValueForKey:@"isExecuting"];
    
    _startTime = [[NSDate date] retain];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_requestURL 
                                                           cachePolicy:(_isCached) ? NSURLRequestReturnCacheDataElseLoad : NSURLRequestReloadIgnoringCacheData 
                                                       timeoutInterval:30.0];

    switch (_requestMethod) {
        case HPRequestMethodGet:
            [request setHTTPMethod:@"GET"];
            break;
        case HPRequestMethodPost:
            [request setHTTPMethod:@"POST"];
            break;
        case HPRequestMethodDelete:
            [request setHTTPMethod:@"DELETE"];
            break;
        case HPRequestMethodPut:
            [request setHTTPMethod:@"PUT"];
            break;
    }
    
    if (_loggingEnabled) {
        NSMutableString *requestLog = [NSMutableString stringWithFormat:@"%@ %@", 
                                       request.HTTPMethod, [request.URL absoluteString]];
        
        if (_requestData != nil && [_requestData length] < HPRequestOperationDataLoggingLimit) {
            [requestLog appendFormat:@"\n%@", 
             [[[NSString alloc] initWithData:_requestData 
                                    encoding:NSUTF8StringEncoding] autorelease]];
        }
        
        NSLog(@"%@", requestLog);
    }
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    
    if (_requestData) {
        [request setHTTPBody:_requestData];
        
        switch (_postType) {
            case HPRequestOperationPostTypeJSON: {
                [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                break;
            }
            case HPRequestOperationPostTypeFile: {
                [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", 
                                   HPRequestOperationMultiPartFormBoundary] forHTTPHeaderField:@"Content-Type"];
                break;
            }
            default: {
                [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
                break;
            }
        }

        [request setValue:[NSString stringWithFormat:@"%d", [_requestData length]] forHTTPHeaderField:@"Content-Length"];
    }
    
    if ([_cookies count] > 0) {
        NSMutableString *cookieHeader = [[NSMutableString alloc] init];
        
        for (NSString *cookie in _cookies) {
            [cookieHeader appendFormat:@"%@;", cookie];
        }
        
        [request setValue:cookieHeader forHTTPHeaderField:@"Cookie"];
        
        [cookieHeader release];
    }
    
    _connection = [[NSURLConnection alloc] initWithRequest:request 
                                                  delegate:self 
                                          startImmediately:NO];
    
    [_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] 
                           forMode:NSRunLoopCommonModes];
	
	if (_connection == nil) {
		[self cancel];
	} else {
        HPCacheItem *cacheItem = nil;
        
        if (_isCached) {
            cacheItem = [[HPCacheManager sharedManager] cachedItemForURL:_requestURL];
        }
        
        if (cacheItem != nil) {
            [_connection cancel];
            
            _MIMEType = [cacheItem.MIMEType copy];
            
            [self callParserBlockWithData:cacheItem.cacheData error:nil];
        } else {
            [_connection start];
        }
	}
}

- (void)cancel {
    [_connection cancel];
	
	[self willChangeValueForKey:@"isCancelled"];
	_isCancelled = YES;
	[self didChangeValueForKey:@"isCancelled"];
    
    if ([self isExecuting]) {
        [self callParserBlockWithData:nil 
                                error:[NSError errorWithDomain:kHPErrorDomain 
                                                          code:kHPRequestConnectionCancelledErrorCode 
                                                      userInfo:nil]];
    }
}

- (BOOL)isConcurrent {
	return YES;
}

- (BOOL)isFinished {
	return _isFinished;
}

- (BOOL)isCancelled {
	return _isCancelled;
}

- (BOOL)isExecuting {
	return _isExecuting;
}

#pragma Progress and completion block handling

- (void)addCompletionBlock:(void(^)(id resources, NSError *error))block {
	[_completionBlocks addObject:[[block copy] autorelease]];
}

- (void)sendResourcesToBlocks:(id)resources {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd 
							   withObject:resources 
							waitUntilDone:NO];
		
		return;
	}
	
	[self sendResourcesToBlocks:resources withError:nil];
}

- (void)sendErrorToBlocks:(NSError *)error {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd 
							   withObject:error 
							waitUntilDone:NO];
		
		return;
	}
    
	[self sendResourcesToBlocks:nil withError:error];
}

- (void)sendResourcesToBlocks:(id)resources withError:(NSError *)error {
	for (void(^blk)(id resources, NSError *error) in _completionBlocks) {
		blk(resources, error);
	}
    
	[self willChangeValueForKey:@"isExecuting"];
	_isExecuting = NO;
	[self didChangeValueForKey:@"isExecuting"];
	
	[self willChangeValueForKey:@"isFinished"];
	_isFinished = YES;
	[self didChangeValueForKey:@"isFinished"];
}

- (void)callParserBlockWithData:(NSData *)data error:(NSError *)error {
	if (data != nil) {
        if ([data length] == 0) {
            [self sendResourcesToBlocks:nil];
            
            return;
        }
        
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
		if (![self isCancelled] && _parserBlock != nil) {
			id parsedData = _parserBlock(data, _MIMEType);
			
            if (parsedData == nil) {
                [self sendErrorToBlocks:[NSError errorWithDomain:kHPErrorDomain 
                                                            code:kHPRequestParserFailureErrorCode 
                                                        userInfo:nil]];
            } else if (error != nil) {
				[self sendErrorToBlocks:[NSError errorWithDomain:kHPErrorDomain 
                                                            code:kHPRequestServerFailureErrorCode 
                                                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                  parsedData, @"serverError", nil]]];
            } else {
				[self sendResourcesToBlocks:parsedData];
			}
		} else {
			[self sendErrorToBlocks:[NSError errorWithDomain:kHPErrorDomain 
                                                        code:kHPRequestParserFailureErrorCode 
                                                    userInfo:nil]];
		}
		
		[pool drain];
	} else {
		[self sendErrorToBlocks:error];
	}
}

- (void)callProgressBlockWithPercentage:(NSNumber *)percentage {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd 
							   withObject:percentage 
							waitUntilDone:NO];
		
		return;
	}
	
	if (![self isCancelled] && _progressBlock != nil) {
		_progressBlock([percentage floatValue]);
	}
}

- (void)callUploadProgressBlockWithPercentage:(NSNumber *)percentage {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd 
							   withObject:percentage 
							waitUntilDone:NO];
		
		return;
	}
	
	if (![self isCancelled] && _uploadProgressBlock != nil) {
		_uploadProgressBlock([percentage floatValue]);
	}
}

#pragma mark - NSURLConnectionDelegate calls

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	_response = [response retain];
    
	NSInteger statusCode = 0;
	
	if ([response respondsToSelector:@selector(statusCode)]) {
		statusCode = [(NSHTTPURLResponse *)response statusCode];
	}
    
	switch (statusCode) {
		case 500: {
			[connection cancel];

			[self callParserBlockWithData:nil 
                                    error:[NSError errorWithDomain:kHPErrorDomain 
                                                              code:kHPRequestServerFailureErrorCode 
                                                          userInfo:nil]];
			
			break;
		}
        case 204: {
            [connection cancel];
            
            [self callParserBlockWithData:nil error:nil];
            
            break;
        }
		default: {
			_expectedSize = [response expectedContentLength];
			
			if (_expectedSize == NSURLResponseUnknownLength) {
				_expectedSize = 0;
			}
            
			_loadedData = [[NSMutableData alloc] initWithCapacity:_expectedSize];
			
			break;
		}
	}
}

- (void)connection:(NSURLConnection *)connection 
   didSendBodyData:(NSInteger)bytesWritten 
 totalBytesWritten:(NSInteger)totalBytesWritten 
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    [self callUploadProgressBlockWithPercentage:[NSNumber numberWithFloat:((float)totalBytesWritten / (float)totalBytesExpectedToWrite)]];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_loadedData appendData:data];
	
	if (_progressBlock != nil) {
		[self callProgressBlockWithPercentage:[NSNumber numberWithFloat:((float)[_loadedData length] / (float)_expectedSize)]];
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[_connection release], _connection = nil;

    if ([error code] == kHPNetworkErrorCode) {
        [self callParserBlockWithData:nil 
                                error:[NSError errorWithDomain:kHPErrorDomain 
                                                          code:kHPNetworkErrorCode 
                                                      userInfo:[NSDictionary dictionaryWithObject:error 
                                                                                           forKey:@"connectionError"]]];
    } else {
        [self callParserBlockWithData:nil 
                                error:[NSError errorWithDomain:kHPErrorDomain 
                                                          code:kHPRequestConnectionFailureErrorCode 
                                                      userInfo:[NSDictionary dictionaryWithObject:error 
                                                                                           forKey:@"connectionError"]]];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[_connection release], _connection = nil;

	NSInteger statusCode = 0;
	
	if ([_response respondsToSelector:@selector(statusCode)]) {
		statusCode = [(NSHTTPURLResponse *)_response statusCode];
	}
    
	if (statusCode == 304 || statusCode >= 400) {
        switch (statusCode) {
            case 400: {
                [self callParserBlockWithData:_loadedData 
                                        error:[NSError errorWithDomain:kHPErrorDomain 
                                                                  code:kHPRequestConnectionFailureErrorCode 
                                                              userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:statusCode] 
                                                                                                   forKey:@"statusCode"]]];
                break;
            }
            default: {
                [self callParserBlockWithData:nil 
                                        error:[NSError errorWithDomain:kHPErrorDomain 
                                                                  code:kHPRequestConnectionFailureErrorCode 
                                                              userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:statusCode] 
                                                                                                   forKey:@"statusCode"]]];
                break;
            }
        }
	} else {
		if (_isCached) {
			if ([_response respondsToSelector:@selector(MIMEType)]) {
				_MIMEType = [[(NSHTTPURLResponse *)_response MIMEType] copy];
			} else {
				_MIMEType = [[NSString alloc] initWithString:@"text/plain"];
			}
            
			[[HPCacheManager sharedManager] cacheData:_loadedData 
											   forURL:_requestURL 
										 withMIMEType:_MIMEType];
		}
		
		[self callParserBlockWithData:_loadedData error:nil];
	}
}

- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request {
    return [NSInputStream inputStreamWithData:_requestData];
}

#pragma mark - Authentication

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    if (_username != nil && _password != nil) {
        return YES;
    }
    
	return [[HPAuthenticationManager sharedManager] isAuthenticated];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge previousFailureCount] >= 2) {
        [self callParserBlockWithData:nil 
                                error:[NSError errorWithDomain:kHPErrorDomain 
                                                          code:kHPRequestAuthenticationFailureErrorCode 
                                                      userInfo:nil]];
        return;
    }
    
    if (_username != nil && _password != nil) {
		[[challenge sender] useCredential:[NSURLCredential credentialWithUser:_username 
																	 password:_password 
																  persistence:NSURLCredentialPersistenceNone] 
			   forAuthenticationChallenge:challenge];

        return;
    }
    
    NSDictionary *userCredentials = [[HPAuthenticationManager sharedManager] userCredentials];

	if (userCredentials != nil && [userCredentials count] > 0) {
		[[challenge sender] useCredential:[NSURLCredential credentialWithUser:[userCredentials objectForKey:HPAuthenticationManagerUsernameKey] 
																	 password:[userCredentials objectForKey:HPAuthenticationManagerPasswordKey] 
																  persistence:NSURLCredentialPersistenceNone] 
			   forAuthenticationChallenge:challenge];
	} else {
        [self callParserBlockWithData:nil 
                                error:[NSError errorWithDomain:kHPErrorDomain 
                                                          code:kHPRequestAuthenticationFailureErrorCode 
                                                      userInfo:nil]];
    }
}

#pragma mark - Cookies

- (void)addCookie:(NSString *)cookie {
    [_cookies addObject:cookie];
}

#pragma mark - Memory management

- (void)dealloc {
	[_connection cancel];

    [_cookies release], _cookies = nil;
	[_MIMEType release], _MIMEType = nil;
	[_response release], _response = nil;
    [_indexPath release], _indexPath = nil;
    [_identifier release], _identifier = nil;
	[_requestURL release], _requestURL = nil;
	[_connection release], _connection = nil;
	[_loadedData release], _loadedData = nil;
    [_requestData release], _requestData = nil;
	[_parserBlock release], _parserBlock = nil;
	[_progressBlock release], _progressBlock = nil;
    [_completionBlocks release], _completionBlocks = nil;
    [_uploadProgressBlock release], _uploadProgressBlock = nil;
    [_startTime release], _startTime = nil;
    [_username release], _username = nil;
    [_password release], _password = nil;
	
	[super dealloc];
}

@end

//
//  HPS3UploadOperation.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-21.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPErrors.h"
#import "HPS3UploadOperation.h"
#import "NSString+HPHashAdditions.h"
#import "NSData+HPBase64Additions.h"


static NSString * const kHPAmazonURL = @"http://%@.s3.amazonaws.com/%@";
static NSString * const kHPAmazonCanonicalHeader = @"x-amz-acl";
static NSString * const kHPAmazonCanonicalPermission = @"public-read";


@interface HPS3UploadOperation (PrivateMethods)
- (void)sendErrorToBlocks:(NSError *)error;
- (void)sendResourcesToBlocks:(id)resources;
- (void)callParserBlockWithData:(NSData *)data error:(NSError *)error;
- (void)sendResourcesToBlocks:(id)resources withError:(NSError *)error;
@end


@implementation HPS3UploadOperation

@synthesize parserBlock = _parserBlock;

+ (HPS3UploadOperation *)uploadOperationWithData:(NSData *)fileData 
                                        MIMEType:(NSString *)MIMEType 
                                       forBucket:(NSString *)bucket 
                                            path:(NSString *)path 
                                   withAccessKey:(NSString *)accessKey 
                                          secret:(NSString *)secret {
    return [[[HPS3UploadOperation alloc] initWithData:fileData 
                                             MIMEType:MIMEType 
                                            forBucket:bucket 
                                                 path:path 
                                        withAccessKey:accessKey 
                                               secret:secret] autorelease];
}

- (id)initWithData:(NSData *)fileData 
          MIMEType:(NSString *)MIMEType 
         forBucket:(NSString *)bucket 
              path:(NSString *)path 
     withAccessKey:(NSString *)accessKey 
            secret:(NSString *)secret {
    self = [super init];
    
    if (self) {
		_completionBlocks = [[NSMutableSet alloc] init];
		
		_isCancelled = NO;
		_isExecuting = NO;
		_isFinished = NO;

		NSString *escapedURLString = [[NSString stringWithFormat:kHPAmazonURL, bucket, path]
                                      stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding];

        NSURL *requestURL = [NSURL URLWithString:escapedURLString];
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL 
															   cachePolicy:NSURLRequestReloadIgnoringCacheData 
														   timeoutInterval:30.0];
		
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        
        [dateFormatter setDateFormat:@"EEE, d MMM yyyy HH:mm:ss zzzz"];
        
        NSString *date = [dateFormatter stringFromDate:[NSDate date]];
        
        [request setHTTPMethod:@"PUT"];
		[request setValue:kHPAmazonCanonicalPermission forHTTPHeaderField:kHPAmazonCanonicalHeader];
        [request setHTTPBody:fileData];
        [request setValue:MIMEType forHTTPHeaderField:@"Content-Type"];
        [request setValue:[NSString stringWithFormat:@"%d", [fileData length]] forHTTPHeaderField:@"Content-Length"];
        [request setValue:date forHTTPHeaderField:@"Date"];
        
        NSString *canonicalResource = [NSString stringWithFormat:@"/%@/%@",bucket,path];
        NSString *canonicalHeaders = [NSString stringWithFormat:@"%@:%@", 
                                      kHPAmazonCanonicalHeader, 
                                      kHPAmazonCanonicalPermission];

        NSString *stringToSign = [NSString stringWithFormat:@"PUT\n\n%@\n%@\n%@\n%@", 
                                  MIMEType, date, canonicalHeaders, canonicalResource];
        
        NSString *signature = [[stringToSign HMACSHA1withKey:secret] base64EncodedString];
        NSString *auth = [NSString stringWithFormat:@"AWS %@:%@", accessKey, signature];
        
        [request setValue:auth forHTTPHeaderField:@"Authorization"];
		//NSLog(@"%@ %@", [request HTTPMethod], [[request URL] absoluteString]);
		_connection = [[NSURLConnection alloc] initWithRequest:request 
													  delegate:self 
											  startImmediately:NO];
        
		[_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] 
							   forMode:NSRunLoopCommonModes];
        
        [dateFormatter release];
    }
    
    return self;
}

#pragma mark - Operation handling

- (void)start {
	if ([self isCancelled] || [self isFinished]) {
		return;
	}
	
	[self willChangeValueForKey:@"isExecuting"];
	_isExecuting = YES;
	[self didChangeValueForKey:@"isExecuting"];
	
	if (_connection == nil) {
		[self cancel];
	} else {
        [_connection start];
	}
}

- (void)cancel {
    [_connection cancel];
	
	[self willChangeValueForKey:@"isCancelled"];
	_isCancelled = YES;
	[self didChangeValueForKey:@"isCancelled"];
	
	[self callParserBlockWithData:nil 
                            error:[NSError errorWithDomain:kHPErrorDomain 
                                                      code:kHPRequestConnectionCancelledErrorCode 
                                                  userInfo:nil]];
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
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
		if (![self isCancelled] && _parserBlock != nil) {
			id parsedData = _parserBlock(data, _MIMEType);
			
            if (parsedData == nil) {
                [self sendErrorToBlocks:[NSError errorWithDomain:kHPErrorDomain 
                                                            code:kHPRequestParserFailureErrorCode 
                                                        userInfo:nil]];
			} else if ([parsedData respondsToSelector:@selector(objectForKey:)] && 
                       [parsedData objectForKey:@"error"] != nil) {
				[self sendErrorToBlocks:[NSError errorWithDomain:kHPErrorDomain 
                                                            code:kHPRequestServerFailureErrorCode 
                                                        userInfo:[NSDictionary dictionaryWithObject:parsedData 
                                                                                             forKey:@"serverError"]]];
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
		default: {
			long long expectedSize = [response expectedContentLength];
			
			if (expectedSize == NSURLResponseUnknownLength) {
				expectedSize = 0;
			}
            
			_loadedData = [[NSMutableData alloc] initWithCapacity:expectedSize];
			
			break;
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_loadedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[self callParserBlockWithData:nil 
                            error:[NSError errorWithDomain:kHPErrorDomain 
                                                      code:kHPRequestConnectionFailureErrorCode 
                                                  userInfo:[NSDictionary dictionaryWithObject:error 
                                                                                       forKey:@"connectionError"]]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSInteger statusCode = 0;
	
	if ([_response respondsToSelector:@selector(statusCode)]) {
		statusCode = [(NSHTTPURLResponse *)_response statusCode];
	}
    
	if (statusCode == 304 || statusCode >= 400) {
		[self callParserBlockWithData:nil 
                                error:[NSError errorWithDomain:kHPErrorDomain 
                                                          code:kHPRequestConnectionFailureErrorCode 
                                                      userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:statusCode] 
                                                                                           forKey:@"statusCode"]]];
	} else {
        if ([_response respondsToSelector:@selector(MIMEType)]) {
            _MIMEType = [[(NSHTTPURLResponse *)_response MIMEType] copy];
        } else {
            _MIMEType = [[NSString alloc] initWithString:@"text/plain"];
        }
		
		[self callParserBlockWithData:_loadedData error:nil];
	}
}

#pragma mark - Memory management

- (void)dealloc {
	[_connection cancel];
    
	[_MIMEType release], _MIMEType = nil;
	[_response release], _response = nil;
	[_connection release], _connection = nil;
	[_loadedData release], _loadedData = nil;
    [_completionBlocks release], _completionBlocks = nil;
	
	[super dealloc];
}

@end

//
//  HPRequestOperation.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#import "HPCacheManager.h"
#import "HPRequestOperation.h"


@interface HPRequestOperation (PrivateMethods)
- (void)callParserBlockWithData:(NSData *)data;
- (void)callProgressBlockWithPercentage:(NSNumber *)percentage;
@end


@implementation HPRequestOperation

@synthesize parserBlock = _parserBlock;
@synthesize progressBlock = _progressBlock;

+ (HPRequestOperation *)operationWithURL:(NSURL *)requestURL cacheResponse:(BOOL)cacheResponse {
	return [[[HPRequestOperation alloc] initWithURL:requestURL 
                                      cacheResponse:cacheResponse] autorelease];
}

- (id)initWithURL:(NSURL *)requestURL cacheResponse:(BOOL)cacheResponse {
	self = [super init];
	
	if (self) {
		_isFinished = NO;
		_isExecuting = NO;
		_isCancelled = NO;
        
		_MIMEType = nil;
		_requestURL = [requestURL copy];
		_cacheResponse = cacheResponse;
		
		NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_requestURL 
															   cachePolicy:(_cacheResponse) ? NSURLRequestReturnCacheDataElseLoad : NSURLRequestReloadIgnoringCacheData 
														   timeoutInterval:30.0];
		
		[request setValue:@"text/javascript" forHTTPHeaderField:@"Accept"];
		
		_connection = [[NSURLConnection alloc] initWithRequest:request 
													  delegate:self 
											  startImmediately:NO];
		
		[_connection scheduleInRunLoop:[NSRunLoop mainRunLoop] 
							   forMode:NSRunLoopCommonModes];
	}
	
	return self;
}

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
        HPCacheItem *cacheItem = nil;
        
        if (_cacheResponse) {
            cacheItem = [[HPCacheManager sharedManager] cachedItemForURL:_requestURL];
        }
        
        if (cacheItem != nil) {
            _MIMEType = [cacheItem.MIMEType copy];
            
            [self callParserBlockWithData:cacheItem.cacheData];
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
	
	[self callParserBlockWithData:nil];
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

- (void)callParserBlockWithData:(NSData *)data {
	if (![NSThread isMainThread]) {
		[self performSelectorOnMainThread:_cmd 
							   withObject:data 
							waitUntilDone:NO];
		
		return;
	}
	
	if (![self isCancelled] && _parserBlock != nil) {
		_parserBlock(data, _MIMEType);
	}
	
	[self willChangeValueForKey:@"isExecuting"];
	_isExecuting = NO;
	[self didChangeValueForKey:@"isExecuting"];
	
	[self willChangeValueForKey:@"isFinished"];
	_isFinished = YES;
	[self didChangeValueForKey:@"isFinished"];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	_response = [response retain];
    
	NSInteger statusCode = 0;
	
	if ([response respondsToSelector:@selector(statusCode)]) {
		statusCode = [(NSHTTPURLResponse *)response statusCode];
	}
    
	switch (statusCode) {
		case 500: {
			[connection cancel];
			
			[self callParserBlockWithData:nil];
			
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

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [_loadedData appendData:data];
	
	if (_progressBlock != nil) {
		[self callProgressBlockWithPercentage:[NSNumber numberWithFloat:((float)[_loadedData length] / (float)_expectedSize)]];
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[self callParserBlockWithData:nil];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSInteger statusCode = 0;
	
	if ([_response respondsToSelector:@selector(statusCode)]) {
		statusCode = [(NSHTTPURLResponse *)_response statusCode];
	}
    
	if (statusCode == 304 || statusCode >= 400) {
		[self callParserBlockWithData:nil];
	} else {
		if (_cacheResponse) {
			if ([_response respondsToSelector:@selector(MIMEType)]) {
				_MIMEType = [[(NSHTTPURLResponse *)_response MIMEType] copy];
			} else {
				_MIMEType = [[NSString alloc] initWithString:@"text/plain"];
			}
            
			[[HPCacheManager sharedManager] cacheData:_loadedData 
											   forURL:_requestURL 
										 withMIMEType:_MIMEType];
		}
		
		[self callParserBlockWithData:_loadedData];
	}
}

- (void)dealloc {
	[_connection cancel];
    
	[_MIMEType release], _MIMEType = nil;
	[_response release], _response = nil;
	[_requestURL release], _requestURL = nil;
	[_connection release], _connection = nil;
	[_loadedData release], _loadedData = nil;
	[_parserBlock release], _parserBlock = nil;
	[_progressBlock release], _progressBlock = nil;
	
	[super dealloc];
}

@end

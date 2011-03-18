//
//  HPRequestOperation.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//


@interface HPRequestOperation : NSOperation {
@private
	NSURLConnection *_connection;
    NSMutableData *_loadedData;
	NSURLResponse *_response;
	NSString *_MIMEType;
	NSURL *_requestURL;
	
	long long _expectedSize;
	
	BOOL _cacheResponse;
	BOOL _isExecuting;
	BOOL _isCancelled;
	BOOL _isFinished;
    
    void (^_parserBlock)(NSData *, NSString *);
    void (^_progressBlock)(float);
}

@property (nonatomic, copy) void (^parserBlock)(NSData *, NSString *);
@property (nonatomic, copy) void (^progressBlock)(float);

+ (HPRequestOperation *)operationWithURL:(NSURL *)requestURL cacheResponse:(BOOL)cacheResponse;

- (id)initWithURL:(NSURL *)requestURL cacheResponse:(BOOL)cacheResponse;

@end

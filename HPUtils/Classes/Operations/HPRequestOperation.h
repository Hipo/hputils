//
//  HPRequestOperation.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//


typedef enum {
	HPRequestMethodGet,
	HPRequestMethodPost,
	HPRequestMethodPut,
	HPRequestMethodDelete
} HPRequestMethod;


@interface HPRequestOperation : NSOperation {
@private
	HPRequestMethod _requestMethod;
    
    NSMutableSet *_completionBlocks;
	NSURLConnection *_connection;
    NSMutableData *_loadedData;
	NSURLResponse *_response;
    NSIndexPath *_indexPath;
	NSData *_requestData;
	NSString *_MIMEType;
	NSURL *_requestURL;
	
	long long _expectedSize;
	
	BOOL _isCached;
	BOOL _isExecuting;
	BOOL _isCancelled;
	BOOL _isFinished;
    
    id (^_parserBlock)(NSData *, NSString *);
    void (^_progressBlock)(float);
}

@property (nonatomic, copy) NSIndexPath *indexPath;

@property (nonatomic, copy) id (^parserBlock)(NSData *, NSString *);
@property (nonatomic, copy) void (^progressBlock)(float);

+ (HPRequestOperation *)requestForURL:(NSURL *)url 
                             withData:(NSData *)data 
                               method:(HPRequestMethod)method 
                               cached:(BOOL)cached;

- (id)initWithURL:(NSURL *)url 
             data:(NSData *)data 
           method:(HPRequestMethod)method 
           cached:(BOOL)cached;

- (void)addCompletionBlock:(void(^)(id resources, NSError *error))block;

@end

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

typedef enum {
    HPRequestOperationPostTypeForm,
    HPRequestOperationPostTypeJSON,
    HPRequestOperationPostTypeFile,
} HPRequestOperationPostType;


extern NSString * const HPRequestOperationMultiPartFormBoundary;


@interface HPRequestOperation : NSOperation {
@private
	HPRequestMethod _requestMethod;
    HPRequestOperationPostType _postType;
    
    NSMutableSet *_cookies;
    NSMutableSet *_completionBlocks;
	NSURLConnection *_connection;
    NSMutableData *_loadedData;
	NSURLResponse *_response;
    NSIndexPath *_indexPath;
    NSString *_identifier;
	NSData *_requestData;
	NSString *_MIMEType;
	NSURL *_requestURL;
	
	long long _expectedSize;
	
	BOOL _isCached;
	BOOL _isExecuting;
	BOOL _isCancelled;
	BOOL _isFinished;
    
    id (^_parserBlock)(NSData *, NSString *);
    void (^_uploadProgressBlock)(float progress);
    void (^_progressBlock)(float);
}

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSIndexPath *indexPath;
@property (nonatomic, assign) HPRequestOperationPostType postType;

@property (nonatomic, copy) id (^parserBlock)(NSData *, NSString *);
@property (nonatomic, copy) void (^uploadProgressBlock)(float progress);
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
- (void)addCookie:(NSString *)cookie;

@end

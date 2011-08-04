//
//  HPCacheManager.h
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//


@interface HPCacheItem : NSObject {
@private
	NSData *_cacheData;
	NSDate *_timeStamp;
	NSString *_MIMEType;
	NSString *_cachePath;
}

@property (nonatomic, retain, readonly) NSData *cacheData;
@property (nonatomic, retain, readonly) NSDate *timeStamp;
@property (nonatomic, retain, readonly) NSString *MIMEType;
@property (nonatomic, retain, readonly) NSString *cachePath;

+ (HPCacheItem *)cacheItemWithPickledObject:(NSDictionary *)pickle;
+ (HPCacheItem *)cacheItemWithCacheData:(NSData *)data 
                                   path:(NSString *)path 
                               MIMEType:(NSString *)type 
                                  stamp:(NSDate *)stamp;

- (id)initWithPickledObject:(NSDictionary *)pickle;
- (id)initWithCacheData:(NSData *)data 
                   path:(NSString *)path 
               MIMEType:(NSString *)type 
                  stamp:(NSDate *)stamp;

- (NSDictionary *)pickledObjectForArchive;

@end


@interface HPCacheManager : NSObject {
@private
	NSString *_cacheDirectoryPath;
	NSString *_storageDirectoryPath;
	NSOperationQueue *_saveQueue;
}

+ (HPCacheManager *)sharedManager;

- (HPCacheItem *)storedItemForStorageKey:(NSString *)storageKey;
- (void)storeData:(NSData *)storageData 
    forStorageKey:(NSString *)storageKey 
     withMIMEType:(NSString *)MIMEType;

- (HPCacheItem *)cachedItemForCacheKey:(NSString *)cacheKey;
- (void)cacheData:(NSData *)cacheData 
      forCacheKey:(NSString *)cacheKey 
     withMIMEType:(NSString *)MIMEType;

- (HPCacheItem *)cachedItemForURL:(NSURL *)url;
- (void)cacheData:(NSData *)cacheData 
           forURL:(NSURL *)url 
     withMIMEType:(NSString *)MIMEType;

- (void)clearCacheForCacheKey:(NSString *)cacheKey;
- (void)clearCacheForURL:(NSURL *)url;

@end

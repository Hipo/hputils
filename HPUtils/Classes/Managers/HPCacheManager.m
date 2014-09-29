//
//  HPCacheManager.m
//  HPUtils
//
//  Created by Taylan Pince on 11-03-18.
//  Copyright 2011 Hippo Foundry. All rights reserved.
//

#include <sys/xattr.h>

#import "HPCacheManager.h"
#import "NSString+HPHashAdditions.h"


const NSUInteger kHPURLCacheMemoryCapacity = 1024 * 1024;
const NSUInteger kHPURLCacheDiskCapacity = 10 * 1024 * 1024;

double const kHPStaleCacheInterval = 60.0 * 60.0 * 24.0;

static NSString * const kURLCachePath = @"caches";
static NSString * const kURLStoragePath = @"storage";
static NSString * const kURLCacheFilename = @"shared";

static NSString * const kCacheInfoPathKey = @"cachePath";
static NSString * const kCacheInfoDataKey = @"cacheData";
static NSString * const kCacheInfoDateKey = @"cacheDate";
static NSString * const kCacheInfoMIMETypeKey = @"mimeType";
static NSString * const kCacheInfoMetaDataKey = @"metaData";


@interface HPURLCache : NSURLCache
@end


@interface HPCacheManager (PrivateMethods)
- (void)storeCacheWithCacheItem:(HPCacheItem *)cacheItem;
- (NSString *)cachePathForCacheKey:(NSString *)cacheKey;
- (NSString *)storagePathForStorageKey:(NSString *)storageKey;
- (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL;
@end


@implementation HPCacheItem

@synthesize cachePath = _cachePath;
@synthesize cacheData = _cacheData;
@synthesize timeStamp = _timeStamp;
@synthesize MIMEType = _MIMEType;

+ (HPCacheItem *)cacheItemWithCacheData:(NSData *)data
                                   path:(NSString *)path
                               MIMEType:(NSString *)type
                                  stamp:(NSDate *)stamp
                               metaData:(NSDictionary *)metaData {
	return [[[HPCacheItem alloc] initWithCacheData:data
                                              path:path
                                          MIMEType:type
                                             stamp:stamp
                                          metaData:metaData] autorelease];
}

+ (HPCacheItem *)cacheItemWithCacheData:(NSData *)data 
                                   path:(NSString *)path 
                               MIMEType:(NSString *)type 
                                  stamp:(NSDate *)stamp {
	return [[[HPCacheItem alloc] initWithCacheData:data 
                                              path:path 
                                          MIMEType:type 
                                             stamp:stamp] autorelease];
}

+ (HPCacheItem *)cacheItemWithPickledObject:(NSDictionary *)pickle {
	return [[[HPCacheItem alloc] initWithPickledObject:pickle] autorelease];
}

- (id)initWithCacheData:(NSData *)data
                   path:(NSString *)path
               MIMEType:(NSString *)type
                  stamp:(NSDate *)stamp
               metaData:(NSDictionary *)metaData {
	self = [super init];
	
	if (self) {
		_cachePath = [path copy];
		_cacheData = [data copy];
		_MIMEType = [type copy];
        _metaData = [metaData copy];
		
		if (stamp != nil) {
			_timeStamp = [stamp copy];
		} else {
			_timeStamp = [[NSDate date] copy];
		}
	}
	
	return self;
}

- (id)initWithCacheData:(NSData *)data 
                   path:(NSString *)path 
               MIMEType:(NSString *)type 
                  stamp:(NSDate *)stamp {
	self = [super init];
	
	if (self) {
		_cachePath = [path copy];
		_cacheData = [data copy];
		_MIMEType = [type copy];
		
		if (stamp != nil) {
			_timeStamp = [stamp copy];
		} else {
			_timeStamp = [[NSDate date] copy];
		}
	}
	
	return self;
}

- (id)initWithPickledObject:(NSDictionary *)pickle {
	return [self initWithCacheData:[pickle objectForKey:kCacheInfoDataKey] 
							  path:[pickle objectForKey:kCacheInfoPathKey] 
						  MIMEType:[pickle objectForKey:kCacheInfoMIMETypeKey] 
							 stamp:[pickle objectForKey:kCacheInfoDateKey]
                          metaData:[pickle objectForKey:kCacheInfoMetaDataKey]];
}

- (NSDictionary *)pickledObjectForArchive {
	NSMutableDictionary *pickle = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   _cacheData, kCacheInfoDataKey,
                                   _timeStamp, kCacheInfoDateKey,
                                   _cachePath, kCacheInfoPathKey,
                                   _MIMEType, kCacheInfoMIMETypeKey, nil];
    
    if (_metaData != nil) {
        [pickle setObject:_metaData forKey:kCacheInfoMetaDataKey];
    }
    
    return pickle;
}

- (void)dealloc {
	[_timeStamp release], _timeStamp = nil;
	[_cachePath release], _cachePath = nil;
	[_cacheData release], _cacheData = nil;
	[_MIMEType release], _MIMEType = nil;
    [_metaData release], _metaData = nil;
	
	[super dealloc];
}

@end


@implementation HPCacheManager

static HPCacheManager *_sharedManager = nil;

+ (HPCacheManager *)sharedManager {
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
		_saveQueue = [[NSOperationQueue alloc] init];
		_cacheDirectoryPath = [[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] 
								stringByAppendingPathComponent:kURLCachePath] copy];
		_storageDirectoryPath = [[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] 
                                  stringByAppendingPathComponent:kURLStoragePath] copy];
		
		[_saveQueue setMaxConcurrentOperationCount:1];
		
		NSFileManager *fileManager = [NSFileManager defaultManager];

		BOOL cachesDirectoryExists = NO;
		
		if (![fileManager fileExistsAtPath:_cacheDirectoryPath isDirectory:&cachesDirectoryExists] || !cachesDirectoryExists) {
			[fileManager createDirectoryAtPath:_cacheDirectoryPath 
				   withIntermediateDirectories:YES 
									attributes:nil 
										 error:nil];
		}
        
		BOOL storageDirectoryExists = NO;
		
		if (![fileManager fileExistsAtPath:_storageDirectoryPath isDirectory:&storageDirectoryExists] || !storageDirectoryExists) {
			[fileManager createDirectoryAtPath:_storageDirectoryPath 
				   withIntermediateDirectories:YES 
									attributes:nil 
										 error:nil];
		}
        
        // Remove legacy storage directory
        NSString *legacyStorageDirectoryPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] 
                                                 stringByAppendingPathComponent:kURLStoragePath];
        
        BOOL legacyStorageDirectoryExists = NO;
		
		if ([fileManager fileExistsAtPath:legacyStorageDirectoryPath isDirectory:&legacyStorageDirectoryExists] || legacyStorageDirectoryExists) {
            NSError *error = nil;

            [fileManager removeItemAtPath:legacyStorageDirectoryPath 
                                    error:&error];
		}

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            // Loop through existing files and delete old ones
            NSError *clearError = nil;
            NSArray *filePaths = [fileManager contentsOfDirectoryAtPath:_cacheDirectoryPath error:&clearError];

            if (clearError == nil && filePaths != nil && [filePaths count] > 0) {
                for (NSString *filePath in filePaths) {
                    NSString *fullFilePath = [_cacheDirectoryPath stringByAppendingPathComponent:filePath];
                    NSDictionary *pickle = [NSKeyedUnarchiver unarchiveObjectWithFile:fullFilePath];

                    if (pickle == nil) {
                        continue;
                    }
                    
                    HPCacheItem *cachedItem = [HPCacheItem cacheItemWithPickledObject:pickle];
                    
                    if (cachedItem.timeStamp != nil
                        && (-1 * [cachedItem.timeStamp timeIntervalSinceNow]) < kHPStaleCacheInterval) {
                        continue;
                    }
                    
                    NSError *deleteError = nil;
                    
                    if (![fileManager removeItemAtPath:fullFilePath error:&deleteError]) {
                        NSLog(@">>> DELETE ERROR: %@", deleteError);
                    }
                }
            }
        });
        
		HPURLCache *urlCache = [[HPURLCache alloc] initWithMemoryCapacity:kHPURLCacheMemoryCapacity
                                                             diskCapacity:kHPURLCacheDiskCapacity 
                                                                 diskPath:_cacheDirectoryPath];
		
		[NSURLCache setSharedURLCache:urlCache];
		
		[urlCache release];
	}
	
	return self;
}

- (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL {
    const char *filePath = [[URL path] fileSystemRepresentation];
    
    const char *attrName = "com.apple.MobileBackup";
    u_int8_t attrValue = 1;
    
    int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
    
    return result == 0;
}

- (NSString *)cachePathForCacheKey:(NSString *)cacheKey {
	return [_cacheDirectoryPath stringByAppendingPathComponent:cacheKey];
}

- (NSString *)storagePathForStorageKey:(NSString *)storageKey {
	return [_storageDirectoryPath stringByAppendingPathComponent:storageKey];
}

- (HPCacheItem *)storedItemForStorageKey:(NSString *)storageKey {
    NSDictionary *pickle = [NSKeyedUnarchiver unarchiveObjectWithFile:[self storagePathForStorageKey:storageKey]];
	
	if (pickle != nil) {
		HPCacheItem *cachedItem = [HPCacheItem cacheItemWithPickledObject:pickle];
		
		return cachedItem;
	} else {
		return nil;
	}
}

- (void)storeData:(NSData *)storageData
    forStorageKey:(NSString *)storageKey
     withMIMEType:(NSString *)MIMEType
         metaData:(NSDictionary *)metaData {
    if (storageData != nil) {
		NSString *storagePath = [self storagePathForStorageKey:storageKey];
        
        [_saveQueue addOperation:[[[NSInvocationOperation alloc]
                                   initWithTarget:self
                                   selector:@selector(storeCacheWithCacheItem:)
                                   object:[HPCacheItem cacheItemWithCacheData:storageData
                                                                         path:storagePath
                                                                     MIMEType:MIMEType
                                                                        stamp:nil
                                                                     metaData:metaData]] autorelease]];
	}
}

- (void)storeData:(NSData *)storageData
    forStorageKey:(NSString *)storageKey
     withMIMEType:(NSString *)MIMEType {

    [self storeData:storageData
      forStorageKey:storageKey
       withMIMEType:MIMEType
           metaData:nil];
}

- (BOOL)hasCachedItemForCacheKey:(NSString *)cacheKey {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self cachePathForCacheKey:cacheKey]];
}

- (HPCacheItem *)cachedItemForCacheKey:(NSString *)cacheKey {
	NSDictionary *pickle = [NSKeyedUnarchiver unarchiveObjectWithFile:[self cachePathForCacheKey:cacheKey]];
	
	if (pickle != nil) {
		HPCacheItem *cachedItem = [HPCacheItem cacheItemWithPickledObject:pickle];
		
		if (cachedItem.timeStamp == nil || 
            (cachedItem.timeStamp != nil && 
             (-1 * [cachedItem.timeStamp timeIntervalSinceNow]) > kHPStaleCacheInterval)) {
			[self clearCacheForCacheKey:cacheKey];
			
			return nil;
		} else {
			return cachedItem;
		}
	} else {
		return nil;
	}
}

- (BOOL)hasCachedItemForURL:(NSURL *)url {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self cachePathForCacheKey:[[url absoluteString] SHA1Hash]]];
}

- (HPCacheItem *)cachedItemForURL:(NSURL *)url {
	return [self cachedItemForCacheKey:[[url absoluteString] SHA1Hash]];
}

- (void)cacheData:(NSData *)cacheData
      forCacheKey:(NSString *)cacheKey
     withMIMEType:(NSString *)MIMEType
         metaData:(NSDictionary *)metaData {
    
	if (cacheData != nil) {
		NSString *cachePath = [self cachePathForCacheKey:cacheKey];
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
			[_saveQueue addOperation:[[[NSInvocationOperation alloc]
                                       initWithTarget:self
                                       selector:@selector(storeCacheWithCacheItem:)
                                       object:[HPCacheItem cacheItemWithCacheData:cacheData
                                                                             path:cachePath
                                                                         MIMEType:MIMEType
                                                                            stamp:nil
                                                                         metaData:metaData]] autorelease]];
		}
	}
}

- (void)cacheData:(NSData *)cacheData
      forCacheKey:(NSString *)cacheKey
     withMIMEType:(NSString *)MIMEType {
    
    [self cacheData:cacheData
        forCacheKey:cacheKey
       withMIMEType:MIMEType
           metaData:nil];
}

- (void)cacheData:(NSData *)cacheData
           forURL:(NSURL *)url
     withMIMEType:(NSString *)MIMEType
         metaData:(NSDictionary *)metaData {
    
	if (cacheData != nil) {
		[self cacheData:cacheData
			forCacheKey:[[url absoluteString] SHA1Hash]
		   withMIMEType:MIMEType
               metaData:metaData];
	}
}

- (void)cacheData:(NSData *)cacheData
           forURL:(NSURL *)url
     withMIMEType:(NSString *)MIMEType {
    
    [self cacheData:cacheData
             forURL:url
       withMIMEType:MIMEType
           metaData:nil];
}

- (void)storeCacheWithCacheItem:(HPCacheItem *)cacheItem {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[NSKeyedArchiver archiveRootObject:[cacheItem pickledObjectForArchive] 
								toFile:cacheItem.cachePath];
    
    [self addSkipBackupAttributeToItemAtURL:[NSURL URLWithString:cacheItem.cachePath]];
	
	[pool drain];
}

- (void)clearCacheForCacheKey:(NSString *)cacheKey {
	NSError *error;
	NSString *cachePath = [self cachePathForCacheKey:cacheKey];
	NSFileManager *fileManager = [NSFileManager defaultManager];

	if ([fileManager fileExistsAtPath:cachePath]) {
		if (![fileManager removeItemAtPath:cachePath error:&error]) {
			NSLog(@"ERROR: %@", [error localizedDescription]);
		}
	}
}

- (void)clearCacheForURL:(NSURL *)url {
	[self clearCacheForCacheKey:[[url absoluteString] SHA1Hash]];
}

- (void)dealloc {
	[_saveQueue cancelAllOperations];
	[_saveQueue release], _saveQueue = nil;
	[_cacheDirectoryPath release], _cacheDirectoryPath = nil;
    [_storageDirectoryPath release], _storageDirectoryPath = nil;
	
	[super dealloc];
}

@end


@implementation HPURLCache

- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request {
	NSCachedURLResponse *memoryResponse = [super cachedResponseForRequest:request];
	
	if (memoryResponse != nil) {
		return memoryResponse;
	}
	
	NSURL *requestURL = [request URL];
	HPCacheItem *cacheItem = [[HPCacheManager sharedManager] cachedItemForURL:requestURL];
    
	if (cacheItem != nil) {
		NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:requestURL 
																	MIMEType:cacheItem.MIMEType 
													   expectedContentLength:[cacheItem.cacheData length] 
															textEncodingName:nil];
		
		NSCachedURLResponse *cachedResponse = [[[NSCachedURLResponse alloc] initWithResponse:response 
																						data:cacheItem.cacheData] autorelease];
		
		[self storeCachedResponse:cachedResponse forRequest:request];
		
		[response release];
		
		return cachedResponse;
	}
    
	return nil;
}

@end

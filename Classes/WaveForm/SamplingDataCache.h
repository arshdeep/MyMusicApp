//
//  SamplingDataCache.h
//  iMusicAmp
//
//  Created by asingh on 2/15/14.
//
//

#import <Foundation/Foundation.h>

@interface SamplingDataCache : NSObject
+ (NSMutableArray *)readData:(NSString *)url;
+ (void)writeData:(NSString *)url data:(NSArray *)data;
@end

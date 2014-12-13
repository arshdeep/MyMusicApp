//
//  SamplingDataCache.m
//  iMusicAmp
//
//  Created by asingh on 2/15/14.
//
//

#import "SamplingDataCache.h"
#import "UtilityExtensions.h"

@implementation SamplingDataCache
+ (NSString *)destination
{
    NSString *root = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    root = [root stringByAppendingPathComponent:@"SamplingDataCache"];
    NSError *err = nil;
    BOOL isDir;

    if (![[NSFileManager defaultManager] fileExistsAtPath:root isDirectory:&isDir])
    {
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:&err];

        [[NSURL fileURLWithPath:root isDirectory:YES] addSkipBackupAttributeToItemAtURL];
        if (err && !success)
        {
            NSLog(@"error creating directory");
            root = nil;
        }
    }
    return root;
}

+ (void)writeData:(NSString *)url data:(NSArray *)data
{
    NSString *filePath = [SamplingDataCache destination];
    
    filePath = [filePath stringByAppendingString:[NSString stringWithFormat:@"/%lu", (unsigned long)[url hash]]];
    BOOL success = [data writeToFile:filePath atomically:YES];

    [[NSURL fileURLWithPath:filePath] addSkipBackupAttributeToItemAtURL];
    if (!success)
    {
        NSLog(@"Error writing sampling data");
    }
}

+ (NSMutableArray *)readData:(NSString *)url
{
    NSString *filePath = [SamplingDataCache destination];
    
    filePath = [filePath stringByAppendingString:[NSString stringWithFormat:@"/%lu", (unsigned long)[url hash]]];
    
    return [NSMutableArray arrayWithContentsOfFile:filePath];
}
@end

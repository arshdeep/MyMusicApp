//
//  ThumbnailDB.m
//  iMusicAmp
//
//  Created by asingh on 2/8/14.
//
//

#import "ThumbnailDB.h"
#import "AssetBrowserItem.h"
#define ThumbnailDBFile @"iMusicAmpThumbDB"
@implementation ThumbnailDB
static ThumbnailDB *sInstance = nil;
- (id)init
{
    if (self = [super init])
    {
        mThumbnailDict = [NSMutableDictionary new];
    }
    return self;
}

+ (ThumbnailDB *)getInstance
{
    @synchronized(self) {
        if (sInstance == nil) {
            sInstance = [[self alloc] init];
        }
    }
    
    return sInstance;
}

- (void)dealloc
{
    [mThumbnailDict release];
    [super dealloc];
}

- (void)addThumbnail:(NSString*)album thumbnail:(UIImage *)image
{
    if (image)
    {
        image = [UIImage imageWithCGImage:image.CGImage scale:2.0 orientation:image.imageOrientation];
        [mThumbnailDict setObject:image forKey:album];
    }
}

- (UIImage *)getThumbnailCached:(AssetBrowserItem *)item
{
    return [self getThumbnailCachedFromString:[item album]];
}

- (UIImage *)getThumbnailCachedFromString:(NSString *)album
{
    return [mThumbnailDict objectForKey:album];
}

-(UIImage *)thumbnail:(AssetBrowserItem *)item
{
    NSString *album = [item album];
    
    UIImage *image = [mThumbnailDict objectForKey:album];
    
    if (image == nil)
    {
        image = [item generateThumbnail:item.asset];
        if (image)
        {
            [self addThumbnail:album thumbnail:image];
        }
    }
    
    return image;
}
@end

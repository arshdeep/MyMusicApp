//
//  ThumbnailDB.h
//  iMusicAmp
//
//  Created by asingh on 2/8/14.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIImage.h>
@class AssetBrowserItem;

@interface ThumbnailDB : NSObject
{
    NSMutableDictionary *mThumbnailDict;
}
+ (ThumbnailDB *)getInstance;
- (UIImage *)thumbnail:(AssetBrowserItem *)item;
- (UIImage *)getThumbnailCached:(AssetBrowserItem *)item;
- (UIImage *)getThumbnailCachedFromString:(NSString *)album;
- (void)addThumbnail:(NSString*)album thumbnail:(UIImage *)image;
@end

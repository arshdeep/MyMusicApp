//
//  UtilityExtensions.h
//  iMusicAmp
//
//  Created by asingh on 12/21/13.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIBarButtonItem.h>
#import <MediaPlayer/MPNowPlayingInfoCenter.h>

#define HEIGHT_IPHONE_5 568
#define IS_IPHONE   ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
#define IS_IPHONE_4 (IS_IPHONE && [[UIScreen mainScreen] bounds ].size.height < HEIGHT_IPHONE_5 )

@class AssetBrowserItem;
@class AVPlayer;

@interface UIBarButtonItem(MusicAmpEx)
+ (UIBarButtonItem *)createCustomButtonWithText:(NSString *)text
                                  textAlignment:(NSUInteger)textAlignment
                                       fontSize:(NSInteger)fontSize
                                         target:(id)target
                                       selector:(SEL)selector;
@end

@interface MPNowPlayingInfoCenter(MusicAmpEx)
+ (void)updateMPCentre :(AVPlayer *)player item:(AssetBrowserItem *)item;
@end

@interface NSURL(MusicAmpEx)
- (BOOL)addSkipBackupAttributeToItemAtURL;
@end
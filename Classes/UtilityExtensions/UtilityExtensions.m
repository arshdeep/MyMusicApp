//
//  UtilityExtensions.m
//  iMusicAmp
//
//  Created by asingh on 12/21/13.
//
//

#import "UtilityExtensions.h"
#import <UIKit/UILabel.h>
#import <UIkit/UIImage.h>
#import <UIKit/UIGraphics.h>
#import <QuartzCore/CALayer.h>
#import "AssetBrowserItem.h"
#import <MediaPlayer/MPMediaItem.h>
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVPlayerItem.h>

@implementation UIBarButtonItem(MusicAmpEx)
+ (UIBarButtonItem *)createCustomButtonWithText:(NSString *)text
                                  textAlignment:(NSUInteger)textAlignment
                                       fontSize:(NSInteger)fontSize
                                         target:(id)target
                                       selector:(SEL)selector
{
    UILabel * addCustomLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 40)] autorelease];
    addCustomLabel.textColor = [UIColor whiteColor];
    addCustomLabel.font = [UIFont boldSystemFontOfSize:fontSize];
    NSMutableString *labelText = [NSMutableString stringWithString:text];
    int spaceCount = [labelText replaceOccurrencesOfString:@" " withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, labelText.length)];
    addCustomLabel.text = labelText;
    addCustomLabel.numberOfLines = spaceCount > 0 ? spaceCount + 1 : 1;
    addCustomLabel.backgroundColor = [UIColor clearColor];
    addCustomLabel.textAlignment = textAlignment;
    
    CGSize size = addCustomLabel.bounds.size;
    
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [addCustomLabel.layer renderInContext: context];
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage * img = [UIImage imageWithCGImage: imageRef];
    CGImageRelease(imageRef);
    UIGraphicsEndImageContext();
    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithImage:img
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:target
                                                                     action:selector];
    barButtonItem.tintColor = [UIColor orangeColor];

    return barButtonItem;
}

@end

@implementation MPNowPlayingInfoCenter(MusicAmpEx)
+ (void)updateMPCentre :(AVPlayer *)player item:(AssetBrowserItem *)item
{
    NSMutableDictionary *nowPlayingInfo = [[NSMutableDictionary new] autorelease];
    NSString *title = [item getTitleSynchronously];
    NSString *artist = [item artist];
    NSString *album = [item album];
    UIImage *mediaArtwork = [item generateThumbnail:item.asset];
    
    if (title) {
        [nowPlayingInfo setObject:title forKey:MPMediaItemPropertyTitle];
    }
    if (artist)
    {
        [nowPlayingInfo setObject:artist forKey:MPMediaItemPropertyArtist];
    }
    if (album)
    {
        [nowPlayingInfo setObject:album forKey:MPMediaItemPropertyAlbumTitle];
    }
    
    [nowPlayingInfo setObject:[NSNumber numberWithFloat:CMTimeGetSeconds(player.currentItem.duration)] forKey:MPMediaItemPropertyPlaybackDuration];
    [nowPlayingInfo setObject:[NSNumber numberWithInt:1] forKey:MPNowPlayingInfoPropertyPlaybackRate];
    [nowPlayingInfo setObject:[NSNumber numberWithInt:CMTimeGetSeconds(player.currentTime)] forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    
    if (mediaArtwork)
    {
        MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithImage:mediaArtwork];
        [nowPlayingInfo setObject:artwork forKey:MPMediaItemPropertyArtwork];
        [artwork release];
    }
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlayingInfo;
}

@end

@implementation NSURL(MusicAmpEx)
- (BOOL)addSkipBackupAttributeToItemAtURL
{
    assert([[NSFileManager defaultManager] fileExistsAtPath: [self path]]);
    
    NSError *error = nil;
    BOOL success = [self setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];

    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [self lastPathComponent], error);
    }
    return success;
}

@end
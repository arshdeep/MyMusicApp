//
//  PlaylistManager.h
//  iMusicAmp
//
//  Created by asingh on 12/22/13.
//
//

#import <Foundation/Foundation.h>
#import "AssetBrowserController.h"
#import "MAReorderTableView.h"
@class AssetBrowserItem;

typedef enum
{
    kPlay,
    kNext,
    kPrevious
} MAPlayerAction;
@interface MAPlaylistManager : NSObject <ReorderTableViewDelegate>
{
    NSMutableDictionary *mPlaylistDict;
    NSString *mCurrentPlaylist;
    id <AssetBrowserControllerDelegate> delegate;
    NSUInteger mCurrentItemIndex;
    AssetBrowserItem *mCurrentItem;
    NSUInteger mEnqueueCount;
}
@property (readonly, nonatomic) NSString *currentPlaylist;
@property (readonly) NSUInteger currentItemIndex;
@property (readonly) BOOL isDirty;
@property (nonatomic, assign) id<AssetBrowserControllerDelegate> delegate;
+ (MAPlaylistManager *)getInstance;
+ (NSString *)playlistDirectory;
- (void)saveCurrentPlayList;
- (NSMutableArray *)getCurrentPlaylist;
- (BOOL)setCurrentItemAtIndex:(NSUInteger)index;
- (void)setPlayList:(NSString *)title values:(NSMutableArray *)values;
- (void)enqueue:(AssetBrowserItem *)item isNext:(BOOL)isNext;
- (void)processRequest:(MAPlayerAction)action;
- (BOOL)removeSongAtIndex:(NSUInteger)row;
- (BOOL)removeSongFromDisk:(NSURL*)url;
- (BOOL)setCurrentItem:(NSURL *)url;
@end

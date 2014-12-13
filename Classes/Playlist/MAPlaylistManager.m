//
//  PlaylistManager.m
//  iMusicAmp
//
//  Created by asingh on 12/22/13.
//
//

#import "MAPlaylistManager.h"
#import "AssetBrowserItem.h"
#import <AVFoundation/AVPlayerItem.h>
#import "MusicAmpPreferences.h"
#import "ThumbnailDB.h"
#import "UtilityExtensions.h"

@interface MAPlaylistManager()
@property (readwrite, retain) NSString *currentPlaylist;
@property (readwrite, retain) AssetBrowserItem *mCurrentItem;
@property (readwrite) BOOL isDirty;
@end

@implementation MAPlaylistManager
@synthesize currentPlaylist = mCurrentPlaylist, currentItemIndex = mCurrentItemIndex, delegate, mCurrentItem, isDirty;
static MAPlaylistManager *sInstance = nil;
- (id)init
{
    if (self = [super init])
    {
        mPlaylistDict = [NSMutableDictionary new];
        self.isDirty = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];
    }
    return self;
}

+ (MAPlaylistManager *)getInstance
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
    sInstance = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [mCurrentPlaylist release];
    [mPlaylistDict release];
    [super dealloc];
}

+ (NSString *)playlistDirectory
{
    NSString *root = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    root = [root stringByAppendingString:@"/Playlists"];
    BOOL isDir;

    if (![[NSFileManager defaultManager] fileExistsAtPath:root isDirectory:&isDir])
    {
        NSError *err = nil;
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

- (BOOL)setCurrentItem:(NSURL *)url
{
    NSMutableArray *playlist = (NSMutableArray *)[mPlaylistDict objectForKey:mCurrentPlaylist];
    BOOL isSuccess = NO;
    
    if (playlist) {
        NSUInteger playlistLen = playlist.count;
        NSUInteger index = 0;
        
        for (; index < playlistLen; index++) {
            AssetBrowserItem *tempItem = [playlist objectAtIndex:index];
            if ([tempItem.URL hash] == [url hash]) {
                mCurrentItemIndex = index;
                mCurrentItem = [playlist objectAtIndex:mCurrentItemIndex];
                isSuccess = YES;
                break;
            }
        }
    }
    if (!isSuccess)
    {
        NSLog(@"No playlist found. Can't set url. Creating default.");
        [self setCurrentPlaylist:@"Now Playing"];
        NSMutableArray *playlistTemp = [[NSMutableArray new] autorelease];
        AssetBrowserItem *item = [[[AssetBrowserItem alloc] initWithURL:url] autorelease];
        [playlistTemp addObject:item];
        [self setPlayList:@"Now Playing" values:playlistTemp];
    }
    
    return isSuccess;
}

- (void)saveCurrentPlayList
{
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"" message:@"Playlist Title" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Cancel", nil] autorelease];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.delegate = self;
    [alert show];
}

// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        NSString *inputText = [[alertView textFieldAtIndex:0] text];
        if (inputText.length) {
            NSMutableArray *playlist = [mPlaylistDict objectForKey:mCurrentPlaylist];
            NSMutableArray *tempList = [[NSMutableArray new] autorelease];
        
            for (AssetBrowserItem *item in playlist) {
                [tempList addObject:item.URL.absoluteString];
            }
            NSString *dest = [MAPlaylistManager playlistDirectory];
            NSString *filePath = [dest stringByAppendingPathComponent:inputText];
            [tempList writeToFile:filePath atomically:YES];
            
            [[NSURL URLWithString:filePath] addSkipBackupAttributeToItemAtURL];
            self.isDirty = NO;
        }
    }
}

// Called when we cancel a view (eg. the user clicks the Home button). This is not called when the user clicks the cancel button.
// If not defined in the delegate, we simulate a click in the cancel button
- (void)alertViewCancel:(UIAlertView *)alertView
{
    
}

#pragma mark -
#pragma mark Notifications
- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    Repeat repeatPref = [MusicAmpPreferences repeatPrefernce];
    Shuffle shufflePref = [MusicAmpPreferences shufflePreference];
    
    [self setCurrentItemAtIndex:repeatPref != kRepeatSong ?
                      shufflePref == kShuffleAll ? mCurrentItemIndex + rand() : ++mCurrentItemIndex : mCurrentItemIndex];
}

- (void)processRequest:(MAPlayerAction)action
{
    Shuffle shufflePref = [MusicAmpPreferences shufflePreference];
    
    [self setCurrentItemAtIndex:shufflePref == kShuffleAll ? mCurrentItemIndex + rand() : action == kNext ? ++mCurrentItemIndex : --mCurrentItemIndex];
}

- (NSMutableArray *)getCurrentPlaylist
{
    return [mPlaylistDict objectForKey:mCurrentPlaylist];
}

- (void)setPlayList:(NSString *)title values:(NSMutableArray *)values
{
    self.isDirty = YES;
    self.currentPlaylist = title;
    [mPlaylistDict removeObjectForKey:title];
    [mPlaylistDict setObject:values forKey:title];
}

- (BOOL)setCurrentItemAtIndex:(NSUInteger)index
{
    NSMutableArray *playlist = (NSMutableArray *)[mPlaylistDict objectForKey:mCurrentPlaylist];
    BOOL isSuccess = NO;
    if (playlist != nil)
    {
        mCurrentItemIndex = index % (playlist.count);
        mCurrentItem = [playlist objectAtIndex:mCurrentItemIndex];
        [self.delegate setAsset:mCurrentItem];
        isSuccess = YES;
    }
    return isSuccess;
}

- (BOOL)removeSongFromDisk:(NSURL*)url
{
    NSMutableArray *playlist = (NSMutableArray *)[mPlaylistDict objectForKey:mCurrentPlaylist];
    BOOL isSuccess = NO;
    
    if (playlist) {
        NSUInteger playlistLen = playlist.count;
        NSUInteger index = 0;

        for (; index < playlistLen; index++) {
            AssetBrowserItem *tempItem = [playlist objectAtIndex:index];
            if ([tempItem.URL hash] == [url hash]) {
                if ([mCurrentItem.URL hash] == [url hash])
                {
                    [self processRequest:kNext];
                }
                [playlist removeObject:tempItem];
                isSuccess = YES;
                self.isDirty = YES;
                break;
            }
        }
    }
    return isSuccess;
}

- (BOOL)removeSongAtIndex:(NSUInteger)row
{
    NSMutableArray *playlist = [mPlaylistDict objectForKey:mCurrentPlaylist];
    
    [playlist removeObjectAtIndex:row];
    self.isDirty = YES;
    
    return YES;
}

- (void)enqueue:(AssetBrowserItem *)item isNext:(BOOL)isNext
{
    NSMutableArray *playlist = (NSMutableArray *)[mPlaylistDict objectForKey:mCurrentPlaylist];
    NSUInteger playlistLen = playlist.count;
    NSUInteger index = 0;
    for (; index < playlistLen; index++) {
        AssetBrowserItem *tempItem = [playlist objectAtIndex:index];
        if ([tempItem.URL hash] == [item.URL hash]
                && index != mCurrentItemIndex) {
            [playlist removeObject:tempItem];

            break;
        }
    }
    if (isNext)
    {
        [playlist insertObject:item atIndex:mCurrentItemIndex < index ? mCurrentItemIndex + 1 : mCurrentItemIndex];
    }
    else
    {
        [playlist addObject:item];
    }
    self.isDirty = YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self setCurrentItemAtIndex:indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [tableView reloadData];
}

- (id)saveObjectAtIndex:(NSIndexPath *)indexPath
{
    return [[self getCurrentPlaylist] objectAtIndex:indexPath.row];
}

// This method is called when starting the re-ording process. You insert a blank row object into your
// data source and return the object you want to save for later. This method is only called once.
- (void)insertBlankRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *playlist = [self getCurrentPlaylist];
    AssetBrowserItem *blankItem = [[[AssetBrowserItem alloc] initWithURL:[NSURL URLWithString:@""] title:@""] autorelease];
    [playlist replaceObjectAtIndex:indexPath.row withObject:blankItem];
}

// This method is called when the selected row is dragged to a new position. You simply update your
// data source to reflect that the rows have switched places. This can be called multiple times
// during the reordering process.
- (void)moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    NSMutableArray *playlist = [self getCurrentPlaylist];
    id object = [[playlist objectAtIndex:fromIndexPath.row] retain];
    [playlist removeObjectAtIndex:fromIndexPath.row];
    [playlist insertObject:object atIndex:toIndexPath.row];
    [object release];
}

// This method is called when the selected row is released to its new position. The object is the same
// object you returned in saveObjectAndInsertBlankRowAtIndexPath:. Simply update the data source so the
// object is in its new position. You should do any saving/cleanup here.
- (void)finishReorderingWithObject:(id)object atIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *playlist = [self getCurrentPlaylist];
    [playlist replaceObjectAtIndex:indexPath.row withObject:object];
    self.isDirty = YES;
    [self syncAssentInfo];
}

- (void)syncAssentInfo
{
    NSMutableArray *playlist = [self getCurrentPlaylist];
    NSUInteger playlistLen = playlist.count;
    NSUInteger index = 0;
    for (; index < playlistLen; ++index) {
        AssetBrowserItem *tempItem = [playlist objectAtIndex:index];
        if ([tempItem.URL hash] == [mCurrentItem.URL hash])
        {
            mCurrentItemIndex = index;
            break;
         }
    }
}
@end

/*
     File: AssetBrowserSource.m
 Abstract: Represents a source like the camera roll and vends AssetBrowserItems.
  Version: 1.3
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2011-2013 Apple Inc. All Rights Reserved.
 
*/

#import "AssetBrowserSource.h"

#import "DirectoryWatcher.h"

#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/UTType.h>

#import <MediaPlayer/MediaPlayer.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ThumbnailDB.h"
#import "MAPlaylistManager.h"
#import "VirtualAssetBrowserItem.h"

@interface AssetBrowserSource () <DirectoryWatcherDelegate>

//@property (nonatomic, readwrite, copy) NSMutableArray *items; // NSArray of AssetBrowserItems
@property (nonatomic, retain) AssetBrowserItem *albumCustomSource;
@property (nonatomic) AssetBrowserSourceType albumSourceType;
@end


@implementation AssetBrowserSource

@synthesize name = sourceName, items = assetBrowserItems, delegate, type = sourceType;

- (NSString*)nameForSourceType
{
	NSString *name = nil;
	
	switch (sourceType) {
		case AssetBrowserSourceTypeFileSharing:
			name = NSLocalizedString(@"Share", nil);
			break;
		case AssetBrowserSourceTypeCameraRoll:
			name = NSLocalizedString(@"Camera Roll", nil);
			break;
		case AssetBrowserSourceTypeIPodLibrary:
			name = NSLocalizedString(@"iPod", nil);
			break;
        case AssetBrowserSourceTypePlayLists:
			name = NSLocalizedString(@"Playlists", nil);
			break;
        case AssetBrowserSourceTypeFileTransfer:
			name = NSLocalizedString(@"File Transfer", nil);
			break;
		default:
			name = nil;
			break;
	}
	
	return name;
}

+ (AssetBrowserSource*)assetBrowserSourceOfType:(AssetBrowserSourceType)sourceType
{
	return [[[self alloc] initWithSourceType:sourceType] autorelease];
}

+ (AssetBrowserSource *)initWithAlbumAsCustomSource:(AssetBrowserItem *)album source:(AssetBrowserSourceType)albumSource
{
    AssetBrowserSource *source = [[AssetBrowserSource alloc] initWithSourceType:AssetBrowserSourceTypeCustomSource];
    source.albumCustomSource = album;
    source.albumSourceType = albumSource;
    return [source autorelease];
}

- (id)initWithSourceType:(AssetBrowserSourceType)type
{
	if ((self = [super init])) {
		sourceType = type;
		sourceName = [[self nameForSourceType] retain];
		assetBrowserItems = nil;
		
		enumerationQueue = dispatch_queue_create("Browser Enumeration Queue", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(enumerationQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0));
	}
	return self;
}

- (void)updateBrowserItemsAndSignalDelegate:(NSMutableArray*)newItems
{	
	self.items = newItems;

	/* Ideally we would reuse the AssetBrowserItems which remain unchanged between updates.
	 This could be done by maintaining a dictionary of assetURLs -> AssetBrowserItems.
	 This would also allow us to more easily tell our delegate which indices were added/removed
	 so that it could animate the table view updates. */
	
	if (self.delegate && [self.delegate respondsToSelector:@selector(assetBrowserSourceItemsDidChange:)]) {
		[self.delegate assetBrowserSourceItemsDidChange:self];
	}
}

- (void)dealloc 
{
    [_albumCustomSource release];
	[sourceName release];
	[assetBrowserItems release];
	
	if (receivingIPodLibraryNotifications) {
		MPMediaLibrary *iPodLibrary = [MPMediaLibrary defaultMediaLibrary];
		[iPodLibrary endGeneratingLibraryChangeNotifications];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MPMediaLibraryDidChangeNotification object:nil];
	}
	dispatch_release(enumerationQueue);
	
	if (assetsLibrary) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:ALAssetsLibraryChangedNotification object:nil];	
		[assetsLibrary release];
	}
	
	[directoryWatcher invalidate];
	directoryWatcher.delegate = nil;
	[directoryWatcher release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark iPod Library

- (void)updateIPodLibrary
{
	dispatch_async(enumerationQueue, ^(void) {
		// Grab videos from the iPod Library
		//MPMediaQuery *videoQuery = [[MPMediaQuery alloc] init];
		
		NSMutableArray *items = [NSMutableArray arrayWithCapacity:0];
		/*NSArray *mediaItems = [videoQuery items];
		for (MPMediaItem *mediaItem in mediaItems) {
			NSURL *URL = (NSURL*)[mediaItem valueForProperty:MPMediaItemPropertyAlbumTitle];//MPMediaItemPropertyAssetURL];
			
			if (URL) {
				NSString *title = (NSString*)[mediaItem valueForProperty:MPMediaItemPropertyTitle];
				AssetBrowserItem *item = [[AssetBrowserItem alloc] initWithURL:URL title:title];
				[items addObject:item];
				[item release];
			}
		}
		[videoQuery release];*/
        MPMediaQuery *mpQuery = [MPMediaQuery albumsQuery];
        NSArray *allAlbums = [mpQuery collections];
        NSHashTable *albumsHash = [[NSHashTable new] autorelease];
        
        for (MPMediaItemCollection *collection in allAlbums) {
            MPMediaItem *mediaItem = [collection representativeItem];
            NSString *title = [mediaItem valueForProperty:MPMediaItemPropertyAlbumTitle];
            NSNumber *titleHash = [NSNumber numberWithInt:[title hash]];
            
            if ([albumsHash member:titleHash] == nil) {
                [albumsHash addObject:titleHash];
                MPMediaItemArtwork *mediaItemArtwork = (MPMediaItemArtwork *)[mediaItem valueForProperty:MPMediaItemPropertyArtwork];
                UIImage *thumb = [mediaItemArtwork imageWithSize:CGSizeMake(50, 60)];
                if (thumb)
                {
                    [[ThumbnailDB getInstance] addThumbnail:title thumbnail:thumb];
                }
                AssetBrowserItem *item = [[AssetBrowserItem alloc] initWithURL:nil title:title];
                item.subTitle = [mediaItem valueForProperty:MPMediaItemPropertyAlbumArtist];
                [items addObject:item];
                [item release];
            }
        }
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self updateBrowserItemsAndSignalDelegate:items];
		});
	});
}

- (void)iPodLibraryDidChange:(NSNotification*)changeNotification
{
	[self updateIPodLibrary];
}

- (void)buildIPodLibrary
{
	MPMediaLibrary *iPodLibrary = [MPMediaLibrary defaultMediaLibrary];
	receivingIPodLibraryNotifications = YES;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iPodLibraryDidChange:) 
												 name:MPMediaLibraryDidChangeNotification object:nil];
	[iPodLibrary beginGeneratingLibraryChangeNotifications];
	
	[self updateIPodLibrary];	
}

#pragma mark -
#pragma mark Assets Library

- (void)updateAssetsLibrary
{
	NSMutableArray *assetItems = [NSMutableArray arrayWithCapacity:0];
	ALAssetsLibrary *assetLibrary = assetsLibrary;
	
	[assetLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
		 if (group) {
			 [group setAssetsFilter:[ALAssetsFilter allVideos]];
			 [group enumerateAssetsUsingBlock:
			  ^(ALAsset *asset, NSUInteger index, BOOL *stopIt)
			  {
				  if (asset) {
					  ALAssetRepresentation *defaultRepresentation = [asset defaultRepresentation];
					  NSString *uti = [defaultRepresentation UTI];
					  NSURL *URL = [[asset valueForProperty:ALAssetPropertyURLs] valueForKey:uti];
					  NSString *title = [NSString stringWithFormat:@"%@ %i", NSLocalizedString(@"Video", nil), [assetItems count]+1];
					  AssetBrowserItem *item = [[[AssetBrowserItem alloc] initWithURL:URL title:title] autorelease];
					  
					  [assetItems addObject:item];
				  }
			  }];
		 }
		// group == nil signals we are done iterating.
		else {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self updateBrowserItemsAndSignalDelegate:assetItems];
			});
		}
	}
	failureBlock:^(NSError *error) {
		NSLog(@"error enumerating AssetLibrary groups %@\n", error);
	}];
}

- (void)assetsLibraryDidChange:(NSNotification*)changeNotification
{
	[self updateAssetsLibrary];
}

- (void)buildAssetsLibrary
{
	assetsLibrary = [[ALAssetsLibrary alloc] init];
	ALAssetsLibrary *notificationSender = nil;
	
	NSString *minimumSystemVersion = @"4.1";
	NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
	if ([systemVersion compare:minimumSystemVersion options:NSNumericSearch] != NSOrderedAscending)
		notificationSender = assetsLibrary;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(assetsLibraryDidChange:) 
												 name:ALAssetsLibraryChangedNotification object:notificationSender];
	[self updateAssetsLibrary];
}

#pragma mark -
#pragma mark iTunes File Sharing
- (UIImage *)getFolderArtwork:(NSString *)directoryPath
{
    UIImage *image = nil;
    NSArray *subPaths = [[[[NSFileManager alloc] init] autorelease] contentsOfDirectoryAtPath:directoryPath error:nil];
	if (subPaths) {
		for (NSString *subPath in subPaths) {
          
			NSString *pathExtension = [subPath pathExtension];
			CFStringRef preferredUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)pathExtension, NULL);
			BOOL fileConformsToUTI = UTTypeConformsTo(preferredUTI, kUTTypeAudiovisualContent);
			CFRelease(preferredUTI);
			NSString *path = [directoryPath stringByAppendingPathComponent:subPath];
			
			if (fileConformsToUTI) {
				AssetBrowserItem *item = [[[AssetBrowserItem alloc] initWithURL:[NSURL fileURLWithPath:path]] autorelease];
                image = [item generateThumbnail:item.asset];
                image = [UIImage imageWithCGImage:image.CGImage scale:4.0 orientation:image.imageOrientation];
                if (image)
                {
                    break;
                }
			}
		}
	}
    return image;
}

- (NSMutableArray*)browserItemsInDirectory:(NSString*)directoryPath readDirOnly:(BOOL)readDirOnly
{
	NSMutableArray *paths = [NSMutableArray arrayWithCapacity:0];
	NSArray *subPaths = [[[[NSFileManager alloc] init] autorelease] contentsOfDirectoryAtPath:directoryPath error:nil];
    directoryPath = [directoryPath stringByAppendingString:@"/"];
	if (subPaths) {
		for (NSString *subPath in subPaths) {
            BOOL isDir = YES;
            [[NSFileManager defaultManager] fileExistsAtPath:[directoryPath stringByAppendingString:subPath] isDirectory:&isDir];
            
			NSString *pathExtension = [subPath pathExtension];
			CFStringRef preferredUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)pathExtension, NULL);
			BOOL fileConformsToUTI = UTTypeConformsTo(preferredUTI, kUTTypeAudiovisualContent);
			CFRelease(preferredUTI);
			NSString *path = [directoryPath stringByAppendingPathComponent:subPath];
			
			if (fileConformsToUTI || isDir) {
				[paths addObject:path];
			}
		}
	}
	
	NSMutableArray *browserItems = [NSMutableArray arrayWithCapacity:0];
    NSMutableDictionary *albumsDict = [[NSMutableDictionary new] autorelease];
    
	for (NSString *path in paths) {
        BOOL isDir = YES;
        [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
        AssetBrowserItem *item = nil;
        if (isDir == YES && readDirOnly)
        {
            NSArray *songs = [[[[NSFileManager alloc] init] autorelease] contentsOfDirectoryAtPath:path error:nil];
            if (songs.count)
            {
                item = [[[AssetBrowserItem alloc] initWithURL:nil title:[path lastPathComponent]] autorelease];

                UIImage *thumb = [self getFolderArtwork:path];
                if (thumb)
                {
                    [[ThumbnailDB getInstance] addThumbnail:[path lastPathComponent] thumbnail:thumb];
                }
            }
        }
        else {
            item = [[[AssetBrowserItem alloc] initWithURL:[NSURL fileURLWithPath:path]] autorelease];
            
            if (readDirOnly)
            {
                NSString *album = [item album];
                if ([album length] == 0)
                {
                    album = [item.URL lastPathComponent];
                }
                NSNumber *titleHash = [NSNumber numberWithInt:[album hash]];
                VirtualAssetBrowserItem *virtualFolder = [albumsDict objectForKey:titleHash];
                
                if (virtualFolder == nil) {
                    UIImage *image = [item generateThumbnail:item.asset];
                    image = [UIImage imageWithCGImage:image.CGImage scale:4.0 orientation:image.imageOrientation];
                    [[ThumbnailDB getInstance] addThumbnail:album thumbnail:image];
                    
                    virtualFolder = [[[VirtualAssetBrowserItem alloc] initWithItem:album] autorelease];
                    [virtualFolder addItem:item];
                    item = virtualFolder;
                    [albumsDict setObject:item forKey:titleHash];
                }
                else
                {
                    [virtualFolder addItem:item];
                    item = nil;
                }
            }
        }
        if (item) {
            [browserItems addObject:item];
        }
	}
	return browserItems;
}

- (void)directoryDidChange:(DirectoryWatcher *)folderWatcher
{
    NSString *documentsDirectory = nil;
    if (sourceType == AssetBrowserSourceTypePlayLists)
    {
        documentsDirectory = [MAPlaylistManager playlistDirectory];
    }
    else {
        documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    }
	dispatch_async(enumerationQueue, ^(void) {
        NSMutableArray *browserItems = nil;
        if (sourceType == AssetBrowserSourceTypePlayLists)
        {
            browserItems = [self getPlayLists];
        }
        else{
            browserItems = [self browserItemsInDirectory:documentsDirectory readDirOnly:YES];
        }
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self updateBrowserItemsAndSignalDelegate:browserItems];
        });
	});
}

- (void)buildFileSharingLibrary
{
	NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
  	directoryWatcher = [[DirectoryWatcher watchFolderWithPath:documentsDirectory delegate:self] retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void) {
        NSMutableArray *browserItems = [self browserItemsInDirectory:documentsDirectory readDirOnly:YES];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self updateBrowserItemsAndSignalDelegate:browserItems];
        });
    });

}
- (NSMutableArray *)getPlayLists
{
    NSString *playlistsDir = [MAPlaylistManager playlistDirectory];
    NSArray *subPaths = [[[[NSFileManager alloc] init] autorelease] contentsOfDirectoryAtPath:playlistsDir error:nil];
    NSMutableArray *playlists = [[NSMutableArray new] autorelease];
    
	if (subPaths) {
		for (NSString *subPath in subPaths) {
			NSString *path = [playlistsDir stringByAppendingPathComponent:subPath];
			AssetBrowserItem *playlistItem = [[[AssetBrowserItem alloc] initWithURL:nil title:subPath] autorelease];
            [playlists addObject:playlistItem];
            NSArray *songs = [NSArray arrayWithContentsOfFile:path];
            
            for (NSString *url in songs) {
				AssetBrowserItem *item = [[[AssetBrowserItem alloc] initWithURL:[NSURL URLWithString:url]] autorelease];
                UIImage *image = [item generateThumbnail:item.asset];
                image = [UIImage imageWithCGImage:image.CGImage scale:4.0 orientation:image.imageOrientation];
                if (image)
                {
                    [[ThumbnailDB getInstance] addThumbnail:subPath thumbnail:image];
                    break;
                }
			}
		}
	}
    return playlists;
}

- (void)buildPlaylists
{
    NSString *playlistsDir = [MAPlaylistManager playlistDirectory];
    directoryWatcher = [[DirectoryWatcher watchFolderWithPath:playlistsDir delegate:self] retain];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void) {
        NSMutableArray *browserItems = [self getPlayLists];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self updateBrowserItemsAndSignalDelegate:browserItems];
        });
    });
}

- (void)buildSourceLibrary
{
	if (haveBuiltSourceLibrary)
		return;
	
	switch (sourceType) {
		case AssetBrowserSourceTypeFileSharing:
			[self buildFileSharingLibrary];
			break;
		case AssetBrowserSourceTypeCameraRoll:
			[self buildAssetsLibrary];
			break;
		case AssetBrowserSourceTypeIPodLibrary:
			[self buildIPodLibrary];
			break;
        case AssetBrowserSourceTypePlayLists:
            [self buildPlaylists];
            break;
        case AssetBrowserSourceTypeCustomSource:
            [self buildAlbum:_albumCustomSource];
		default:
			break;
	}
	
	haveBuiltSourceLibrary = YES;
}

- (void)buildAlbum:(AssetBrowserItem *)album
{
    NSString *albumName = [album album];
    NSMutableArray *songsList = nil;
    if (_albumSourceType == AssetBrowserSourceTypeIPodLibrary)
    {
        songsList = [NSMutableArray array];
        MPMediaPropertyPredicate *albumPredicate = [MPMediaPropertyPredicate predicateWithValue:albumName forProperty:MPMediaItemPropertyAlbumTitle];
        MPMediaQuery *mediaItems = [[MPMediaQuery new] autorelease];
    
        [mediaItems addFilterPredicate:albumPredicate];
        NSArray *songListArray = [mediaItems items];
        for (MPMediaItem *mediaItem in songListArray) {
            NSURL *URL = (NSURL*)[mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
        
            if (URL) {
                NSString *title = (NSString*)[mediaItem valueForProperty:MPMediaItemPropertyTitle];

                AssetBrowserItem *item = [[AssetBrowserItem alloc] initWithURL:URL title:title];
                [(NSMutableArray *)songsList addObject:item];
                [item release];
            }
        }
    }
    else if (_albumSourceType == AssetBrowserSourceTypeFileSharing)
    {
        if ([album isKindOfClass:[VirtualAssetBrowserItem class]])
        {
            songsList = ((VirtualAssetBrowserItem *)album).urlItems;
        }
        else
        {
            NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
            path = [path stringByAppendingPathComponent:albumName];
            songsList = [self browserItemsInDirectory:path readDirOnly:NO];
        }
    }
    else if (_albumSourceType == AssetBrowserSourceTypePlayLists)
    {
        NSString *playlistsDir = [MAPlaylistManager playlistDirectory];
        NSString *path = [playlistsDir stringByAppendingPathComponent:albumName];
        NSArray *songs = [NSArray arrayWithContentsOfFile:path];
        songsList = [[NSMutableArray new] autorelease];
        for (NSString *url in songs) {
            AssetBrowserItem *item = [[[AssetBrowserItem alloc] initWithURL:[NSURL URLWithString:url]] autorelease];
            [songsList addObject:item];
        }
    }
    //dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self updateBrowserItemsAndSignalDelegate:songsList];
    //});
}

@end

/*

File: AVPlayerDemoAppDelegate.m

Abstract: An application delegate managing the picker view controller, playback view controller, and shared navigation controller.

Version: 1.1

Disclaimer: IMPORTANT:  This Apple software is supplied to you by 
Apple Inc. ("Apple") in consideration of your agreement to the
following terms, and your use, installation, modification or
redistribution of this Apple software constitutes acceptance of these
terms.  If you do not agree with these terms, please do not use,
install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software. 
Neither the name, trademarks, service marks or logos of Apple Inc. 
may be used to endorse or promote products derived from the Apple
Software without specific prior written permission from Apple.  Except
as expressly stated in this notice, no other rights or licenses, express
or implied, are granted by Apple herein, including but not limited to
any patent rights that may be infringed by your derivative works or by
other works in which the Apple Software may be incorporated.

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

Copyright (C) 2010-2013 Apple Inc. All Rights Reserved.

*/


#import "iMusicAmpAppDelegate.h"
#import "MusicAmpPlaybackViewController.h"
#import "HTTPServerController.h"
#import "MAPlaylistManager.h"
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

typedef void (^AlertViewCompletionHandler)(void);

@implementation MusicAmpAppDelegate

@synthesize cachedAssetBrowser, playbackViewController;

- (UINavigationController*)assetBrowserControllerWithSourceType:(AssetBrowserSourceType)sourceType delegate:(id <AssetBrowserControllerDelegate>)delegate
{
    UINavigationController *navController = nil;
    if (sourceType & AssetBrowserSourceTypeFileTransfer) {
        navController = [[[UINavigationController alloc] initWithRootViewController:httpServer] autorelease];
    }
    else {
        AssetBrowserController *browser = [[[AssetBrowserController alloc] initWithSourceType:sourceType modalPresentation:NO] autorelease];
        browser.delegate = delegate;
	
        navController = [[[UINavigationController alloc] initWithRootViewController:browser] autorelease];
    }
	[navController.navigationBar setTranslucent:YES];
    //navController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
    navController.navigationBar.tintColor = [UIColor orangeColor];
	return navController;
}

- (UITabBarController*)tabbedAssetBrowserControllerWithSourceType:(AssetBrowserSourceType)sourceType delegate:(id <AssetBrowserControllerDelegate>)delegate
{
	UITabBarController *assetTabBarController = [[[UITabBarController alloc] init] autorelease];

    assetTabBarController.tabBar.barStyle = UIBarStyleDefault;
    assetTabBarController.tabBar.tintColor = [UIColor orangeColor];
	NSMutableArray *assetBrowserControllers = [NSMutableArray arrayWithCapacity:0];
	
	if (sourceType & AssetBrowserSourceTypeCameraRoll) {
	//	[assetBrowserControllers addObject:[self assetBrowserControllerWithSourceType:AssetBrowserSourceTypeCameraRoll
        //delegate:delegate]];
	}
	if (sourceType & AssetBrowserSourceTypeFileSharing) {
        UINavigationController *navController = [self assetBrowserControllerWithSourceType:AssetBrowserSourceTypeFileSharing delegate:delegate];
        navController.tabBarItem.image = [UIImage imageNamed:@"FileShare_25"];
		[assetBrowserControllers addObject:navController];
	}
	if (sourceType & AssetBrowserSourceTypeIPodLibrary) {
        UINavigationController *navController = [self assetBrowserControllerWithSourceType:AssetBrowserSourceTypeIPodLibrary delegate:delegate];
        navController.tabBarItem.image = [UIImage imageNamed:@"ipod_25"];
		[assetBrowserControllers addObject:navController];
	}
    if (sourceType & AssetBrowserSourceTypePlayLists) {
        UINavigationController *navController = [self assetBrowserControllerWithSourceType:AssetBrowserSourceTypePlayLists delegate:delegate];
        navController.tabBarItem.image = [UIImage imageNamed:@"playlist-bar-25"];
		[assetBrowserControllers addObject:navController];
    }
    if (sourceType & AssetBrowserSourceTypeFileTransfer) {
        UINavigationController *navController = [self assetBrowserControllerWithSourceType:AssetBrowserSourceTypeFileTransfer delegate:delegate];
        navController.tabBarItem.image = [UIImage imageNamed:@"Wifi-Share_25"];
        [assetBrowserControllers addObject:navController];
    }
    [MAPlaylistManager getInstance].delegate = self;
	assetTabBarController.viewControllers = assetBrowserControllers;
	
	return assetTabBarController;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([url isFileURL])
    {
        [[MAPlaylistManager getInstance] setCurrentItem:url];
       
        [self didPickURL:[[[AVURLAsset alloc] initWithURL:url options:nil] autorelease]];
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"" message:@"Saved To Share > Inbox" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] autorelease];
        [alert show];
        return YES;
    }
    return NO;
}

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    self->tabBarController = [self tabbedAssetBrowserControllerWithSourceType:AssetBrowserSourceTypeAll delegate:self];

    [self->window setRootViewController:self.cachedAssetBrowser];
    [self->window addSubview:self.cachedAssetBrowser.view];
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    // Restore saved tab bar item from the defaults system.
    // The UITabBarItem 'tag' value is used to identify the saved tab bar item.
    NSInteger tabBarItemIndex = [defaults integerForKey:AVPlayerDemoPickerViewControllerSourceTypeUserDefaultsKey];
    NSArray *viewControllers = self->tabBarController.viewControllers;
    if (tabBarItemIndex < 0)
    {
        // If saved tab bar item does not match any existing item, then default to the first item.
        self->tabBarController.selectedIndex = 0;
    }
    else
    {
        NSUInteger tempTabBarItemIndex = (NSUInteger)tabBarItemIndex;
        if (tempTabBarItemIndex > [viewControllers count])
        {
                // If saved tab bar item does not match any existing item, then default to the first item.
            self->tabBarController.selectedIndex = 0;
        }
        else
        {
            self->tabBarController.selectedIndex = tabBarItemIndex;
        }

    }
    //self.cachedAssetBrowser.navigationBar.barStyle = UIBarStyleBlackOpaque;
    // Add the tab bar controller's current view as a subview of the window
    [self.cachedAssetBrowser pushViewController:self->tabBarController animated:NO];
    [self->window makeKeyAndVisible];
    
    // Restore saved media from the defaults system.
    NSURL* URL = [defaults URLForKey:AVPlayerDemoContentURLUserDefaultsKey];
    if (URL)
    {
        if (!self.playbackViewController)
        {
           self->playbackViewController = [[MusicAmpPlaybackViewController alloc] init];
        }
        
        if ([self.playbackViewController player] == nil
                    || [[self.playbackViewController player] rate] == 0.0f) {
            [[MAPlaylistManager getInstance] setCurrentItem:URL];
            [self showPlayer];
            [self.playbackViewController restoreURL:URL play:NO];
        }
    }

	return YES;
}

- (void)didReceiveRemoteEvent:(UIEvent *)event
{
    if (self->playbackViewController)
    {
        [self->playbackViewController remoteControlReceivedWithEvent:event];
    }
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	if (self.playbackViewController && ![self.playbackViewController URL])
	{
		self.playbackViewController = nil;
	}
}

/* When the app goes to the background, save the media url and time values
 to the application preferences. */
- (void)applicationDidEnterBackground:(UIApplication*)application
{
	if (self.playbackViewController)
	{
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		NSURL* URL = [self.playbackViewController URL];
		
		if (URL)
		{
			NSTimeInterval time = CMTimeGetSeconds([[self.playbackViewController player] currentTime]);
			
			[defaults setURL:URL forKey:AVPlayerDemoContentURLUserDefaultsKey];
			[defaults setDouble:time forKey:AVPlayerDemoContentTimeUserDefaultsKey];
		}
		else
		{
			[defaults removeObjectForKey:AVPlayerDemoContentURLUserDefaultsKey];
			[defaults removeObjectForKey:AVPlayerDemoContentTimeUserDefaultsKey];
		}
		
		[defaults synchronize];
	}
    [self.playbackViewController becomeFirstResponder];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"App did become active");
   [self.playbackViewController updateView];
    [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayback
                                           error: nil];
}

#pragma mark -
#pragma mark AssetBrowser Delegate

- (void)didPickURL:(AVURLAsset *)urlAsset
{
	if (urlAsset)
	{
		if (!self.playbackViewController)
		{
			self->playbackViewController = [[MusicAmpPlaybackViewController alloc] init];
		}
		
		[self.playbackViewController setURL:urlAsset.URL];
	}
	else if (self.playbackViewController)
	{
		[self.playbackViewController setURL:nil];
	}
    [[AVAudioSession sharedInstance]
        setCategory: AVAudioSessionCategoryPlayback
        error: nil];
}

- (void)assetBrowser:(AssetBrowserController *)assetBrowser didChooseItem:(AssetBrowserItem *)assetBrowserItem
{
    [self setAsset:assetBrowserItem];
}

- (void)setAsset:(AssetBrowserItem *)assetBrowserItem
{
	AVURLAsset *asset = (AVURLAsset*)assetBrowserItem.asset;
    [self didPickURL:asset];
}

- (void)showPlayer
{
    if (!self.playbackViewController)
    {
        self->playbackViewController = [[MusicAmpPlaybackViewController alloc] init];
    }
    
    [self.cachedAssetBrowser pushViewController:self.playbackViewController animated:YES];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    /* Don't show the navigation bar when displaying the assets browser view */
    if (viewController == self->tabBarController) {
        navigationController.navigationBarHidden = YES;
    }
    else
    {
        navigationController.navigationBarHidden = NO;        
    }
}

/*- (void)dealloc
{
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [super dealloc];
}*/

@end

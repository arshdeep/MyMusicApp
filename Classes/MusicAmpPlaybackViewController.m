//
//  MusicAmpPlaybackViewController.m
//  iMusicAmp
//
//  Created by asingh on 12/21/13.
//
//

#import "MusicAmpPlaybackViewController.h"
//#import "AVPlayerDemoPlaybackView.h"
#import "AVPlayerDemoMetadataViewController.h"
#import "WaveFormView.h"
#import "AssetBrowserItem.h"
#import "UtilityExtensions.h"
#import "MusicAmpPreferences.h"
#import "MAPlaylistViewController.h"
#import "MAPlaylistManager.h"
#import "iMusicAmpAppDelegate.h"
#import <MediaPlayer/MPVolumeView.h>

/* Asset keys */
NSString * const kTracksKey         = @"tracks";
NSString * const kPlayableKey		= @"playable";

/* PlayerItem keys */
NSString * const kStatusKey         = @"status";

/* AVPlayer keys */
NSString * const kRateKey			= @"rate";
NSString * const kCurrentItemKey	= @"currentItem";

@interface MusicAmpPlaybackViewController ()
- (void)play:(id)sender;
- (void)pause:(id)sender;
- (void)showPlayButton;
- (void)showPauseButton;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
- (id)init;
- (void)dealloc;
- (void)viewDidLoad;
//- (void)viewWillDisappear:(BOOL)animated;
//- (void)handleSwipe:(UISwipeGestureRecognizer*)gestureRecognizer;
//- (void)syncPlayPauseButtons;
- (void)setURL:(NSURL*)URL;
- (NSURL*)URL;
@property (nonatomic, readwrite) UIActionSheet *mConfirmSheet;
@end

/*@interface MusicAmpPlaybackViewController (Player)
- (void)removePlayerTimeObserver;
- (CMTime)playerItemDuration;
- (BOOL)isPlaying;
- (void)playerItemDidReachEnd:(NSNotification *)notification ;
- (void)observeValueForKeyPath:(NSString*) path ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys;
@end*/

static void *AVPlayerDemoPlaybackViewControllerRateObservationContext = &AVPlayerDemoPlaybackViewControllerRateObservationContext;
static void *AVPlayerDemoPlaybackViewControllerStatusObservationContext = &AVPlayerDemoPlaybackViewControllerStatusObservationContext;
static void *AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext = &AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext;

#pragma mark -
@implementation MusicAmpPlaybackViewController

@synthesize mArtwork, mToolbar, mPlayButton, mStopButton;

#pragma mark Asset URL
- (void)updatePlaybackView
{
    if (mURL != nil)
    {
        AssetBrowserItem *item = [[[AssetBrowserItem alloc] initWithURL:mURL] autorelease];

        mAlbumName.text = [item album];
        mArtistName.text = [item artist];
        mArtwork.image = [item generateThumbnail:item.asset];
        if(!mArtwork.image)
        {
            mArtwork.image = [item placeHolderImage];
        }
        mSongName.text = [item getTitleSynchronously];
    }
}

- (void)setURL:(NSURL*)URL
{
	if (mURL != URL)
	{
		[mURL release];
		mURL = [URL copy];
        [self updatePlaybackView];
        dispatch_async( dispatch_get_main_queue(),
                       ^{
                           [mWaveformView openAudioURL:mURL];
                           [self play:nil];
                       });
	}
    else if ([mWaveformView player].rate == 0.0)
    {
        [mWaveformView replayAudio];
        [self showPauseButton];
    }
}

- (void)restoreURL:(NSURL*)URL play:(BOOL)flag
{
    [mURL release];
    mURL = [URL copy];
    [self updatePlaybackView];
    dispatch_async( dispatch_get_main_queue(),
                   ^{
                        [mWaveformView openAudioURL:mURL];
                        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
                        [[self player] seekToTime:CMTimeMakeWithSeconds([defaults doubleForKey:AVPlayerDemoContentTimeUserDefaultsKey], NSEC_PER_SEC)];
                       if (flag)
                       {
                           [self play:nil];
                       }
                    });
}

- (NSURL*)URL
{
	return mURL;
}

#pragma mark -
#pragma mark Movie controller methods

#pragma mark
#pragma mark Button Action Methods

- (IBAction)play:(id)sender
{
	/* If we are at the end of the movie, we must seek to the beginning first 
		before starting playback. */
	/*if (YES == seekToZeroBeforePlay)
	{
		seekToZeroBeforePlay = NO;
		[self.mPlayer seekToTime:kCMTimeZero];
	}

	[self.mPlayer play];
	
    [self showStopButton];*/
    [mWaveformView playAudio];
    [self showPauseButton];
    if ([self player].rate == 0.0f)
    {
        [self restoreState:YES];
    }
}

- (IBAction)pause:(id)sender
{
	//[self.mPlayer pause];
    [mWaveformView pauseAudio];
    [self showPlayButton];
}

- (IBAction)fastForward:(id)sender
{
    [[MAPlaylistManager getInstance] processRequest:kNext];
}

- (IBAction)rewind:(id)sender
{
    [[MAPlaylistManager getInstance] processRequest:kPrevious];
}

#pragma mark -
#pragma mark Play, Stop buttons

/* Show the pause button in the movie player controller. */
-(void)showPauseButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:4 withObject:mPauseButton];
    self.mToolbar.items = toolbarItems;
}

/* Show the play button in the movie player controller. */
-(void)showPlayButton
{
    if (mWaveformView != nil && [[mWaveformView player] rate] == 0.0){
        NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
        [toolbarItems replaceObjectAtIndex:4 withObject:self.mPlayButton];
        self.mToolbar.items = toolbarItems;
    }
}

- (BOOL)isPlaying
{
    return [[mWaveformView player] rate];
}

/* If the media is playing, show the stop button; otherwise, show the play button. */
- (void)syncPlayPauseButtons
{
	if ([self isPlaying])
	{
        [self showPauseButton];
	}
	else
	{
        [self showPlayButton];        
	}
}

-(void)enablePlayerButtons
{
    self.mPlayButton.enabled = YES;
    self.mStopButton.enabled = YES;
}

-(void)disablePlayerButtons
{
    self.mPlayButton.enabled = NO;
    self.mStopButton.enabled = NO;
}

- (AVPlayer *)player
{
    return [mWaveformView player];
}

#pragma mark
#pragma mark View Controller

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(showPlayButton)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];	}
	
	return self;
}

- (id)init
{
    self = [self initWithNibName:IS_IPHONE_4 ? @"MusicAmpPlaybackView" : @"MusicAmpPlaybackViewEx" bundle:nil];
    self.title = NSLocalizedString(@"Now Playing", nil);
   
    return self;
}

- (void)updateView
{
    [self syncPlayPauseButtons];
}

- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[mVolumeSlider release];
    mVolumeSlider = nil;
    self.mToolbar = nil;
    [mPlayButton release];
    [mNextButton release];
    [mRewindButton release];
    self.mPlayButton = nil;
    self.mStopButton = nil;

    [mURL release];
    
    [super viewDidUnload];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    float volume = mVolumeSlider.value;
    BOOL volumeChange = YES;
    
    CGPoint nowPoint = [touches.anyObject locationInView:self.view];
    CGPoint prevPoint = [touches.anyObject previousLocationInView:self.view];
    
    if (nowPoint.x >= prevPoint.x && nowPoint.y >= prevPoint.y) {
        volume -= 0.035f;
        if (volume < 0.0f)
            volume = 0.0f;
    }
    else if (nowPoint.x >= prevPoint.x && nowPoint.y <= prevPoint.y) {
        volume += 0.035f;
        if (volume > 1.0f)
            volume = 1.0f;
    }
    else
    {
        volumeChange = NO;
    }
    
    if (volumeChange)
    {
        mVolumeSlider.value = volume;
    }
}

- (void)createVolumeSlider
{
    MPVolumeView *volumeView = [[MPVolumeView new] autorelease];
    
    [[volumeView subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[UISlider class]]) {
            mVolumeSlider = [obj retain];
            *stop = YES;
        }
    }];
}

- (void)viewDidLoad
{
   /* [self.navigationController.navigationBar setBackgroundImage:[[UIImage new] autorelease]
                                                  forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [[UIImage new] autorelease];
    self.navigationController.navigationBar.translucent = YES;*/
    
    [self createVolumeSlider];
	/*[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDeviceOrientationDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    */
    [self.navigationController.interactivePopGestureRecognizer setEnabled:NO];
    [mArtwork setUserInteractionEnabled:YES];
    [self updatePlaybackView];

    UISwipeGestureRecognizer *leftSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(fastForward:)];
    UISwipeGestureRecognizer *rightSwipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(rewind:)];
    [leftSwipe setDirection:UISwipeGestureRecognizerDirectionLeft];
    [rightSwipe setDirection:UISwipeGestureRecognizerDirectionRight];
    
    [mArtwork addGestureRecognizer:leftSwipe];
    [mArtwork addGestureRecognizer:rightSwipe];
    
    mPlayButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                target:self
                                                                action:@selector(play:)];
    mPlayButton.tintColor = [UIColor orangeColor];
    mPauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                                target:self
                                                                action:@selector(pause:)];
    mPauseButton.tintColor = [UIColor orangeColor];
    mNextButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
                                                                target:self
                                                                action:@selector(fastForward:)];
    mNextButton.tintColor = [UIColor orangeColor];
    mRewindButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind
                                                                  target:self
                                                                  action:@selector(rewind:)];
    mRewindButton.tintColor = [UIColor orangeColor];
    /*UIBarButtonItem *repeatBtn = [UIBarButtonItem createCustomButtonWithText:NSLocalizedString(@"Repeat", nil)
                                                               textAlignment:UITextAlignmentCenter
                                                                    fontSize:13
                                                                      target:self
                                                                    selector:@selector(showRepeatAlert:)];
    UIBarButtonItem *shuffleBtn = [UIBarButtonItem createCustomButtonWithText:NSLocalizedString(@"Shuffle", nil)
                                                                textAlignment:UITextAlignmentCenter
                                                                     fontSize:13
                                                                       target:self
                                                                     selector:@selector(showShuffleAlert:)];*/
    UIBarButtonItem *repeatBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Repeat", nil) style:UIBarButtonItemStylePlain target:self action:@selector(showRepeatAlert:)];
    UIBarButtonItem *shuffleBtn = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Shuffle", nil) style:UIBarButtonItemStylePlain target:self action:@selector(showShuffleAlert:)];
    shuffleBtn.tintColor = [UIColor orangeColor];
    repeatBtn.tintColor = [UIColor orangeColor];
    UIBarButtonItem *spaceItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease];
    self.mToolbar.items = [NSArray arrayWithObjects:repeatBtn, spaceItem, mRewindButton, spaceItem, mPlayButton, spaceItem, mNextButton, spaceItem, shuffleBtn, nil];
    //self.mToolbar.barStyle = UIBarStyleBlackOpaque;
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"playlist-bar-25"] style:UIBarButtonItemStylePlain
                                                                                           target:self
                                                                                            action:@selector(showPlaylist:)] autorelease];
    [super viewDidLoad];
    self.navigationController.navigationBar.tintColor = [UIColor orangeColor];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hidePlaylist:)
                                                 name:kPlaylistViewDoneNotification
                                               object:nil];
    [self syncPlayPauseButtons];
    NSError *setCategoryError = nil;
    NSError *activationError = nil;

    [[AVAudioSession sharedInstance] setActive:YES error:&activationError];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&setCategoryError];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:[AVAudioSession sharedInstance]];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(handleInterruption:)
                                                 name: AVAudioSessionInterruptionNotification
                                               object: [AVAudioSession sharedInstance]];
    // Registers the audio route change listener callback function
}

-(void)handleInterruption:(NSNotification*)notification{
    NSInteger reason = 0;
    NSString* reasonStr=@"";
    if ([notification.name isEqualToString:@"AVAudioSessionInterruptionNotification"]) {
        //Posted when an audio interruption occurs.
        reason = [[[notification userInfo] objectForKey:@" AVAudioSessionInterruptionTypeKey"] integerValue];
        if (reason == AVAudioSessionInterruptionTypeBegan) {
            //       Audio has stopped, already inactive
            //       Change state of UI, etc., to reflect non-playing state
            [self showPlayButton];
            //mIsPlayerInterrupted = YES;
        }
        
        if (reason == AVAudioSessionInterruptionTypeEnded) {
            //       Make session active
            //       Update user interface
            //       AVAudioSessionInterruptionOptionShouldResume option
            reasonStr = @"AVAudioSessionInterruptionTypeEnded";
            NSNumber* seccondReason = [[notification userInfo] objectForKey:@"AVAudioSessionInterruptionOptionKey"] ;
            switch ([seccondReason integerValue]) {
                case AVAudioSessionInterruptionOptionShouldResume:
                {
                    //          Indicates that the audio session is active and immediately ready to be used. Your app can resume the audio operation that was interrupted.
                    if (mIsPlayerInterrupted == YES)
                    {
                        [self play:nil];
                    }
                    mIsPlayerInterrupted = NO;
                }
                    break;
                default:
                {
                    mIsPlayerInterrupted = [[mWaveformView player] rate] != 0.0;
                }
                    break;
            }
        }
        
        
        if ([notification.name isEqualToString:@"AVAudioSessionDidBeginInterruptionNotification"]) {

            //      Posted after an interruption in your audio session occurs.
            //      This notification is posted on the main thread of your app. There is no userInfo dictionary.
        }
        if ([notification.name isEqualToString:@"AVAudioSessionDidEndInterruptionNotification"]) {
            //      Posted after an interruption in your audio session ends.
            //      This notification is posted on the main thread of your app. There is no userInfo dictionary.
        }
        if ([notification.name isEqualToString:@"AVAudioSessionInputDidBecomeAvailableNotification"]) {
            //      Posted when an input to the audio session becomes available.
            //      This notification is posted on the main thread of your app. There is no userInfo dictionary.
        }
        if ([notification.name isEqualToString:@"AVAudioSessionInputDidBecomeUnavailableNotification"]) {
            //      Posted when an input to the audio session becomes unavailable.
            //      This notification is posted on the main thread of your app. There is no userInfo dictionary.
        }
        
    };
    NSLog(@"handleInterruption: %@ reason %@",[notification name],reasonStr);
}

-(void)handleRouteChange:(NSNotification*)notification
{
    AVAudioSession *session = [ AVAudioSession sharedInstance ];
    NSString* seccReason = @"";
    NSInteger  reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    //  AVAudioSessionRouteDescription* prevRoute = [[notification userInfo] objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            seccReason = @"The route changed because no suitable route is now available for the specified category.";
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            seccReason = @"The route changed when the device woke up from sleep.";
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            seccReason = @"The output route was overridden by the app.";
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            seccReason = @"The category of the session object changed.";
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        {
            seccReason = @"The previous audio output path is no longer available.";
            [self saveState];
            [self pause:nil];
        }
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            seccReason = @"A preferred new audio output path is now available.";
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default:
            seccReason = @"The reason for the change is unknown.";
            break;
    }
    NSLog(seccReason);
    AVAudioSessionPortDescription *input = [[session.currentRoute.inputs count]?session.currentRoute.inputs:nil objectAtIndex:0];
    if (input.portType == AVAudioSessionPortHeadsetMic) {
        
    }
}

- (void)showShuffleAlert:(id)sender
{
    self.mConfirmSheet = [[UIActionSheet alloc] initWithTitle:@"Shuffle"
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                       destructiveButtonTitle:nil
                                            otherButtonTitles:NSLocalizedString(@"Shuffle Off", nil),
                                                NSLocalizedString(@"Shuffle All", nil), nil];
    [self.mConfirmSheet showInView:self.view];
}

- (void)showRepeatAlert:(id)sender {
    self.mConfirmSheet = [[UIActionSheet alloc] initWithTitle:@"Repeat"
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                       destructiveButtonTitle:nil
                                            otherButtonTitles:NSLocalizedString(@"Repeat Off", nil),
                                                NSLocalizedString(@"Repeat Song", nil),
                                                NSLocalizedString(@"Repeat Album", nil),
                                                nil];
    [self.mConfirmSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if ([actionSheet.title compare:@"Repeat"] == NSOrderedSame)
    {
        [MusicAmpPreferences setRepeatPreference:buttonIndex];
    }
    else if ([actionSheet.title compare:@"Shuffle"] == NSOrderedSame)
    {
        [MusicAmpPreferences setShufflePreference:buttonIndex];
    }
    [actionSheet release];
    actionSheet = nil;
    self.mConfirmSheet = nil;
}

- (void)showPlaylist:(id)sender
{
    [mWaveformView needsDisplay:NO];
    if (mPlaylistController == nil) {
        mPlaylistController = [[UINavigationController alloc] initWithRootViewController:[[MAPlaylistViewController new] autorelease]];
        mPlaylistController.view.autoresizesSubviews = YES;
        mPlaylistController.view.autoresizingMask |= UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }

    //[self presentViewController:mPlaylistController animated:YES completion:nil];
    [self.parentViewController.view addSubview:mPlaylistController.view];
}

- (void)hidePlaylist:(NSNotification *)object
{
    [mWaveformView needsDisplay:YES];
    //[self dismissViewControllerAnimated:mPlaylistController completion:nil];
    [mPlaylistController.view removeFromSuperview];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    //Once the view has loaded then we can register to begin recieving controls and we can become the first responder
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    //End recieving events
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
}

//Make sure we can recieve remote control events
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)restoreState:(BOOL)playFlag
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSURL* URL = [defaults URLForKey:AVPlayerDemoContentURLUserDefaultsKey];
	if (URL)
    {
        [[MAPlaylistManager getInstance] setCurrentItem:URL];
        [self restoreURL:URL play:playFlag];
    }
}

- (void)saveState
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    NSURL* URL = [self URL];
    
    if (URL)
    {
        NSTimeInterval time = CMTimeGetSeconds([[self player] currentTime]);
        
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

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    //if it is a remote control event handle it correctly
    if (event.type == UIEventTypeRemoteControl) {
        if (event.subtype == UIEventSubtypeRemoteControlPlay) {
            if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
            {
                [self restoreState:YES];
            }
            else
            {
                [self play:nil];
            }
        }
        else if (event.subtype == UIEventSubtypeRemoteControlPause) {
            [self saveState];
            [self pause:nil];
        }
        else if (event.subtype == UIEventSubtypeRemoteControlTogglePlayPause) {
            if ([[mWaveformView player] rate] == 0.0f)
            {
                if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
                {
                    [self restoreState:YES];
                }
                else
                {
                    [self play:nil];
                }
            }
            else
            {
                [self saveState];
                [self pause:nil];
            }
        }
        else if (event.subtype == UIEventSubtypeRemoteControlNextTrack
                 || event.subtype == UIEventSubtypeMotionShake) {
            [self fastForward:nil];
        }
        else if (event.subtype == UIEventSubtypeRemoteControlPreviousTrack) {
            [self rewind:nil];
        }
    }
}

//| ----------------------------------------------------------------------------
//  Support only portrait orientation.
//
/*- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}*/
//| ----------------------------------------------------------------------------
//  This method contains the logic for presenting and dismissing the
//  LandscapeViewController depending on the current device orientation and
//  whether the LandscapeViewController is currently presented.
//
- (void)updateLandscapeView
{
    // Get the device's current orientation.  By the time the
    // UIDeviceOrientationDidChangeNotification has been posted, this value
    // reflects the new orientation of the device.
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    
    if (UIDeviceOrientationIsLandscape(deviceOrientation) && self.presentedViewController == nil)
        // Only take action if the orientation is landscape and
        // presentedViewController is nil (no view controller is presented).  The
        // later check prevents this view controller from trying to present
        // landscapeViewController again if the device rotates from landscape to
        // landscape (the user turns the device 180 degrees).
	{
        // Trigger the segue to present LandscapeViewController modally.
        //[self performSegueWithIdentifier:@"PresentLandscapeViewControllerSegue" sender:self];
        //[mArtwork setHidden:YES];
        /*CGRect rect = mArtwork.frame;
        rect.size.height/= 2;
        [mArtwork setFrame:rect];*/
        [mWaveformView setNeedsDisplay];
    }
	else if (deviceOrientation == UIDeviceOrientationPortrait && self.presentedViewController != nil)
        // Only take action if the orientation is portrait and
        // presentedViewController is not nil (a view controller is presented).
	{
        [mWaveformView setNeedsDisplay];
         //[mArtwork setHidden:NO];
       // [self dismissViewControllerAnimated:YES completion:NULL];
    }
}

/*-(void)setUpViewForOrientation:(UIInterfaceOrientation)orientation
{
    //[self.view removeFromSuperview];
    if(UIInterfaceOrientationIsLandscape(orientation))
    {
        [self.view addSubview:mLandscapeController.view];
    }
    else
    {
        [mLandscapeController.view removeFromSuperview];
        //[self.view addSubview:mPortraitView];
    }
}
*/
//| ----------------------------------------------------------------------------
//! Handler for the UIDeviceOrientationDidChangeNotification.
//
- (void)onDeviceOrientationDidChange:(NSNotification *)notification
{
    // A delay must be added here, otherwise the new view will be swapped in
	// too quickly resulting in an animation glitch
    [self performSelector:@selector(updateLandscapeView) withObject:nil afterDelay:0];
}
//-(void)setViewDisplayName
//{
//    /* Set the view title to the last component of the asset URL. */
//    self.title = [mURL lastPathComponent];
//    
//    /* Or if the item has a AVMetadataCommonKeyTitle metadata, use that instead. */
//	for (AVMetadataItem* item in ([[[self.mPlayer currentItem] asset] commonMetadata]))
//	{
//		NSString* commonKey = [item commonKey];
//		
//		if ([commonKey isEqualToString:AVMetadataCommonKeyTitle])
//		{
//			self.title = [item stringValue];
//		}
//	}
//}

//- (void)handleSwipe:(UISwipeGestureRecognizer *)gestureRecognizer
//{
//	UIView* view = [self view];
//	UISwipeGestureRecognizerDirection direction = [gestureRecognizer direction];
//	CGPoint location = [gestureRecognizer locationInView:view];
//	
//	if (location.y < CGRectGetMidY([view bounds]))
//	{
//		if (direction == UISwipeGestureRecognizerDirectionUp)
//		{
//			[UIView animateWithDuration:0.2f animations:
//			^{
//				[[self navigationController] setNavigationBarHidden:YES animated:YES];
//			} completion:
//			^(BOOL finished)
//			{
//				[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
//			}];
//		}
//		if (direction == UISwipeGestureRecognizerDirectionDown)
//		{
//			[UIView animateWithDuration:0.2f animations:
//			^{
//				[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
//			} completion:
//			^(BOOL finished)
//			{
//				[[self navigationController] setNavigationBarHidden:NO animated:YES];
//			}];
//		}
//	}
//	else
//	{
//		if (direction == UISwipeGestureRecognizerDirectionDown)
//		{
//            if (![self.mToolbar isHidden])
//			{
//				[UIView animateWithDuration:0.2f animations:
//				^{
//					[self.mToolbar setTransform:CGAffineTransformMakeTranslation(0.f, CGRectGetHeight([self.mToolbar bounds]))];
//				} completion:
//				^(BOOL finished)
//				{
//					[self.mToolbar setHidden:YES];
//				}];
//			}
//		}
//		else if (direction == UISwipeGestureRecognizerDirectionUp)
//		{
//            if ([self.mToolbar isHidden])
//			{
//				[self.mToolbar setHidden:NO];
//				
//				[UIView animateWithDuration:0.2f animations:
//				^{
//					[self.mToolbar setTransform:CGAffineTransformIdentity];
//				} completion:^(BOOL finished){}];
//			}
//		}
//	}
//}

- (void)dealloc
{
    //[self resignFirstResponder];
    //[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:[AVAudioSession sharedInstance]];
    [[NSNotificationCenter defaultCenter] removeObserver: self
                                                 name: AVAudioSessionInterruptionNotification
                                               object: [AVAudioSession sharedInstance]];
    [mPlaylistController release];
	[mURL release];
	
	[super dealloc];
}

@end

@implementation MusicAmpPlaybackViewController (Player)

#pragma mark Player Item

//- (BOOL)isPlaying
//{
//	return mRestoreAfterScrubbingRate != 0.f || [self.mPlayer rate] != 0.f;
//}
//
///* Called when the player item has played to its end time. */
//- (void)playerItemDidReachEnd:(NSNotification *)notification 
//{
//	/* After the movie has played to its end time, seek back to time zero 
//		to play it again. */
//	seekToZeroBeforePlay = YES;
//}
//
///* ---------------------------------------------------------
// **  Get the duration for a AVPlayerItem. 
// ** ------------------------------------------------------- */
//
//- (CMTime)playerItemDuration
//{
//	AVPlayerItem *playerItem = [self.mPlayer currentItem];
//	if (playerItem.status == AVPlayerItemStatusReadyToPlay)
//	{
//        /* 
//         NOTE:
//         Because of the dynamic nature of HTTP Live Streaming Media, the best practice 
//         for obtaining the duration of an AVPlayerItem object has changed in iOS 4.3. 
//         Prior to iOS 4.3, you would obtain the duration of a player item by fetching 
//         the value of the duration property of its associated AVAsset object. However, 
//         note that for HTTP Live Streaming Media the duration of a player item during 
//         any particular playback session may differ from the duration of its asset. For 
//         this reason a new key-value observable duration property has been defined on 
//         AVPlayerItem.
//         
//         See the AV Foundation Release Notes for iOS 4.3 for more information.
//         */		
//
//		return([playerItem duration]);
//	}
//	
//	return(kCMTimeInvalid);
//}
//
//
///* Cancels the previously registered time observer. */
//-(void)removePlayerTimeObserver
//{
//	if (mTimeObserver)
//	{
//		[self.mPlayer removeTimeObserver:mTimeObserver];
//		[mTimeObserver release];
//		mTimeObserver = nil;
//	}
//}

#pragma mark -
#pragma mark Loading the Asset Keys Asynchronously

#pragma mark -
#pragma mark Error Handling - Preparing Assets for Playback Failed

/* --------------------------------------------------------------
 **  Called when an asset fails to prepare for playback for any of
 **  the following reasons:
 ** 
 **  1) values of asset keys did not load successfully, 
 **  2) the asset keys did load successfully, but the asset is not 
 **     playable
 **  3) the item did not become ready to play. 
 ** ----------------------------------------------------------- */
//
//-(void)assetFailedToPrepareForPlayback:(NSError *)error
//{
//    [self removePlayerTimeObserver];
//    [self syncScrubber];
//    [self disableScrubber];
//    [self disablePlayerButtons];
//    
//    /* Display the error. */
//	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
//														message:[error localizedFailureReason]
//													   delegate:nil
//											  cancelButtonTitle:@"OK"
//											  otherButtonTitles:nil];
//	[alertView show];
//	[alertView release];
//}


#pragma mark Prepare to play asset, URL

/*
 Invoked at the completion of the loading of the values for all keys on the asset that we require.
 Checks whether loading was successfull and whether the asset is playable.
 If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
//- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
//{
//    /* Make sure that the value of each key has loaded successfully. */
//	for (NSString *thisKey in requestedKeys)
//	{
//		NSError *error = nil;
//		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
//		if (keyStatus == AVKeyValueStatusFailed)
//		{
//			[self assetFailedToPrepareForPlayback:error];
//			return;
//		}
//		/* If you are also implementing -[AVAsset cancelLoading], add your code here to bail out properly in the case of cancellation. */
//	}
//    
//    /* Use the AVAsset playable property to detect whether the asset can be played. */
//    if (!asset.playable) 
//    {
//        /* Generate an error describing the failure. */
//		NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
//		NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
//		NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
//								   localizedDescription, NSLocalizedDescriptionKey, 
//								   localizedFailureReason, NSLocalizedFailureReasonErrorKey, 
//								   nil];
//		NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
//        
//        /* Display the error to the user. */
//        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
//        
//        return;
//    }
//	
//	/* At this point we're ready to set up for playback of the asset. */
//    	
//    /* Stop observing our prior AVPlayerItem, if we have one. */
//    if (self.mPlayerItem)
//    {
//        /* Remove existing player item key value observers and notifications. */
//        
//        [self.mPlayerItem removeObserver:self forKeyPath:kStatusKey];            
//		
//        [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                        name:AVPlayerItemDidPlayToEndTimeNotification
//                                                      object:self.mPlayerItem];
//    }
//	
//    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
//    self.mPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
//    
//    /* Observe the player item "status" key to determine when it is ready to play. */
//    [self.mPlayerItem addObserver:self 
//                      forKeyPath:kStatusKey 
//                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
//                         context:AVPlayerDemoPlaybackViewControllerStatusObservationContext];
//	
//    /* When the player item has played to its end time we'll toggle
//     the movie controller Pause button to be the Play button */
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(playerItemDidReachEnd:)
//                                                 name:AVPlayerItemDidPlayToEndTimeNotification
//                                               object:self.mPlayerItem];
//	
//    seekToZeroBeforePlay = NO;
//	
//    /* Create new player, if we don't already have one. */
//    if (!self.mPlayer)
//    {
//        /* Get a new AVPlayer initialized to play the specified player item. */
//        [self setPlayer:[AVPlayer playerWithPlayerItem:self.mPlayerItem]];	
//		
//        /* Observe the AVPlayer "currentItem" property to find out when any 
//         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did 
//         occur.*/
//        [self.player addObserver:self 
//                      forKeyPath:kCurrentItemKey 
//                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
//                         context:AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext];
//        
//        /* Observe the AVPlayer "rate" property to update the scrubber control. */
//        [self.player addObserver:self 
//                      forKeyPath:kRateKey 
//                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
//                         context:AVPlayerDemoPlaybackViewControllerRateObservationContext];
//    }
//    
//    /* Make our new AVPlayerItem the AVPlayer's current item. */
//    if (self.player.currentItem != self.mPlayerItem)
//    {
//        /* Replace the player item with a new player item. The item replacement occurs 
//         asynchronously; observe the currentItem property to find out when the 
//         replacement will/did occur*/
//        [self.mPlayer replaceCurrentItemWithPlayerItem:self.mPlayerItem];
//        
//        [self syncPlayPauseButtons];
//    }
//	
//    [self.mScrubber setValue:0.0];
//}

#pragma mark -
#pragma mark Asset Key Value Observing
#pragma mark

#pragma mark Key Value Observer for player rate, currentItem, player item status

///* ---------------------------------------------------------
//**  Called when the value at the specified key path relative
//**  to the given object has changed. 
//**  Adjust the movie play and pause button controls when the 
//**  player item "status" value changes. Update the movie 
//**  scrubber control when the player item is ready to play.
//**  Adjust the movie scrubber control when the player item 
//**  "rate" value changes. For updates of the player
//**  "currentItem" property, set the AVPlayer for which the 
//**  player layer displays visual output.
//**  NOTE: this method is invoked on the main queue.
//** ------------------------------------------------------- */
//
///*- (void)observeValueForKeyPath:(NSString*) path
//			ofObject:(id)object 
//			change:(NSDictionary*)change 
//			context:(void*)context
//{
//	/* AVPlayerItem "status" property value observer. */
//	if (context == AVPlayerDemoPlaybackViewControllerStatusObservationContext)
//	{
//		[self syncPlayPauseButtons];
//
//        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
//        switch (status)
//        {
//            /* Indicates that the status of the player is not yet known because 
//             it has not tried to load new media resources for playback */
//            case AVPlayerStatusUnknown:
//            {
//                [self removePlayerTimeObserver];
//                [self syncScrubber];
//                
//                [self disableScrubber];
//                [self disablePlayerButtons];
//            }
//            break;
//                
//            case AVPlayerStatusReadyToPlay:
//            {
//                /* Once the AVPlayerItem becomes ready to play, i.e. 
//                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
//                 its duration can be fetched from the item. */
//                
//                [self initScrubberTimer];
//                
//                [self enableScrubber];
//                [self enablePlayerButtons];
//            }
//            break;
//                
//            case AVPlayerStatusFailed:
//            {
//                AVPlayerItem *playerItem = (AVPlayerItem *)object;
//                [self assetFailedToPrepareForPlayback:playerItem.error];
//            }
//            break;
//        }
//	}
//	/* AVPlayer "rate" property value observer. */
//	else if (context == AVPlayerDemoPlaybackViewControllerRateObservationContext)
//	{
//        [self syncPlayPauseButtons];
//	}
//	/* AVPlayer "currentItem" property observer. 
//        Called when the AVPlayer replaceCurrentItemWithPlayerItem: 
//        replacement will/did occur. */
//	else if (context == AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext)
//	{
//        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
//        
//        /* Is the new player item null? */
//        if (newPlayerItem == (id)[NSNull null])
//        {
//            [self disablePlayerButtons];
//            [self disableScrubber];
//        }
//        else /* Replacement of player currentItem has occurred */
//        {
//            /* Set the AVPlayer for which the player layer displays visual output. */
//            [self.mPlaybackView setPlayer:mPlayer];
//            
//            [self setViewDisplayName];
//            
//            /* Specifies that the player should preserve the video’s aspect ratio and 
//             fit the video within the layer’s bounds. */
//            [self.mPlaybackView setVideoFillMode:AVLayerVideoGravityResizeAspect];
//            
//            [self syncPlayPauseButtons];
//        }
//	}
//	else
//	{
//		[super observeValueForKeyPath:path ofObject:object change:change context:context];
//	}
//}


@end


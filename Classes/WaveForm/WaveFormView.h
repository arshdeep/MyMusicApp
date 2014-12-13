//
//  WaveFormView.h
//  WaveFormTest
//
//  Created by Gyetván András on 7/11/12.
// This software is free.
//

#import <UIKit/UIKit.h>
#include <AVFoundation/AVFoundation.h>
#import "WaveSampleProvider.h"
#import "WaveSampleProviderDelegate.h"

@interface WaveFormView : UIControl<WaveSampleProviderDelegate>
{
	UIActivityIndicatorView *progress;
	CGPoint* sampleData;
	int sampleLength;
	WaveSampleProvider *wsp;	
	AVPlayer *player;
	float playProgress;
	NSString *infoString;
	NSString *timeString;
	UIColor *green;
	UIColor *gray;
	UIColor *lightgray;
	UIColor *darkgray;
	UIColor *white;
	UIColor *marker;
    IBOutlet UILabel *playbackTimeLabel;
    BOOL mUpdateFlag;
    BOOL mIsScrubbing;
}

//- (void) openAudio:(NSString *)path;
- (AVPlayer *)player;
- (void) openAudioURL:(NSURL *)url;
- (void) playerItemDidReachEnd:(NSNotification *)notification;
- (void) playAudio;
- (void) pauseAudio;
- (void)replayAudio;
- (void)needsDisplay:(BOOL)flag;
- (void)updatePlayProgress:(BOOL)isScrubbing;
@end

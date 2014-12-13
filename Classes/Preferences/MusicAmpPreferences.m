//
//  MusicAmpPreferences.m
//  iMusicAmp
//
//  Created by asingh on 12/22/13.
//
//

#import "MusicAmpPreferences.h"

#define MusicAmpRepeatPreference @"MusicAmpRepeatPreference"
#define MusicAmpShufflePreference @"MusicAmpShufflePreference"

@implementation MusicAmpPreferences
+ (void)setRepeatPreference:(Repeat)value
{
    if (value >= kNoRepeat && value < kRepeatLast) {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
        [defaults setInteger:value forKey:MusicAmpRepeatPreference];
        [defaults synchronize];
    }
}

+ (void)setShufflePreference:(Shuffle)value
{
    if (value >= kNoShuffle && value < kShuffleLast)
    {
        NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
        [defaults setInteger:value forKey:MusicAmpShufflePreference];
        [defaults synchronize];
    }
}

+ (Repeat)repeatPrefernce
{
    Repeat value = kNoRepeat;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    value = [defaults integerForKey:MusicAmpRepeatPreference];

    return value >= kNoRepeat && value < kRepeatLast ? value : kNoRepeat;
}

+ (Shuffle)shufflePreference
{
    Shuffle value = kNoShuffle;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    value = [defaults integerForKey:MusicAmpShufflePreference];
    
    return value >= kNoShuffle && value < kShuffleLast ? value : kNoShuffle;
}
@end

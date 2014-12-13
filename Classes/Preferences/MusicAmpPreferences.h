//
//  MusicAmpPreferences.h
//  iMusicAmp
//
//  Created by asingh on 12/22/13.
//
//

#import <Foundation/Foundation.h>
typedef enum
{
    kNoRepeat,
    kRepeatSong,
    kRepeatAlbum,
    kRepeatLast
} Repeat;

typedef enum
{
    kNoShuffle,
    kShuffleAll,
    kShuffleLast
} Shuffle;

@interface MusicAmpPreferences : NSObject
+ (void)setRepeatPreference:(Repeat)value;
+ (void)setShufflePreference:(Shuffle)value;
+ (Repeat)repeatPrefernce;
+ (Shuffle)shufflePreference;
@end

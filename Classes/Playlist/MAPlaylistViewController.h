//
//  MAPlaylistViewController.h
//  iMusicAmp
//
//  Created by asingh on 12/28/13.
//
//

#import <UIKit/UIKit.h>
#import "MAReorderTableView.h"

#define kPlaylistViewDoneNotification @"MusicAmpPlaylistViewDoneNotification"

@interface MAPlaylistViewController : UITableViewController
- (void)updateView;
@end

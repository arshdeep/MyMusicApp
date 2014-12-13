//
//  MAPlaylistViewController.m
//  iMusicAmp
//
//  Created by asingh on 12/28/13.
//
//

#import "MAPlaylistViewController.h"
#import "MAPlaylistManager.h"
#import <AVFoundation/AVPlayerItem.h>

@interface MAPlaylistViewController ()

@end

@implementation MAPlaylistViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.tableView = [[MAReorderTableView new] autorelease];
        self.tableView.delegate = [MAPlaylistManager getInstance];
        // Custom initialization
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateView)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];
    }
    return self;
}

- (void)updateView
{
    [self.tableView reloadData];
}
/*- (void)viewWillAppear:(BOOL)animated
{
    [self.tableView reloadData];
}*/

- (void)viewWillAppear:(BOOL)animated
{
    [self.tableView reloadData];
    [super viewWillAppear:animated];

    self.navigationController.navigationBar.tintColor = [UIColor orangeColor];
    self.title = [MAPlaylistManager getInstance].currentPlaylist;
    self.view.alpha = 0.9;
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    self.editing = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(dismissPlaylistView:)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                           target:self
                                                                                           action:@selector(savePlaylist:)];
}

- (void)savePlaylist:(id)sender
{
    MAPlaylistManager *playlistManager = [MAPlaylistManager getInstance];
    if (playlistManager.isDirty)
    {
        [playlistManager saveCurrentPlayList];
    }
}

- (void)dismissPlaylistView:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kPlaylistViewDoneNotification object:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [[MAPlaylistManager getInstance] getCurrentPlaylist].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
        cell.detailTextLabel.textColor = [UIColor grayColor];
	}
    // Configure the cell...
    NSMutableArray *activeAssetSources = [[MAPlaylistManager getInstance] getCurrentPlaylist];
    AssetBrowserItem *item = [activeAssetSources objectAtIndex:indexPath.row];
	cell.textLabel.text = item.title;
    cell.detailTextLabel.text = item.artist;
    
    if ([MAPlaylistManager getInstance].currentItemIndex == (NSUInteger)indexPath.row)
    {
        cell.textLabel.textColor = [UIColor orangeColor];
    }
    else
    {
        cell.textLabel.textColor = [UIColor blackColor];
    }
    return cell;
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[MAPlaylistManager getInstance] removeSongAtIndex:indexPath.row];
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
}

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

@end

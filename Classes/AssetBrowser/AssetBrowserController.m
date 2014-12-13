//
//  AssetBrowserController.m
//  iMusicAmp
//
//  Created by asingh on 12/22/13.
//
//

#import "AssetBrowserController.h"
#import "AssetBrowserSource.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import "UtilityExtensions.h"
#import "MAPlaylistManager.h"
#import "MAPlaylistViewController.h"
#import "ThumbnailDB.h"

/* Generating thumbnails is expensive and requires a lot of resources.
 If we do this while scrolling our framerate is affected. If your app presents a persistent
 media library it may make sense to cache thumbnails and metadata in a database. */
#define ONLY_GENERATE_THUMBS_AND_TITLES_WHEN_NOT_SCROLLING 1

@interface AssetBrowserController () <AssetBrowserSourceDelegate, UIScrollViewDelegate, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, copy) NSArray *assetSources;

- (void)configureCell:(UITableViewCell*)cell forIndexPath:(NSIndexPath *)indexPath;
- (void)updateActiveAssetSources;

- (void)enableThumbnailAndTitleGeneration;
- (void)disableThumbnailAndTitleGeneration;
- (void)generateThumbnailsAndTitles;
- (void)cancelAction;
@end


@implementation AssetBrowserController

@synthesize assetSources;
@synthesize delegate;

enum {
	AssetBrowserScrollDirectionDown,
    AssetBrowserScrollDirectionUp
};

- (void)createSearchBar {
    UISearchBar * theSearchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    [theSearchBar sizeToFit];
   // theSearchBar.tintColor = [UIColor whiteColor];
    theSearchBar.searchBarStyle = UISearchBarStyleMinimal;
    //theSearchBar.barTintColor = [UIColor whiteColor];
    theSearchBar.delegate = self;
    theSearchBar.placeholder = @"Search";
    for (UIView *subView in theSearchBar.subviews)
    {
        for (UIView *secondLevelSubview in subView.subviews){
            if ([secondLevelSubview isKindOfClass:[UITextField class]])
            {
                UITextField *searchBarTextField = (UITextField *)secondLevelSubview;
                
                //set font color here
                searchBarTextField.textColor = [UIColor whiteColor];
                
                break;
            }
        }
    }
    
    self.tableView.tableHeaderView = theSearchBar;
    
    searchController = [[UISearchDisplayController alloc]
                                            initWithSearchBar:theSearchBar
                                            contentsController:self ];
    searchController.delegate = self;
    searchController.searchResultsDataSource = self;
    searchController.searchResultsDelegate = self;

    //[theSearchBar becomeFirstResponder];
}

#pragma mark - UISearchDisplayDelegate

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [searchResults release];
    // name field matching
    [searchQueue cancelAllOperations];
    if ([activeAssetSources count])
    {
        [searchQueue addOperationWithBlock: ^(void) {
            isSearchInProcess = YES;
            NSExpression *lhs = [NSExpression expressionForKeyPath:@"title"];
            NSExpression *rhs = [NSExpression expressionForConstantValue:searchString];
            NSPredicate *finalPredicate = [NSComparisonPredicate
                                       predicateWithLeftExpression:lhs
                                       rightExpression:rhs
                                       modifier:NSDirectPredicateModifier
                                       type:NSContainsPredicateOperatorType
                                       options:NSCaseInsensitivePredicateOption];
            searchResults = [[activeAssetSources objectAtIndex:0] items];

            searchResults = [[searchResults filteredArrayUsingPredicate:finalPredicate] copy];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^() {
                [searchController.searchResultsTableView reloadData];
            }];
        }];
    }
    return NO;
}

- (void) searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller
{
    isSearchInProcess = NO;
    [searchResults release];
    searchResults = nil;
    [searchQueue cancelAllOperations];
}

#pragma mark -
#pragma mark Initialization
- (id)initWithSourceType:(AssetBrowserSourceType)sourceType modalPresentation:(BOOL)modalPresentation;
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) 
	{
        searchQueue = [NSOperationQueue new];
        [searchQueue setMaxConcurrentOperationCount:1];
		browserSourceType = sourceType;
		if ((browserSourceType & AssetBrowserSourceTypeAll) == 0) {
			NSLog(@"AssetBrowserController: Invalid sourceType");
			[self release];
			return nil;
		}
		
		//self.wantsFullScreenLayout = YES;
		
		thumbnailScale = [[UIScreen mainScreen] scale];
		
		activeAssetSources = [[NSMutableArray alloc] initWithCapacity:0];
		isModal = modalPresentation;
		
		
		// Okay now generate the list of Assets to be displayed.
		// This should be relatively quick since we are not creating assets or thumbnails.
		NSMutableArray *sources = [NSMutableArray arrayWithCapacity:0];
		
		if (browserSourceType & AssetBrowserSourceTypeFileSharing) {
			[sources addObject:[AssetBrowserSource assetBrowserSourceOfType:AssetBrowserSourceTypeFileSharing]];
		}
		/*if (browserSourceType & AssetBrowserSourceTypeCameraRoll) {
			[sources addObject:[AssetBrowserSource assetBrowserSourceOfType:AssetBrowserSourceTypeCameraRoll]];
		}*/
		if (browserSourceType & AssetBrowserSourceTypeIPodLibrary) {
			[sources addObject:[AssetBrowserSource assetBrowserSourceOfType:AssetBrowserSourceTypeIPodLibrary]];
		}
		if (browserSourceType & AssetBrowserSourceTypePlayLists) {
			[sources addObject:[AssetBrowserSource assetBrowserSourceOfType:AssetBrowserSourceTypePlayLists]];
		}
        
		self.assetSources = sources;
		
		if ([sources count] == 1) {
			singleSourceTypeMode = YES;
			self.title = [[self.assetSources objectAtIndex:0] name];
		}
		else {
			self.title = NSLocalizedString(@"Media", nil);
		}
	}
    return self;
}

- (id)initWithAlbumAsCustomSource:(AssetBrowserItem *)album source:(AssetBrowserSourceType)sourceType
{
    if ((self = [super initWithStyle:UITableViewStylePlain]))
	{
        activeAssetSources = [[NSMutableArray alloc] initWithCapacity:0];
        self.assetSources = [NSMutableArray arrayWithObject:[AssetBrowserSource initWithAlbumAsCustomSource:album source:sourceType]];
        browserSourceType = sourceType;
        //self.wantsFullScreenLayout = YES;
        self.title = [album album];
        searchQueue = [NSOperationQueue new];
        [searchQueue setMaxConcurrentOperationCount:1];
        singleSourceTypeMode = YES;
    }
    return self;
}

#pragma mark -
#pragma mark View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationController.navigationBar.tintColor = [UIColor orangeColor];
    self.tableView.tintColor = [UIColor orangeColor];
	self.tableView.rowHeight = 53.0; // 1 point is for the divider, we want our thumbnails to have an even height.
	
	if (!singleSourceTypeMode)
		self.tableView.sectionHeaderHeight = 22.0;
	
	// We wait until the scroll view has finished decelerating to generate thumbnails so make the deceleration a bit faster than normal.
	float decel = UIScrollViewDecelerationRateNormal - (UIScrollViewDecelerationRateNormal - UIScrollViewDecelerationRateFast)/2.0;
	self.tableView.decelerationRate = decel;	
    
	if (isModal && (self.modalPresentationStyle == UIModalPresentationFullScreen)) {
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
                                                                                                target:self action:@selector(cancelAction)] autorelease];
	}
    
    /*UIBarButtonItem *buttonItem = [[UIBarButtonItem createCustomButtonWithText:NSLocalizedString(@"Now Playing", nil)
                                                                textAlignment:UITextAlignmentRight
                                                                     fontSize:13
                                                                       target:self.delegate
                                                                     selector:@selector(showPlayer)] autorelease];*/
   // UIBarButtonItem *buttonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:self.delegate action:@selector(showPlayer)] autorelease];
    
    UIBarButtonItem *buttonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav-icon_20"] style:UIBarButtonItemStylePlain target:self.delegate action:@selector(showPlayer)] autorelease];
    buttonItem.enabled = NO;

    self.navigationItem.rightBarButtonItem = buttonItem;

    busyIndicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    busyIndicator.center = CGPointMake(160, 210);
    busyIndicator.hidesWhenStopped = YES;
    [self.view addSubview:busyIndicator];
    [busyIndicator startAnimating];
    
    /*UIView *view = [buttonItem valueForKey:@"view"];
    
    view.transform = CGAffineTransformMakeScale(-1, 1);
    [buttonItem setValue:view forKey:@"view"];*/
}

- (void)viewWillAppear:(BOOL)animated
{
    self.navigationItem.rightBarButtonItem.enabled = [MAPlaylistManager getInstance].currentPlaylist != nil;
	[super viewWillAppear:animated];

	/*if (isModal && (self.modalPresentationStyle == UIModalPresentationFullScreen)) {
		lastStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
		if ( lastStatusBarStyle != UIStatusBarStyleBlackTranslucent ) {
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:animated];
		}
	}*/
	lastTableViewYContentOffset = self.tableView.contentOffset.y;
	lastTableViewScrollDirection = AssetBrowserScrollDirectionDown;
	
	if (haveBuiltSourceLibraries)
		return;
	
	haveBuiltSourceLibraries = YES;
	for (AssetBrowserSource *source in self.assetSources) {
		source.delegate = self;	
	}	
	for (AssetBrowserSource *source in self.assetSources) {
		[source buildSourceLibrary];
	}
	
	[self updateActiveAssetSources];
	
	[self.tableView reloadData];
}

- (void)cancelAction
{
	if ([self.delegate respondsToSelector:@selector(assetBrowserDidCancel:)]) {
		[self.delegate assetBrowserDidCancel:self];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	[self enableThumbnailAndTitleGeneration];
	[self generateThumbnailsAndTitles];
	
	NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
	if (indexPath) {
		[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	}
    //Once the view has loaded then we can register to begin recieving controls and we can become the first responder
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

//Make sure we can recieve remote control events
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
	
	[self disableThumbnailAndTitleGeneration];

    //End recieving events
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];
/*	if (isModal && (self.modalPresentationStyle == UIModalPresentationFullScreen)) {
		if ( lastStatusBarStyle != UIStatusBarStyleBlackTranslucent ) {
			[[UIApplication sharedApplication] setStatusBarStyle:lastStatusBarStyle animated:animated];
		}
	}*/
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    [self.delegate didReceiveRemoteEvent:event];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
	NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
	if (indexPath)
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
}

- (void)clearSelection
{
	NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
	if (indexPath)
		[self.tableView deselectRowAtIndexPath:indexPath animated:YES];	
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	/*if ( [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ) {
		return YES;
	}
	return (interfaceOrientation == UIInterfaceOrientationPortrait);*/
    return NO;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	// If a thumbnail finished while we were rotating then its cell might not have been updated, but the cell could still be cached.
	for (UITableViewCell *visibleCell in [self.tableView visibleCells]) {
		NSIndexPath *indexPath = [self.tableView indexPathForCell:visibleCell];
		[self configureCell:visibleCell forIndexPath:indexPath];
	}
}

#pragma mark -
#pragma mark Table view data source

- (void)updateActiveAssetSources
{
	[activeAssetSources removeAllObjects];
	for (AssetBrowserSource *source in self.assetSources) {
		if ( ([source.items count] > 0) ) {
			[activeAssetSources addObject:source];
		}
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return [activeAssetSources count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{
	if (singleSourceTypeMode)
		return nil;
	AssetBrowserSource *source = [activeAssetSources objectAtIndex:section];
	NSString *name = [source.items count] > 0 ? source.name : nil;
	return name;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	
	NSInteger numRows = 0;
	numRows = searchController.searchResultsTableView == tableView ? searchResults.count : [[[activeAssetSources objectAtIndex:section] items] count];
	
	return numRows;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    NSArray *retArray = nil;

    if (activeAssetSources.count) {
        BOOL showSectionTitle = NO;
        AssetBrowserSource *source = [activeAssetSources objectAtIndex:0];
        
        showSectionTitle = source.type != AssetBrowserSourceTypeCustomSource;
        if (showSectionTitle) {
            retArray = [NSArray arrayWithObjects:@"{search}", @"A", @"B", @"C", @"D", @"E", @"F"
                        , @"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N", @"O"
                        , @"P", @"Q", @"R", @"S", @"T", @"U", @"V", @"W", @"X"
                        , @"Y", @"Z", nil];
        }
    }
    return retArray;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    if ([title compare:@"{search}"] != NSOrderedSame && index != 0)
    {
        NSUInteger foundIndex = 0;
        AssetBrowserSource *source = [activeAssetSources objectAtIndex:0];
        NSArray *dataArray = [source items];

        for (AssetBrowserItem *obj in dataArray) {
            NSString *startChar = [obj.title substringToIndex:1];

            if ([[startChar uppercaseString] compare:title] == NSOrderedSame/* || [[startChar uppercaseString] compare: title] == NSOrderedDescending*/)
                break;
            foundIndex++;
        }
        if(foundIndex >= [dataArray count]) {
            foundIndex = [dataArray count]-1;
        }
        [tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:foundIndex inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
    else {
        [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    }
    return 1;
}

- (void)configureCell:(UITableViewCell *)cell forItem:(AssetBrowserItem *)item
{
    cell.textLabel.text = item.title;
    NSString *subTitle = item.subTitle;
    
    if (subTitle == nil || subTitle.length == 0) {
        cell.detailTextLabel.text = [item artist];
    }
    else {
        cell.detailTextLabel.text = item.subTitle;
    }

    if (item.URL == nil) // Only generate artwork for albums.
    {
        UIImage *thumb = [[ThumbnailDB getInstance] getThumbnailCached:item];
	
        if (!thumb)
        {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^() {
                UIImage *thumbnail = [[ThumbnailDB getInstance] thumbnail:item];

                if (thumbnail)
                {
                    dispatch_async(dispatch_get_main_queue(), ^() {
                        [self updateCellForBrowserItemIfVisible:item];
                    });
                }
            });
        }

        if(!thumb)
        {
            thumb = [item placeHolderImage];
        }
        cell.imageView.image = thumb;
    }
}

- (void)configureCell:(UITableViewCell*)cell forIndexPath:(NSIndexPath *)indexPath
{	
	if ( cell == nil)
		return;
    AssetBrowserSource *source = [activeAssetSources objectAtIndex:indexPath.section];
    AssetBrowserItem *item = [[source items] objectAtIndex:indexPath.row];

    [self configureCell:cell forItem:item];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{    
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
		cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
        cell.detailTextLabel.textColor = [UIColor grayColor];
	}
	
    if (searchController.searchResultsTableView == tableView)
    {
        AssetBrowserItem *item = [searchResults objectAtIndex:indexPath.row];
        [self configureCell:cell forItem:item];
    }
    else
    {
        [self configureCell:cell forIndexPath:indexPath];
    }
	
	return cell;
}

- (void)onItemSelectAtIndex:tableView forPath:(NSIndexPath *)indexPath
{
    NSArray *sourceItems = nil;
    if (searchController.searchResultsTableView == tableView)
    {
        sourceItems = searchResults;
    }
    else
    {
        sourceItems = [[activeAssetSources objectAtIndex:indexPath.section] items];
    }
    [[MAPlaylistManager getInstance] setPlayList:NSLocalizedString(@"Now Playing", nil) values:[NSMutableArray arrayWithArray:sourceItems]];
    [[MAPlaylistManager getInstance] setCurrentItemAtIndex:indexPath.row];
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *sourceItems = nil;
    if (searchController.searchResultsTableView == tableView)
    {
        sourceItems = searchResults;
    }
    else
    {
        sourceItems = [[activeAssetSources objectAtIndex:indexPath.section] items];
    }
	AssetBrowserItem *selectedItem = [sourceItems objectAtIndex:indexPath.row];
    
    if ([selectedItem URL] != nil)
    {
        [self onItemSelectAtIndex:tableView forPath:indexPath];
        [delegate showPlayer];
    }
    else
    {
        AssetBrowserController *customController = [[[[self class] alloc] initWithAlbumAsCustomSource:selectedItem source:browserSourceType] autorelease];
        customController.delegate = self.delegate;
        id rootNavigationController = [[self.view window] rootViewController];
        if ([rootNavigationController isKindOfClass:[UINavigationController class]])
        {
            [(UINavigationController *)rootNavigationController pushViewController:customController animated:YES];
        }
    }
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    BOOL flag = NO;
    if (browserSourceType == AssetBrowserSourceTypeFileSharing)
    {
        NSMutableArray *sourceItems = (NSMutableArray *)[[activeAssetSources objectAtIndex:indexPath.section] items];
        AssetBrowserItem *selectedItem = [sourceItems objectAtIndex:indexPath.row];
        
        flag = selectedItem.URL != nil;
    }
    else
    {
        flag = browserSourceType == AssetBrowserSourceTypePlayLists;
    }
    
    return flag;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        BOOL isSuccess = NO;
        AssetBrowserSource *source = [activeAssetSources objectAtIndex:indexPath.section];
        NSMutableArray *sourceItems = source.items;
        AssetBrowserItem *selectedItem = [sourceItems objectAtIndex:indexPath.row];
        
        if (browserSourceType == AssetBrowserSourceTypeFileSharing)
        {
            [[MAPlaylistManager getInstance] removeSongFromDisk:selectedItem.URL];
            NSError *err = nil;
            
            isSuccess = [[NSFileManager defaultManager] removeItemAtURL:selectedItem.URL error:&err];
        }
        else if (browserSourceType == AssetBrowserSourceTypePlayLists)
        {
            NSString *path = [[MAPlaylistManager playlistDirectory] stringByAppendingPathComponent:selectedItem.title];
            isSuccess = [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        }


        if (isSuccess)
        {
            [(NSMutableArray *)sourceItems removeObject:selectedItem];
            // Delete the row from the data source
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

#pragma mark -
#pragma mark Asset Library Delegate

- (void)assetBrowserSourceItemsDidChange:(AssetBrowserSource*)source
{
	[self updateActiveAssetSources];
	[self.tableView reloadData];
    [busyIndicator stopAnimating];
    [busyIndicator removeFromSuperview];
    busyIndicator = nil;
    [self createSearchBar];
}

#pragma mark -
#pragma mark Thumbnail Generation

- (void)updateCellForBrowserItemIfVisible:(AssetBrowserItem*)browserItem
{
	NSArray *visibleIndexPaths = [self.tableView indexPathsForVisibleRows];
	for (NSIndexPath *indexPath in visibleIndexPaths) {
		AssetBrowserItem *visibleBrowserItem = [[[activeAssetSources objectAtIndex:indexPath.section] items] objectAtIndex:indexPath.row];
		if ([browserItem isEqual:visibleBrowserItem]) {
			UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
			[self configureCell:cell forIndexPath:indexPath];
			[cell setNeedsLayout];
			break;
		}
	}
}

- (void)thumbnailsAndTitlesTask
{	
	if (! thumbnailAndTitleGenerationEnabled) {
		thumbnailAndTitleGenerationIsRunning = NO;
		return;
	}
	
	thumbnailAndTitleGenerationIsRunning = YES;
	
	NSArray *visibleIndexPaths = [self.tableView indexPathsForVisibleRows];
	
	id objOrEnumerator = (lastTableViewScrollDirection == AssetBrowserScrollDirectionDown) ? (id)visibleIndexPaths : (id)[visibleIndexPaths reverseObjectEnumerator];
	for (NSIndexPath *path in objOrEnumerator) 
	{
		NSArray *assetItemsInSection = [[activeAssetSources objectAtIndex:path.section] items];
		AssetBrowserItem *assetItem = ((NSInteger)[assetItemsInSection count] > path.row) ? [assetItemsInSection objectAtIndex:path.row] : nil;
        
		if (assetItem) {
			__block NSInteger runningRequests = 0;
			/*if (assetItem.thumbnailImage == nil) {
				CGFloat targetHeight = self.tableView.rowHeight -1.0; // The contentView is one point smaller than the cell because of the divider.
				targetHeight *= thumbnailScale;
				
				CGFloat targetAspectRatio = 1.5;
				CGSize targetSize = CGSizeMake(targetHeight*targetAspectRatio, targetHeight);
				
				runningRequests++;
				[assetItem generateThumbnailAsynchronouslyWithSize:targetSize fillMode:AssetBrowserItemFillModeCrop completionHandler:^(UIImage *thumbnail)
				{
					runningRequests--;
					if (runningRequests == 0) {
						[self updateCellForBrowserItemIfVisible:assetItem];
						// Continue generating until all thumbnails/titles in range have been finished.
						[self thumbnailsAndTitlesTask];
					}
				}];
				

			}*/
			if (!assetItem.haveRichestTitle) {
				runningRequests++;
				[assetItem generateTitleFromMetadataAsynchronouslyWithCompletionHandler:^(NSString *title){
					runningRequests--;
					if (runningRequests == 0) {
						[self updateCellForBrowserItemIfVisible:assetItem];
						// Continue generating until all thumbnails/titles in range have been finished.
						[self thumbnailsAndTitlesTask];
					}
				}];
			}
			// If we are generating a title or thumbnail then wait until that returns to generate the next one.
			if ( runningRequests > 0 )
				return;
		}
	}
	
	thumbnailAndTitleGenerationIsRunning = NO;
	
	return;
}

- (void)enableThumbnailAndTitleGeneration
{
	thumbnailAndTitleGenerationEnabled = YES;
}

- (void)disableThumbnailAndTitleGeneration
{
	thumbnailAndTitleGenerationEnabled = NO;
}

- (void)generateThumbnailsAndTitles
{
	if (! thumbnailAndTitleGenerationEnabled) {
		return;
	}
	if (! thumbnailAndTitleGenerationIsRunning) {
		/* Run on the next run loop iteration. We may be called from with configureCell: and we don't want to slow down table view display. */
		thumbnailAndTitleGenerationIsRunning = YES;
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self thumbnailsAndTitlesTask];
		});
	}
}

#pragma mark -
#pragma mark Deferred image loading (UIScrollViewDelegate)

#if ONLY_GENERATE_THUMBS_AND_TITLES_WHEN_NOT_SCROLLING

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	[self disableThumbnailAndTitleGeneration];
}

// Load images for all onscreen rows when scrolling is finished
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (!decelerate) {
		[self enableThumbnailAndTitleGeneration];
		[self generateThumbnailsAndTitles];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	[self enableThumbnailAndTitleGeneration];
	[self generateThumbnailsAndTitles];
}

#endif //ONLY_GENERATE_THUMBS_AND_TITLES_WHEN_NOT_SCROLLING

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	CGFloat newOffset = scrollView.contentOffset.y;
	CGFloat oldOffset = lastTableViewYContentOffset;
	
	CGFloat offsetAmount = newOffset-oldOffset;
	
	// Only update the scroll direction if we've passed some threshold (8 points).
	if ( fabs(offsetAmount) > 8.0 ) {
		if (offsetAmount > 0.0)
			lastTableViewScrollDirection = AssetBrowserScrollDirectionDown;
		else if (newOffset < oldOffset)
			lastTableViewScrollDirection = AssetBrowserScrollDirectionUp;
		
		lastTableViewYContentOffset = newOffset;
	}
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Get rid of AVAsset and thumbnail caches for items which aren't on screen.
	NSLog(@"%@ memory warning, clearing asset and thumbnail caches", self);
	NSArray *visibleIndexPaths = [self.tableView indexPathsForVisibleRows];
	NSUInteger section = 0;
	NSUInteger row = 0;
	for (AssetBrowserSource *source in activeAssetSources) {
		row = 0;
		for (AssetBrowserItem *item in [source items]) {
			NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
			if (![visibleIndexPaths containsObject:path]) {
				[item clearAssetCache];
				[item clearThumbnailCache];
			}
			row++;
		}
		section++;
	}
}
- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AssetBrowserItem *selectedItem = nil;
    
    // TODO : enqueue folders/albums.
    if (activeAssetSources.count)
    {
        NSArray *sourceItems = [[activeAssetSources objectAtIndex:indexPath.section] items];
	
        selectedItem = [sourceItems objectAtIndex:indexPath.row];
    }
    
    if ([MAPlaylistManager getInstance].currentPlaylist != nil
            && selectedItem.URL != nil) {
        [mLastSelectedIndexPath release];
        mLastSelectedIndexPath = [indexPath copy];
        UIActionSheet *confirmSheet = [[UIActionSheet alloc] initWithTitle:@""
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                       destructiveButtonTitle:nil
                                            otherButtonTitles:NSLocalizedString(@"Enqueue Next", nil),
                                            NSLocalizedString(@"Enqueue End", nil),
                                            nil];
        [confirmSheet showInView:self.view];
    }
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    return NO;
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    
}

- (void)handlePlayMenu:(id)sender
{
    
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSArray *sourceItems = nil;
    if (isSearchInProcess)
    {
        sourceItems = searchResults;
    }
    else{
        sourceItems = [[activeAssetSources objectAtIndex:mLastSelectedIndexPath.section] items];
    }
	AssetBrowserItem *selectedItem = [[sourceItems objectAtIndex:mLastSelectedIndexPath.row] copy];
    
    switch (buttonIndex) {
        case kEnqueueNext:
            [[MAPlaylistManager getInstance] enqueue:selectedItem isNext:YES];
            break;
        case kEnqueue:
            [[MAPlaylistManager getInstance] enqueue:selectedItem isNext:NO];
            break;
            
        default:
            break;
    }
    [selectedItem release];
    selectedItem = nil;
}

- (void)dealloc
{
	delegate = nil;
    [searchQueue release];
    [searchController release];
	[assetSources release];
	[activeAssetSources release];
	[super dealloc];
}

@end


@implementation UINavigationController (AssetBrowserConvenienceMethods)

+ (UINavigationController*)modalAssetBrowserControllerWithSourceType:(AssetBrowserSourceType)sourceType delegate:(id <AssetBrowserControllerDelegate>)delegate
{
	AssetBrowserController *browser = [[[AssetBrowserController alloc] initWithSourceType:sourceType modalPresentation:YES] autorelease];
	browser.delegate = delegate;
	
	UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController:browser] autorelease];
	[navController.navigationBar setBarStyle:UIBarStyleBlack];
	[navController.navigationBar setTranslucent:YES];

	return navController;
}

@end

@implementation UITabBarController (AssetBrowserConvenienceMethods)

+ (UITabBarController*)tabbedModalAssetBrowserControllerWithSourceType:(AssetBrowserSourceType)sourceType delegate:(id <AssetBrowserControllerDelegate>)delegate
{
	UITabBarController *tabBarController = [[[UITabBarController alloc] init] autorelease];
	
	NSMutableArray *assetBrowserControllers = [NSMutableArray arrayWithCapacity:0];
	
	if (sourceType & AssetBrowserSourceTypeCameraRoll) {
		[assetBrowserControllers addObject:[UINavigationController modalAssetBrowserControllerWithSourceType:AssetBrowserSourceTypeCameraRoll delegate:delegate]];
	}
	if (sourceType & AssetBrowserSourceTypeFileSharing) {
		[assetBrowserControllers addObject:[UINavigationController modalAssetBrowserControllerWithSourceType:AssetBrowserSourceTypeFileSharing delegate:delegate]];
	}
	if (sourceType & AssetBrowserSourceTypeIPodLibrary) {
		[assetBrowserControllers addObject:[UINavigationController modalAssetBrowserControllerWithSourceType:AssetBrowserSourceTypeIPodLibrary delegate:delegate]];
	}
    /*if (sourceType & AssetBrowserSourceTypeFileTransfer) {
		[assetBrowserControllers addObject:[UINavigationController modalAssetBrowserControllerWithSourceType:AssetBrowserSourceTypeFileTransfer delegate:delegate]];
	}*/
	tabBarController.viewControllers = assetBrowserControllers;
	
	return tabBarController;
}

@end

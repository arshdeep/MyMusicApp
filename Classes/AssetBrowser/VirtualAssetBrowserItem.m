//
//  VirtualAssetBrowserItem.m
//  iMusicAmp
//
//  Created by asingh on 8/19/14.
//
//

#import "VirtualAssetBrowserItem.h"
#import "AssetBrowserItem.h"

@implementation VirtualAssetBrowserItem
@synthesize urlItems = _itemArray;

- (id)initWithItem:(NSString *)title
{
    if (self = [super initWithURL:nil title:title])
    {
        _itemArray = [NSMutableArray new];
    }
    
    return self;
}

- (void)addItem:(AssetBrowserItem *)item
{
    [_itemArray addObject:item];
}

- (void)dealloc
{
    [super dealloc];
    [_itemArray release];
}
@end

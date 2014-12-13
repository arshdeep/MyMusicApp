//
//  VirtualAssetBrowserItem.h
//  iMusicAmp
//
//  Created by asingh on 8/19/14.
//
//

#import "AssetBrowserItem.h"

@interface VirtualAssetBrowserItem : AssetBrowserItem
{
    NSMutableArray *_itemArray;
}
- (id)initWithItem:(NSString *)title;
- (void)addItem:(AssetBrowserItem *)item;

@property (nonatomic, readonly, retain) NSMutableArray *urlItems;
@end

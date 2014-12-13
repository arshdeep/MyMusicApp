//
//  MATableViewCell.m
//  iMusicAmp
//
//  Created by asingh on 4/24/14.
//
//

#import "MATableViewCell.h"

@implementation MATableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.indentationLevel = -1;
    //self.imageView.frame = CGRectMake(8, 8, 50, 50);
    CGRect imgRect = self.imageView.frame;
    imgRect.origin.x -= 5;
    self.imageView.frame = imgRect;
    //self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    /*CGRect labelRect = self.textLabel.frame;
    labelRect.origin.x = self.imageView.frame.origin.x + self.imageView.frame.size.width + 5;
    self.textLabel.frame = labelRect;*/
}

@end

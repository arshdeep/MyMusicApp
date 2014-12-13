//
//  MAPlaybackTimeLabel.m
//  iMusicAmp
//
//  Created by asingh on 1/12/14.
//
//

#import "MAPlaybackTimeLabel.h"

@implementation MAPlaybackTimeLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.alpha = 0.8f;
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    if (![self isHidden])
    {
        CGRect bounds = self.bounds;
        float lineWidth = 0.2f;
        float radius = 4.0f;
    //CGColorRef strokeColor = [UIColor greenColor].CGColor;
        CGColorRef fillColor = [UIColor colorWithWhite:1.0f alpha:0.8f].CGColor;//[UIColor colorWithRed:242.0/255.0 green:147.0/255.0 blue:0.0/255.0 alpha:0.8].CGColor;
        CGRect rrect = CGRectMake(bounds.origin.x+(lineWidth/2), bounds.origin.y+(lineWidth/2), bounds.size.width - lineWidth, bounds.size.height - lineWidth);
	
        CGFloat minx = CGRectGetMinX(rrect), midx = CGRectGetMidX(rrect), maxx = CGRectGetMaxX(rrect);
        CGFloat miny = CGRectGetMinY(rrect), midy = CGRectGetMidY(rrect), maxy = CGRectGetMaxY(rrect);
        CGContextRef cx = UIGraphicsGetCurrentContext();
        CGContextSaveGState(cx);
        CGContextMoveToPoint(cx, minx, midy);
        CGContextAddArcToPoint(cx, minx, miny, midx, miny, radius);
        CGContextAddArcToPoint(cx, maxx, miny, maxx, midy, radius);
        CGContextAddArcToPoint(cx, maxx, maxy, midx, maxy, radius);
        CGContextAddArcToPoint(cx, minx, maxy, minx, midy, radius);
        CGContextClosePath(cx);
	
        CGContextSetStrokeColorWithColor(cx, fillColor);
        CGContextSetFillColorWithColor(cx, fillColor);
    //CGContextSetShadowWithColor(cx, CGSizeMake(-2, -2), 5.0f, strokeColor);
        CGContextDrawPath(cx, kCGPathFillStroke);

        CGContextRestoreGState(cx);
    }
    [super drawRect:rect];
}


@end

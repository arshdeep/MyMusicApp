//
//  This class was created by Nonnus,
//  who graciously decided to share it with the CocoaHTTPServer community.
//

#import <UIKit/UIKit.h>
@class   HTTPServer;

@interface HTTPServerController : UIViewController 
{
	HTTPServer *httpServer;
	NSDictionary *addresses;
	
	IBOutlet UILabel *displayInfo;
    IBOutlet UITextField *portTextField;
}

-(IBAction) startStopServer:(id)sender;
@end


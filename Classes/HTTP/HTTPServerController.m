//
//  This class was created by Nonnus,
//  who graciously decided to share it with the CocoaHTTPServer community.
//

#import "HTTPServerController.h"
#import "HTTPServer.h"
#import "AppHTTPConnection.h"
#import "LocalHostAddresses.h"


@implementation HTTPServerController
- (void)awakeFromNib
{
    self.title = NSLocalizedString(@"File Transfer", nil);
}

- (void)initialize
{
    //NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    NSString *root = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"web"];
    httpServer = [HTTPServer new];
    [httpServer setType:@"_http._tcp."];
    [httpServer setConnectionClass:[AppHTTPConnection class]];
    [httpServer setDocumentRoot:root];
        
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayInfoUpdate:) name:@"LocalhostAdressesResolved" object:nil];
    [LocalHostAddresses performSelectorInBackground:@selector(list) withObject:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    UIToolbar* keyboardDoneButtonView = [[[UIToolbar alloc] init] autorelease];
    [keyboardDoneButtonView sizeToFit];
    UIBarButtonItem* doneButton = [[[UIBarButtonItem alloc] initWithTitle:@"Done"
                                                                    style:UIBarButtonItemStyleBordered target:self
                                                                   action:@selector(doneClicked:)] autorelease];
    [keyboardDoneButtonView setItems:[NSArray arrayWithObjects:doneButton, nil]];
    keyboardDoneButtonView.transform = CGAffineTransformMakeScale(-1, 1);
    UIView *itemView = [doneButton valueForKey:@"view"];
    itemView.transform = CGAffineTransformMakeScale(-1, 1);
    portTextField.inputAccessoryView = keyboardDoneButtonView;
}

- (IBAction)doneClicked:(id)sender
{
    NSLog(@"Done Clicked.");
    [self.view endEditing:YES];
}

- (void)displayInfoUpdate:(NSNotification *) notification
{
	NSLog(@"displayInfoUpdate:");

	if(notification)
	{
		[addresses release];
		addresses = [[notification object] copy];
		NSLog(@"addresses: %@", addresses);
	}

	if(addresses == nil)
	{
		return;
	}
	
	NSString *info;
	UInt16 port = [httpServer port];
	
	NSString *localIP = nil;
	
	localIP = [addresses objectForKey:@"en0"];
	
	if (!localIP)
	{
		localIP = [addresses objectForKey:@"en1"];
	}

	if (!localIP)
		info = @"Wifi: No Connection!\n";
	else
    {
        if (port != 0) {
            info = [NSString stringWithFormat:@"Please type following address in your browser:\n http://%@:%d\n", localIP, port];
        }
        else
        {
            info = @"";
        }
    }
	/*NSString *wwwIP = [addresses objectForKey:@"www"];

	if (wwwIP)
		info = [info stringByAppendingFormat:@"Web: %@:%d\n", wwwIP, port];
	else
		info = [info stringByAppendingString:@"Web: Unable to determine external IP\n"];
*/
	displayInfo.text = info;
}


- (IBAction)startStopServer:(id)sender
{
	if ([sender isOn])
	{
        [self initialize];
		// You may OPTIONALLY set a port for the server to run on.
		// 
		// If you don't set a port, the HTTP server will allow the OS to automatically pick an available port,
		// which avoids the potential problem of port conflicts. Allowing the OS server to automatically pick
		// an available port is probably the best way to do it if using Bonjour, since with Bonjour you can
		// automatically discover services, and the ports they are running on.
        
		[httpServer setPort:[portTextField.text intValue]];
		
		NSError *error;
		if(![httpServer start:&error])
		{
            displayInfo.text = @"Error starting HTTP Server";
			NSLog(@"Error starting HTTP Server: %@", error);
		}
        else {
            [self displayInfoUpdate:nil];
        }
 	}
	else
	{
		[httpServer stop];
        [httpServer release];
        httpServer = nil;
        displayInfo.text = @"";
	}
}

- (void)dealloc 
{
	[httpServer release];
    [super dealloc];
}


@end

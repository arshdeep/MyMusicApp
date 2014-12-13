
#import "HTTPConnection.h"

@class MultipartFormDataParser;

@interface AppHTTPConnection : HTTPConnection  {
    MultipartFormDataParser*        parser;
	NSFileHandle*					storeFile;
	
	NSMutableArray*					uploadedFiles;
}

@end

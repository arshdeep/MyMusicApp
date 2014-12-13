//
//  WaveSampleProvider.m
//  CoreAudioTest
//
//  Created by Gyetván András on 6/22/12.
// This software is free.
//

#import "WaveSampleProvider.h"
#import "SamplingDataCache.h"

@interface WaveSampleProvider (Private)
- (void) loadSample;
- (void) processSample;
- (void) calculateSampleFromArray:(float**)audio lenght:(int)length;
- (void) normalizeSample;
- (void) status:(WaveSampleStatus)status message:(NSString *)desc;
- (OSStatus) readConsecutive:(SInt64)numFrames intoArray:(float**)audio;
@end

@implementation WaveSampleProvider
@synthesize status, statusMessage, binSize, minute, sec, delegate,audioURL;

- (NSString *)title
{
	return title;	
}

- (void) status:(WaveSampleStatus)theStatus message:(NSString *)desc;
{
	status = theStatus;
	[statusMessage release];
	statusMessage = [desc copy];
	[self performSelectorOnMainThread:@selector(informDelegateOfStatusChange) withObject:nil waitUntilDone:NO];
}

//- (id) initWithPath:(NSString *)thePath
//{
//	self = [super init];
//	if(self) {
//		extAFNumChannels = 2;
//		[self status:LOADING message:@"Processing"];
//		binSize = 50;
//		path = [[NSString stringWithString:thePath] retain];
//		audioURL = [[NSURL fileURLWithPath:path]retain];
//		title = [[path lastPathComponent] copy];
//	}
//	return self;
//}

- (id) initWithURL:(NSURL *)theURL
{
	self = [super init];
	if(self) {
		extAFNumChannels = 1;
		[self status:LOADING message:@"Processing"];
		binSize = 100;
//		path = [[NSString stringWithString:thePath] retain];
		audioURL = [theURL retain];//[[NSURL fileURLWithPath:path]retain];
		title = [[theURL lastPathComponent] copy];// @"";//[[path lastPathComponent] copy];
		//sampleData = nil;
		normalizedData = nil;
        //mSamplingQueue = [NSOperationQueue new];
	}
	return self;
}

- (void) dealloc
{
    //[mSamplingQueue cancelAllOperations];
    //[mSamplingQueue release];
//	[path release];
	[audioURL release];
	[statusMessage release];
	//[sampleData release];
	[normalizedData release];
	[delegate release];
	[title release];
	[super dealloc];
	
}

- (void) createSampleData
{
    //[self loadSample];
   [self performSelectorInBackground:@selector(loadSample) withObject:nil];
}

- (void) informDelegateOfFinish
{
	if(delegate != nil) {
		if([delegate respondsToSelector:@selector(sampleProcessed:)]) {
			[delegate sampleProcessed:self];
		}
	}
}

- (void) informDelegateOfStatusChange
{
	if(delegate != nil) {
		if([delegate respondsToSelector:@selector(statusUpdated:)]) {
			[delegate statusUpdated:self];
		}
	}
}

- (void) loadSample
{
    normalizedData = [[SamplingDataCache readData:audioURL.absoluteString] retain];
    if (normalizedData == nil)
    {
        [self processSample];
        [SamplingDataCache writeData:audioURL.absoluteString data:normalizedData];
    }
    else
    {
        [self status:LOADED message:@"Sample data loaded"];
    }
	[self performSelectorOnMainThread:@selector(informDelegateOfFinish) withObject:nil waitUntilDone:NO];
    /*[mSamplingQueue addOperationWithBlock:^{
        [self processSample];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self informDelegateOfFinish];
        }];
    }];*/
}

- (void) processSample
{
	extAFReachedEOF = NO;
	OSStatus err;
	CFURLRef inpUrl = (CFURLRef)audioURL;
	err = ExtAudioFileOpenURL(inpUrl, &extAFRef);
	if(err != noErr) {
		[self status:ERROR message:@"Cannot open audio file"];
		return;
	}
	
	AudioFileID afid;
	AudioFileOpenURL(inpUrl, kAudioFileReadPermission, 0, &afid);
	UInt32 size = 0;
	UInt32 writable;
	OSStatus error = AudioFileGetPropertyInfo(afid, kAudioFilePropertyInfoDictionary, &size, &writable);
	if ( error == noErr ) {
		CFDictionaryRef info = NULL;
		error = AudioFileGetProperty(afid, kAudioFilePropertyInfoDictionary, &size, &info);
		if ( error == noErr ) {
			NSLog(@"file properties: %@", (NSDictionary *)info);
			NSDictionary *dict = (NSDictionary *)info;
			NSString *idTitle = [dict valueForKey:@"title"];
			NSString *idArtist = [dict valueForKey:@"artist"];
			if(idTitle != nil && idArtist != nil) {
				[title release];
				title = [[NSString stringWithFormat:@"%@ - %@",idArtist, idTitle]retain];
			} else if(idTitle != nil) {
				[title release];
				title = [idTitle copy];
			}
		}
		if(info) CFRelease(info);
	} else {
		NSLog(@"Error reading tags");
	}
	AudioFileClose(afid);
	
	AudioStreamBasicDescription fileFormat;
	
    UInt32 propSize = sizeof(fileFormat);
    memset(&fileFormat, 0, sizeof(AudioStreamBasicDescription));
	
    err = ExtAudioFileGetProperty(extAFRef, kExtAudioFileProperty_FileDataFormat, &propSize, &fileFormat);
	if(err != noErr) {
		[self status:ERROR message:@"Cannot get audio file properties"];
		return;
	}
	
	Float64 sampleRate = fileFormat.mSampleRate > 44100.0 ? 44100.0 : fileFormat.mSampleRate;
    extAFRateRatio = sampleRate / fileFormat.mSampleRate;
	
    AudioStreamBasicDescription clientFormat;
    propSize = sizeof(clientFormat);
	
    memset(&clientFormat, 0, sizeof(AudioStreamBasicDescription));
    clientFormat.mFormatID           = kAudioFormatLinearPCM;
    clientFormat.mSampleRate         = sampleRate;
    clientFormat.mFormatFlags        = kAudioFormatFlagIsFloat;//kAudioFormatFlagsCanonical;//kAudioFormatFlagIsFloat | kAudioFormatFlagIsAlignedHigh | kAudioFormatFlagsCanonical;// | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;// |  kAudioFormatFlagIsNonInterleaved;
    clientFormat.mChannelsPerFrame   = extAFNumChannels;
    clientFormat.mBitsPerChannel     = sizeof(float) * 8;
    clientFormat.mFramesPerPacket    = 1;
    clientFormat.mBytesPerFrame      = extAFNumChannels * sizeof(float);
    clientFormat.mBytesPerPacket     = extAFNumChannels * sizeof(float);
//    clientFormat.mReserved           = 0;
	
    err = ExtAudioFileSetProperty(extAFRef, kExtAudioFileProperty_ClientDataFormat, propSize, &clientFormat);
	if(err != noErr) {
		[self status:ERROR message:@"Cannot convert audio file to PCM format"];
		return;
	}

	SInt64 NUM_FRAMES_PER_READ = 500*binSize;
    float *audio[extAFNumChannels];
	
    for (int i=0; i < extAFNumChannels; ++i) {
        audio[i] = (float *)malloc(sizeof(float)*NUM_FRAMES_PER_READ);
    }

    if (normalizedData != nil)
    {
        [normalizedData release];
    }
    normalizedData = [NSMutableArray new];
	int packetReads = 0;
	NSDate *start = [NSDate date];
	while (!extAFReachedEOF) {
		int k = 0;
        if ((k = [self readConsecutive:NUM_FRAMES_PER_READ intoArray:audio]) < 0) { 
			[self status:ERROR message:@"Cannot read audio file"];
			goto cleanup;
        }
		[self calculateSampleFromArray:audio lenght:k];
		packetReads += k;
	}
    NSDate *endTime = [NSDate date];
    NSTimeInterval timeDiff = [endTime timeIntervalSinceDate:start];
    NSLog(@"Process sample data : %f", timeDiff);
	float allSec = packetReads / sampleRate;
	lengthInSec = allSec;
	minute = allSec / 60;
	sec = ceil(allSec - ((float)(minute * 60) + 0.5));
	err = ExtAudioFileDispose(extAFRef);
	if(err != noErr) {
		[self status:ERROR message:@"Error closing audio file"];
        [normalizedData release];
        normalizedData = nil;
	}
    else
    {
        [self status:LOADED message:@"Sample data loaded"];
    }
    
cleanup:
    for (int i=0; i < extAFNumChannels; ++i) {
        free(audio[i]);
    }
	
//	NSLog(@"Packets read : %d (%ld)",packetReads, sampleData.count);
}

- (void) calculateSampleFromArray:(float**)audio lenght:(int)length
{
	float maxValuesArray[extAFNumChannels];
    float *maxValues = maxValuesArray;
	for(int i = 0; i < extAFNumChannels;i++) {
		maxValues[i] = 0.0; 
	}
	for(int v = 0; v < length; v+=1000) {
		for(int c = 0; c < extAFNumChannels;c++) {
			for(NSUInteger p = 0;p < binSize; p++) {
				int idx = v + p;
				if(idx < length) {
					float val = audio[c][idx];
					if(val > maxValues[c]) maxValues[c] = val;
				} else {
					break;
				}
			}
		}
		float maxValue = 0;
		for(int i = 0; i < extAFNumChannels;i++) {
			if(maxValues[i] > maxValue) maxValue = maxValues[i]; 
		}

        if(maxValue > 1.0) maxValue = 1.0;
        else if(maxValue < 0.0) maxValue = 0.0;
		NSNumber *nMaxValue = [NSNumber numberWithFloat:maxValue];
		[normalizedData addObject:nMaxValue];
	}
    //[sampleData release];
    //sampleData = [[NSMutableArray arrayWithCapacity:length] retain];
    /*UInt32 stride = length / 2;
    dispatch_apply(length / stride, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(UInt32 v) {
        UInt32 start = v * stride;
        UInt32 end = start + stride;
        do {
            for(int c = 0; c < extAFNumChannels;c++) {
                for(int p = 0;p < binSize;p++) {
                    int idx = start + p;
                    if(idx < length) {
                        float val = audio[c][idx];
                        if(val > maxValues[c])
                            maxValues[c] = val;
                    } else {
                        break;
                    }
                }
            }
            float maxValue = 0;
            for(int i = 0; i < extAFNumChannels;i++) {
                if(maxValues[i] > maxValue)
                    maxValue = maxValues[i];
            }
            if(maxValue > 1.0) maxValue = 1.0;
            if(maxValue < 0.0) maxValue = 0.0;
            NSNumber *nMaxValue = [NSNumber numberWithFloat:maxValue];
            [normalizedData addObject:nMaxValue];
            start += 2000;
        } while (start < end);
    });*/
}

- (OSStatus) readConsecutive:(SInt64)numFrames intoArray:(float**)audio
{
    OSStatus err = noErr;
	
    if (!extAFRef)  return -1;
	
    int kSegmentSize;
    if (extAFRateRatio < 1.) 
        kSegmentSize = (int)(numFrames * extAFNumChannels / extAFRateRatio + .5);
    else
        kSegmentSize = (int)(numFrames * extAFNumChannels * extAFRateRatio + .5);
	
    UInt32 loadedPackets;
    float *data = (float*)malloc(kSegmentSize*sizeof(float));
    if (!data) {
		return -1;
    } else {
		
		UInt32 numPackets = numFrames; // Frames to read
		UInt32 samples = numPackets * extAFNumChannels; // 2 channels (samples) per frame
		
		AudioBufferList bufList;
		bufList.mNumberBuffers = 1;
		bufList.mBuffers[0].mNumberChannels = extAFNumChannels; // Always 2 channels in this example
		bufList.mBuffers[0].mData = data; // data is a pointer (float*) to our sample buffer
		bufList.mBuffers[0].mDataByteSize = samples * sizeof(float);
		
		loadedPackets = numPackets;
		
		err = ExtAudioFileRead(extAFRef, &loadedPackets, &bufList);
		if (!err) {
			if (audio) {
				for (long c = 0; c < extAFNumChannels; c++) {
					if (!audio[c]) continue;
					/*for (unsigned int v = 0; v < numFrames; v++) {
						if (v < loadedPackets) audio[c][v] = data[v*extAFNumChannels+c];
						else audio[c][v] = 0.;
					}*/
                    UInt32 stride = numFrames / 5;
                    dispatch_apply(numFrames / stride, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t v) {
                        UInt32 start = v * stride;
                        UInt32 end = start + stride;
                        do {
                            if (start < loadedPackets)
                                audio[c][start] = data[start*extAFNumChannels+c];
                            else
                                audio[c][start] = 0.;
                        } while (++start < end);
                    });
				}
			}
		}
		free(data);
		if (err != noErr) return err;
		if (loadedPackets < numFrames) extAFReachedEOF = YES;
		return loadedPackets;
	}
}	

- (NSArray *)sampleData
{
    return normalizedData;
}

- (float *)dataForResolution:(int)pixelWide lenght:(int *)length
{
//	int samplePerSec = 44100.0 / binSize;
//	int secPerPixel = (int)lengthInSec / (int)pixelWide;
	UInt32 rangeLength = normalizedData.count / pixelWide + 1;
	UInt32 retLength = pixelWide;
	float *ret = (float *)calloc(sizeof(float),retLength);
	int k = 0;
	for(UInt32 r = 0; r < normalizedData.count; r += rangeLength) {
		float valMax = 0;
		for(UInt32 j = 0; j < rangeLength; j++) {
			UInt32 idx = r + j;
			if(idx < normalizedData.count) {
				NSNumber *nVal = [normalizedData objectAtIndex:idx];
				float val = nVal.floatValue;
				if(valMax < val) valMax = val;
			}
		}
		ret[k] = valMax;
		k++;
	}
	*length = k;
	return ret;
	
//	float samplePerSec = 44100.0 / binSize;
//	float secPerPixel = (float)lengthInSec / (float)pixelWide;
//	float rangeLength = samplePerSec * secPerPixel;
//	float retLength = (normalizedData.count / rangeLength) + 1;
//	float *ret = (float *)malloc(sizeof(float) *retLength);
//	int k = 0;
//	for(int r = 0; r < normalizedData.count; r += rangeLength) {
//		float valMax = 0;
//		for(int j = 0; j < rangeLength; j++) {
//			int idx = r + j;
//			if(idx < normalizedData.count) {
//				NSNumber *nVal = [normalizedData objectAtIndex:idx];
//				float val = nVal.floatValue;
//				if(valMax < val) valMax = val;
//			}
//		}
//		ret[k] = valMax;
//		k++;
//	}
//	*length = k;
//	return ret;
}
@end

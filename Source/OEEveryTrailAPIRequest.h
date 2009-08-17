//
//  OEEveryTrailAPIRequest.h
//
// Copyright (c) 2009 Houdah Software s.à r.l. (http://www.houdah.com)
// Copyright (c) 2009 Lukhnos D. Liu (http://lukhnos.org)
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#import <Foundation/Foundation.h>

#import "LFWebAPIKit.h"
#import "OEUtilities.h"
#import "OEXMLMapper.h"


@class OEEveryTrailAPIContext;
@protocol OEEveryTrailAPIRequestDelegate;


extern NSString *const OEEveryTrailAPIReturnedErrorDomain;
extern NSString *const OEEveryTrailAPIRequestErrorDomain;

enum {
	// refer to EveryTrail API document for EveryTrail's own error codes
    OEEveryTrailAPIRequestConnectionError				= -1,
    OEEveryTrailAPIRequestTimeoutError					= -2,    
	OEEveryTrailAPIRequestFaultyXMLResponseError		= -3,
	OEEveryTrailAPIRequestAuthenticationError			= -4,
    OEEveryTrailAPIRequestUnknownError					= -100
};

@class OEEveryTrailAPIRequest;

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@protocol OEEveryTrailAPIRequestDelegate <NSObject>
@optional
#else
@interface NSObject (OEEveryTrailAPIRequestDelegateCategory)
#endif
- (void)everyTrailAPIRequest:(OEEveryTrailAPIRequest *)inRequest didCompleteWithResponse:(NSDictionary *)inResponseDictionary;
- (void)everyTrailAPIRequest:(OEEveryTrailAPIRequest *)inRequest didFailWithError:(NSError *)inError;
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_4                
- (void)everyTrailAPIRequest:(OEEveryTrailAPIRequest *)inRequest imageUploadSentBytes:(NSUInteger)inSentBytes totalBytes:(NSUInteger)inTotalBytes;
#else
- (void)everyTrailAPIRequest:(OEEveryTrailAPIRequest *)inRequest imageUploadSentBytes:(unsigned int)inSentBytes totalBytes:(unsigned int)inTotalBytes;
#endif
@end

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
typedef id<OEEveryTrailAPIRequestDelegate> OEEveryTrailAPIRequestDelegateType;
#else
typedef id OEEveryTrailAPIRequestDelegateType;
#endif

@interface OEEveryTrailAPIRequest : NSObject
{
    OEEveryTrailAPIContext *context;
    LFHTTPRequest *httpRequest;
    
    OEEveryTrailAPIRequestDelegateType delegate;
    id sessionInfo;
    
    NSString *uploadTempFilename;

	NSString *userId;
	NSInvocation *invocation;
}

- (id)initWithAPIContext:(OEEveryTrailAPIContext *)inContext;
- (OEEveryTrailAPIContext *)context;

- (OEEveryTrailAPIRequestDelegateType)delegate;
- (void)setDelegate:(OEEveryTrailAPIRequestDelegateType)inDelegate;

- (id)sessionInfo;
- (void)setSessionInfo:(id)inInfo;

- (NSTimeInterval)requestTimeoutInterval;
- (void)setRequestTimeoutInterval:(NSTimeInterval)inTimeInterval;
- (BOOL)isRunning;
- (void)cancel;

// elementary methods
- (void)callAPIMethodWithGET:(NSString *)inMethodName
					inDomain:(NSString *)inDomainName
				   arguments:(NSDictionary *)inArguments
			  authentication:(BOOL)inAuthentication;
- (void)callAPIMethodWithPOST:(NSString *)inMethodName
					 inDomain:(NSString *)inDomainName
					arguments:(NSDictionary *)inArguments
			   authentication:(BOOL)inAuthentication;

// image upload—we use NSInputStream here because we want to have flexibity; with this you can upload either a file or NSData from NSImage
- (void)uploadJPEGImageStream:(NSInputStream *)inImageStream
			suggestedFilename:(NSString *)inFilename
					arguments:(NSDictionary *)inArguments;

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@property (nonatomic, readonly) OEEveryTrailAPIContext *context;
@property (nonatomic, assign) OEEveryTrailAPIRequestDelegateType delegate;
@property (nonatomic, retain) id sessionInfo;
@property (nonatomic, assign) NSTimeInterval requestTimeoutInterval;
#endif

@end
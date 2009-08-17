//
//  OEEveryTrailAPIContext.h
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


extern NSString *const OEEveryTrailThumbnailSizenail;
extern NSString *const OEEveryTrailFullSize;		


@protocol OEEveryTrailAPIUserIdConsumer;

@interface OEEveryTrailAPIContext : NSObject
{
	LFHTTPRequest *httpRequest;

    NSString *key;
    NSString *secret;
	
    NSString *userName;
    NSString *password;
	NSString *userId;
    
    NSString *apiEndpoint;
	NSString *authEndpoint;
}

- (id)initWithAPIKey:(NSString *)inKey secret:(NSString *)inSharedSecret;

- (void)setUserName:(NSString *)inUserName;
- (NSString *)userName;

- (void)setPassword:(NSString *)inPassword;
- (NSString *)password;

- (void)setUserId:(NSString *)inUserId;
- (NSString *)userId;

// URL provisioning
- (NSURL *)photoSourceURLFromDictionary:(NSDictionary *)inDictionary size:(NSString *)inSizeModifier;

// API endpoints
- (void)setApiEndpoint:(NSString *)inEndpoint;
- (NSString *)apiEndpoint;

- (void)setAuthEndpoint:(NSString *)inEndpoint;
- (NSString *)authEndpoint;

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@property (nonatomic, readonly) NSString *key;
@property (nonatomic, readonly) NSString *secret;

@property (nonatomic, retain) NSString *userName;
@property (nonatomic, retain) NSString *password;

@property (nonatomic, retain) NSString *apiEndpoint;
@property (nonatomic, retain) NSString *authEndpoint;
#endif

- (void)enableBasicAuthentication:(LFHTTPRequest*)inHttpRequest;

- (BOOL)requestUserId:(id<OEEveryTrailAPIUserIdConsumer>)inUserIdConsumer;

- (NSArray *)signedArgumentComponentsFromArguments:(NSDictionary *)inArguments
									  useURIEscape:(BOOL)inUseEscape
									authentication:(BOOL)inAuthentication
											 error:(NSError**)error;
- (NSString *)signedQueryFromArguments:(NSDictionary *)inArguments
						authentication:(BOOL)inAuthentication
								 error:(NSError**)error;

@end


@protocol OEEveryTrailAPIUserIdConsumer

- (void)context:(OEEveryTrailAPIContext*)inContext providesUserId:(NSString*)inUserId;
- (void)context:(OEEveryTrailAPIContext*)inContext failedToProvideUserIdWithError:(NSError*)inError;

@end
//
//  OEEveryTrailAPIContext.m
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

#import "OEEveryTrailAPIContext.h"

#import "OEEveryTrailAPIRequest.h"

#import "NSData-Base64Extensions.h"


NSString *const OEEveryTrailThumbnailSize	= @"thumbnail";
NSString *const OEEveryTrailFullSize		= @"fullsize";		


@interface OEEveryTrailAPIContext (PrivateMethods)

@end


#define kDefaultEveryTrailRESTAPIEndpoint		@"http://test.everytrail.com/api"
#define kDefaultEveryTrailAuthEndpoint			@"http://www.everytrail.com/api/user/login"


@implementation OEEveryTrailAPIContext

- (void)dealloc
{
    [key release], key = nil;
    [secret release], secret = nil;

	[userName release], userName = nil;
    [password release], password = nil;

    [apiEndpoint release], apiEndpoint = nil;
	[authEndpoint release], authEndpoint = nil;
    
	[httpRequest release], httpRequest = nil;

    [super dealloc];
}

- (id)initWithAPIKey:(NSString *)inKey secret:(NSString *)inSecret
{
    if (self = [super init]) {
        key = [inKey copy];
        secret = [inSecret copy];
        
        apiEndpoint = kDefaultEveryTrailRESTAPIEndpoint;
		authEndpoint = kDefaultEveryTrailAuthEndpoint;

		httpRequest = [[LFHTTPRequest alloc] init];
		
        [httpRequest setContentType:nil];
        [httpRequest setDelegate:self];
	}
    return self;
}

- (void)setUserName:(NSString *)inUserName
{
    NSString *tmp = userName;
    userName = [inUserName copy];
    [tmp release];
}

- (NSString *)userName
{
    return userName;
}

- (void)setPassword:(NSString *)inPassword
{
    NSString *tmp = password;
    password = [inPassword copy];
    [tmp release];
}

- (NSString *)password
{
    return password;
}

- (NSURL *)photoSourceURLFromDictionary:(NSDictionary *)inDictionary size:(NSString *)inSizeModifier
{
	NSDictionary *urls = [inDictionary valueForKeyPath:@"photo.urls"];
	NSString *urlString = [urls objectForKey:inSizeModifier];
	
	return [NSURL URLWithString:urlString];
}

- (void)setApiEndpoint:(NSString *)inEndpoint
{
    NSString *tmp = apiEndpoint;
    apiEndpoint = [inEndpoint copy];
    [tmp release];
}

- (NSString *)apiEndpoint
{
    return apiEndpoint;
}

- (void)setAuthEndpoint:(NSString *)inEndpoint
{
	NSString *tmp = authEndpoint;
	authEndpoint = [inEndpoint copy];
	[tmp release];
}

- (NSString *)authEndpoint
{
	return authEndpoint;
}

#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4
@synthesize key;
@synthesize secret;
@synthesize userName;
@synthesize password;
#endif

- (void)enableBasicAuthentication:(LFHTTPRequest*)inHttpRequest
{
	NSMutableDictionary *requestHeader = [NSMutableDictionary dictionaryWithDictionary:[inHttpRequest requestHeader]];
	NSString *authString = [NSString stringWithFormat:@"%@:%@", key, secret];
	NSData *authData = [authString dataUsingEncoding:NSUTF8StringEncoding];
	NSString *authHeader = [NSString stringWithFormat:@"Basic %@", [authData encodeBase64]];
	
	[requestHeader setObject:authHeader forKey:@"Authorization"];
	[inHttpRequest setRequestHeader:requestHeader];
}

- (BOOL)requestUserId:(id<OEEveryTrailAPIUserIdConsumer>)inUserIdConsumer
{
    if ([httpRequest isRunning]) {
        return NO;
    }
    
	[httpRequest setSessionInfo:inUserIdConsumer];
	
	NSMutableString *arguments = [NSMutableString string];
	
	[arguments appendFormat:@"username=%@", self.userName];
	[arguments appendString:@"&"];
	[arguments appendFormat:@"password=%@", self.password];
			
	[self enableBasicAuthentication:httpRequest];

	return [httpRequest performMethod:LFHTTPRequestPOSTMethod
								onURL:[NSURL URLWithString:authEndpoint]
							 withData:[arguments dataUsingEncoding:NSUTF8StringEncoding]];
}


#pragma mark -
#pragma mark LFHTTPRequest delegate methods

- (void)httpRequestDidComplete:(LFHTTPRequest *)request
{
	NSData *data = [request receivedData];
	NSDictionary *response = [OEXMLMapper dictionaryMappedFromXMLData:data];
	NSString *userIdString = [response objectForKey:@"user"];
	
	id<OEEveryTrailAPIUserIdConsumer> userIdConsumer = [request sessionInfo];

	if (userIdString != nil) {
		[userIdConsumer context:self providesUserId:userIdString];
	}
	else {
		NSArray *errors = [response valueForKeyPath:@"errors.error"];
		NSString *errorString = nil;
		
		if ([errors count] > 0) {
			errorString = [errors objectAtIndex:0];
		}
		else {
			errorString = NSLocalizedString(@"Failure to acquire user ID", @"Failure to acquire user ID");
		}
		
		NSError *error = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain
											 code:OEEveryTrailAPIRequestConnectionError
										 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedFailureReasonErrorKey, nil]];
		
		[userIdConsumer context:self failedToProvideUserIdWithError:error];
	}
}

- (void)httpRequest:(LFHTTPRequest *)request didFailWithError:(NSString *)errorString
{
	id<OEEveryTrailAPIUserIdConsumer> userIdConsumer = [request sessionInfo];
	
	if (errorString == nil) {
		errorString = NSLocalizedString(@"Failure to acquire user ID",
										@"Failure to acquire user ID");
	}
	
	NSError *error = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain
										 code:OEEveryTrailAPIRequestConnectionError
									 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:errorString, NSLocalizedFailureReasonErrorKey, nil]];
	
	[userIdConsumer context:self failedToProvideUserIdWithError:error];
}

@end
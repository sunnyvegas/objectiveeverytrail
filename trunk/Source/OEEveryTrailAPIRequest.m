//
//  OEEveryTrailAPIRequest.m
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

#import "OEEveryTrailAPIRequest.h"

#import "OEEveryTrailAPIContext.h"
#import "OEUtilities.h"

NSString *const OEEveryTrailUploadTempFilenamePrefix = @"com.houdah.ObjectiveEveryTrail.upload";
NSString *const OEEveryTrailAPIReturnedErrorDomain = @"com.EveryTrail";
NSString *const OEEveryTrailAPIRequestErrorDomain = @"com.houdah.ObjectiveEveryTrail";


@interface OEEveryTrailAPIRequest (PrivateMethods) <OEEveryTrailAPIUserIdConsumer>

- (void)cleanUpTempFile;

@end            


@implementation OEEveryTrailAPIRequest

- (void)dealloc
{
	[self cancel];

    [context release], context = nil;
    [httpRequest release], httpRequest = nil;
    [sessionInfo release], sessionInfo = nil;
    
    [invocation release], invocation = nil;

	[self cleanUpTempFile];
    
    [super dealloc];
}

- (id)initWithAPIContext:(OEEveryTrailAPIContext *)inContext
{
    if (self = [super init]) {
        context = [inContext retain];
        
        httpRequest = [[LFHTTPRequest alloc] init];
        [httpRequest setDelegate:self];
    }
    
    return self;
}

- (OEEveryTrailAPIContext *)context
{
	return context;
}

- (OEEveryTrailAPIRequestDelegateType)delegate
{
    return delegate;
}

- (void)setDelegate:(OEEveryTrailAPIRequestDelegateType)inDelegate
{
    delegate = inDelegate;
}

- (id)sessionInfo
{
    return [[sessionInfo retain] autorelease];
}

- (void)setSessionInfo:(id)inInfo
{
    id tmp = sessionInfo;
    sessionInfo = [inInfo retain];
    [tmp release];
}

- (NSTimeInterval)requestTimeoutInterval
{
    return [httpRequest timeoutInterval];
}

- (void)setRequestTimeoutInterval:(NSTimeInterval)inTimeInterval
{
    [httpRequest setTimeoutInterval:inTimeInterval];
}

- (BOOL)isRunning
{
    return [httpRequest isRunning];
}

- (void)cancel
{
 	[invocation release], invocation = nil;
	[httpRequest cancelWithoutDelegateMessage];
  
	[self cleanUpTempFile];
}

- (void)callAPIMethodWithGET:(NSString *)inMethodName
					inDomain:(NSString *)inDomainName
				   arguments:(NSDictionary *)inArguments
			  authentication:(BOOL)inAuthentication
{
    if ([self isRunning]) {
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			NSError *error = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain
												 code:OEEveryTrailAPIRequestConnectionError
											 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Concurrent requests not supported", NSLocalizedFailureReasonErrorKey, nil]];
			
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
    }
    
	if (inAuthentication  && ([context userId] == nil)) {
		SEL mySelector = @selector(callAPIMethodWithGET:inDomain:arguments:authentication:);
		NSMethodSignature *mySignature = [[self class] instanceMethodSignatureForSelector:mySelector];
		NSInvocation *myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		NSNumber *myAuthentication = [NSNumber numberWithBool:inAuthentication];
		
		[myInvocation retainArguments];
		[myInvocation setTarget:self];
		[myInvocation setSelector:mySelector];
		[myInvocation setArgument:&inMethodName atIndex:2];
		[myInvocation setArgument:&inDomainName atIndex:3];
		[myInvocation setArgument:&inArguments atIndex:4];
		[myInvocation setArgument:&myAuthentication atIndex:5];
		
		invocation = [myInvocation retain];
		
		[context requestUserId:self];
		
		return;
	}
	
    
    // combine the parameters 
	NSMutableDictionary *newArgs = inArguments ? [NSMutableDictionary dictionaryWithDictionary:inArguments] : [NSMutableDictionary dictionary];
	
	NSError *error = nil;
	NSString *query = [[self context] signedQueryFromArguments:newArgs
												authentication:inAuthentication
														 error:&error];
	
	if (error != nil) {
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
	}
	
	NSString *urlString = [NSString stringWithFormat:@"%@/%@/%@?%@",
						   [context apiEndpoint], inDomainName,inMethodName, query];
	
    [httpRequest setContentType:nil];
	
	[[self context] enableBasicAuthentication:httpRequest];
	
	BOOL success = [httpRequest performMethod:LFHTTPRequestGETMethod
										onURL:[NSURL URLWithString:urlString]
									 withData:nil];
	
	if (!success) {
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			NSError *error = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain
												 code:OEEveryTrailAPIRequestConnectionError
											 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not connect", NSLocalizedFailureReasonErrorKey, nil]];
			
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
	}
}

- (void)callAPIMethodWithPOST:(NSString *)inMethodName
					 inDomain:(NSString *)inDomainName
					arguments:(NSDictionary *)inArguments
			   authentication:(BOOL)inAuthentication
{
    if ([self isRunning]) {
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			NSError *error = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain
												 code:OEEveryTrailAPIRequestConnectionError
											 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Concurrent requests not supported", NSLocalizedFailureReasonErrorKey, nil]];
			
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
    }
    
	if (inAuthentication && ([context userId] == nil)) {
		SEL mySelector = @selector(callAPIMethodWithPOST:inDomain:arguments:authentication:);
		NSMethodSignature *mySignature = [[self class] instanceMethodSignatureForSelector:mySelector];
		NSInvocation *myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		NSNumber *myAuthentication = [NSNumber numberWithBool:inAuthentication];
		
		[myInvocation retainArguments];
		[myInvocation setTarget:self];
		[myInvocation setSelector:mySelector];
		[myInvocation setArgument:&inMethodName atIndex:2];
		[myInvocation setArgument:&inDomainName atIndex:3];
		[myInvocation setArgument:&inArguments atIndex:4];
		[myInvocation setArgument:&myAuthentication atIndex:5];
		
		invocation = [myInvocation retain];
		
		[context requestUserId:self];
		
		return;
	}
    
    // combine the parameters 
	NSMutableDictionary *newArgs = inArguments ? [NSMutableDictionary dictionaryWithDictionary:inArguments] : [NSMutableDictionary dictionary];
	
	NSError *error = nil;
	NSString *arguments = [[self context] signedQueryFromArguments:newArgs
													authentication:inAuthentication
															 error:&error];
    
	if (error != nil) {
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
	}
	
	NSData *postData = [arguments dataUsingEncoding:NSUTF8StringEncoding];
	NSString *urlString = [NSString stringWithFormat:@"%@/%@/%@",
						   [context apiEndpoint], inDomainName,inMethodName];
	
	[httpRequest setContentType:LFHTTPRequestWWWFormURLEncodedContentType];
	
	[[self context] enableBasicAuthentication:httpRequest];

	BOOL success = [httpRequest performMethod:LFHTTPRequestPOSTMethod onURL:[NSURL URLWithString:urlString] withData:postData];
	
	if (!success) {
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			NSError *error = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain
												 code:OEEveryTrailAPIRequestConnectionError
											 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not connect", NSLocalizedFailureReasonErrorKey, nil]];
			
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
	}
}	

- (void)uploadJPEGImageStream:(NSInputStream *)inImageStream
			suggestedFilename:(NSString *)inFilename
					arguments:(NSDictionary *)inArguments
{
    if ([self isRunning]) {
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			NSError *error = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain
												 code:OEEveryTrailAPIRequestConnectionError
											 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Concurrent requests not supported", NSLocalizedFailureReasonErrorKey, nil]];
			
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
    }
    
	if ([context userId] == nil) {
		SEL mySelector = @selector(uploadJPEGImageStream:suggestedFilename:arguments:);
		NSMethodSignature *mySignature = [[self class] instanceMethodSignatureForSelector:mySelector];
		NSInvocation *myInvocation = [NSInvocation invocationWithMethodSignature:mySignature];
		
		[myInvocation retainArguments];
		[myInvocation setTarget:self];
		[myInvocation setSelector:mySelector];
		[myInvocation setArgument:&inImageStream atIndex:2];
		[myInvocation setArgument:&inFilename atIndex:3];
		[myInvocation setArgument:&inArguments atIndex:4];
		
		invocation = [myInvocation retain];
		
		[context requestUserId:self];
		
		return;
	}
	
    // get the api_sig
	NSError *error = nil;
    NSArray *argComponents = [[self context] signedArgumentComponentsFromArguments:(inArguments ? inArguments : [NSDictionary dictionary]) 
																	  useURIEscape:NO 
																	authentication:YES
																			 error:&error];
	
	if (error != nil) {
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
	}
	
    NSString *separator = OEGenerateUUIDString();
	NSString *mimeType = @"image/jpeg";
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", separator];
    
    // build the multipart form
    NSMutableString *multipartBegin = [NSMutableString string];
    NSMutableString *multipartEnd = [NSMutableString string];
    
    NSEnumerator *componentEnumerator = [argComponents objectEnumerator];
    NSArray *nextArgComponent;
    while (nextArgComponent = [componentEnumerator nextObject]) {        
        [multipartBegin appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", separator, [nextArgComponent objectAtIndex:0], [nextArgComponent objectAtIndex:1]];
    }
	
    // add filename, if nil, generate a UUID
    [multipartBegin appendFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", separator, [inFilename length] ? inFilename : OEGenerateUUIDString()];
    [multipartBegin appendFormat:@"Content-Type: %@\r\n\r\n", mimeType];
	
    [multipartEnd appendFormat:@"\r\n--%@--", separator];
    
    
    // now we have everything, create a temp file for this purpose; although UUID is inferior to 
    [self cleanUpTempFile];
    uploadTempFilename = [[NSTemporaryDirectory() stringByAppendingString:[NSString stringWithFormat:@"%@.%@", OEEveryTrailUploadTempFilenamePrefix, OEGenerateUUIDString()]] retain];
    
    // create the write stream
    NSOutputStream *outputStream = [NSOutputStream outputStreamToFileAtPath:uploadTempFilename append:NO];
    [outputStream open];
    
    const char *UTF8String;
    size_t writeLength;
    UTF8String = [multipartBegin UTF8String];
    writeLength = strlen(UTF8String);
    NSAssert([outputStream write:(uint8_t *)UTF8String maxLength:writeLength] == writeLength, @"Must write multipartBegin");
	
    // open the input stream
    const size_t bufferSize = 65536;
    size_t readSize = 0;
    uint8_t *buffer = (uint8_t *)calloc(1, bufferSize);
    NSAssert(buffer, @"Must have enough memory for copy buffer");
	
    [inImageStream open];
    while ([inImageStream hasBytesAvailable]) {
        if (!(readSize = [inImageStream read:buffer maxLength:bufferSize])) {
            break;
        }
        
        NSAssert (readSize == [outputStream write:buffer maxLength:readSize], @"Must completes the writing");
    }
    
    [inImageStream close];
    free(buffer);
    
    
    UTF8String = [multipartEnd UTF8String];
    writeLength = strlen(UTF8String);
    NSAssert([outputStream write:(uint8_t *)UTF8String maxLength:writeLength] == writeLength, @"Must write multipartBegin");
    [outputStream close];
    
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4	
    NSDictionary *fileInfo = [[NSFileManager defaultManager] fileSystemAttributesAtPath:uploadTempFilename];
    NSAssert(fileInfo, @"Must have upload temp file");
#else
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:uploadTempFilename error:&error];
    NSAssert(fileInfo && !error, @"Must have upload temp file");
#endif
	
    NSNumber *fileSizeNumber = [fileInfo objectForKey:NSFileSize];
    NSUInteger fileSize = 0;
	
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4                
    fileSize = [fileSizeNumber intValue];
#else
    if ([fileSizeNumber respondsToSelector:@selector(integerValue)]) {
        fileSize = [fileSizeNumber integerValue];                    
    }
    else {
        fileSize = [fileSizeNumber intValue];                    
    }                
#endif
    
    NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:uploadTempFilename];
	
    [httpRequest setContentType:contentType];
	
	[[self context] enableBasicAuthentication:httpRequest];

	BOOL success = [httpRequest performMethod:LFHTTPRequestPOSTMethod onURL:[NSURL URLWithString:[context apiEndpoint]] withInputStream:inputStream knownContentSize:fileSize];
	
	if (!success) {
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			NSError *error = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain
												 code:OEEveryTrailAPIRequestConnectionError
											 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Could not connect", NSLocalizedFailureReasonErrorKey, nil]];
			
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
	}
}

#pragma mark LFHTTPRequest delegate methods
- (void)httpRequestDidComplete:(LFHTTPRequest *)request
{
	NSLog(@"%@", [[[NSString alloc] initWithData:[request receivedData] encoding:NSUTF8StringEncoding] autorelease]);

	NSDictionary *responseDictionary = [OEXMLMapper dictionaryMappedFromXMLData:[request receivedData]];	
	NSArray *errorsElement = [responseDictionary valueForKeyPath:@"errors"];
	
	if (([responseDictionary count] == 0) || ([errorsElement count] > 0)) {
		NSError *error = nil;
		
		if ([responseDictionary count] > 0) {
			NSArray *errors = [responseDictionary valueForKeyPath:@"errors.error._text"];
			NSString *message = NSLocalizedString(@"Unknown EveryTrail error",
												  @"Unknown EveryTrail error");
			int errorCode = OEEveryTrailAPIRequestUnknownError;
			
			if ([errors count] > 0) {
				NSString *errorString = [errors objectAtIndex:0];
				int errorValue = [errorString intValue];
				
				if ((errorValue != 0) && (errorValue != INT_MIN) && (errorValue != INT_MAX)) {
					errorCode = errorValue;
				}
			}
			
			if (errorCode == 11) {
				message = NSLocalizedString(@"Incorrect user name or password",
											@"Incorrect user name or password");
			}
			
			error = [NSError errorWithDomain:OEEveryTrailAPIReturnedErrorDomain
										code:errorCode
									userInfo:[NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedFailureReasonErrorKey, nil]];				
		}
		
		if (error == nil) {
			error = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain
										code:OEEveryTrailAPIRequestFaultyXMLResponseError
									userInfo:nil];
		}
		
		if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
			[delegate everyTrailAPIRequest:self didFailWithError:error];        
		}
		
		return;
	}
	
    [self cleanUpTempFile];
	
    if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didCompleteWithResponse:)]) {
		[delegate everyTrailAPIRequest:self didCompleteWithResponse:responseDictionary];
    }    
}

- (void)httpRequest:(LFHTTPRequest *)request didFailWithError:(NSString *)error
{
    NSError *toDelegateError = nil;
    if ([error isEqualToString:LFHTTPRequestConnectionError]) {
		toDelegateError = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain code:OEEveryTrailAPIRequestConnectionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Network connection error", NSLocalizedFailureReasonErrorKey, nil]];
    }
    else if ([error isEqualToString:LFHTTPRequestTimeoutError]) {
		toDelegateError = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain code:OEEveryTrailAPIRequestTimeoutError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Request timeout", NSLocalizedFailureReasonErrorKey, nil]];
    }
    else {
		toDelegateError = [NSError errorWithDomain:OEEveryTrailAPIRequestErrorDomain code:OEEveryTrailAPIRequestUnknownError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Unknown error", NSLocalizedFailureReasonErrorKey, nil]];
    }
    
    [self cleanUpTempFile];
    if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
        [delegate everyTrailAPIRequest:self didFailWithError:toDelegateError];        
    }
}

- (void)httpRequest:(LFHTTPRequest *)request sentBytes:(NSUInteger)bytesSent total:(NSUInteger)total
{
    if (uploadTempFilename && [delegate respondsToSelector:@selector(everyTrailAPIRequest:imageUploadSentBytes:totalBytes:)]) {
        [delegate everyTrailAPIRequest:self imageUploadSentBytes:bytesSent totalBytes:total];
    }
}

@end

@implementation OEEveryTrailAPIRequest (PrivateMethods)

- (void)cleanUpTempFile

{
    if (uploadTempFilename) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:uploadTempFilename]) {
#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4                
            NSAssert([fileManager removeFileAtPath:uploadTempFilename handler:nil], @"Should be able to remove temp file");
#else
			NSError *error = nil;
			NSAssert([fileManager removeItemAtPath:uploadTempFilename error:&error], @"Should be able to remove temp file");
#endif
        }
        
        [uploadTempFilename release];
        uploadTempFilename = nil;
    }
}

- (void)context:(OEEveryTrailAPIContext*)inContext providesUserId:(NSString*)inUserId;
{
	[context setUserId:inUserId];
	
	if (invocation != nil) {
		NSInvocation *myInvocation = [invocation retain];
		
		[invocation release], invocation = nil;
		
		[myInvocation invoke];
		[myInvocation release];
	}
}

- (void)context:(OEEveryTrailAPIContext*)inContext failedToProvideUserIdWithError:(NSError*)inError;
{
	[context setUserId:nil];
	[invocation release], invocation = nil;
	
	if ([delegate respondsToSelector:@selector(everyTrailAPIRequest:didFailWithError:)]) {
		[delegate everyTrailAPIRequest:self didFailWithError:inError];        
	}
}

@end
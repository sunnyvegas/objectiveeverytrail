//
// OEUtilities.h
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

#import <CommonCrypto/CommonDigest.h>

#import "LFHTTPRequest.h"


#if !defined(NS_INLINE)
#if defined(__GNUC__)
#define NS_INLINE static __inline__ __attribute__((always_inline))
#elif defined(__MWERKS__) || defined(__cplusplus)
#define NS_INLINE static inline
#elif defined(_MSC_VER)
#define NS_INLINE static __inline
#elif defined(__WIN32__)
#define NS_INLINE static __inline__
#endif
#endif

NS_INLINE NSString *OEMD5HexStringFromNSString(NSString *inStr)
{
    const char *data = [inStr UTF8String];
    size_t length = strlen(data);
    
    unsigned char *md5buf = (unsigned char*)calloc(1, CC_MD5_DIGEST_LENGTH);
 
    CC_MD5_CTX md5ctx;
    CC_MD5_Init(&md5ctx);
    CC_MD5_Update(&md5ctx, data, length);
    CC_MD5_Final(md5buf, &md5ctx);

    NSMutableString *md5hex = [NSMutableString string];
	size_t i;
    for (i = 0 ; i < CC_MD5_DIGEST_LENGTH ; i++) {
        [md5hex appendFormat:@"%02x", md5buf[i]];
    }
    free(md5buf);
    return md5hex;
}

NS_INLINE NSString *OEEscapedURLStringFromNSString(NSString *inStr)
{
	CFStringRef escaped = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)inStr, NULL, CFSTR("&"), kCFStringEncodingUTF8);

    #if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4	
	return (NSString *)[(NSString*)escaped autorelease];			    
    #else
	return (NSString *)[NSMakeCollectable(escaped) autorelease];			    
	#endif
}

NS_INLINE NSString *OEGenerateUUIDString()
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4	
	return (NSString *)[(NSString*)uuidStr autorelease];			    
#else
	return (NSString *)[NSMakeCollectable(uuidStr) autorelease];			    
#endif	
}

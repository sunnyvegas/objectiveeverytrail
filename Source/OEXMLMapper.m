//
// OEXMLMapper.m
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

#import "OEXMLMapper.h"

#import "OEEveryTrailAPIRequest.h"

NSString *OEXMLMapperExceptionName = @"OEXMLMapperException";
NSString *OEXMLAttributesKey = @"_attributes";
NSString *OEXMLTextContentKey = @"_text";

@implementation OEXMLMapper

- (void)dealloc
{
    [resultantDictionary release];
	[elementStack release];
	[currentElementName release];
    [super dealloc];
}

- (id)init
{
    if (self = [super init]) {
        resultantDictionary = [[NSMutableDictionary alloc] init];
		elementStack = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)runWithData:(NSData *)inData
{
	currentDictionary = resultantDictionary;
	
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:inData];
	[parser setDelegate:self];
	[parser parse];
	[parser release];
}

- (NSDictionary *)resultantDictionary
{
	return [[resultantDictionary retain] autorelease];
}

+ (NSDictionary *)dictionaryMappedFromXMLData:(NSData *)inData
{
	OEXMLMapper *mapper = [[OEXMLMapper alloc] init];
	[mapper runWithData:inData];
	NSDictionary *result = [mapper resultantDictionary];
	[mapper release];
	return result;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
	NSMutableDictionary *mutableDict = attributeDict ?  [NSMutableDictionary dictionaryWithObject:attributeDict forKey:OEXMLAttributesKey] : [NSMutableDictionary dictionary];
	
	// see if it's duplicated
	id element;
	if (element = [currentDictionary objectForKey:elementName]) {
		if (![element isKindOfClass:[NSMutableArray class]]) {
			if ([element isKindOfClass:[NSMutableDictionary class]]) {
				[element retain];
				[currentDictionary removeObjectForKey:elementName];
				
				NSMutableArray *newArray = [NSMutableArray arrayWithObject:element];
				[currentDictionary setObject:newArray forKey:elementName];
				[element release];
				
				element = newArray;
			}
			else {
				@throw [NSException exceptionWithName:OEXMLMapperExceptionName reason:@"Faulty XML structure" userInfo:nil];
			}
		}
		
		[element addObject:mutableDict];
	}
	else {
		// plural tag rule: if the parent's tag is plural and the incoming is singular, we'll make it into an array (we only handles the -s case)
		
		if ([currentElementName length] > [elementName length] && [currentElementName hasPrefix:elementName] && [currentElementName hasSuffix:@"s"]) {
			[currentDictionary setObject:[NSMutableArray arrayWithObject:mutableDict] forKey:elementName];
		}
		else {
			[currentDictionary setObject:mutableDict forKey:elementName];
		}
	}
	
	[elementStack insertObject:currentDictionary atIndex:0];
	currentDictionary = mutableDict;
	
	NSString *tmp = currentElementName;
	currentElementName = [elementName retain];
	[tmp release];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if (![elementStack count]) {
		@throw [NSException exceptionWithName:OEXMLMapperExceptionName reason:@"Unbalanced XML element tag closing" userInfo:nil];
	}
	
	currentDictionary = [elementStack objectAtIndex:0];
	[elementStack removeObjectAtIndex:0];
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	NSString *existingString = [currentDictionary objectForKey:OEXMLTextContentKey];
	
	if (existingString != nil) {
		[currentDictionary setObject:[existingString stringByAppendingString:string] forKey:OEXMLTextContentKey];
	}
	else {
		[currentDictionary setObject:string forKey:OEXMLTextContentKey];
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	[resultantDictionary release];
	resultantDictionary = nil;
}

@end


@implementation NSDictionary (OEXMLMapperExtension)

- (NSDictionary *)oeAttributes
{
    return [self objectForKey:OEXMLAttributesKey];
}

- (NSString *)oeTextContent
{
    return [self objectForKey:OEXMLTextContentKey];
}

- (NSObject *)oeRootElement
{
	if ([self count] == 1) {
		NSObject *key = [[self allKeys] objectAtIndex:0];
		
		return [self objectForKey:key];
	}
	
	return nil;
}

- (BOOL)oeRootHasError:(NSError**)outError
{
	NSDictionary *attributes = [self oeAttributes];
	NSString *status = [attributes objectForKey:@"status"];
	
	// this also fails when responseDictionary == nil, so it's a guranteed way of checking the result
	if (![status isEqualToString:@"success"]) {
		NSObject *error = [self valueForKeyPath:@"errors.error"];
		
		if ([error isKindOfClass:[NSArray class]]) {
			// Only handle the first error
			NSArray *errorArray = (NSArray*)error;
			
			if ([errorArray count] > 0) {
				error = [errorArray objectAtIndex:0];
			}
			else {
				error = nil;
			}
		}
		
		NSString *code = [error valueForKeyPath:@"code._text"];
		NSString *msg = [error valueForKeyPath:@"message._text"];
		NSError *toDelegateError = nil;
		
		if ([code length]) {
			NSDictionary *userInfo =
			[msg length] ?
			[NSDictionary dictionaryWithObjectsAndKeys:msg, NSLocalizedFailureReasonErrorKey, nil] :
			nil;
			
			toDelegateError = [NSError errorWithDomain:OEEveryTrailAPIReturnedErrorDomain
												  code:[code intValue]
											  userInfo:userInfo];				
		}
		else {
			toDelegateError = [NSError errorWithDomain:OEEveryTrailAPIReturnedErrorDomain
												  code:OEEveryTrailAPIRequestFaultyXMLResponseError
											  userInfo:nil];
		}
		
		if ((toDelegateError != nil) && (*outError != nil)) {
			*outError = toDelegateError;
		}
				
		return YES;
	}
	
	return NO;
}	

@end
//
//  SEEStyleSheet.m
//  SubEthaEdit
//
//  Created by Martin Pittenauer on 05.11.10.
//  Copyright 2010 TheCodingMonkeys. All rights reserved.
//

#import "SEEStyleSheet.h"
#import "SyntaxDefinition.h"


/*
 
 Every mode can has multiple style sheets encapsulating 
 scope/style pairs.
 
 */


@implementation SEEStyleSheet

@synthesize scopeStyleDictionary;
@synthesize scopeCache;

- (SEEStyleSheet*)initWithDefinition:(SyntaxDefinition*)aDefinition {
    self=[super init];
    if (self) {

		scopeStyleDictionary = [NSMutableDictionary new];
		scopeCache = [NSMutableDictionary new];
		if (aDefinition) {
			[aDefinition getReady];
			[scopeStyleDictionary addEntriesFromDictionary:[aDefinition scopeStyleDictionary]];
			NSArray *styleSheets = [aDefinition linkedStyleSheets];
			
			for (NSString *sheet in styleSheets) {
				[self importStyleSheetAtPath:[[[NSURL alloc] initFileURLWithPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"Modes/Styles/%@.sss",sheet]]] autorelease]];
			}
		}		
//		NSLog(@"scopes: %@", scopeStyleDictionary);
//		NSLog(@"inherit: %@", [self styleAttributesForScope:@"meta.block.directives.objective-c"]);
#warning autoexport still active
		[self exportStyleSheetToPath:[[[NSURL alloc]initFileURLWithPath:[NSString stringWithFormat:@"/tmp/%@.sss",[aDefinition name]]] autorelease]];
//		[self importStyleSheetAtPath:[[[NSURL alloc]initFileURLWithPath:@"/Users/pittenau/Desktop/test.seestylesheet"] autorelease]];
		
	}
	return self;
}

- (void)dealloc {
	scopeCache = nil;
	scopeStyleDictionary = nil;
	[super dealloc];
}


- (void) importStyleSheetAtPath:(NSURL *)aPath;
{
	NSError *err;
	NSString *importString = [NSString stringWithContentsOfURL:aPath encoding:NSUTF8StringEncoding error:&err];
		
	NSArray *scopeStrings = [importString componentsSeparatedByString:@"}"];
	
	for (NSString *scopeString in scopeStrings) {
	
		NSArray *scopeAndAttributes = [scopeString componentsSeparatedByString:@"{"];
		if ([scopeAndAttributes count] !=2) continue;
		NSString *scope = [[scopeAndAttributes objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSArray *attributes = [[scopeAndAttributes objectAtIndex:1] componentsSeparatedByString:@";"];
		NSMutableDictionary *scopeDictionary = [NSMutableDictionary dictionary];
		for (NSString *attribute in attributes) {
			NSArray *keysAndValues = [attribute componentsSeparatedByString:@":"];
			if ([keysAndValues count] !=2) continue;
			NSString *key = [[keysAndValues objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			id value = [[keysAndValues objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if ([key rangeOfString:@"color"].location != NSNotFound) {
				value = [NSColor colorForHTMLString:value];
			}
			if ([key isEqualToString:@"font-trait"]) {
				value = [NSNumber numberWithInt:[value intValue]];
			}
			
			[scopeDictionary setObject:value forKey:key];
		}

		if (scope && [scopeDictionary count]>0)
		[scopeStyleDictionary setObject:scopeDictionary forKey:scope];
	
	}
	
}

- (void) exportStyleSheetToPath:(NSURL *)aPath;
{
	NSMutableString *exportString = [NSMutableString string];
	for (NSString *scope in [[scopeStyleDictionary allKeys]sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
		[exportString appendString:[NSString stringWithFormat:@"%@ {\n", scope]];
		
		for(NSString *attribute in [[[scopeStyleDictionary objectForKey:scope] allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
			id value = [[scopeStyleDictionary objectForKey:scope] objectForKey:attribute];
			if ([value isKindOfClass:[NSColor class]]) value = [(NSColor*)value HTMLString];
			[exportString appendString:[NSString stringWithFormat:@"   %@:%@;\n", attribute, value]];
		}
		
		[exportString appendString:@"}\n\n"];
		
	}
	
	NSError *err;
	if (aPath) [exportString writeToURL:aPath atomically:YES encoding:NSUTF8StringEncoding error:&err];
	else NSLog(@"%@",exportString);
}

- (NSDictionary *)styleAttributesForScope:(NSString *)aScope {
	
	//Delete language specific part
	
	NSDictionary *computedStyle = [scopeCache objectForKey:aScope];
	
	
	if (!computedStyle) {
		NSString *newScope = [NSString stringWithString:aScope];
		newScope = [newScope stringByDeletingPathExtension];
		// Search for optimal style
//		 NSLog(@"Asked for %@", aScope);
		// First try full matching
		if (!(computedStyle = [scopeStyleDictionary objectForKey:newScope])||[computedStyle objectForKey:@"inherit"]) {
			while([newScope rangeOfString:@"."].location != NSNotFound) {
				newScope = [newScope stringByDeletingPathExtension];
//				NSLog(@"Looking for %@", newScope);
				if (computedStyle = [scopeStyleDictionary objectForKey:newScope]) {
					[scopeCache setObject:computedStyle forKey:aScope];
//					NSLog(@"Returned %@", newScope);
					return computedStyle;
				}
			}
		}
		
		// last, fall back to inheritence and language specifics
		
		if (!computedStyle) computedStyle = [scopeStyleDictionary objectForKey:aScope];
		if ([computedStyle objectForKey:@"inherit"]) {
			while ([computedStyle objectForKey:@"inherit"]) {
				if ([aScope isEqualToString:[computedStyle objectForKey:@"inherit"]]) {
					NSLog(@"WARNING: Endless inheritance for %@", aScope);
					break;
				}
				aScope = [computedStyle objectForKey:@"inherit"];
				computedStyle = [scopeStyleDictionary objectForKey:aScope];
			}
		} 
		
		if (!computedStyle) return nil;
//		NSLog(@"Returned %@", aScope);
		[scopeCache setObject:computedStyle forKey:aScope];
	}
	
	return computedStyle;
}


@end



/*
 CHDataStructures.framework -- CHSortedDictionary.m
 
 Copyright (c) 2009-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2024	Kinnami Software Corporation. All rights reserved.
 */

#import "CHSortedDictionary.h"
#import "CHAVLTree.h"

@implementation CHSortedDictionary

- (void) dealloc {
	[sortedKeys release];
	[super dealloc];
}

- (id) initWithCapacity:(NSUInteger)numItems {
	if ((self = [super initWithCapacity:numItems]) == nil) return nil;
	sortedKeys = [[CHAVLTree alloc] init];
	return self;
}

// The NSCoding methods inherited from CHMutableDictionary work fine here.

#pragma mark <NSFastEnumeration>

/** @test Add unit test. */
- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState*)state
                                   objects:(id*)stackbuf
                                     count:(NSUInteger)len
{
	return [sortedKeys countByEnumeratingWithState:state objects:stackbuf count:len];
}

#pragma mark Querying Contents

- (id) firstKey {
	return [sortedKeys firstObject];
}

- (NSUInteger) hash {
	return hashOfCountAndObjects([sortedKeys count],
	                             [sortedKeys firstObject],
	                             [sortedKeys lastObject]);
}

- (id) lastKey {
	return [sortedKeys lastObject];
}

- (NSEnumerator*) keyEnumerator {
	return [sortedKeys objectEnumerator];
}

- (NSEnumerator*) reverseKeyEnumerator {
	return [sortedKeys reverseObjectEnumerator];
}

- (NSMutableDictionary*) subsetFromKey:(id)start
                                 toKey:(id)end
                               options:(CHSubsetConstructionOptions)options
{
	id<CHSortedSet> keySubset = [sortedKeys subsetFromObject:start toObject:end options:options];
	NSMutableDictionary* subset = [[[[self class] alloc] init] autorelease];
	for (id aKey in keySubset) {
		[subset setObject:[self objectForKey:aKey] forKey:aKey];
	}
	return subset;
}

#pragma mark Modifying Contents

- (void) removeAllObjects {
	[super removeAllObjects];
	[sortedKeys removeAllObjects];
}

- (void) removeObjectForKey:(id)aKey {
	[aKey retain];			/* CJEC, 27-May-15: Retain while we're using the object to prevent deallocation */
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	if (CFDictionaryContainsKey(dictionary, aKey)) {
#else
	if ([m_poDict objectForKey: aKey] != nil) {
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
		[super removeObjectForKey:aKey];
		[sortedKeys removeObject:aKey];
	}
	[aKey release];			/* CJEC, 27-May-15: Safe to deallocate now */
}

- (void) setObject:(id)anObject forKey:(id)aKey {
	if (anObject == nil || aKey == nil)
		CHNilArgumentException([self class], _cmd);
	id clonedKey = [[aKey copy] autorelease];
	[sortedKeys addObject:clonedKey];
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	CFDictionarySetValue(dictionary, clonedKey, anObject);
#else
	[m_poDict setObject: anObject forKey: clonedKey];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

@end

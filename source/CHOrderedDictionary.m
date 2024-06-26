/*
 CHDataStructures.framework -- CHOrderedDictionary.m
 
 Copyright (c) 2009-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2024	Kinnami Software Corporation. All rights reserved.
 */

#import "CHOrderedDictionary.h"
#import "CHCircularBuffer.h"

@implementation CHOrderedDictionary

- (void) dealloc {
	[keyOrdering release];
	[super dealloc];
}

- (id) initWithCapacity:(NSUInteger)numItems {
	if ((self = [super initWithCapacity:numItems]) == nil) return nil;
	keyOrdering = [[CHCircularBuffer alloc] initWithCapacity:numItems];
	return self;
}

- (id) initWithCoder:(NSCoder*)decoder {
	if ((self = [super initWithCoder:decoder]) == nil) return nil;
	[keyOrdering release];
	keyOrdering = [[decoder decodeObjectForKey:@"keyOrdering"] retain];
	return self;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
	[super encodeWithCoder:encoder];
	[encoder encodeObject:keyOrdering forKey:@"keyOrdering"];
}

#pragma mark <NSFastEnumeration>

/** @test Add unit test. */
- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState*)state
                                   objects:(id*)stackbuf
                                     count:(NSUInteger)len
{
	return [keyOrdering countByEnumeratingWithState:state objects:stackbuf count:len];
}

#pragma mark Querying Contents

- (id) firstKey {
	return [keyOrdering firstObject];
}

- (NSUInteger) hash {
	return [keyOrdering hash];
}

- (id) lastKey {
	return [keyOrdering lastObject];
}

- (NSUInteger) indexOfKey:(id)aKey {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	if (CFDictionaryContainsKey(dictionary, aKey))
#else
	if ([m_poDict objectForKey: aKey] != nil)
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
		return [keyOrdering indexOfObject:aKey];
	else
		return NSNotFound;
}

- (id) keyAtIndex:(NSUInteger)index {
	return [keyOrdering objectAtIndex:index];
}

- (NSArray*) keysAtIndexes:(NSIndexSet*)indexes {
	return [keyOrdering objectsAtIndexes:indexes];
}

- (NSEnumerator*) keyEnumerator {
	return [keyOrdering objectEnumerator];
}

- (id) objectForKeyAtIndex:(NSUInteger)index {
	// Note: -keyAtIndex: will raise an exception if the index is invalid.
	return [self objectForKey:[self keyAtIndex:index]];
}

- (NSArray*) objectsForKeysAtIndexes:(NSIndexSet*)indexes {
	return [self objectsForKeys:[self keysAtIndexes:indexes] notFoundMarker:self];
}

- (CHOrderedDictionary*) orderedDictionaryWithKeysAtIndexes:(NSIndexSet*)indexes {
	if (indexes == nil)
		CHNilArgumentException([self class], _cmd);
	if ([indexes count] == 0)
		return [[self class] dictionary];
	CHOrderedDictionary* newDictionary = [[self class] dictionaryWithCapacity:[indexes count]];
	NSUInteger index = [indexes firstIndex];
	while (index != NSNotFound) {
		id key = [self keyAtIndex:index];
		[newDictionary setObject:[self objectForKey:key] forKey:key];
		index = [indexes indexGreaterThanIndex:index];
	}
	return newDictionary;
}

- (NSEnumerator*) reverseKeyEnumerator {
	return [keyOrdering reverseObjectEnumerator];
}

#pragma mark Modifying Contents

- (void) exchangeKeyAtIndex:(NSUInteger)idx1 withKeyAtIndex:(NSUInteger)idx2 {
	[keyOrdering exchangeObjectAtIndex:idx1 withObjectAtIndex:idx2];
}

- (void) insertObject:(id)anObject forKey:(id)aKey atIndex:(NSUInteger)index {
	if (index > [self count])
		CHIndexOutOfRangeException([self class], _cmd, index, [self count]);
	if (anObject == nil || aKey == nil)
		CHNilArgumentException([self class], _cmd);
	
	id clonedKey = [[aKey copy] autorelease];
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	if (!CFDictionaryContainsKey(dictionary, clonedKey)) {
#else
	if (nil == [m_poDict objectForKey: clonedKey]) {
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
		[keyOrdering insertObject:clonedKey atIndex:index];
	}
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	CFDictionarySetValue(dictionary, clonedKey, anObject);
#else
	[m_poDict setObject: anObject forKey: clonedKey];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (void) removeAllObjects {
	[super removeAllObjects];
	[keyOrdering removeAllObjects];
}

- (void) removeObjectForKey:(id)aKey {
	[aKey retain];			/* CJEC, 27-May-15: Retain while we're using the object to prevent deallocation */
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	if (CFDictionaryContainsKey(dictionary, aKey)) {
#else
	if ([m_poDict objectForKey: aKey] != nil) {
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
		[super removeObjectForKey:aKey];
		[keyOrdering removeObject:aKey];
	}
	[aKey release];			/* CJEC, 27-May-15: Safe to deallocate now */
}

- (void) removeObjectForKeyAtIndex:(NSUInteger)index {
	id		aKey;
	// Note: -keyAtIndex: will raise an exception if the index is invalid.
	aKey = [self keyAtIndex:index];
	[aKey retain];			/* CJEC, 27-May-15: Retain while we're using the object to prevent deallocation */
	[super removeObjectForKey: aKey];
	[keyOrdering removeObjectAtIndex:index];
	[aKey release];			/* CJEC, 27-May-15: Safe to deallocate now */
}

- (void) removeObjectsForKeysAtIndexes:(NSIndexSet*)indexes {
	NSArray* keysToRemove = [keyOrdering objectsAtIndexes:indexes];
	[keyOrdering removeObjectsAtIndexes:indexes];
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	[(NSMutableDictionary*)dictionary removeObjectsForKeys:keysToRemove];
#else
	[m_poDict removeObjectsForKeys: keysToRemove];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (void) setObject:(id)anObject forKey:(id)aKey {
	[self insertObject:anObject forKey:aKey atIndex:[self count]];
}

- (void) setObject:(id)anObject forKeyAtIndex:(NSUInteger)index {
	[self insertObject:anObject forKey:[self keyAtIndex:index] atIndex:index];
}

@end

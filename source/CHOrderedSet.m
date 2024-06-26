/*
 CHDataStructures.framework -- CHOrderedSet.h
 
 Copyright (c) 2009-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2024	Kinnami Software Corporation. All rights reserved.
 */

#import "CHOrderedSet.h"
#import "CHCircularBuffer.h"

@implementation CHOrderedSet

- (void) dealloc {
	[ordering release];
	[super dealloc];
}

- (id) init {
	return [self initWithCapacity:0];
}

- (id) initWithCapacity:(NSUInteger)numItems {
	if ((self = [super initWithCapacity:numItems]) == nil) return nil;
	ordering = [[CHCircularBuffer alloc] initWithCapacity:numItems];
	return self;
}

#if defined (GNUSTEP)

/* GNUStep's -[NSMutableSet initWithObjects: count:] adds objects in
	reverse order, which is not very useful for an ordered set!
	See /GNUstep/libs-base/Source/NSSet.m: line 1078.
	So we have to reimplement it.
*/
- (id) initWithObjects: (const id []) objects count: (NSUInteger) count
{
	NSUInteger	uiCount;
	
	self = [self initWithCapacity: count];
	if (self != nil)
		{
		for (uiCount = 0; uiCount < count; uiCount ++)
			[self addObject: objects [uiCount]];
		}
	return self;
}

#endif	/* defined (GNUSTEP) */

#pragma mark Querying Contents

- (NSArray*) allObjects {
	return [ordering allObjects];
}

- (id) firstObject {
	return [ordering firstObject];
}

- (NSUInteger) hash {
	return [ordering hash];
}

- (NSUInteger) indexOfObject:(id)anObject {
	return [ordering indexOfObject:anObject];
}

- (BOOL) isEqualToOrderedSet:(CHOrderedSet*)otherOrderedSet {
	return collectionsAreEqual(self, otherOrderedSet);
}

- (id) lastObject {
	return [ordering lastObject];
}

- (id) objectAtIndex:(NSUInteger)index {
	return [ordering objectAtIndex:index];
}

- (NSEnumerator*) reverseObjectEnumerator {			/* CJEC, 15-Oct-14: Add missing reverse enumerator method */
	return [ordering reverseObjectEnumerator];
}

- (NSEnumerator*) objectEnumerator {
	return [ordering objectEnumerator];
}

- (NSArray*) objectsAtIndexes:(NSIndexSet*)indexes {
	if (indexes == nil)
		CHNilArgumentException([self class], _cmd);
	if ([indexes count] == 0)
		return [NSArray array];
	if ([indexes lastIndex] >= [self count])
		CHIndexOutOfRangeException([self class], _cmd, [indexes lastIndex], [self count]);
	NSMutableArray* objects = [NSMutableArray arrayWithCapacity:[self count]];
	NSUInteger index = [indexes firstIndex];
	while (index != NSNotFound) {
		[objects addObject:[self objectAtIndex:index]];
		index = [indexes indexGreaterThanIndex:index];
	}
	return objects;
}

- (CHOrderedSet*) orderedSetWithObjectsAtIndexes:(NSIndexSet*)indexes {
	if (indexes == nil)
		CHNilArgumentException([self class], _cmd);
	if ([indexes count] == 0)
		return [[self class] set];
	CHOrderedSet* newSet = [[self class] setWithCapacity:[indexes count]];
	NSUInteger index = [indexes firstIndex];
	while (index != NSNotFound) {
		[newSet addObject:[ordering objectAtIndex:index]];
		index = [indexes indexGreaterThanIndex:index];
	}
	return newSet;
}

#pragma mark Modifying Contents

- (void) addObject:(id)anObject {
	if (anObject == nil)
		CHNilArgumentException([self class], _cmd);
	if (![self containsObject:anObject])
		[ordering addObject:anObject];
	[super addObject:anObject];
}

- (void) exchangeObjectAtIndex:(NSUInteger)idx1 withObjectAtIndex:(NSUInteger)idx2 {
	[ordering exchangeObjectAtIndex:idx1 withObjectAtIndex:idx2];
}

- (void) insertObject:(id)anObject atIndex:(NSUInteger)index {
	if (index > [self count])
		CHIndexOutOfRangeException([self class], _cmd, index, [self count]);
	if ([self containsObject:anObject])
		[ordering removeObject:anObject];
	[ordering insertObject:anObject atIndex:index];
	[super addObject:anObject];
}

- (void) removeAllObjects {
	[super removeAllObjects];
	[ordering removeAllObjects];
}

- (void) removeFirstObject {
	[self removeObject:[ordering firstObject]];
}

- (void) removeLastObject {
	[self removeObject:[ordering lastObject]];
}

- (void) removeObject:(id)anObject {
	[anObject retain];			/* CJEC, 27-May-15: Retain while we're using the object to prevent deallocation */
	[super removeObject:anObject];
	[ordering removeObject:anObject];
	[anObject release];			/* CJEC, 27-May-15: Safe to deallocate now */
}

- (void) removeObjectAtIndex:(NSUInteger)index {
	id	anObject;
	
	anObject = [ordering objectAtIndex:index];
	[anObject retain];			/* CJEC, 27-May-15: Retain while we're using the object to prevent deallocation */
	[super removeObject: anObject];
	[ordering removeObjectAtIndex:index];
	[anObject release];			/* CJEC, 27-May-15: Safe to deallocate now */
}

- (void) removeObjectsAtIndexes:(NSIndexSet*)indexes {
	[(NSMutableSet*)set minusSet:[NSSet setWithArray:[self objectsAtIndexes:indexes]]];
	[ordering removeObjectsAtIndexes:indexes];
}

#pragma mark <NSFastEnumeration>

- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState*)state
                                   objects:(id*)stackbuf
                                     count:(NSUInteger)len
{
	return [ordering countByEnumeratingWithState:state objects:stackbuf count:len];
}

@end

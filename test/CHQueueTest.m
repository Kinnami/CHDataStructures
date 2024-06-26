/*
 CHDataStructures.framework -- CHQueueTest.m
 
 Copyright (c) 2008-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2024	Kinnami Software Corporation. All rights reserved.
 */

/* Note: This Unit Test Code relies on OS X/Darwin 10.10, Xcode 6.4 and the Xcode Test Framework.
			MacOS SDK must be 10.10, compiler must be Apple llvm/clang 6.1, set in the Xcode build
			target CHDataStructuresMacTests
*/

#import <XCTest/XCTest.h>
#import "CHCircularBufferQueue.h"
#import "CHListQueue.h"

@interface CHQueueTest : XCTestCase {
	id<CHQueue> queue;
	NSArray *objects, *queueClasses;
	NSEnumerator *e;
	id anObject;
}
@end

@implementation CHQueueTest

- (void) setUp {
	queueClasses = [NSArray arrayWithObjects:
					[CHListQueue class],
					[CHCircularBufferQueue class],
					nil];
	objects = [NSArray arrayWithObjects:@"A",@"B",@"C",nil];
}

- (void) testInitWithArray {
	NSMutableArray *moreObjects = [NSMutableArray array];
	for (NSUInteger i = 0; i < 32; i++)
		[moreObjects addObject:[NSNumber numberWithUnsignedInteger:i]];
	
	NSEnumerator *classes = [queueClasses objectEnumerator];
	Class aClass;
	while (aClass = [classes nextObject]) {
		// Test initializing with nil and empty array parameters
		queue = [[[aClass alloc] initWithArray:nil] autorelease];
		XCTAssertEqual([queue count], (NSUInteger)0);
		queue = [[[aClass alloc] initWithArray:[NSArray array]] autorelease];
		XCTAssertEqual([queue count], (NSUInteger)0);
		// Test initializing with a valid, non-empty array
		queue = [[[aClass alloc] initWithArray:objects] autorelease];
		XCTAssertEqual([queue count], [objects count]);
		XCTAssertEqualObjects([queue allObjects], objects);
		// Test initializing with an array larger than the default capacity
		queue = [[[aClass alloc] initWithArray:moreObjects] autorelease];
		XCTAssertEqual([queue count], [moreObjects count]);
		XCTAssertEqualObjects([queue allObjects], moreObjects);
	}
}

- (void) testIsEqualToQueue {
	NSMutableArray *emptyQueues = [NSMutableArray array];
	NSMutableArray *equalQueues = [NSMutableArray array];
	NSMutableArray *reversedQueues = [NSMutableArray array];
	NSArray *reversedObjects = [[objects reverseObjectEnumerator] allObjects];
	NSEnumerator *classes = [queueClasses objectEnumerator];
	Class aClass;
	while (aClass = [classes nextObject]) {
		[emptyQueues addObject:[[aClass alloc] init]];
		[equalQueues addObject:[[aClass alloc] initWithArray:objects]];
		[reversedQueues addObject:[[aClass alloc] initWithArray:reversedObjects]];
	}
	// Add a repeat of the first class to avoid wrapping.
	[equalQueues addObject:[equalQueues objectAtIndex:0]];
	
	id<CHQueue> queue1, queue2;
	for (NSUInteger i = 0; i < [queueClasses count]; i++) {
		queue1 = [equalQueues objectAtIndex:i];
		XCTAssertThrowsSpecificNamed([queue1 isEqualToQueue: (id <CHQueue>) [NSString string]], NSException, NSInvalidArgumentException);
		XCTAssertFalse([queue1 isEqual:[NSString string]]);
		XCTAssertEqualObjects(queue1, queue1);
		queue2 = [equalQueues objectAtIndex:i+1];
		XCTAssertEqualObjects(queue1, queue2);
		XCTAssertEqual([queue1 hash], [queue2 hash]);
		queue2 = [emptyQueues objectAtIndex:i];
		XCTAssertFalse([queue1 isEqual:queue2]);
		queue2 = [reversedQueues objectAtIndex:i];
		XCTAssertFalse([queue1 isEqual:queue2]);
	}
}

- (void) testAddObject {
	NSEnumerator *classes = [queueClasses objectEnumerator];
	Class aClass;
	while (aClass = [classes nextObject]) {
		queue = [[[aClass alloc] init] autorelease];
		// Test that adding a nil parameter raises an exception
		XCTAssertThrows([queue addObject:nil]);
		XCTAssertEqual([queue count], (NSUInteger)0);
		// Test adding objects one by one and verify count and ordering
		e = [objects objectEnumerator];
		while (anObject = [e nextObject])
			[queue addObject:anObject];
		XCTAssertEqual([queue count], [objects count]);
		XCTAssertEqualObjects([queue allObjects], objects);
	}
}

- (void) testRemoveFirstObject {
	NSEnumerator *classes = [queueClasses objectEnumerator];
	Class aClass;
	while (aClass = [classes nextObject]) {
		queue = [[[aClass alloc] init] autorelease];
		e = [objects objectEnumerator];
		while (anObject = [e nextObject]) {
			[queue addObject:anObject];
			XCTAssertEqualObjects([queue lastObject], anObject);
		}
		NSUInteger expected = [objects count];
		XCTAssertEqual([queue count], expected);
		XCTAssertEqualObjects([queue firstObject], @"A");
		XCTAssertEqualObjects([queue lastObject],  @"C");
		[queue removeFirstObject];
		--expected;
		XCTAssertEqual([queue count], expected);
		XCTAssertEqualObjects([queue firstObject], @"B");
		XCTAssertEqualObjects([queue lastObject],  @"C");
		[queue removeFirstObject];
		--expected;
		XCTAssertEqual([queue count], expected);
		XCTAssertEqualObjects([queue firstObject], @"C");
		XCTAssertEqualObjects([queue lastObject],  @"C");
		[queue removeFirstObject];
		--expected;
		XCTAssertEqual([queue count], expected);
		XCTAssertNil([queue firstObject]);
		XCTAssertNil([queue lastObject]);
		XCTAssertNoThrow([queue removeFirstObject]);
		XCTAssertEqual([queue count], expected);
		XCTAssertNil([queue firstObject]);
		XCTAssertNil([queue lastObject]);
	}
}

@end

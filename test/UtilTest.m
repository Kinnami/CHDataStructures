/*
 CHDataStructures.framework -- UtilTest.m
 
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
#import "Util.h"

@interface UtilTest : XCTestCase {
	Class aClass;
	SEL aMethod;
	NSMutableString *reason;
	BOOL raisedException;
}

@end

@implementation UtilTest

- (void) setUp {
	aClass = [NSObject class];
	aMethod = @selector(foo:bar:);
	reason = [NSMutableString stringWithString:@"[NSObject foo:bar:] -- "];
	raisedException = NO;
}

- (void) testCollectionsAreEqual {
	NSArray *array = [NSArray arrayWithObjects:@"A",@"B",@"C",nil];
	NSDictionary *dict = [NSDictionary dictionaryWithObjects:array forKeys:array];
	NSSet *set = [NSSet setWithObjects:@"A",@"B",@"C",nil];
	
	XCTAssertTrue(collectionsAreEqual(nil, nil));
	
	XCTAssertTrue(collectionsAreEqual(array, array));
	XCTAssertTrue(collectionsAreEqual(dict, dict));
	XCTAssertTrue(collectionsAreEqual(set, set));

	XCTAssertTrue(collectionsAreEqual(array, [array copy]));
	XCTAssertTrue(collectionsAreEqual(dict, [dict copy]));
	XCTAssertTrue(collectionsAreEqual(set, [set copy]));
	
	XCTAssertFalse(collectionsAreEqual(array, nil));
	XCTAssertFalse(collectionsAreEqual(dict, nil));
	XCTAssertFalse(collectionsAreEqual(set, nil));

	id obj = [NSString string];
	XCTAssertThrowsSpecificNamed(collectionsAreEqual(array, obj), NSException, NSInvalidArgumentException);
	XCTAssertThrowsSpecificNamed(collectionsAreEqual(dict, obj), NSException, NSInvalidArgumentException);
	XCTAssertThrowsSpecificNamed(collectionsAreEqual(set, obj), NSException, NSInvalidArgumentException);
}

- (void) testIndexOutOfRangeException {
	@try {
		CHIndexOutOfRangeException(aClass, aMethod, 4, 4);
	}
	@catch (NSException * e) {
		raisedException = YES;
		XCTAssertEqualObjects([e name], NSRangeException);
		[reason appendString:@"Index (4) beyond bounds for count (4)"];
		XCTAssertEqualObjects([e reason], reason);
	}
	XCTAssertTrue(raisedException);
}

- (void) testInvalidArgumentException {
	@try {
		CHInvalidArgumentException(aClass, aMethod, @"Some silly reason.");
	}
	@catch (NSException * e) {
		raisedException = YES;
		XCTAssertEqualObjects([e name], NSInvalidArgumentException);
		[reason appendString:@"Some silly reason."];
		XCTAssertEqualObjects([e reason], reason);
	}
	XCTAssertTrue(raisedException);
}

- (void) testNilArgumentException {
	@try {
		CHNilArgumentException(aClass, aMethod);
	}
	@catch (NSException * e) {
		raisedException = YES;
		XCTAssertEqualObjects([e name], NSInvalidArgumentException);
		[reason appendString:@"Invalid nil argument"];
		XCTAssertEqualObjects([e reason], reason);
	}
	XCTAssertTrue(raisedException);
}

- (void) testMutatedCollectionException {
	@try {
		CHMutatedCollectionException(aClass, aMethod);
	}
	@catch (NSException * e) {
		raisedException = YES;
		XCTAssertEqualObjects([e name], NSGenericException);
		[reason appendString:@"Collection was mutated during enumeration"];
		XCTAssertEqualObjects([e reason], reason);
	}
	XCTAssertTrue(raisedException);
}

- (void) testUnsupportedOperationException {
	@try {
		CHUnsupportedOperationException(aClass, aMethod);
	}
	@catch (NSException * e) {
		raisedException = YES;
		XCTAssertEqualObjects([e name], NSInternalInconsistencyException);
		[reason appendString:@"Unsupported operation"];
		XCTAssertEqualObjects([e reason], reason);
	}
	XCTAssertTrue(raisedException);
}

- (void) testCHQuietLog {
	// Can't think of a way to verify stdout, so I'll just exercise all the code
	CHQuietLog(@"Hello, world!");
	CHQuietLog(@"Hello, world! I accept specifiers: %@ instance at 0x%x.",
			   [self class], self);
	CHQuietLog(nil);
}

@end

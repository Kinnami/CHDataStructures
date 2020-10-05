/*
 CHDataStructures.framework -- CHMutableDictionary.h
 
 Copyright (c) 2009-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2020	Kinnami Software Corporation. All rights reserved.
 */

#import "Util.h"

HIDDEN void createCollectableCFMutableDictionary(CFMutableDictionaryRef* dictionary, NSUInteger initialCapacity);

/**
 @file CHMutableDictionary.h
 
 A mutable dictionary class.
 */

/**
 A mutable dictionary class.
 
 A CFMutableDictionaryRef is used internally to store the key-value pairs. Subclasses may choose to add other instance variables to enable a specific ordering of keys, override methods to modify behavior, and add methods to extend existing behaviors. However, all subclasses should behave like a standard Cocoa dictionary as much as possible, and document clearly when they do not.
 
 @note Any method inherited from NSDictionary or NSMutableDictionary is supported by this class and its children. Please see the documentation for those classes for details.
 
 @todo Implement @c -copy and @c -mutableCopy differently (so users can actually obtain an immutable copy) and make mutation methods aware of immutability?
 */
@interface CHMutableDictionary : NSMutableDictionary {
	CFMutableDictionaryRef dictionary; // A Core Foundation dictionary.
}

- (id) initWithCapacity:(NSUInteger)numItems;

- (NSUInteger) count;
- (NSEnumerator*) keyEnumerator;
- (id) objectForKey:(id)aKey;
- (void) removeAllObjects;
- (void) removeObjectForKey:(id)aKey;
- (void) setObject:(id)anObject forKey:(id)aKey;

@end

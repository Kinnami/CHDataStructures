/*
 CHDataStructures.framework -- CHMultiOrderedDictionary.h

 CHMultiOrderedDictionary is very heavily based on CHMultiDictionary. Modifications to support the ordering were made by Christopher James Elphinstone Chandler
 
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2024	Kinnami Software Corporation. All Rights Reserved.

 CHMultiDictionary:

 Copyright (c) 2008-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.
 */

#import "CHMutableDictionary.h"
#import "CHOrderedSet.h"

/**
 @file CHMultiOrderedDictionary.h
 
 A <a href="http://en.wikipedia.org/wiki/Multimap_(data_structure)">multimap</a> in which multiple values may be associated with a given key.
 */

/**
 A <a href="http://en.wikipedia.org/wiki/Multimap_(data_structure)">multimap</a> implementation, in which multiple values may be associated with a given key.
 
 A map is the same as a "dictionary", "associative array", etc. and consists of a unique ordered set of keys and a collection of values. In a standard map, each key is associated with one value; in a multimap, more than one value may be associated with a given key. A multimap is appropriate for any situation in which one item may correspond to (map to) multiple values, such as a term in an book index and occurrences of that term, courses for which a student is registered, etc.
 
 The values for a key are ordered. Unlike CHMultiDictionary, this implementation maintains the insertion ordering for objects associated with a key. Like CHMultiDictionary, it does not allow for multiple occurrences of an object associated with the same key. Internally, this class uses an NSMutableDictionary, and the associated values for each key are stored in distinct CHOrderedSet instances. (Just as with NSDictionary, each key added to a CHMultiOrderedDictionary is copied using \link NSCopying#copyWithZone: -copyWithZone:\endlink and all keys must conform to the NSCopying protocol.) Objects are retained on insertion and released on removal or deallocation.
 
 Since NSDictionary and CHOrderedSet conform to the NSCoding protocol, any internal data can be serialized. Unlike CHMultiDictionary, CHOrderedSet can automatically be written to or read from a property list, since it has a specified order. Thus, instances of CHMultiOrderedDictionary do not have to be encoded as an NSData object before saving to disk.
 
 Currently, this implementation does not support key-value coding, observing, or binding like NSDictionary does. Consequently, the distinction between "object" and "value" is blurrier, although hopefully consistent with the Cocoa APIs in general....
 
 Unlike NSDictionary and other Cocoa collections, CHMultiOrderedDictionary has not been designed with mutable and immutable variants. A multimap is not that much more useful if it is immutable, so any copies made of this class are mutable by definition.
 
 @todo CJEC, 30-Jan-14: This is bare-bones implementation, that preserves the insertion ordering that we need for BoxOS. It should be extended with methods to manipulate and take advantage of the ordering directly
 */
@interface CHMultiOrderedDictionary : CHMutableDictionary {
	NSUInteger objectCount; // Number of objects currently in the dictionary.
}

#pragma mark Querying Contents

/**
 Returns the number of objects in the receiver, associated with any key.
 
 @return The number of objects in the receiver. This is the sum total of objects associated with each key in the dictonary.
 
 @see allObjects
 */
- (NSUInteger) countForAllKeys;

/**
 Returns the number of objects associated with a given key.
 
 @param aKey The key for which to return the object count.
 @return The number of objects associated with a given key in the dictionary.
 
 @see objectsForKey:
 */
- (NSUInteger) countForKey:(id)aKey;

/**
 Returns an array of objects associated with a given key.
 
 @param aKey The key for which to return the corresponding objects.
 @return An CHOrderedSet of objects associated with a given key, or nil if the key is not in the receiver.
 
 @see countForKey:
 @see removeObjectsForKey:
 */
- (CHOrderedSet*) objectsForKey:(id)aKey;

#pragma mark Modifying Contents

/**
 Adds a given object to an entry for a given key in the receiver.
 
 @param aKey The key with which to associate @a anObject.
 @param anObject An object to add to an entry for @a aKey in the receiver. If an entry for @a aKey already exists in the receiver, @a anObject is added using \link CHOrderedSet#addObject: -[CHOrderedSet addObject:]\endlink, otherwise a new entry is created.
 
 @throw NSInvalidArgumentException if @a aKey or @a anObject is @c nil.
 
 @see addObjects:forKey:
 @see objectsForKey:
 @see removeObjectsForKey:
 @see setObjects:forKey:
 */
- (void) addObject:(id)anObject forKey:(id)aKey;

/**
 Adds the given object(s) to a key entry in the receiver.
 
 @param aKey The key with which to associate @a anObject.
 @param objectSet An ordered set of objects to add to an entry for @a aKey in the receiver. If an entry for @a aKey already exists in the receiver, @a anObject is added using \link CHOrderedSet#unionSet: -[CHOrderedSet unionSet:]\endlink, otherwise a new entry is created.
 
 @throw NSInvalidArgumentException if @a aKey or @a objectSet is @c nil.
 
 @see addObject:forKey:
 @see objectsForKey:
 @see removeObjectsForKey:
 @see setObjects:forKey:
 */
- (void) addObjects:(CHOrderedSet*)objectSet forKey:(id)aKey;

/**
 Remove @b all occurrences of @a anObject associated with a given key.
 
 @param aKey The key for which to remove an entry.
 @param anObject An object (possibly) associated with @a aKey in the receiver. Objects are considered to be equal if -compare: returns NSOrderedSame.
 
 @throw NSInvalidArgumentException if @a aKey or @a anObject is @c nil.
 
 If @a aKey does not exist in the receiver, or if @a anObject is not associated with @a aKey, the contents of the receiver are not modified.
 
 @see containsObject
 @see objectsForKey:
 @see removeObjectsForKey:
 */
- (void) removeObject:(id)anObject forKey:(id)aKey;

/**
 Remove a given key and its associated value(s) from the receiver.
 
 @param aKey The key for which to remove an entry.
 
 If @a aKey does not exist in the receiver, there is no effect on the receiver.
 
 @see objectsForKey:
 @see removeObject:forKey:
 */
- (void) removeObjectsForKey:(id)aKey;

/**
 Sets the object(s) associated with a key entry in the receiver.
 
 @param aKey The key with which to associate the objects in @a objectSet.
 @param objectSet An ordered set of objects to associate with @a key. If @a objectSet is empty, the contents of the receiver are not modified. If an entry for @a key already exists in the receiver, @a objectSet is added using \link CHOrderedSet#setSet: -[CHOrderedSet setSet:]\endlink, otherwise a new entry is created.
 
 @throw NSInvalidArgumentException if @a aKey or @a objectSet is @c nil.
 
 @see addObject:forKey:
 @see addObjects:forKey:
 @see objectsForKey:
 @see removeObjectsForKey:
 */
- (void) setObjects:(CHOrderedSet*)objectSet forKey:(id)aKey;

@end

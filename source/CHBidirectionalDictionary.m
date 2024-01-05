/*
 CHDataStructures.framework -- CHBidirectionalDictionary.m
 
 Copyright (c) 2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2023	Kinnami Software Corporation. All rights reserved.
 */

#import "CHBidirectionalDictionary.h"

@implementation CHBidirectionalDictionary

// This macro is used as an alias for the 'dictionary'/'m_poDict' ivar in the parent class.
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
#define keysToObjects dictionary
#else
#define m_poDictKeysToObjects 	m_poDict
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */

- (void) dealloc {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	if (inverse != nil)
		inverse->inverse = nil; // Unlink from inverse dictionary if one exists.
	NSAssert (objectsToKeys != NULL, @"Invalid reverse dictionary IN %p (class %@)", self, [self class]);
	CFRelease(objectsToKeys); // The dictionary can never be null at this point.
#else
	if (m_poBDictInverse != nil)
		m_poBDictInverse -> m_poBDictInverse = nil; // Unlink from inverse dictionary if one exists.
	NSAssert (m_poDictObjectsToKeys != nil, @"Invalid reverse dictionary IN %p (class %@)", self, [self class]);
	[m_poDictObjectsToKeys release];
	m_poDictObjectsToKeys = nil;
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
	[super dealloc];
}

- (id) initWithCapacity:(NSUInteger)numItems {
	if ((self = [super initWithCapacity:numItems]) == nil) return nil;
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	createCollectableCFMutableDictionary(&objectsToKeys, numItems);
	NSAssert (objectsToKeys != NULL, @"Could not create reverse dictionary IN %p (class %@)", self, [self class]);
	if (objectsToKeys == NULL)
#else
	m_poDictObjectsToKeys = [[NSMutableDictionary alloc] initWithCapacity: numItems];
	NSAssert (m_poDictObjectsToKeys != nil, @"Could not create reverse dictionary IN %p (class %@)", self, [self class]);
	if (m_poDictObjectsToKeys == nil)
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
		{
		[self release];
		self = nil;
		}
	return self;
}

#pragma mark Querying Contents

/** @todo Determine the proper ownership/lifetime of the inverse dictionary. */
- (CHBidirectionalDictionary*) inverseDictionary {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	if (inverse == nil) {
		// Create a new instance of this class to represent the inverse mapping
		inverse = [[CHBidirectionalDictionary alloc] init];
		// Release the CFMutableDictionary -init creates so we don't leak memory
		CFRelease(inverse->dictionary);
		// Set its dictionary references to the reverse of what they are here
		// (NOTE: CFMakeCollectable() works under GC, and is a no-op otherwise.)
		CFMakeCollectable(CFRetain(inverse->keysToObjects = objectsToKeys));
		CFMakeCollectable(CFRetain(inverse->objectsToKeys = keysToObjects));
		// Set this instance as the mutual inverse of the newly-created instance 
		inverse->inverse = self;
	}
	return inverse;
#else
	if (m_poBDictInverse == nil) {
		// Create a new instance of this class to represent the inverse mapping
		m_poBDictInverse = [[CHBidirectionalDictionary alloc] init];
		// Release the CFMutableDictionary -init creates so we don't leak memory
		[m_poBDictInverse -> m_poDict release];
		// Set its dictionary references to the reverse of what they are here
		m_poBDictInverse -> m_poDictKeysToObjects = m_poDictObjectsToKeys;
		[m_poBDictInverse -> m_poDictKeysToObjects retain];
		m_poBDictInverse -> m_poDictObjectsToKeys = m_poDictKeysToObjects;
		[m_poBDictInverse -> m_poDictObjectsToKeys retain];
		// Set this instance as the mutual inverse of the newly-created instance
		m_poBDictInverse -> m_poBDictInverse = self;
	}
	return m_poBDictInverse;
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (id) keyForObject:(id)anObject {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	return (id)CFDictionaryGetValue(objectsToKeys, anObject);
#else
	return [m_poDictObjectsToKeys objectForKey: anObject];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (NSEnumerator*) objectEnumerator {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	return [(id)objectsToKeys keyEnumerator];
#else
	return [m_poDictObjectsToKeys keyEnumerator];
#endif	/* #if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
 */
}

#pragma mark Modifying Contents

- (void) addEntriesFromDictionary:(NSDictionary*)otherDictionary {
	[super addEntriesFromDictionary:otherDictionary];
}

- (void) removeAllObjects {
	[super removeAllObjects];
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	CFDictionaryRemoveAllValues(objectsToKeys);
#else
	[m_poDictObjectsToKeys removeAllObjects];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (void) removeKeyForObject:(id)anObject {
	[super removeObjectForKey:[self keyForObject:anObject]];
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	CFDictionaryRemoveValue(objectsToKeys, anObject);
#else
	[m_poDictObjectsToKeys removeObjectForKey: anObject];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (void) removeObjectForKey:(id)aKey {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	CFDictionaryRemoveValue(objectsToKeys, [self objectForKey:aKey]);
#else
	[m_poDictObjectsToKeys removeObjectForKey: aKey];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
	[super removeObjectForKey:aKey];
}

- (void) setObject:(id)anObject forKey:(id)aKey {
	if (anObject == nil || aKey == nil)
		CHNilArgumentException([self class], _cmd);
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	// Remove existing mappings for aKey and anObject if they currently exist.
	CFDictionaryRemoveValue(keysToObjects, CFDictionaryGetValue(objectsToKeys, anObject));
	CFDictionaryRemoveValue(objectsToKeys, CFDictionaryGetValue(keysToObjects, aKey));
	aKey = [[aKey copy] autorelease];
	anObject = [[anObject copy] autorelease];
	CFDictionarySetValue(keysToObjects, aKey, anObject); // May replace key-value pair
	CFDictionarySetValue(objectsToKeys, anObject, aKey); // May replace value-key pair
#else
	// Remove existing mappings for aKey and anObject if they currently exist.
	id	poKeyObject;
	id	poObjectKey;
	
	poKeyObject = [m_poDictObjectsToKeys objectForKey: anObject];
	if (poKeyObject != nil)
		[m_poDictKeysToObjects removeObjectForKey: poKeyObject];
	poObjectKey = [m_poDictKeysToObjects objectForKey: aKey];
	if (poObjectKey != nil)
		[m_poDictObjectsToKeys removeObjectForKey: poObjectKey];
	aKey = [[aKey copy] autorelease];
	anObject = [[anObject copy] autorelease];
	[m_poDictKeysToObjects setObject: anObject forKey: aKey];	 // May replace key-value pair
	[m_poDictObjectsToKeys setObject: aKey forKey: anObject];	// May replace value-key pair
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

@end

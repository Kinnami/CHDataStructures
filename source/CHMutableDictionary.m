/*
 CHDataStructures.framework -- CHMutableDictionary.m
 
 Copyright (c) 2009-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2020	Kinnami Software Corporation. All rights reserved.
 */

#import "CHMutableDictionary.h"

/*****************************************************************************/
/*	DEBUG: Define this to log all "dealloc IN" messages for debugging memory
			management
*/
// #define DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN		1

#pragma mark CFDictionary callbacks

const void* CHDictionaryRetain(CFAllocatorRef allocator, const void *value) {
	(void) allocator;				/* CJEC, 3-Jul-13: Avoid unused parameter compiler warning */
	return [(id)value retain];
}

void CHDictionaryRelease(CFAllocatorRef allocator, const void *value) {
	(void) allocator;				/* CJEC, 3-Jul-13: Avoid unused parameter compiler warning */
	[(id)value release];
}

CFStringRef CHDictionaryCopyDescription(const void *value) {
	return (CFStringRef)[[(id)value description] copy];
}

Boolean CHDictionaryEqual(const void *value1, const void *value2) {
	return [(id)value1 isEqual:(id)value2];
}

CFHashCode CHDictionaryHash(const void *value) {
	return (CFHashCode)[(id)value hash];
}

static const CFDictionaryKeyCallBacks kCHDictionaryKeyCallBacks = {
	0, // default version
	CHDictionaryRetain,
	CHDictionaryRelease,
	CHDictionaryCopyDescription,
	CHDictionaryEqual,
	CHDictionaryHash
};

static const CFDictionaryValueCallBacks kCHDictionaryValueCallBacks = {
	0, // default version
	CHDictionaryRetain,
	CHDictionaryRelease,
	CHDictionaryCopyDescription,
	CHDictionaryEqual
};

HIDDEN void createCollectableCFMutableDictionary(CFMutableDictionaryRef* dictionary, NSUInteger initialCapacity)
{
	// Create a CFMutableDictionaryRef with callback functions as defined above.
	*dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault,
	                                       initialCapacity,
	                                       &kCHDictionaryKeyCallBacks,
	                                       &kCHDictionaryValueCallBacks);
}

#pragma mark -

@implementation CHMutableDictionary

- (void) dealloc {
#if defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN)
	NSLog (@"dealloc IN %p (class %@)", self, [self class]);
#endif	/* defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN) */
	NSAssert (dictionary != NULL, @"Invalid dictionary IN %p (class %@)", self, [self class]);
	CFRelease(dictionary); // The dictionary will never be null at this point.
	[super dealloc];
}

// Note: Defined here since -init is not implemented in NS(Mutable)Dictionary.
- (id) init {
	return [self initWithCapacity:0]; // The 0 means we provide no capacity hint
}

// Note: This is the designated initializer for NSMutableDictionary and this class.
// Subclasses may override this as necessary, but must call back here first.
- (id) initWithCapacity:(NSUInteger)numItems {
	if ((self = [super init]) == nil) return nil;
	createCollectableCFMutableDictionary(&dictionary, numItems);
	NSAssert (dictionary != NULL, @"Could not create dictionary IN %p (class %@)", self, [self class]);
	if (dictionary == NULL)
		{
		[self release];
		self = nil;
		}
#if defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN)
	else
		NSLog (@"Created dictionary %p IN %p (class %@)", dictionary, self, [self class]);
#endif	/* defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN) */
	return self;
}

// Ovverridden to ensure that this object's dictionary member is initialised
//	even when the argument is empty.
// Note: Disable the compiler warning "convenience initializer should not invoke an initializer on 'super'"
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wobjc-designated-initializers"
- (id)	initWithDictionary: (NSDictionary *) a_poDict
	{
	if ([a_poDict count] == 0)			/* GNUstep's -[NSDictionary initWithDictionary:] does not call the default initialiser if the argument is empty */
		self = [self init];
	else
		self = [super initWithDictionary: a_poDict];
	return self;
	}
#pragma GCC diagnostic pop

#pragma mark <NSCoding>

// Overridden from NSMutableDictionary to encode/decode as the proper class.
- (Class) classForKeyedArchiver {
	return [self class];
}

- (id) initWithCoder:(NSCoder*)decoder {
	NSDictionary *	poDict;
	
	if ([decoder allowsKeyedCoding])
		poDict = [decoder decodeObjectForKey: @"dictionary"];
	else
		poDict = [decoder decodeObject];
	NSAssert (poDict != nil, @"Could not decode dictionary using coder %@ IN %p (class %@)", decoder, self, [self class]);
	if (poDict == nil)
		{
		[self release];
		self = nil;
		}
	else
		{
		self = [self initWithDictionary: poDict];
		NSAssert (self != nil, @"Could not initialise CHMutableDictionary using dictionary %@ IN %p (class %@)", poDict, self, [self class]);
		NSAssert (dictionary != NULL, @"Could not create dictionary IN %p (class %@)", self, [self class]);
		}
#if defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN)
	if (self != nil)
		NSLog (@"Created dictionary %p IN %p (class %@)", dictionary, self, [self class]);
#endif	/* defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN) */
	return self;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
	if ([encoder allowsKeyedCoding])
		[encoder encodeObject: (id) dictionary forKey:@"dictionary"];
	else
		[encoder encodeObject: (id) dictionary];
}

#pragma mark <NSCopying>

- (id) copyWithZone:(NSZone*) zone {
	// We could use -initWithDictionary: here, but it would just use more memory.
	// (It marshals key-value pairs into two id* arrays, then inits from those.)
	CHMutableDictionary *copy = [[[self class] allocWithZone:zone] init];
	[copy addEntriesFromDictionary:self];
#if defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN)
	NSLog (@"Created dictionary %p copy IN %p (class %@)", copy, self, [self class]);
#endif	/* defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN) */
	return copy;
}

#pragma mark <NSFastEnumeration>

- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState*)state
                                   objects:(id*)stackbuf
                                     count:(NSUInteger)len
{
	return [super countByEnumeratingWithState:state objects:stackbuf count:len];
}

#pragma mark Querying Contents

- (NSUInteger) count {
	return CFDictionaryGetCount(dictionary);
}

- (NSString *) description
	{
	NSString *	poszDescription;
	
	poszDescription = [NSString stringWithFormat: @"<<%@: %p>(%lu): dictionary %p>", [self class], self, (unsigned long) [self retainCount], dictionary];
	return poszDescription;
	}

- (NSString*) debugDescription {
	CFStringRef description = CFCopyDescription(dictionary);
	CFRelease([(id)description retain]);
	return [(id)description autorelease];
}

- (NSEnumerator*) keyEnumerator {
	return [(id)dictionary keyEnumerator];
}

- (NSEnumerator*) objectEnumerator {
	return [(id)dictionary objectEnumerator];
}

- (id) objectForKey:(id)aKey {
	return (id)CFDictionaryGetValue(dictionary, aKey);
}

#pragma mark Modifying Contents

- (void) removeAllObjects {
	CFDictionaryRemoveAllValues(dictionary);
}

- (void) removeObjectForKey:(id)aKey {
	CFDictionaryRemoveValue(dictionary, aKey);
}

- (void) setObject:(id)anObject forKey:(id)aKey {
	if (anObject == nil || aKey == nil)
		CHNilArgumentException([self class], _cmd);
	CFDictionarySetValue(dictionary, [[aKey copy] autorelease], anObject);
}

@end

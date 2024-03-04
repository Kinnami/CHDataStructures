/*
 CHDataStructures.framework -- CHMutableDictionary.m
 
 Copyright (c) 2009-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2024	Kinnami Software Corporation. All rights reserved.
 */

#import "CHMutableDictionary.h"

/*****************************************************************************/
/*	DEBUG: Define this to log all "dealloc IN" messages for debugging memory
			management
*/
// #define DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN		1

#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
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
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */

#pragma mark -

@implementation CHMutableDictionary

- (void) dealloc {
#if defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN)
	NSLog (@"dealloc IN %p (class %@)", self, [self class]);
#endif	/* defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN) */

#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	NSAssert (dictionary != NULL, @"Invalid dictionary IN %p (class %@)", self, [self class]);
	CFRelease(dictionary); // The dictionary will never be null at this point.
#else
	NSAssert (m_poDict != nil, @"Invalid dictionary IN %p (class %@)", self, [self class]);
	[m_poDict release];
	m_poDict = nil;
#endif	/* CHMUTABLEDICTIONARY_USING_COREFOUNDATION */
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

#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
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
#else
	m_poDict = [[NSMutableDictionary alloc] initWithCapacity: numItems];
	NSAssert (m_poDict != nil, @"Could not create dictionary IN %p (class %@)", self, [self class]);
	if (m_poDict == nil)
		{
		[self release];
		self = nil;
		}
#if defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN)
	else
		NSLog (@"Created dictionary %p IN %p (class %@)", m_poDict, self, [self class]);
#endif	/* defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN) */
	
#endif	/* defiend (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
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
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
		NSAssert (dictionary != NULL, @"Could not create dictionary IN %p (class %@)", self, [self class]);
#else
		NSAssert (m_poDict != nil, @"Could not create dictionary IN %p (class %@)", self, [self class]);
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
		}
#if defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN)
	if (self != nil)
#if defined (defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION))
		NSLog (@"Created dictionary %p IN %p (class %@)", dictionary, self, [self class]);
#else
		NSLog (@"Created dictionary %p IN %p (class %@)", m_poDict, self, [self class]);
#endif	/* defined (defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
#endif	/* defined (DEBUG_CHMUTABLEDICTIONARY_LOG_DEALLOCIN) */
	return self;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	if ([encoder allowsKeyedCoding])
		[encoder encodeObject: (id) dictionary forKey:@"dictionary"];
	else
		[encoder encodeObject: (id) dictionary];
#else
	if ([encoder allowsKeyedCoding])
		[encoder encodeObject: m_poDict forKey:@"dictionary"];
	else
		[encoder encodeObject: m_poDict];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
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
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	// Note: GNUstep's NSMutableDictionary and NSDictionary classes do not provide
	//			an implementation for this method. Instead, those classes designate
	//			the method as the subclass's responsibility to implement, and throw
	//			an exception.
	//
#if defined (GNUSTEP)
	return [super countByEnumeratingWithState:state objects:stackbuf count:len];
#else
	(void) state;												/* Avoid unused parameter compiler warning */
	(void) stackbuf;											/* Avoid unused parameter compiler warning */
	(void) len;													/* Avoid unused parameter compiler warning */
	
	CHUnsupportedOperationException ([self class], _cmd);		/* Raise an exception on Apple platforms as well to be bug-for-bug compatible with GNUstep until fast enumeration works on GNUstep */
	return 0;
#endif	/* defined (GNUSTEP) */
#else
	return [m_poDict countByEnumeratingWithState: state objects: stackbuf count: len];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

#pragma mark Querying Contents

- (NSUInteger) count {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	return CFDictionaryGetCount(dictionary);
#else
	return [m_poDict count];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (NSString *) description
	{
	NSString *	poszDescription;

#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	poszDescription = [NSString stringWithFormat: @"<<%@: %p>(%lu): dictionary %p>", [self class], self, (unsigned long) [self retainCount], dictionary];
#else
	poszDescription = [NSString stringWithFormat: @"<<%@: %p>(%lu): dictionary %@>", [self class], self, (unsigned long) [self retainCount], m_poDict];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
	return poszDescription;
	}

- (NSString*) debugDescription {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	CFStringRef description = CFCopyDescription(dictionary);
	CFRelease([(id)description retain]);
	return [(id)description autorelease];
#else
	return [self description];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (NSEnumerator*) keyEnumerator {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	return [(id)dictionary keyEnumerator];
#else
	return [m_poDict keyEnumerator];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (NSEnumerator*) objectEnumerator {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	return [(id)dictionary objectEnumerator];
#else
	return [m_poDict objectEnumerator];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (id) objectForKey:(id)aKey {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	return (id)CFDictionaryGetValue(dictionary, aKey);
#else
	return [m_poDict objectForKey: aKey];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

#pragma mark Modifying Contents

- (void) removeAllObjects {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	CFDictionaryRemoveAllValues(dictionary);
#else
	[m_poDict removeAllObjects];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (void) removeObjectForKey:(id)aKey {
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	CFDictionaryRemoveValue(dictionary, aKey);
#else
	[m_poDict removeObjectForKey: aKey];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

- (void) setObject:(id)anObject forKey:(id)aKey {
	if (anObject == nil || aKey == nil)
		CHNilArgumentException([self class], _cmd);
#if defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION)
	CFDictionarySetValue(dictionary, [[aKey copy] autorelease], anObject);
#else
	[m_poDict setValue: anObject forKey: [[aKey copy] autorelease]];
#endif	/* defined (CHMUTABLEDICTIONARY_USING_COREFOUNDATION) */
}

@end

/*
 CHDataStructures.framework -- CHAbstractBinarySearchTree.m
 
 Copyright (c) 2008-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2022	Kinnami Software Corporation. All rights reserved.
 */

#import "CHAbstractBinarySearchTree.h"
#import "CHAbstractBinarySearchTree_Internal.h"

// Definitions of extern variables from CHAbstractBinarySearchTree_Internal.h
size_t kCHBinaryTreeNodeSize = sizeof(CHBinaryTreeNode);

/**
 A dummy object that resides in the header node for a tree. Using a header node can simplify insertion logic by eliminating the need to check whether the root is null. The actual root of the tree is generally stored as the right child of the header node. In order to always proceed to the actual root node when traversing down the tree, instances of this class always return @c NSOrderedAscending when called as the receiver of the @c -compare: method.
 
 Since all header objects behave the same way, all search tree instances can share the same dummy header object. The singleton instance can be obtained via the \link #object +object\endlink method. The singleton is created once and persists for the duration of the program. Any calls to @c -retain, @c -release, or @c -autorelease will raise an exception. (Note: If garbage collection is enabled, any such calls are likely to be ignored or "optimized out" by the compiler before the object can respond anyway.)
 */
@interface CHSearchTreeHeaderObject : NSObject

/**
 Returns the singleton instance of this class. The singleton variable is defined in this file and is initialized only once.
 
 @return The singleton instance of this class.
 */
+ (id) object;

/**
 Always indicate that another given object should appear to the right side.
 
 @param otherObject The object to be compared to the receiver.
 @return @c NSOrderedAscending, indicating that traversal should go to the right child of the containing tree node.
 
 @warning The header object @b must be the receiver of the message (e.g. <code>[headerObject compare:anObject]</code>) in order to work correctly. Calling <code>[anObject compare:headerObject]</code> instead will almost certainly result in a crash.
 */
- (NSComparisonResult) compare:(id)otherObject;

@end

// Static variable for storing singleton instance of search tree header object.
static CHSearchTreeHeaderObject *headerObject = nil;

@implementation CHSearchTreeHeaderObject

+ (id) object {
	// Protecting the @synchronized block prevents unnecessary lock contention.
	if (headerObject == nil) {
		@synchronized([CHSearchTreeHeaderObject class]) {
			// Make sure the object wasn't created since we blocked on the lock.
			if (headerObject == nil) {
				headerObject = [[CHSearchTreeHeaderObject alloc] init];
			}
		}		
	}
	return headerObject;
}

- (NSComparisonResult) compare:(id)otherObject {
	(void) otherObject;				/* CJEC, 3-Jul-13: Avoid unused parameter compiler warning */
	return NSOrderedAscending;
}

- (id) retain {
	CHUnsupportedOperationException([self class], _cmd); return nil;
}

- (oneway void) release {
	CHUnsupportedOperationException([self class], _cmd);
}

- (id) autorelease {
	CHUnsupportedOperationException([self class], _cmd); return nil;
}

@end

#pragma mark -

/**
 An NSEnumerator for traversing any CHAbstractBinarySearchTree subclass in a specified order.
 
 This enumerator implements only iterative (non-recursive) tree traversal algorithms for two main reasons:
 <ol>
 <li>Recursive algorithms cannot easily be stopped and resumed in the middle of a traversal.</li>
 <li>Iterative algorithms are usually faster since they reduce overhead from function calls.</li>
 </ol>
 
 Traversal state is stored in either a stack or queue using dynamically-allocated C structs and @c \#define pseudo-functions to increase performance and reduce the required memory footprint.
 
 Enumerators encapsulate their own state, and more than one enumerator may be active at once. However, if a collection is modified, any existing enumerators for that collection become invalid and will raise a mutation exception if any further objects are requested from it.
 */
@interface CHBinarySearchTreeEnumerator : NSEnumerator
{	
@private
	__strong id<CHSearchTree> searchTree; // The tree being enumerated.
	__strong CHBinaryTreeNode *current; // The next node to be enumerated.
	__strong CHBinaryTreeNode *sentinelNode; // Sentinel node in the tree.
	CHTraversalOrder traversalOrder; // Order in which to traverse the tree.
	unsigned long mutationCount; // Stores the collection's initial mutation.
	unsigned long *mutationPtr; // Pointer for checking changes in mutation.

	// Pointers and counters that are used for various tree traveral orderings.
	CHBinaryTreeStack_DECLARE();
	CHBinaryTreeQueue_DECLARE();
	// These macros are defined in CHAbstractBinarySearchTree_Internal.h
	
	unsigned int				m_fuiOptions;	/* CJEC, 8-Jul-13: CHTreeOptionsMultiLevel enumerates sub-collections, rather than returning the sub-collection */
	__strong NSMutableArray *	m_poaoEnumerators;	/* CJEC, 1-Jul-13: Array of enumrators for multi-level search trees */
}

/**
 Create an enumerator which traverses a given (sub)tree in the specified order.
 
 @param tree The tree collection that is being enumerated. This collection is to be retained while the enumerator has not exhausted all its objects.
 @param root The root node of the @a tree whose elements are to be enumerated.
 @param sentinel The sentinel value used at the leaves of the specified @a tree.
 @param order The traversal order to use for enumerating the given @a tree.
 @param mutations A pointer to the collection's mutation count for invalidation.
 @param a_fuiOptions The multi-level tree search options to support trees of trees. When options are 0, the enhanced code behaves like the original. The options are a bitarray of flags: 
					CHTreeOptionsMultiLevel		= 0x01,		// CJEC, 2-Jul-13: Support multi-level trees
					CHTreeOptionsMultiLeaves	= 0x02		// CJEC, 19-Jul-13: Support NSMutable Sets as leaves, allowing multiple items with NSOrderedSame

 @return An initialized CHBinarySearchTreeEnumerator which will enumerate objects in @a tree in the order specified by @a order.

 @attention Both option flags can be used together as the class library will not use CHTreeOptionsMultiLevel if there is no appropriate comparison method
 */
- (id) initWithTree:(id<CHSearchTree>)tree
               root:(CHBinaryTreeNode*)root
           sentinel:(CHBinaryTreeNode*)sentinel
     traversalOrder:(CHTraversalOrder)order
    mutationPointer:(unsigned long*)mutations
	options: (unsigned int) a_fuiOptions;	/* CJEC, 8-Jul-13: Support multi-level trees */

/**
 Returns an array of objects the receiver has yet to enumerate.
 
 @return An array of objects the receiver has yet to enumerate.
 
 Invoking this method exhausts the remainder of the objects, such that subsequent invocations of #nextObject return @c nil.
 */
- (NSArray*) allObjects;

/**
 Returns the next object from the collection being enumerated.
 
 @return The next object from the collection being enumerated, or @c nil when all objects have been enumerated.
 */
- (id) nextObject;

@end

@implementation CHBinarySearchTreeEnumerator

- (id) initWithTree:(id<CHSearchTree>)tree
               root:(CHBinaryTreeNode*)root
           sentinel:(CHBinaryTreeNode*)sentinel
     traversalOrder:(CHTraversalOrder)order
    mutationPointer:(unsigned long*)mutations
	options: (unsigned int) a_fuiOptions	/* CJEC, 8-Jul-13: Support multi-level trees */
{
	self = [super init];
	if ((self == nil) || (order > CHTraverseLevelOrder))
		{						/* CJEC, 3-Jul-13: Fix broken macro. Compiler reports: "Comparison of unsigned expression >= 0 is always true". #define isValidTraversalOrder(o) (o>=CHTraverseAscending && o<=CHTraverseLevelOrder) */
		[self release];			/* CJEC, 3-Jul-13: Fix memory leak */
		self = nil;
		return self;
		}
	traversalOrder = order;
	searchTree = (root != sentinel) ? [tree retain] : nil;
	if (traversalOrder == CHTraverseLevelOrder) {
		CHBinaryTreeQueue_INIT();
		CHBinaryTreeQueue_ENQUEUE(root);
	} else {
		CHBinaryTreeStack_INIT();
		if (traversalOrder == CHTraversePreOrder) {
			CHBinaryTreeStack_PUSH(root);
		} else {
			current = root;
		}
	}
	sentinel->object = nil;
	sentinelNode = sentinel;
	mutationCount = *mutations;
	mutationPtr = mutations;
	m_poaoEnumerators = nil;	/* CJEC, 1-Jul-13: By default, no array of enumerators for enumarating inside the outer-most enumerator */
	m_fuiOptions = a_fuiOptions;
	return self;
}

- (void) dealloc {
	[m_poaoEnumerators release];
	[searchTree release];
	free(stack);
	free(queue);
	[super dealloc];
}

// CJEC, 1-Jul-13: Bitarray of flags. Extension to support trees of trees.
//					When options are 0, enhanced code behaves like original
//					CHTreeOptionsMultiLevel enables multi-level collections
- (unsigned int)	options
	{
	return m_fuiOptions;
	}

/* CJEC, 1-Jul-13: Enumerate the nodes of a tree. If the object in the tree is not itself a collection, just return it.
					Otherwise, create an enumerator for the node's object, and start enumerating it. If the collection
					isn't empty, add the enumerator to the enumerator collection so that it will be invoked during
					nextObject
*/
- (id)	SubcollectionEnumerate: (id) a_po
	{
	if (!(m_fuiOptions & CHTreeOptionsMultiLevel) || ![a_po respondsToSelector: @selector (count)])
		return a_po;
	else					/* Enumerate sub-collection if enabled and the object is a (sub-)collection */
		{
		id				po;
		NSEnumerator *	poEnumerator = [a_po objectEnumerator];

		if (m_poaoEnumerators == nil)
			m_poaoEnumerators = [[NSMutableArray alloc] init];
		po = [a_po nextObject];
		NSAssert (po != nil, @"Empty Collection is illegal");
		[m_poaoEnumerators addObject: poEnumerator];
		po = [self SubcollectionEnumerate: po];
		return po;
		}
	}

- (NSArray*) allObjects {
	if (mutationCount != *mutationPtr)
		CHMutatedCollectionException([self class], _cmd);
	NSMutableArray *array = [[NSMutableArray alloc] init];
	id anObject;
	while ((anObject = [self nextObject]))
		[array addObject:anObject];
	[searchTree release];
	searchTree = nil;
	return [array autorelease];
}

- (id) nextObject {
	if (mutationCount != *mutationPtr)
		CHMutatedCollectionException([self class], _cmd);
	
	id			po;
	NSUInteger	cEnumerators = [m_poaoEnumerators count];	/* CJEC, 1-Jul-13: If we have multiple enumerators, enumerate them first */

	if (cEnumerators == 0)
		po = nil;
	else
		{
		po = [[m_poaoEnumerators objectAtIndex: cEnumerators - 1] nextObject];	/* Enumerate the deepest level first */
		if (po == nil)					/* CJEC, 1-Jul-13: No more objects at this level? Backtrack by removing this level's enumerator and repeating */
			{
			[m_poaoEnumerators removeObjectAtIndex: cEnumerators - 1];
			po = [self nextObject];
			}
		else
			po = [self SubcollectionEnumerate: po];	/* CJEC, 1-Jul-13: Enumerate deeper if the enumerated object is a collection */
		}
	if (po == nil)						/* CJEC, 1-Jul-13: Only if we've enumerated all the node levels do we advance the tree */
		{
		switch (traversalOrder) {
			case CHTraverseAscending: {
				if (stackSize == 0 && current == sentinelNode) {
					goto collectionExhausted;
				}
				while (current != sentinelNode) {
					CHBinaryTreeStack_PUSH(current);
					current = current->left;
					// TODO: How to not push/pop leaf nodes unnecessarily?
				}
				current = CHBinaryTreeStack_POP(); // Save top node for return value
				NSAssert((id) current != nil, @"Illegal state, current should never be nil!");
				id tempObject = current->object;
				current = current->right;
				return [self SubcollectionEnumerate: tempObject];
			}
			
			case CHTraverseDescending: {
				if (stackSize == 0 && current == sentinelNode) {
					goto collectionExhausted;
				}
				while (current != sentinelNode) {
					CHBinaryTreeStack_PUSH(current);
					current = current->right;
					// TODO: How to not push/pop leaf nodes unnecessarily?
				}
				current = CHBinaryTreeStack_POP(); // Save top node for return value
				NSAssert((id) current != nil, @"Illegal state, current should never be nil!");
				id tempObject = current->object;
				current = current->left;
				return [self SubcollectionEnumerate: tempObject];
			}
			
			case CHTraversePreOrder: {
				current = CHBinaryTreeStack_POP();
				if (current == NULL) {
					goto collectionExhausted;
				}
				if (current->right != sentinelNode)
					CHBinaryTreeStack_PUSH(current->right);
				if (current->left != sentinelNode)
					CHBinaryTreeStack_PUSH(current->left);
				return [self SubcollectionEnumerate: current->object];
			}
			
			case CHTraversePostOrder: {
				// This algorithm from: http://www.johny.ca/blog/archives/05/03/04/
				if (stackSize == 0 && current == sentinelNode) {
					goto collectionExhausted;
				}
				while (1) {
					while (current != sentinelNode) {
						CHBinaryTreeStack_PUSH(current);
						current = current->left;
					}
					NSAssert(stackSize > 0, @"Stack should never be empty!");
					// A null entry indicates that we've traversed the left subtree
					if (CHBinaryTreeStack_TOP != NULL) {
						current = CHBinaryTreeStack_TOP->right;
						CHBinaryTreeStack_PUSH(NULL);
						// TODO: How to not push a null pad for leaf nodes?
					}
					else {
						(void) CHBinaryTreeStack_POP(); // ignore the null pad
						return [self SubcollectionEnumerate: CHBinaryTreeStack_POP()->object];
					}				
				}
			}

			case CHTraverseLevelOrder: {
				current = CHBinaryTreeQueue_FRONT;
				CHBinaryTreeQueue_DEQUEUE();
				if (current == NULL) {
					goto collectionExhausted;
				}
				if (current->left != sentinelNode)
					CHBinaryTreeQueue_ENQUEUE(current->left);
				if (current->right != sentinelNode)
					CHBinaryTreeQueue_ENQUEUE(current->right);
				return [self SubcollectionEnumerate: current->object];
			}

			collectionExhausted:
				if (searchTree != nil) {
					[searchTree release];
					searchTree = nil;
					CHBinaryTreeStack_FREE(stack);
					CHBinaryTreeQueue_FREE(queue);
				}
			}
		return nil;
		}
	return po;
}

@end

#pragma mark -

CHBinaryTreeNode* CHCreateBinaryTreeNodeWithObject(id anObject) {
	CHBinaryTreeNode *node;
	// NSScannedOption tells the garbage collector to scan object and children.
	node = NSAllocateCollectable(kCHBinaryTreeNodeSize, NSScannedOption);
	node->object = anObject;
	node->balance = 0; // Affects balancing info for any subclass (anon. union)
	return node;
}

@implementation CHAbstractBinarySearchTree

/* CJEC, 19-Jul-13:  Default class used with CHTreeOptionsMultiLeaves collections
*/
+ (Class)			ClassCollectionDefault
	{
	return [NSMutableSet class];
	}

/* CJEC, 12-Feb-15: Read-only accessor to the options flags
*/
- (unsigned int)	GetOptions
	{
	CHUnsupportedOperationException ([self class], _cmd);
	return 0;
	}

/* CJEC, 22-Jul-13: Depending on the nesting level, return the appropriate comparison selector
*/
+ (SEL)		SelCompare: (unsigned int) a_uiNestingLevel
	{
	SEL		pSelCompare;
	
	if (a_uiNestingLevel == 0)		/* Generate the particular object comparison's selector name from the nesting level, and create an NSInvocation to invoke it */
		pSelCompare = NSSelectorFromString (@"compare:");	/* Note: Using compare: rather than compare0: also supports non-multi-level collections */
	else
		pSelCompare = NSSelectorFromString ([NSString stringWithFormat: @"compare%u:", a_uiNestingLevel]);
	return pSelCompare;
	}

/* CJEC, 8-Jul-13: Create an NSInvocation for comparing objects based on the nesting level.
					Nesting level 0 uses compare:
					Nesting level 1 uses compare1:
					Nesting level 2 uses compare2: and so on
*/
+ (NSInvocation *)	InvocationCompare: (id) a_po nestingLevel: (unsigned int) a_uiNestingLevel
	{
	SEL					pSelCompare;
	NSInvocation *		poInvocationCompare;
	NSMethodSignature *	poMethodSignatureCompare;

	pSelCompare = [self SelCompare: a_uiNestingLevel];
	poMethodSignatureCompare = [[a_po class] instanceMethodSignatureForSelector: pSelCompare];
	poInvocationCompare = [NSInvocation invocationWithMethodSignature: poMethodSignatureCompare];
	[poInvocationCompare setSelector: pSelCompare];
	return poInvocationCompare;
	}

/* CJEC, 10-Jul-13: Provide a comparison method using the comparison invocation
*/
- (NSComparisonResult)	Compare: (NSInvocation *) a_poInvocationCompare target: (id) a_poTarget argument: (id) a_poArgument
	{
	NSComparisonResult	eComparisonResult;
	id					poTarget;
	SEL					pSelAnyObject;

	if (a_poArgument != nil)
		[a_poInvocationCompare setArgument: &a_poArgument atIndex: 2];	/* Note: Skip past hidden target (index 0) and selector (index 1) arguments for our first argument. Arguments are not retained without [poInvocationCompare retainArguments] */
	poTarget = a_poTarget;
	if ([self GetOptions] & CHTreeOptionsMultiLevel)	/* Multi-level collections allowed? */
		{
		pSelAnyObject = @selector (anyObject);	/* Identify a leaf object as fast as possible */
		while ([poTarget respondsToSelector: pSelAnyObject])
			{
			poTarget = [poTarget anyObject];	/* All objects in the subcollections should compare the same way at a particular nesting level so use any of them */
			NSAssert (poTarget != nil, @"Empty Collection is illegal");
			}
		NSAssert (![poTarget respondsToSelector: @selector (count)], @"Collection object does not respond to anyObject but does respond to count");
		}
	[a_poInvocationCompare invokeWithTarget: poTarget];	/* Note: Equivalent to eComparisonResult = (NSComparisonResult) [po performSelector: pSelCompare withObject: <Argument>]; but we don't have an object-sized return value so can't actually do this */
	[a_poInvocationCompare getReturnValue: &eComparisonResult];
	return eComparisonResult;
	}

/* CJEC, 19-Jul-13: Depending on the object in question and the options flags, support multiple objects
	all ordered NSOrderedSame at the same leaf. This is either a collection of the same type as this one
	or a mutable (and hence unordered) set

	Note: Conforms to Foundation's naming conventions. The caller MUST release
*/
- (Class)	newLeafCollection: (id) a_po nestingLevel: (unsigned int) a_uiNestingLevel returnsIsMultiLevel: (bool *) a_pfMultiLevel
	{
	unsigned int	fuiOptions;
	SEL				pSelCompare;
	id				poNew;

	fuiOptions = [self GetOptions];
	poNew = nil;													/* Default is no sub-collection */
	*a_pfMultiLevel = false;										/* Default is not multi-level collection */
	if (fuiOptions & CHTreeOptionsMultiLevel)						/* If multi-level trees are supported */
		{
		pSelCompare = [[self class] SelCompare: a_uiNestingLevel];
		if ([a_po respondsToSelector: pSelCompare])					/* If the object responds to the appropriate comparison method */
			{
			poNew = [[[self class] alloc] initWithTreeOptions: fuiOptions];
			*a_pfMultiLevel = true;
			}
		}
	if ((poNew == nil) && (fuiOptions & CHTreeOptionsMultiLeaves))	/* Haven't already got a collection, and multiple leaves are supported? */
		poNew = [[[[self class] ClassCollectionDefault] alloc] init];
	return poNew;
	}

// This is the designated initializer for CHAbstractBinarySearchTree, CHBinarySearchTree and all its derived classes
// CJEC, 1-Jul-13: New designated intialiser specifies options from CHTreeOptions
- (id) initWithTreeOptions: (unsigned int) a_fuiOptions {
	if ((self = [super init]) == nil)
		{
		[self release];						/* CJEC, 12-Feb-15: Avoid memory leak when initialisation fails */
		self = nil;
		return self;
		}
	(void) a_fuiOptions;					/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning. CJEC, 12-Feb-15: TODO: Complete the conversion to a class cluster */
	return self;
}

// CJEC, 1-Jul-13: Default initialiser behaves like the original code
- (id)	init {
	return [self initWithTreeOptions: 0];
}
// Calling [self init] allows child classes to initialize their specific state.
// (The -init method in any subclass must always call to -[super init] first.)
- (id) initWithArray:(NSArray*)anArray {
	if ([self init] == nil) return nil;
	[self addObjectsFromArray:anArray];
	return self;
}

#pragma mark <NSCoding>

// CJEC, 2-Jul-13: TODO: Support multi-level trees
- (id) initWithCoder:(NSCoder*) a_poCoder
	{
	bool			fAllowsKeyCoding;
	int				fiOptions;
	NSUInteger		cObjects;
	NSUInteger		uiCount;
	id				po;

	fAllowsKeyCoding = [a_poCoder allowsKeyedCoding];
	if (fAllowsKeyCoding)
		{
		fiOptions = [a_poCoder decodeIntForKey: @"options"];
		cObjects = [a_poCoder decodeIntegerForKey: @"count"];
		}
    else
		{
		[a_poCoder decodeValueOfObjCType: @encode (int) at: &fiOptions];
		[a_poCoder decodeValueOfObjCType: @encode (NSInteger) at: &cObjects];
		}
	self = [self initWithTreeOptions: fiOptions];
	for (uiCount = 0; uiCount < cObjects; uiCount ++)
		{
		if (fAllowsKeyCoding)
			po = [a_poCoder decodeObjectForKey: [[NSNumber numberWithUnsignedInteger: uiCount] stringValue]];
		else
			po = [a_poCoder decodeObject];
		[self addObject: po];
		}
	return self;
	}

- (void) encodeWithCoder:(NSCoder*) a_poCoder
	{
	(void) a_poCoder;					/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	CHUnsupportedOperationException ([self class], _cmd);
	}

#pragma mark <NSCopying> methods

- (id) copyWithZone:(NSZone*)zone {
	id<CHSearchTree> newTree = [[[self class] allocWithZone:zone] initWithTreeOptions: [self GetOptions]];
	// No point in using fast enumeration here until rdar://6296108 is addressed.
	NSEnumerator *e = [self objectEnumeratorWithTraversalOrder:CHTraverseLevelOrder options: 0];	/* 18-Jul-13: CJEC: Don't bother enumerating sub-levels. Just copy en masse */
	id anObject;
	while ((anObject = [e nextObject])) {
		[newTree addObject:anObject];
	}
	return newTree;
}

#pragma mark <NSFastEnumeration>
- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState*)state
                                   objects:(id*)stackbuf
                                     count:(NSUInteger)len
{
	(void) state;					/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	(void) stackbuf;				/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	(void) len;						/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	CHUnsupportedOperationException ([self class], _cmd);
	return 0;
}

#pragma mark Concrete Implementations

- (void) addObjectsFromArray:(NSArray*)anArray {
	for (id anObject in anArray) {
		[self addObject:anObject];
	}
}

- (NSArray*) allObjects {
	return [self allObjectsWithTraversalOrder:CHTraverseAscending];
}

/* 18-Jul-13: CJEC: Support multi-level trees */
- (NSArray*) allObjectsWithTraversalOrder:(CHTraversalOrder)order {
	return [[self objectEnumeratorWithTraversalOrder:order options: [self GetOptions]] allObjects];
}

- (id) anyObject
	{
	CHUnsupportedOperationException ([self class], _cmd);
	return nil;
	}

- (NSUInteger) count {
	CHUnsupportedOperationException ([self class], _cmd);
	return 0;
}

- (BOOL) containsObject:(id)anObject {
	return ([self member:anObject] != nil);
}

- (id) firstObject {
	CHUnsupportedOperationException ([self class], _cmd);
	return nil;
}

- (NSUInteger) hash {
	return hashOfCountAndObjects([self count], [self firstObject], [self lastObject]);
}

- (BOOL) isEqual:(id)otherObject {
	if ([otherObject conformsToProtocol:@protocol(CHSortedSet)])
		return [self isEqualToSortedSet:otherObject];
	else
		return NO;
}

- (BOOL) isEqualToSearchTree:(id<CHSearchTree>)otherTree {
	return collectionsAreEqual(self, otherTree);
}

- (BOOL) isEqualToSortedSet:(id<CHSortedSet>)otherSortedSet {
	return collectionsAreEqual(self, otherSortedSet);
}

- (id) lastObject {
	CHUnsupportedOperationException ([self class], _cmd);
	return nil;
}

- (id)	member: (id) a_po nestingLevel: (unsigned int) a_uiNestingLevel options: (unsigned int) a_fuiOptions
	{
	(void) a_po;					/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	(void) a_uiNestingLevel;		/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	(void) a_fuiOptions;			/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	CHUnsupportedOperationException ([self class], _cmd);
	return nil;
	}
		
/* CJEC, 2-Jul-13: Support multi-level collections */
- (id) member:(id)anObject {
	return [self member: anObject nestingLevel: 0 options: [self GetOptions]];
}

/* CJEC, 18-Jul-13: Support multi-level collections */
- (NSEnumerator*) objectEnumerator {
	return [self objectEnumeratorWithTraversalOrder:CHTraverseAscending options: [self GetOptions]];
}

- (NSEnumerator*) objectEnumeratorWithTraversalOrder:(CHTraversalOrder)order options: (unsigned int) a_fuiOptions {
	(void) order;					/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	(void) a_fuiOptions;			/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	CHUnsupportedOperationException ([self class], _cmd);
	return nil;
}

- (void) removeAllObjects {
	CHUnsupportedOperationException ([self class], _cmd);
}

// Incurs an extra search cost, but we don't know how the child class removes...
- (void) removeFirstObject {
	[self removeObject:[self firstObject]];
}

// Incurs an extra search cost, but we don't know how the child class removes...
- (void) removeLastObject {
	[self removeObject:[self lastObject]];
}

/* CJEC, 18-Jul-13: Support multi-level collections */
- (NSEnumerator*) reverseObjectEnumerator {
	return [self objectEnumeratorWithTraversalOrder:CHTraverseDescending options: [self GetOptions]];
}

/* CJEC, 18-Jul-13: Support multi-level collections */
- (NSSet*) set {
	NSMutableSet *set = [NSMutableSet new];
	NSEnumerator *e = [self objectEnumeratorWithTraversalOrder:CHTraversePreOrder options: [self GetOptions]];
	id anObject;
	while ((anObject = [e nextObject])) {
		[set addObject:anObject];
	}
	return [set autorelease];
}

- (id <CHSortedSet>)	subsetFromObject: (id) a_poStart toObject: (id) a_poEnd options: (CHSubsetConstructionOptions) a_fuiSubsetConstructionOptions nestingLevel: (unsigned int) a_uiNestingLevel
	{
	(void) a_poStart;				/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	(void) a_poEnd;					/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	(void) a_fuiSubsetConstructionOptions;	/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	(void) a_uiNestingLevel;		/* CJEC, 12-Feb-15: Avoid unused parameter compiler warning */
	CHUnsupportedOperationException ([self class], _cmd);
	return nil;
	}

// CJEC, 2-Jul-13: Support multi-level trees */
/*
 \copydoc CHSortedSet::subsetFromObject:toObject:
 
 \see     CHSortedSet#subsetFromObject:toObject:
 
 \link    CHSortedSet#subsetFromObject:toObject: \endlink
 
 \attention This implementation tests objects for membership in the subset according to their sorted order. This worst-case input causes more work for self-balancing trees, and subsets of unbalanced trees will always degenerate to linked lists.
 */
- (id<CHSortedSet>) subsetFromObject:(id)start
                            toObject:(id)end
                             options:(CHSubsetConstructionOptions)options
{
	return [self subsetFromObject: start toObject: end options: options nestingLevel: 0];
}

- (NSString*) debugDescriptionForNode:(CHBinaryTreeNode*)node {
	return [NSString stringWithFormat:@"\"%@\"", node->object];
}

- (NSString*) dotGraphStringForNode:(CHBinaryTreeNode*)node {
	return [NSString stringWithFormat:@"  \"%@\";\n", node->object];
}

/* CJEC, 8-Jul-13: Support multi-level trees */
- (void) addObject:(id) a_po nestingLevel: (unsigned int) a_uiNestingLevel
	{
	(void) a_po;						/* CJEC, 8-Jul-13: Avoid unused parameter compiler warning */
	(void) a_uiNestingLevel;			/* CJEC, 8-Jul-13: Avoid unused parameter compiler warning */
	CHUnsupportedOperationException ([self class], _cmd);
	}

/* CJEC, 8-Jul-13: Support multi-level trees */
- (void) addObject:(id)anObject {
	return [self addObject: anObject nestingLevel: 0];
}

/* CJEC, 8-Jul-13: Support multi-level trees */
- (void) removeObject: (id) a_po nestingLevel: (unsigned int) a_uiNestingLevel
	{
	(void) a_po;						/* CJEC, 8-Jul-13: Avoid unused parameter compiler warning */
	(void) a_uiNestingLevel;			/* CJEC, 8-Jul-13: Avoid unused parameter compiler warning */
	CHUnsupportedOperationException ([self class], _cmd);
	}

/* CJEC, 8-Jul-13: Support multi-level trees */
- (void) removeObject:(id)element {
	[self removeObject: element nestingLevel: 0];
}

@end

@implementation CHBinarySearchTree

- (void) dealloc {
	[self removeAllObjects];
	free(header);
	free(sentinel);
	[super dealloc];
}

// This is the designated initializer for CHBinarySearchTree, CHBinarySearchTree and all its derived classes
// Only to be called from concrete child classes to initialize shared variables.
// CJEC, 1-Jul-13: New designated intialiser specifies options from CHTreeOptions
- (id) initWithTreeOptions: (unsigned int) a_fuiOptions {
	bool	fOK;
	
	self = [super initWithTreeOptions: a_fuiOptions];
	fOK = (self != nil);
	if (fOK)
		{
		m_fuiOptions = a_fuiOptions;
		count = 0;
		mutations = 0;
		sentinel = CHCreateBinaryTreeNodeWithObject (nil);
		sentinel -> right = sentinel;
		sentinel -> left = sentinel;
		header = CHCreateBinaryTreeNodeWithObject ([CHSearchTreeHeaderObject object]);
		header -> right = sentinel;
		header -> left = sentinel;
		fOK = ((id) sentinel != nil) && ((id) header != nil);	/* CJEC, 13-Feb-15: Add checks to ensure successful initialisation */
		}
	if (!fOK)
		{
		[self release];						/* CJEC, 12-Feb-15: Avoid memory leak when initialisation fails */
		self = nil;
		}
	return self;
}

/* CJEC, 12-Feb-15: Read-only accessor to the options flags
*/
- (unsigned int)	GetOptions
	{
	return m_fuiOptions;
	}

#pragma mark <NSCoding>

// CJEC, 2-Jul-13: TODO: Support multi-level trees
- (void) encodeWithCoder:(NSCoder*) a_poCoder
	{
	bool			fAllowsKeyCoding;
	int				fiOptions;
	NSEnumerator *	poEnumerator;
	id				po;
	NSUInteger		uiCount;
	NSInteger		cObjects;

	fAllowsKeyCoding = [a_poCoder allowsKeyedCoding];
	fiOptions = m_fuiOptions;
	cObjects = count;
	if (fAllowsKeyCoding)
		{
		[a_poCoder encodeInt: fiOptions forKey: @"options"];
		[a_poCoder encodeInteger: cObjects forKey: @"count"];
		}
    else 
		{
		[a_poCoder encodeValueOfObjCType: @encode (int) at: &fiOptions];
		[a_poCoder encodeValueOfObjCType: @encode (NSInteger) at: &cObjects];
		}
	poEnumerator = [[CHBinarySearchTreeEnumerator alloc] initWithTree: self root: header -> right sentinel: sentinel traversalOrder: CHTraverseLevelOrder mutationPointer: &mutations options: 0];
	uiCount = 0;
	po = [poEnumerator nextObject];			/* Enumerate, but do not enumerate subtrees */
	while (po != nil)
		{
		if (fAllowsKeyCoding)
			[a_poCoder encodeObject: po forKey: [[NSNumber numberWithUnsignedInteger: uiCount] stringValue]];
		else
			[a_poCoder encodeObject: po];
		uiCount ++;
		po = [poEnumerator nextObject];
		}
	[poEnumerator release];
	}

#pragma mark <NSCopying> methods

#pragma mark <NSFastEnumeration>
// CJEC, 5-Jul-13: Support multi-level trees
// CJEC, 5-Jul-13: Note: Beware temporary objects inside -[NSFastEnumeration countByEnumeratingWithState: objects: count:]. See http://www.mikeash.com/pyblog/friday-qa-2010-04-16-implementing-fast-enumeration.html
- (NSUInteger) countByEnumeratingWithState:(NSFastEnumerationState*)state
                                   objects:(id*)stackbuf
                                     count:(NSUInteger)len
{
	NSUInteger			batchCount = 0;
	id					po;
	CHBinaryTreeNode *	current;
	CHBinaryTreeStack_DECLARE();
	
	// For the first call, start at leftmost node, otherwise the last saved node
	if (state->state == 0) {
		state->itemsPtr = stackbuf;
		state->mutationsPtr = &mutations;
		current = header ->right;
		CHBinaryTreeStack_INIT();
	}
	else if (state->state == 1) {
		stack = (CHBinaryTreeNode * *) state -> extra [0];
		CHBinaryTreeStack_FREE (stack);	/* CJEC, 5-Jul-13: Put all clean-up code in the termination call */
		if ((id) state -> extra [3] != nil)
			[(id) state -> extra [3] release];	/* CJEC, 5-Jul-13: Release the object enumerator, if there is one */
		return 0;		
	}
	else {
		current = (CHBinaryTreeNode*) state->state;
		stack = (CHBinaryTreeNode**) state->extra[0];
		stackCapacity = (NSUInteger) state->extra[1];
		stackSize = (NSUInteger) state->extra[2];
	}
	NSAssert((id) current != nil, @"Illegal state, current should never be nil!");
	if ((id) state -> extra [3] != nil)		/* CJEC, 5-Jul-13: Already enumerating a sub-collection? */
		{
		NSLog (@"Current node %p. Trying to finish object enumeration", current);
		do									/* CJEC, 5-Jul-13: TODO: Use state -> extra [4] to protect against a mutation of state -> extra [3] */
			{
			if (batchCount < len)			/* Use the object enumerator to squeeze as many objects into the limit as possible */
				{
				po = [(id) state -> extra [3] nextObject];
				stackbuf [batchCount] = po;
				batchCount ++;
				}
			}
		while ((po != nil) && (batchCount < len));
		if (po != nil)						/* Not finished the enumeration? */
			return batchCount;				/* Can't advance through the tree yet */
		else
			{
			NSLog (@"Current node %p. Finished object enumeration", current);
			[(id) state -> extra [3] release];	/* Release the object enumerator */
			state -> extra [3] = (uintptr_t) nil;	/* Mark it deleted so we know we're not in object enumeration mode */
			current = current -> right;		/* Advance to point to the next object, and continue through the tree */
			}
		}
	// Accumulate objects from the tree until we reach all nodes or the maximum
	while ( (current != sentinel || stackSize > 0) && batchCount < len) {
		while (current != sentinel) {
			CHBinaryTreeStack_PUSH(current);
			current = current->left;
		}
		current = CHBinaryTreeStack_POP(); // Save top node for return value
		NSAssert((id) current != nil, @"Illegal state, current should never be nil!");
		if (m_fuiOptions & CHTreeOptionsMultiLevel)	/* CJEC, 5-Jul-13: Support multi-level collections */
			{
			if (![current -> object respondsToSelector: @selector (count)])	
				{							/* CJEC, 5-Jul-13: Not a collection object, use original code */
				stackbuf [batchCount] = current -> object;
				batchCount ++;
				current = current -> right;	/* Advance to point to the next object, next time we come round */
				}
			else
				{
				NSUInteger	cObjects;
				
				cObjects = [current -> object count];
				if (cObjects + batchCount < len)	/* Ensure that the sub-collection(s)' objects can fit in the stack, if so use fast enumeration which is almost always quicker and has mutation protection */
					{
					for (po in current -> object)	/* (Fast) enumerate sub-collection. Note: Assume that it supports fast enumeration */
						{
						stackbuf [batchCount] = po;
						batchCount ++;
						}
					current = current -> right;	/* Advance to point to the next object, next time we come round */
					}
				else						/* If the sub-collection count won't fit, we can't use fast enumeration on it */
					{
					NSLog (@"Current node %p. Could not fit %lu sub-objects in %lu limit with with fast enumeration. Using object enumeration", current, (unsigned long) cObjects, (unsigned long) len);
					NSAssert ((id) state -> extra [3] != nil, @"Already using an object enumerator?");	/* Note: Assume sub-collection supports objectEnumerator */
					state -> extra [3] = (uintptr_t) ((id __strong) [[current -> object objectEnumerator] retain]);	/* Note: Retain it so we don't get messed up by autorelease pools */
					do						/* CJEC, 5-Jul-13: TODO: Use state -> extra [4] to protect against a mutation of state -> extra [3] */
						{
						if (batchCount < len)	/* Use the object enumerator to squeeze as many objects into the limit as possible */
							{
							po = [(id) state -> extra [3] nextObject];
							stackbuf [batchCount] = po;
							batchCount ++;
							}
						}
					while ((po != nil) && (batchCount < len));
					NSAssert (po != nil, @"Reached end of enumeration, but didn't use fast enumeration");
					break;					/* If the sub-collection count did not fit, don't advance the current pointer, and stop looping */
					}
				}
			}
		else								/* CJEC, 5-Jul-13: Multi-level collections not enabled, use original code */
			{								
			stackbuf [batchCount] = current -> object;
			batchCount ++;
			current = current -> right;
			}
	}
	
	if (current == sentinel && stackSize == 0) {
		state->extra[0] = (uintptr_t) stack;
		state->state = 1; // used as a termination flag
	}
	else {
		state->state    = (unsigned long) current;
		state->extra[0] = (uintptr_t) stack;
		state->extra[1] = (uintptr_t) stackCapacity;
		state->extra[2] = (uintptr_t) stackSize;
	}
	return batchCount;
}

#pragma mark Concrete Implementations

// CJEC, 2-Jul-13: Support multi-level trees */
- (id) anyObject
	{
	id		po;
	SEL		pSelAnyObject;

	if (count == 0)				// In an empty tree, sentinel's object may be nil, but let's not chance it. (Our -removeAllObjects nils the pointer, child's -removeObject: may not.)
		po = nil;
	else
		{
		po = header -> right -> object;
		if (m_fuiOptions & CHTreeOptionsMultiLevel)
			{
			pSelAnyObject = @selector (anyObject);
			while ([po respondsToSelector: pSelAnyObject])
				{
				po = [po anyObject];	/* Recurse through the multi-level collection until a non-collection object is reached */
				NSAssert (po != nil, @"Empty Collection is illegal");
				if ([po isKindOfClass: [CHAbstractBinarySearchTree class]])
					break;				/* And repeat if the collection is not one of these tree classes, which will recurse in this code */
				}
			}
		}
	return po;
	}

- (NSUInteger) count {
	return count;
}

// CJEC, 1-Jul-13: Support multi-level trees */
- (id) firstObject {
	sentinel ->object = nil;
	CHBinaryTreeNode *current = header ->right;
	while (current->left != sentinel)
		current = current->left;
	id	po = current->object;
	SEL	pSelFirstObject;

	if (m_fuiOptions & CHTreeOptionsMultiLevel)	/* CJEC, 1-Jul-13: Tree is a multi-level tree? */
		{
		pSelFirstObject = @selector (firstObject);
		while ([po respondsToSelector: pSelFirstObject])
			{
			po = [po firstObject];		/* Recurse through the multi-level collection until a non-collection object is reached */
			NSAssert (po != nil, @"Empty Collection is illegal");
			if ([po isKindOfClass: [CHAbstractBinarySearchTree class]])
				break;					/* And repeat if the collection is not one of these tree classes, which will recurse in this code */
			}
		}
	return po;
}

// CJEC, 1-Jul-13: Support multi-level trees */
- (id) lastObject {
	sentinel ->object = nil;
	CHBinaryTreeNode *current = header ->right;
	while (current->right != sentinel)
		current = current->right;
	id	po = current->object;
	SEL	pSelLastObject;

	if (m_fuiOptions & CHTreeOptionsMultiLevel)	/* CJEC, 1-Jul-13: Tree is a multi-level tree? */
		{
		pSelLastObject = @selector (lastObject);
		while ([po respondsToSelector: pSelLastObject])
			{
			po = [po lastObject];		/* Recurse through the multi-level collection until a non-collection object is reached */
			NSAssert (po != nil, @"Empty Collection is illegal");
			if ([po isKindOfClass: [CHAbstractBinarySearchTree class]])
				break;					/* And repeat if the collection is not one of these tree classes, which will recurse in this code */
			}
		}
	return po;
}

/* CJEC, 2-Jul-13: Support multi-level collections by using a different compare*: method for each nesting level */
- (id)	member: (id) a_po nestingLevel: (unsigned int) a_uiNestingLevel options: (unsigned int) a_fuiOptions
	{
	CHBinaryTreeNode *	pBinaryTreeNodeCurrent;
	NSInvocation *		poInvocationCompare;
	NSComparisonResult	eComparisonResult;
	
	if (a_po == nil)
		return nil;

	sentinel -> object = a_po; // Make sure the target value is always "found"
	pBinaryTreeNodeCurrent = header -> right;
	poInvocationCompare = [[self class] InvocationCompare: a_po nestingLevel: a_uiNestingLevel];	/* Note: Technically, we should use the other object as we're sending the compare*: method to it. But compare*: must be symmetric so we use the argument because we already have it */
	eComparisonResult = [self Compare: poInvocationCompare target: pBinaryTreeNodeCurrent -> object argument: a_po];
	while (eComparisonResult != NSOrderedSame)
		{
		pBinaryTreeNodeCurrent = pBinaryTreeNodeCurrent -> link [eComparisonResult == NSOrderedAscending]; // R on YES
		eComparisonResult = [self Compare: poInvocationCompare target: pBinaryTreeNodeCurrent -> object argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
		}
	if (pBinaryTreeNodeCurrent == sentinel)
		return nil;
	else
		if (a_fuiOptions & CHTreeOptionsMultiLevel)	/* Multi-level collections allowed? */
			{
			if ([pBinaryTreeNodeCurrent -> object conformsToProtocol:@protocol (CHMultiLevelTreeP)])
				return [pBinaryTreeNodeCurrent -> object member: a_po nestingLevel: a_uiNestingLevel + 1 options: a_fuiOptions];	/* Support multi-level collections */
			else
				if ([pBinaryTreeNodeCurrent -> object respondsToSelector: @selector (member:)])
					return [pBinaryTreeNodeCurrent -> object member: a_po];	/* Support other collections that support the member: method */
				else									/* Object is not a collection that supports membership */
					return pBinaryTreeNodeCurrent -> object;
			}
		else						/* No multi-level collections */
			return pBinaryTreeNodeCurrent -> object;	/* Just return the object, whether or not it's a collection */
	}
		
/* CJEC, 18-Jul-13: Support multi-level collections */
- (NSEnumerator*) objectEnumeratorWithTraversalOrder:(CHTraversalOrder)order options: (unsigned int) a_fuiOptions {
	return [[[CHBinarySearchTreeEnumerator alloc]
			 initWithTree:self
	                 root:header->right
	             sentinel:sentinel
	       traversalOrder:order
	      mutationPointer:&mutations
		  options: a_fuiOptions] autorelease];	/* CJEC, 8-Jul-13: Apply multi-level tree options to the enumerator */
}

// Doesn't call -[NSGarbageCollector collectIfNeeded] -- lets the sender choose.
- (void) removeAllObjects {
	if (count == 0)
		return;
	++mutations;
	count = 0;
	
	// Remove each node from the tree and release the object it points to.
	// Use pre-order (depth-first) traversal for simplicity and performance.
	CHBinaryTreeStack_DECLARE();
	CHBinaryTreeStack_INIT();
	CHBinaryTreeStack_PUSH(header->right);
	
	CHBinaryTreeNode *current;
	while ((current = CHBinaryTreeStack_POP())) {
		if (current->right != sentinel)
			CHBinaryTreeStack_PUSH(current->right);
		if (current->left != sentinel)
			CHBinaryTreeStack_PUSH(current->left);
		[current->object release];
		free(current);
	}
	free(stack); // declared in CHBinaryTreeStack_DECLARE() macro
	header->right = sentinel; // With GC, this is sufficient to unroot the tree.
	sentinel->object = nil; // Make sure we don't accidentally retain an object.
}

/* CJEC, 2-Jul-13: Support multi-level collections by using a different compare*: method for each nesting level */
- (id <CHSortedSet>)	subsetFromObject: (id) a_poStart toObject: (id) a_poEnd options: (CHSubsetConstructionOptions) a_fuiSubsetConstructionOptions nestingLevel: (unsigned int) a_uiNestingLevel
	{
	NSEnumerator *		poEnumerator;
	id					po;
	id <CHSortedSet>	poSortedSetSubset;
	NSInvocation *		poInvocationCompare;
	NSComparisonResult	eComparisonResult;
	
	// If both parameters are nil, return a copy containing all the objects.
	if (a_poStart == nil && a_poEnd == nil)
		return [[self copy] autorelease];
	poSortedSetSubset = [[[[self class] alloc] initWithTreeOptions: m_fuiOptions] autorelease];	/* CJEC, 5-Jul-13: FIXME: This could be more efficient. We should avoid allocating the subset unless we're going to use it, and we won't if the arguments' ordering is NSOrderedSame */
	if (count == 0)
		return poSortedSetSubset;
	poInvocationCompare = [[self class] InvocationCompare: ((a_poStart != nil) ? a_poStart : a_poEnd) nestingLevel: a_uiNestingLevel];	/* Note: Technically, we should use the other object as we're sending the compare*: method to it. But compare*: must be symmetric so we use the (non-nil) argument because we already have it */
	if (a_poStart == nil)			// Start from the first object and add until we pass the end parameter.
		{
		poEnumerator = [self objectEnumeratorWithTraversalOrder: CHTraverseAscending options: 0];	/* Don't enumerate to leaf level */
		po = [poEnumerator nextObject];
		eComparisonResult = [self Compare: poInvocationCompare target: po argument: a_poEnd];
		while ((po != nil) && (eComparisonResult != NSOrderedDescending))
			{
			[poSortedSetSubset addObject: po];
			po = [poEnumerator nextObject];
			eComparisonResult = [self Compare: poInvocationCompare target: po argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
			}
		}
	else
		if (a_poEnd == nil)			// Start from the last object and add until we pass the start parameter.
			{
			poEnumerator = [self objectEnumeratorWithTraversalOrder: CHTraverseDescending options: 0];	/* Don't enumerate to leaf level */
			po = [poEnumerator nextObject];
			eComparisonResult = [self Compare: poInvocationCompare target: po argument: a_poStart];
			while ((po != nil) && (eComparisonResult != NSOrderedAscending))
				{
				[poSortedSetSubset addObject: po];
				po = [poEnumerator nextObject];
				eComparisonResult = [self Compare: poInvocationCompare target: po argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
				}
			}
		else						/* We have non-nil start and end arguments. First, determine their ordering */
			{
			eComparisonResult = [self Compare: poInvocationCompare target: a_poStart argument: a_poEnd];
			if (eComparisonResult == NSOrderedSame)
				{
				if (a_fuiSubsetConstructionOptions & CHSubsetForceSingleLevel)	/* Not traversing through the levels? */
					[poSortedSetSubset addObject: [self member: a_poStart nestingLevel: a_uiNestingLevel options: 0]];	/* Just return the single object that matches the search criteria, and which may also be a collection. Don't look for a leaf object */
				else				/* Support multi-level trees */
					{				/* If the ordering is the same, find the subset by comparing at the next level. Replace this subtree with one from the next nesting level */
					[poSortedSetSubset release];	/* CJEC, 5-Jul-13: FIXME: This could be more efficient. We should avoid allocating the subset unless we're going to use it, and we won't if the arguments' ordering is NSOrderedSame */
					poSortedSetSubset = [self subsetFromObject: a_poStart toObject: a_poEnd options: a_fuiSubsetConstructionOptions nestingLevel: a_uiNestingLevel + 1];
					}
				}
			else
				if (eComparisonResult == NSOrderedAscending)	// Include subset of objects between the range parameters.
					{
					poEnumerator = [self objectEnumeratorWithTraversalOrder: CHTraverseAscending options: 0];	/* Don't enumerate to leaf level */
					po = [poEnumerator nextObject];
					eComparisonResult = [self Compare: poInvocationCompare target: po argument: a_poStart];
					while ((po != nil) && (eComparisonResult == NSOrderedAscending))
						{
						po = [poEnumerator nextObject];
						eComparisonResult = [self Compare: poInvocationCompare target: po argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
						}
					[poInvocationCompare setArgument: &a_poEnd atIndex: 2];	/* Note: Skip past hidden target (index 0) and selector (index 1) arguments for our first argument. Arguments are not retained without [poInvocationCompare retainArguments] */
					do
						{
						[poSortedSetSubset addObject: po];
						po = [poEnumerator nextObject];
						eComparisonResult = [self Compare: poInvocationCompare target: po argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
						}
					while ((po != nil) && (eComparisonResult != NSOrderedDescending));
					}
				else				// Include subset of objects NOT between the range parameters.
					{
					poEnumerator = [self objectEnumeratorWithTraversalOrder: CHTraverseDescending options: 0];	/* Don't enumerate to leaf level */
					po = [poEnumerator nextObject];
					eComparisonResult = [self Compare: poInvocationCompare target: po argument: a_poStart];
					while ((po != nil) && (eComparisonResult != NSOrderedAscending))
						{
						[poSortedSetSubset addObject: po];
						po = [poEnumerator nextObject];
						eComparisonResult = [self Compare: poInvocationCompare target: po argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
						}
					poEnumerator = [self objectEnumeratorWithTraversalOrder: CHTraverseAscending options: 0];	/* Don't enumerate to leaf level */
					po = [poEnumerator nextObject];
					eComparisonResult = [self Compare: poInvocationCompare target: po argument: a_poEnd];
					while ((po != nil) && (eComparisonResult != NSOrderedDescending))
						{
						[poSortedSetSubset addObject: po];
						po = [poEnumerator nextObject];
						eComparisonResult = [self Compare: poInvocationCompare target: po argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
						}
					}
			}
	if (a_uiNestingLevel == 0)		/* If we're at the outermost nesting level */
		{
		if (a_fuiSubsetConstructionOptions & CHSubsetExcludeLowEndpoint)	// If the start and/or end value is to be excluded, remove before returning.
			[poSortedSetSubset removeObject: a_poStart];
		if (a_fuiSubsetConstructionOptions & CHSubsetExcludeHighEndpoint)
			[poSortedSetSubset removeObject: a_poEnd];
		}
	return poSortedSetSubset;
	}

- (NSString*) description {
	return [[self allObjectsWithTraversalOrder:CHTraverseAscending] description];
}

- (NSString*) debugDescription {
	NSMutableString *description = [NSMutableString stringWithFormat:
	                                @"<%@: 0x%p> = {\n", [self class], self];
	CHBinaryTreeNode *current;
	CHBinaryTreeStack_DECLARE();
	CHBinaryTreeStack_INIT();
	
	sentinel ->object = nil;
	if (header ->right != sentinel)
		CHBinaryTreeStack_PUSH(header ->right);	
	while ((current = CHBinaryTreeStack_POP())) {
		if (current->right != sentinel)
			CHBinaryTreeStack_PUSH(current->right);
		if (current->left != sentinel)
			CHBinaryTreeStack_PUSH(current->left);
		// Append entry for the current node, including children
		[description appendFormat:@"\t%@ -> \"%@\" and \"%@\"\n",
		 [self debugDescriptionForNode:current],
		 current->left->object, current->right->object];
	}
	CHBinaryTreeStack_FREE(stack);
	[description appendString:@"}"];
	return description;
}

// Uses an iterative reverse pre-order traversal to generate the diagram so that
// DOT tools will render the graph as a binary search tree is expected to look.
- (NSString*) dotGraphString {
	NSMutableString *graph = [NSMutableString stringWithFormat:
							  @"digraph %@\n{\n", NSStringFromClass([self class])];
	if (header ->right == sentinel) {
		[graph appendFormat:@"  nil;\n"];
	} else {
		NSString *leftChild, *rightChild;
		NSUInteger sentinelCount = 0;
		sentinel ->object = nil;
		
		CHBinaryTreeNode *current;
		CHBinaryTreeStack_DECLARE();
		CHBinaryTreeStack_INIT();
		CHBinaryTreeStack_PUSH(header ->right);
		// Uses a reverse pre-order traversal to make the DOT output look right.
		while ((current = CHBinaryTreeStack_POP())) {
			if (current->left != sentinel)
				CHBinaryTreeStack_PUSH(current->left);
			if (current->right != sentinel)
				CHBinaryTreeStack_PUSH(current->right);
			// Append entry for node with any subclass-specific customizations.
			[graph appendString:[self dotGraphStringForNode:current]];
			// Append entry for edges from current node to both its children.
			leftChild = (current->left->object == nil)
				? [NSString stringWithFormat:@"nil%lu", (unsigned long) ++sentinelCount]
				: [NSString stringWithFormat:@"\"%@\"", current->left->object];
			rightChild = (current->right->object == nil)
				? [NSString stringWithFormat:@"nil%lu", (unsigned long) ++sentinelCount]
				: [NSString stringWithFormat:@"\"%@\"", current->right->object];
			[graph appendFormat:@"  \"%@\" -> {%@;%@};\n",
			                    current->object, leftChild, rightChild];
		}
		CHBinaryTreeStack_FREE(stack);
		
		// Create entry for each null leaf node (each nil is modeled separately)
		for (NSUInteger i = 1; i <= sentinelCount; i++)
			[graph appendFormat:@"  nil%lu [shape=point,fillcolor=black];\n", (unsigned long) i];
	}
	// Terminate the graph string, then return it
	[graph appendString:@"}\n"];
	return graph;
}

@end

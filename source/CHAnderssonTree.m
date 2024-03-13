/*
 CHDataStructures.framework -- CHAnderssonTree.m
 
 Copyright (c) 2008-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is  provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2024	Kinnami Software Corporation. All rights reserved.
 */

#import "CHAnderssonTree.h"
#import "CHAbstractBinarySearchTree_Internal.h"

// Remove left horizontal links
#define skew(node) { \
	if ( node->left->level == node->level && node->level != 0 ) { \
		CHBinaryTreeNode *save = node->left; \
		node->left = save->right; \
		save->right = node; \
		node = save; \
	} \
}

// Remove consecutive horizontal links
#define split(node) { \
	if ( node->right->right->level == node->level && node->level != 0 ) { \
		CHBinaryTreeNode *save = node->right; \
		node->right = save->left; \
		save->left = node; \
		node = save; \
		++(node->level); \
	} \
}

#pragma mark -

@implementation CHAnderssonTree

// NOTE: The header and sentinel nodes are initialized to level 0 by default.
/* CJEC, 8-Jul-13: Support multi-level trees */
- (void) addObject:(id)anObject nestingLevel: (unsigned int) a_uiNestingLevel {
	if (anObject == nil)
		CHNilArgumentException([self class], _cmd);
	++mutations;
	
	CHBinaryTreeNode *parent, *current = header;
	CHBinaryTreeStack_DECLARE();
	CHBinaryTreeStack_INIT();
	
	sentinel ->object = anObject; // Assure that we find a spot to insert

	NSComparisonResult	comparison;
	NSInvocation *		poInvocationCompare = [[self class] InvocationCompare: anObject nestingLevel: a_uiNestingLevel];	/* Note: Technically, we should use the other object as we're sending the compare*: method to it. But compare*: must be symmetric so we use the (non-nil) argument because we already have it */

	comparison = [self Compare: poInvocationCompare target: current -> object argument: anObject];
	while (comparison != NSOrderedSame) {
		CHBinaryTreeStack_PUSH(current);
		current = current->link[comparison == NSOrderedAscending]; // R on YES
		comparison = [self Compare: poInvocationCompare target: current -> object argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
	}
	
	if (current != sentinel) {
		if (m_fuiOptions & (CHTreeOptionsMultiLevel | CHTreeOptionsMultiLeaves))	/* Multi-level or multiple leaf collections allowed? */
			{
			if ([current -> object conformsToProtocol: @protocol (CHMultiLevelTreeP)])
				[current -> object addObject: anObject nestingLevel: a_uiNestingLevel + 1];	/* Support multi-level collections */
			else
				if ([current -> object respondsToSelector: @selector (addObject:)])
					[current -> object addObject: anObject];	/* Support other collections that support the addObject: method */
				else									/* Object is not a collection that supports addObject: */
					{
					id			po;
					bool		fMultiLevel;
					
					po = current -> object;
					current -> object = [self newLeafCollection: po nestingLevel: a_uiNestingLevel + 1 returnsIsMultiLevel: &fMultiLevel];	/* Replace the single leaf object with a new collection */
					if (current -> object == nil)		/* No multi-level collection nor multiple leaves */
						{								/* Same as original behaviour */
						[anObject retain];	// Must retain whether replacing value or adding new node
						// Replace the existing object with the new object.
						[current -> object release];
						current -> object = anObject;
						}
					else								/* We have a new sub-collection */
						{
						if (fMultiLevel)				/* Multi-level collection? Must conform to the extended addobject: nestingLevel: method */
							{
							[current -> object addObject: po nestingLevel: a_uiNestingLevel + 1];	/* Add the object that was the leaf object to the sub-collection */
							[current -> object addObject: anObject nestingLevel: a_uiNestingLevel + 1];	/* Now add the new object to the sub-collection */
							}
						else							/* Multiple leaves. Must conform to addObject: method */
							{
							[current -> object addObject: po];	/* Add the object that was the leaf object to the sub-collection */
							[current -> object addObject: anObject];	/* Now add the new object to the sub-collection */
							}
						[po release];					/* Release the original leaf as it has now been added to (and retained by) the sub-collection */
						}
					}
			}
		else						/* No multi-level collection nor multiple leaves allowed */
			{
			[anObject retain]; // Must retain whether replacing value or adding new node
			// Replace the existing object with the new object.
			[current->object release];
			current->object = anObject;
			}
		// No need to rebalance up the path since we didn't modify the structure
		goto done;
	} else {
		[anObject retain]; // Must retain whether replacing value or adding new node
		current = CHCreateBinaryTreeNodeWithObject(anObject);
		current->left   = sentinel;
		current->right  = sentinel;
		current->level  = 1;
		++count;
		// Link from parent as the proper child, based on last comparison
		parent = CHBinaryTreeStack_POP();
		NSAssert((id) parent != nil, @"Illegal state, parent should never be nil!");
		comparison = [self Compare: poInvocationCompare target: parent -> object argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
		parent->link[comparison == NSOrderedAscending] = current; // R if YES
	}
	
	// Trace back up the path, rebalancing as we go
	BOOL isRightChild;
	while (parent != NULL) {
		isRightChild = (parent->right == current);
		skew(current);
		split(current);
		parent->link[isRightChild] = current;
		// Move to the next node up the path to the root
		current = parent;
		parent = CHBinaryTreeStack_POP();
	}
done:
	CHBinaryTreeStack_FREE(stack);
}

/* CJEC, 8-Jul-13: Support multi-level trees */
- (void) removeObject:(id)anObject nestingLevel: (unsigned int) a_uiNestingLevel {
	if (count == 0 || anObject == nil)
		return;
	++mutations;
	
	CHBinaryTreeNode *parent, *current = header;
	CHBinaryTreeStack_DECLARE();
	CHBinaryTreeStack_INIT();
	
	sentinel ->object = anObject; // Assure that we stop at a leaf if not found.

	NSComparisonResult	comparison;
	NSInvocation *		poInvocationCompare = [[self class] InvocationCompare: anObject nestingLevel: a_uiNestingLevel];	/* Note: Technically, we should use the other object as we're sending the compare*: method to it. But compare*: must be symmetric so we use the (non-nil) argument because we already have it */

	comparison = [self Compare: poInvocationCompare target: current -> object argument: anObject];
	while (comparison != NSOrderedSame) {
		CHBinaryTreeStack_PUSH(current);
		current = current->link[comparison == NSOrderedAscending]; // R on YES
		comparison = [self Compare: poInvocationCompare target: current -> object argument: nil];	/* Note: Argument hasn't changed so don't need to set it */
	}

	// Exit if the specified node was not found in the tree.
	if (current == sentinel) {
		goto done;
	}
	
	if (m_fuiOptions & (CHTreeOptionsMultiLevel | CHTreeOptionsMultiLeaves))	/* CJEC, 19-Jul-13: Support multi-level trees and multiple leaves */
		{
		if ([current -> object conformsToProtocol: @protocol (CHMultiLevelTreeP)])
			{
			[current-> object removeObject: anObject nestingLevel: a_uiNestingLevel + 1];	/* Support multi-level collections */
			if ([current -> object count] > 0)		/* Still objects in the subcollection? Nothing more to do, and no rebalancing necessary */
				goto done;
			}
		else
			if ([current -> object respondsToSelector: @selector (removeObject:)])
				{
				[current -> object removeObject: anObject];	/* Support other collections that support the removeObject: method */
				if ([current -> object count] > 0)	/* Still objects in the subcollection? Nothing more to do, and no rebalancing necessary */
					goto done;
				}									/* Otherwise, object is not a collection that supports object removal or no more objects in the sub-collection, so fall through to the standard removal code, and rebalance the tree */
		}

	[current->object release]; // Object must be released in any case
	--count;
	if (current->left == sentinel || current->right == sentinel) {
		// Single/zero child case -- replace node with non-nil child (if exists)
		parent = CHBinaryTreeStack_TOP;
		NSAssert((id) parent != nil, @"Illegal state, parent should never be nil!");
		parent->link[parent->right == current]
			= current->link[current->left == sentinel];
		free(current);
	} else {
		// Two child case -- replace with minimum object in right subtree
		CHBinaryTreeStack_PUSH(current); // Need to start here when rebalancing
		CHBinaryTreeNode *replacement = current->right;
		while (replacement->left != sentinel) {
			CHBinaryTreeStack_PUSH(replacement);
			replacement = replacement->left;
		}
		parent = CHBinaryTreeStack_TOP;
		// Grab object from replacement node, steal its right child, deallocate
		current->object = replacement->object;
		parent->link[parent->right == replacement] = replacement->right;
		free(replacement);
	}
	
	// Walk back up the path and rebalance as we go
	// Note that 'parent' always has the correct value coming into the loop
	BOOL isRightChild;
	while (current != NULL && stackSize > 1) {
		current = parent;
		(void)CHBinaryTreeStack_POP();
		parent = CHBinaryTreeStack_TOP;
		isRightChild = (parent->right == current);
		
		if (current->left->level < current->level-1 ||
			current->right->level < current->level-1)
		{
			if (current->right->level > --(current->level)) {
				current->right->level = current->level;
			}
			skew(current);
			skew(current->right);
			skew(current->right->right);
			split(current);
			split(current->right);
		}
		parent->link[isRightChild] = current;
	}
done:
	CHBinaryTreeStack_FREE(stack);
}

- (NSString*) debugDescriptionForNode:(CHBinaryTreeNode*)node {
	return [NSString stringWithFormat:@"[%d]\t\"%@\"", node->level, node->object];
}

- (NSString*) dotGraphStringForNode:(CHBinaryTreeNode*)node {
	return [NSString stringWithFormat:@"  \"%@\" [label=\"%@\\n%d\"];\n",
			node->object, node->object, node->level];
}

@end

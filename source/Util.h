/*
 CHDataStructures.framework -- Util.h
 
 Copyright (c) 2008-2010, Quinn Taylor <http://homepage.mac.com/quinntaylor>
 
 This source code is released under the ISC License. <http://www.opensource.org/licenses/isc-license>
 
 Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted, provided that the above copyright notice and this permission notice appear in all copies.
 
 The software is provided "as is", without warranty of any kind, including all implied warranties of merchantability and fitness. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

	Fixes, additions, extensions, port to GNUstep by Christopher Chandler
	Copyright © 2013-2015	Christopher James Elphinstone Chandler, Russell Geoffrey Watts. All Rights Reserved.
	Copyright © 2015-2024	Kinnami Software Corporation. All rights reserved.
 */

/* Before including anything, set essential platform option compiler switches */
#if defined (_WIN32)
#if defined (__MINGW32__)						/* When using MinGW32 or MinGW-w64 */
#define __USE_MINGW_ANSI_STDIO		1			/* Use MinGW-w64 stdio for proper C99 support, such as %llu, _vswprintf(). See https://sourceforge.net/p/mingw-w64/wiki2/printf%20and%20scanf%20family/ */
#include <_mingw.h>
#if defined (__MINGW64__)
#include <sdkddkver.h>							/* Use MSYS2/MinGW-w64 standard version header for 64-bit and 32-bit Windows */
#include <w32api.h>								/* Use the system header provided with Msys2/MinGW-w64 */
#define Windows2008					0x0600		/* Missing from w32api.h. Values identified in /mingw64/x86_64-w64-mingw32/include/sdkkddkver.h so these can also be used to define _WIN32_WINNT */
#define Windows7					0x0601
#define Windows8					0x0602
#define WindowsBlue					0x0603
#define Windows10					0x0A00
#else											/* Otherwise buiding with MinGW32 for 32-bit Windows */
#include <w32api.h>								/* Use the system header provided with Msys/MinGW32 */
#endif	/* defined (__MINGW64__) */
#else											/* Otherwise building with Microsoft Visual C/C++ */
#error "Windows: Not building with MinGW32 nor MinGW-w64? Needs porting"
#endif	/* defined (__MINGW32__) */
#if !defined (_WIN32_WINNT)
#warning "Windows: _WIN32_WINNT is not defined. Normally defined in GNUMakefile or make command line. EG make CPPFLAGS='-D_WIN32_WINNT=WindowsXP'"
#else
#if (_WIN32_WINNT >= WindowsVista) && !defined (__MINGW64_VERSION_MAJOR)
#define __MSVCRT_VERSION__ 			0x0700		/* Note: MinGW32: Allow use of later MSVCRT functions. Windows Vista seems to have v7.0 of MSVCRT.DLL. WindowsXP doesn't always have it. Baseline installation has only v4.0. Note: MinGW-w64 always sets this */
#endif	/* (_WIN32_WINNT >= WindowsVista) && !defined (__MINGW64_VERSION_MAJOR) */
#endif	/* !defined (_WIN32_WINNT) */
#include <ws2tcpip.h>							/* Need to include ws2tcpip.h before windows.h to avoid warning in ws2tcpip.h */
#include <windows.h>							/* Need to includes w32api.h and windows.h before Foundation.h to use WSAEVENT */
#define _CRT_RAND_S								/* For rand_s() */
#endif	/* defined (_WIN32) */

#if defined (__APPLE__)
#define _DARWIN_USE_64_BIT_INODE	1			/* Always use 64-bit inode definitions for things like struct stat */
#endif	/* defined (__APPLE__) */

#if defined (__linux__)
#define _GNU_SOURCE					1			/* Required for dladdr() and struct Dl_info on Linux */
#if !defined (__ANDROID__)
#include <bsd/stdlib.h>							/* For arc4random(3bsd). Android defines this in stdio.h */
#endif	/* !defined (__ANDROID__) */
#endif	/* defined (__linux__) */

/* Include the essential Objective-C environment umbrella header file(s) */
#import <Foundation/Foundation.h>				/* See "Foundation Framework Reference" and "Foundation Reference Update" */

#if defined (_WIN32)
typedef uint32_t	u_int32_t;					/* Missing in Windows. Defined in sys/types.h on UNIX */
#endif	/* defined (_WIN32) */

/**
 @file Util.h
 A group of utility C functions for simplifying common exceptions and logging.
 */

/* Newer Objective-C environments define NS_DESIGNATED_INITIALIZER to identify designated initialisers. Define this for backward compatibility */
#if !defined (NS_DESIGNATED_INITIALIZER)
#define NS_DESIGNATED_INITIALIZER
#endif	/* !defined (NS_DESIGNATED_INITIALIZER) */

/* CJEC, 17-Jul-20: Add additional definitions for building with GNUstep
*/
#if defined (GNUSTEP)

/* Defined in Apple's objc-api.h
*/
#if !defined(OBJC_EXTERN)
#   if defined(__cplusplus)
#       define OBJC_EXTERN extern "C" 
#   else
#       define OBJC_EXTERN extern
#   endif
#endif

#if !defined(OBJC_VISIBLE)
#   if TARGET_OS_WIN32
#       if defined(BUILDING_OBJC)
#           define OBJC_VISIBLE __declspec(dllexport)
#       else
#           define OBJC_VISIBLE __declspec(dllimport)
#       endif
#   else
#       define OBJC_VISIBLE  __attribute__((visibility("default")))
#   endif
#endif

#if !defined(OBJC_EXPORT)
#   define OBJC_EXPORT  OBJC_EXTERN OBJC_VISIBLE
#endif

#endif	/* defined (GNUSTEP) */


/** Macro for reducing visibility of symbol names not indended to be exported. */
#define HIDDEN __attribute__((visibility("hidden")))

/** Macro for designating symbols as being unused to suppress compile warnings. */
#define UNUSED __attribute__((unused))

#pragma mark -

/** Global variable to store the size of a pointer only once. */
OBJC_EXPORT size_t kCHPointerSize;

/**
 Simple function for checking object equality, to be used as a function pointer.
 
 @param o1 The first object to be compared.
 @param o2 The second object to be compared.
 @return <code>[o1 isEqual:o2]</code>
 */
HIDDEN BOOL objectsAreEqual(id o1, id o2);

/**
 Simple function for checking object identity, to be used as a function pointer.
 
 @param o1 The first object to be compared.
 @param o2 The second object to be compared.
 @return <code>o1 == o2</code>
 */
HIDDEN BOOL objectsAreIdentical(id o1, id o2);

/**
 Determine whether two collections enumerate the equivalent objects in the same order.
 
 @param collection1 The first collection to be compared.
 @param collection2 The second collection to be compared.
 @return Whether the collections are equivalent.
 
 @throw NSInvalidArgumentException if one of both of the arguments do not respond to the @c -count or @c -objectEnumerator selectors.
 */
OBJC_EXPORT BOOL collectionsAreEqual(id collection1, id collection2);

/**
 Generate a hash for a collection based on the count and up to two objects. If objects are provided, the result of their -hash method will be used.
 
 @param count The number of objects in the collection.
 @param o1 The first object to include in the hash.
 @param o2 The second object to include in the hash.
 @return An unsigned integer that can be used as a table address in a hash table structure.
 */
HIDDEN NSUInteger hashOfCountAndObjects(NSUInteger count, id o1, id o2);

#pragma mark -

/**
 Convenience function for raising an exception for an invalid range (index).
 
 Currently, there is no support for calling this function from a C function.
 
 @param aClass The class object for the originator of the exception. Callers should pass the result of <code>[self class]</code> for this parameter.
 @param method The method selector where the problem originated. Callers should pass @c _cmd for this parameter.
 @param index The offending index passed to the receiver.
 @param elements The number of elements present in the receiver.
 
 @throw NSRangeException
 
 @see \link NSException#raise:format: +[NSException raise:format:]\endlink
 */
OBJC_EXPORT void CHIndexOutOfRangeException(Class aClass, SEL method,
                                       NSUInteger index, NSUInteger elements);

/**
 Convenience function for raising an exception on an invalid argument.
 
 Currently, there is no support for calling this function from a C function.
 
 @param aClass The class object for the originator of the exception. Callers should pass the result of <code>[self class]</code> for this parameter.
 @param method The method selector where the problem originated. Callers should pass @c _cmd for this parameter.
 @param str An NSString describing the offending invalid argument.
 
 @throw NSInvalidArgumentException
 
 @see \link NSException#raise:format: +[NSException raise:format:]\endlink
 */
OBJC_EXPORT void CHInvalidArgumentException(Class aClass, SEL method, NSString *str);

/**
 Convenience function for raising an exception on an invalid nil object argument.
 
 Currently, there is no support for calling this function from a C function.
 
 @param aClass The class object for the originator of the exception. Callers should pass the result of <code>[self class]</code> for this parameter.
 @param method The method selector where the problem originated. Callers should pass @c _cmd for this parameter.
 
 @throw NSInvalidArgumentException
 
 @see CHInvalidArgumentException()
 */
OBJC_EXPORT void CHNilArgumentException(Class aClass, SEL method);

/**
 Convenience function for raising an exception when a collection is mutated.
 
 Currently, there is no support for calling this function from a C function.
 
 @param aClass The class object for the originator of the exception. Callers should pass the result of <code>[self class]</code> for this parameter.
 @param method The method selector where the problem originated. Callers should pass @c _cmd for this parameter.
 
 @throw NSGenericException
 
 @see \link NSException#raise:format: +[NSException raise:format:]\endlink
 */
OBJC_EXPORT void CHMutatedCollectionException(Class aClass, SEL method);

/**
 Convenience function for raising an exception for un-implemented functionality.
 
 Currently, there is no support for calling this function from a C function.
 
 @param aClass The class object for the originator of the exception. Callers should pass the result of <code>[self class]</code> for this parameter.
 @param method The method selector where the problem originated. Callers should pass @c _cmd for this parameter.
 
 @throw NSInternalInconsistencyException
 
 @see \link NSException#raise:format: +[NSException raise:format:]\endlink
 */
OBJC_EXPORT void CHUnsupportedOperationException(Class aClass, SEL method);

/**
 Provides a more terse alternative to NSLog() which accepts the same parameters. The output is made shorter by excluding the date stamp and process information which NSLog prints before the actual specified output.
 
 @param format A format string, which must not be nil.
 @param ... A comma-separated list of arguments to substitute into @a format.
 
 Read <b>Formatting String Objects</b> and <b>String Format Specifiers</b> on <a href="http://developer.apple.com/documentation/Cocoa/Conceptual/Strings/"> this webpage</a> for details about using format strings. Look for examples that use @c NSLog() since the parameters and syntax are idential.
 */
OBJC_EXPORT void CHQuietLog(NSString *format, ...);

/**
 A macro for including the source file and line number where a log occurred.
 
 @param format A format string, which must not be nil.
 @param ... A comma-separated list of arguments to substitute into @a format.
 
 This is defined as a compiler macro so it can automatically fill in the file name and line number where the call was made. After printing these values in brackets, this macro calls #CHQuietLog with @a format and any other arguments supplied afterward.
 
 @see CHQuietLog
 */
#ifndef CHLocationLog
#define CHLocationLog(format,...) \
{ \
	NSString *file = [[NSString alloc] initWithUTF8String:__FILE__]; \
	printf("[%s:%d] ", [[file lastPathComponent] UTF8String], __LINE__); \
	[file release]; \
	CHQuietLog((format),##__VA_ARGS__); \
}
#endif

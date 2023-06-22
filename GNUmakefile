#**************************************************************************************#
#
# GNUstep makefile to build CHDataStructures for the GNUstep environment
#
# See http://www.gnustep.org/resources/documentation/Developer/Make/Manual/make_toc.html
#    for details about the GNUstep Makefile system
#
#**************************************************************************************#

# Include the common variables defined by the Makefile Package
include $(GNUSTEP_MAKEFILES)/common.make

# Build an aggregate project. CJEC, 13-Jun-23: TODO: Adapt makefiles to use parallel builds. See GNUstep Make 2.4.0 release notes at https://gnustep.github.io/resources/documentation/Developer/Make/ReleaseNotes/RELEASENOTES

# CJEC, 17-Jul-20: TODO: Add subprojects to build CHDataStructures documentation and tests
SUBPROJECTS = source

-include GNUmakefile.preamble

# Include in the rules for making GNUstep AGGREGATE projects
include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble

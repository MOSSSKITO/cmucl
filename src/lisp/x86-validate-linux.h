/*
 *
 * This code was written as part of the CMU Common Lisp project at
 * Carnegie Mellon University, and has been placed in the public domain.
 *
 */

#ifndef _X86_VALIDATE_LINUX_H_
#define _X86_VALIDATE_LINUX_H_

/*
 * Also look in compiler/x86/parms.lisp for some of the parameters.
 *
 * Address map:
 *
 *  Linux:
 *	0x00000000->0x08000000  128M Unused.
 *	0x08000000->0x10000000  128M C program and memory allocation.
 *	0x10000000->0x20000000  256M Read-Only Space.
 *	0x20000000->0x28000000  128M Binding stack growing up.
 *	0x28000000->0x38000000  256M Static Space.
 *	0x38000000->0x40000000  128M Control stack growing down.
 *	0x40000000->0x48000000  128M Reserved for shared libraries.
 *      0x58000000->0x58100000   16M Foreign Linkage Table
 *	0x58100000->0xBE000000 1631M Dynamic Space.
 *      0xBFFF0000->0xC0000000       Unknown Linux mapping
 *
 *      (Note: 0x58000000 allows us to run on a Linux system on an AMD
 *      x86-64.  Hence we have a gap of unused memory starting at
 *      0x48000000.)
 */

#define READ_ONLY_SPACE_START   (SpaceStart_TargetReadOnly)
#define READ_ONLY_SPACE_SIZE    (0x0ffff000)	/* 256MB - 1 page */

#define STATIC_SPACE_START	(SpaceStart_TargetStatic)
#define STATIC_SPACE_SIZE	(0x0ffff000)	/* 256MB - 1 page */

#if 0
#define BINDING_STACK_START	(0x20000000)
#endif
#define BINDING_STACK_SIZE	(0x07fff000)	/* 128MB - 1 page */

#if 0
#define CONTROL_STACK_START	0x38000000
#endif
#define CONTROL_STACK_SIZE	(0x07fff000 - 8192)

#if 0
#define SIGNAL_STACK_START	CONTROL_STACK_END
#endif
#define SIGNAL_STACK_SIZE	SIGSTKSZ

#define DYNAMIC_0_SPACE_START	(SpaceStart_TargetDynamic)

#ifdef GENCGC
#define DYNAMIC_SPACE_SIZE	(0x66000000)	/* 1.632GB */
#else
#define DYNAMIC_SPACE_SIZE	(0x04000000)	/* 64MB */
#endif

#define DEFAULT_DYNAMIC_SPACE_SIZE	(0x20000000)	/* 512MB */

#ifdef LINKAGE_TABLE
#define FOREIGN_LINKAGE_SPACE_START (LinkageSpaceStart)
#define FOREIGN_LINKAGE_SPACE_SIZE (0x100000)	/* 1MB */
#endif

#endif


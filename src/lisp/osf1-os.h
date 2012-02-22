/*

 $Header: /Volumes/share2/src/cmucl/cvs2git/cvsroot/src/lisp/osf1-os.h,v 1.3 2005/01/13 19:55:00 fgilham Rel $

 This code was written as part of the CMU Common Lisp project at
 Carnegie Mellon University, and has been placed in the public domain.

*/

#ifndef _OSF1_OS_H_
#define _OSF1_OS_H_

#include <sys/types.h>
#include <sys/mman.h>

typedef caddr_t os_vm_address_t;
typedef size_t os_vm_size_t;
typedef off_t os_vm_offset_t;
typedef int os_vm_prot_t;

#define OS_VM_PROT_READ PROT_READ
#define OS_VM_PROT_WRITE PROT_WRITE
#define OS_VM_PROT_EXECUTE PROT_EXEC

#define OS_VM_DEFAULT_PAGESIZE	8192

#endif /* _OSF1_OS_H_ */

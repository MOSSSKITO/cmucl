/*

 This code was written as part of the CMU Common Lisp project at
 Carnegie Mellon University, and has been placed in the public domain.

*/

#ifndef _VARS_H_
#define _VARS_H_

extern void flush_vars(void);
extern struct var *lookup_by_name(char *name);
extern struct var *lookup_by_obj(lispobj obj);
extern struct var *define_var(char *name, lispobj obj, boolean perm);
extern struct var *define_dynamic_var(char *name,
				      lispobj update_fn(struct var *var),

				      boolean perm);

extern char *var_name(struct var *var);
extern lispobj var_value(struct var *var);
extern long var_clock(struct var *var);
extern void var_setclock(struct var *var, long value);

#endif /* _VARS_H_ */

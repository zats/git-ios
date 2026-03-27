#ifndef GIT_IOS_EXIT_H
#define GIT_IOS_EXIT_H

#include <setjmp.h>

void git_ios_install_exit_env(sigjmp_buf *env);
void git_ios_clear_exit_env(void);
int git_ios_take_exit_code(void);
void NORETURN git_ios_exit(int code);

#endif

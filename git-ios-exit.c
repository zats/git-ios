#include "git-compat-util.h"
#include "git-ios-exit.h"

static __thread sigjmp_buf *git_ios_exit_env;
static __thread int git_ios_exit_code;

void git_ios_install_exit_env(sigjmp_buf *env)
{
	git_ios_exit_env = env;
	git_ios_exit_code = 0;
}

void git_ios_clear_exit_env(void)
{
	git_ios_exit_env = NULL;
}

int git_ios_take_exit_code(void)
{
	return git_ios_exit_code;
}

void NORETURN git_ios_exit(int code)
{
	git_ios_exit_code = code & 0xff;
	if (git_ios_exit_env)
		siglongjmp(*git_ios_exit_env, 1);
	_Exit(git_ios_exit_code);
}

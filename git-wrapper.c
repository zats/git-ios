#include "git-compat-util.h"
#include "common-init.h"
#include "git-ios-exit.h"

int git_main(int argc, const char **argv)
{
	sigjmp_buf exit_env;
	setvbuf(stdout, NULL, _IONBF, 0);
	setvbuf(stderr, NULL, _IONBF, 0);
	if (sigsetjmp(exit_env, 0)) {
		int code = git_ios_take_exit_code();
		fflush(NULL);
		git_ios_clear_exit_env();
		return code;
	}
	git_ios_install_exit_env(&exit_env);
	init_git(argv);
	int code = cmd_main(argc, argv);
	fflush(NULL);
	git_ios_clear_exit_env();
	return code;
}

#include "git-compat-util.h"
#include "common-init.h"
#include "git-ios-exit.h"

int git_remote_http_main(int argc, const char **argv)
{
	sigjmp_buf exit_env;
	if (sigsetjmp(exit_env, 0)) {
		int code = git_ios_take_exit_code();
		git_ios_clear_exit_env();
		return code;
	}
	git_ios_install_exit_env(&exit_env);
	init_git(argv);
	int code = cmd_main(argc, argv);
	git_ios_clear_exit_env();
	return code;
}

int git_remote_https_main(int argc, const char **argv)
{
	sigjmp_buf exit_env;
	if (sigsetjmp(exit_env, 0)) {
		int code = git_ios_take_exit_code();
		git_ios_clear_exit_env();
		return code;
	}
	git_ios_install_exit_env(&exit_env);
	init_git(argv);
	int code = cmd_main(argc, argv);
	git_ios_clear_exit_env();
	return code;
}

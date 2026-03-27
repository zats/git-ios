#include "git-compat-util.h"
#include "common-init.h"

int git_main(int argc, const char **argv)
{
	init_git(argv);
	return cmd_main(argc, argv);
}

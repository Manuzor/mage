#include "bar.h"
#include <foo/foo.h>
#include <cstdio>

void printBar(int level)
{
   printFoo(level + 1);
   std::printf("%*s%s\n", 2 * level, "", "Yes, this is the bar!");
}

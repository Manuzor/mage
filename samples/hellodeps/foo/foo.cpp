#include "foo.h"

#include <cstdio>

void printFoo(int level)
{
   std::printf("%*s%s", 2 * level, "", "Well, foo!\n");
}

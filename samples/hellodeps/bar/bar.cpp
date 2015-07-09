#include "bar.h"
#include <foo/foo.h>
#include <cstdio>

void printBar()
{
   printFoo();
   std::printf("Yes, this is the bar!");
}

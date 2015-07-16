#include <foo/foo.h>
#include <bar/bar.h>
#include <cstdio>

int main(int argc, char const *argv[])
{
   std::printf("Printing foo...\n");
   printFoo(1);
   std::printf("Printing bar...\n");
   printBar(1);
   std::printf("Done!\n");
   return 0;
}

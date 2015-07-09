#include <foo/foo.h>
#include <bar/bar.h>
#include <cstdio>

int main(int argc, char const *argv[])
{
   std::printf("Printing foo...\n");
   printFoo();
   std::printf("Printing bar...\n");
   printBar();
   std::printf("Done!\n");
   return 0;
}

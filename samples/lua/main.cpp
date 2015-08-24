#include <lua.hpp>

int main(int argc, const char* argv[])
{
   auto L = luaL_newstate();
   luaL_openlibs(L);
   luaL_dostring(L, "print(\"Hello Buildsystem World!\")");
   lua_close(L);
   return 0;
}

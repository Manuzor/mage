module mage.gen.vs2013;

import mage;
import std.conv : to;

class VS2013Generator
{
  void generate(T)(T target)
  {
    logf("Generator vs2013");
    logf("Target: %s", target.to!string);
    logf("Source Files: %(\n  %s%)", target.getSourceFiles());
  }
}

shared static this() {
  registerGenerator("vs2013", new VS2013Generator());
}

module wand;

import mage;
import std.stdio;
import helloworld;

int main(string[] args) {
  writeln("Running wand.");
  foreach(targetFactory; targetFactories) {
    with(ScopedChdir(targetFactory.filePath.parent)) {
      auto target = targetFactory.create();
      writefln("Target: %s", target);
    }
  }
  return 0;
}

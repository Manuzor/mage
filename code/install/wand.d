module wand;

import mage;
import std.conv : to;
import std.uni : isWhite;
import std.algorithm : strip;


struct GeneratorConfig
{
  string name;
}

auto readGeneratorConfigs(in Path p) {
  GeneratorConfig[] cfgs;
  foreach(line; p.open().byLine()) {
    GeneratorConfig cfg;
    cfg.name = cast(string)line.strip!(a => a.isWhite);
    cfgs ~= cfg;
  }
  return cfgs;
}

// Is expected to be run in the `temp` dir that `mage` created.
int main(string[] args) {
  log("Running wand.");
  ITarget[] targets;
  foreach(targetFactory; targetFactories) {
    with(ScopedChdir(targetFactory.filePath.parent)) {
      auto target = targetFactory.create();
      logf("Found target: %s", target.to!string);
      targets ~= target;
    }
  }
  foreach(target; targets) {
    auto cfgs = readGeneratorConfigs(cwd() ~ "gen.cfg");
    foreach(cfg; cfgs) {
      generatorRegistry[cfg.name].generate(target);
    }
  }
  return 0;
}

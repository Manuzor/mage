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
  Log.info("Running wand.");
  Target[] targets;
  foreach(targetFactory; targetFactories) {
    auto _chdir = ScopedChdir(targetFactory.filePath.parent);
    auto _block = Log.Block(`Creating target %s`, targetFactory.targetName);

    auto target = targetFactory.create();
    target.mageFilePath = targetFactory.filePath;
    targets ~= target;
  }

  // Iterate all configured generators and pass all targets.`
  auto cfgs = readGeneratorConfigs(cwd() ~ "gen.cfg");
  foreach(cfg; cfgs) {
    Log.info(`Generator "%s"`, cfg.name);
    
    auto path = Path(cfg.name);
    if(!path.exists) {
      path.mkdir(true);
    }
    with(ScopedChdir(path)) {
      generatorRegistry[cfg.name].generate(targets);
    }
  }

  return 0;
}

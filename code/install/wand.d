module wand;

import mage;
import std.conv : to;
import std.uni : isWhite;
import std.algorithm : strip;

debug = ShuffleTargets;
debug = LogResolveDeps;

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

const(TypeInfo)[] targetOrder(ITargetWrapper[] targets)
{
  debug(ShuffleTargets)
  {
    import std.random;
    randomShuffle(targets);
  }
  debug(LogResolveDeps) Log.info("Original Target Order: %-(\n       %s%)", targets.map!(a => a.wrappedTypeInfo));

  const(TypeInfo)[] queue;
  void helper(ref const(TypeInfo)[] queue, const(ITargetWrapper) wrapper)
  {
    auto _begin = Log.Block("%s", wrapper.targetName);
    debug(LogResolveDeps) Log.info("Deps: %s", wrapper.dependencies);
    foreach(dep; wrapper.dependencies)
    {
      helper(queue, targets.find!(a => a.wrappedTypeInfo == dep)[0]);
    }
    if(!queue.canFind!(a => a == wrapper.wrappedTypeInfo)) {
      queue ~= wrapper.wrappedTypeInfo;
      debug(LogResolveDeps) Log.info("[add]");
    }
    else
    {
      debug(LogResolveDeps) Log.info("[skip]");
    }
  }
  foreach(wrapper; targets)
  {
    helper(queue, wrapper);
  }

  debug(LogResolveDeps) Log.info("Sorted Target Type Infos (Queue):%-(\n       %s%)", queue);

  return queue;
}

// Is expected to be run in the `temp` dir that `mage` created.
int main(string[] args)
{
  Log.info("Running wand.");
  Target[] targets;

  auto order = targetOrder(wrappedTargets);

  foreach(ti; order) {
    auto wrapper = wrappedTargets.find!(a => a.wrappedTypeInfo == ti)[0];
    auto _chdir = ScopedChdir(wrapper.filePath.parent);
    auto _block = Log.Block(`Creating target %s`, wrapper.targetName);

    auto target = wrapper.create();
    target.mageFilePath = wrapper.filePath;
    target.dependencies = wrapper.dependencies.map!(a => targets.find!(t => a == typeid(t))[0]).array;
    Log.info("Target deps: %s", wrapper.dependencies);
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

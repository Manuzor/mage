module mage.msbuild.link;

import mage;
import mage.msbuild : VSInfo;
import mage.msbuild.cpp : isMatch;
import cpp = mage.msbuild.cpp;
import mage.util.option;

import std.typetuple : allSatisfy;


struct Link
{
  string subSystem;
  string genDebugInfo;
  string enableCOMDATFolding;
  string optimizeReferences;
  string[] dependencies;
  bool inheritDependencies = true;
  Option!bool debugSymbols;
  Path debugSymbolsFile;
}

auto createLink(P...)(ref in VSInfo info, ref cpp.Config cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  // TODO Split this up so it becomes more readable and understandable...

  auto link = Link();

  log.info("+++ +++ +++ +++ +++ +++ +++ +++");

  log.info(`src: %s`, src);
  log.info(`fallbacks: %s`, fallbacks[]);

  if(auto pValue = src.tryGet!(Target[])("linkTargets", fallbacks))
  {
    // Here's the idea:
    // 1. Check for the existance of linkTargets (above).
    // 2. Iterate all targets and see whether their configurations match one of ours.
    // 2.1.1 First, check for ExternalTarget types. These are pre-built binaries, specifying only a set of configurations and libs for them.
    // 2.1.2 Set a linker dependency for the first matching configuration and continue with the loop.
    // 2.2.1 Check for a vcxproj file property on the target. If it is a dependency of ours, this property is set and contains the outputFile.
    // 2.2.2 Check for a matching config and use that outputFile as our dependency.

    auto _ = log.Block("Processing Link Targets");

    foreach(t; *pValue)
    {
      log.info("Target: %s", t.toString());
      if(typeid(t) == typeid(ExternalTarget))
      {
        if(auto pConfigs = t.properties.tryGet!(Properties[])("configurations", fallbacks))
        {
          foreach(ref cfgProp; *pConfigs)
          {
            if(isMatch(cfg, cfgProp))
            {
              auto pLibPath = cfgProp.tryGet!Path("lib").enforce();
              link.dependencies ~= (*pLibPath).normalizedData;
              break;
            }
            log.info("Config doesn't match: %s", cfgProp._values);
          }
        }
        else
        {
          log.info(`No "configurations" property found.`);
        }
        continue;
      }
      auto otherProj = t.properties.tryGet!(cpp.Project*)("%s_vcxproj".format(info.genName));
      if(otherProj is null)
      {
        log.warning(`Link target "%s" can not be added to linker dependencies at this time. You might have a cyclic dependency.`.format(typeid(t)));
        continue;
      }
      foreach(otherCfg; (*otherProj).configs)
      {
        if(isMatch(cfg, otherCfg)) {
          log.info("Adding linker dependency: %s", otherCfg.outputFile);
          link.dependencies ~= otherCfg.link.dependencies[];
          link.dependencies ~= otherCfg.outputFile.normalizedData;
          break;
        }
      }
    }
  }

  if(auto pValue = src.tryGet!bool("debugSymbols", fallbacks)) {
    link.debugSymbols = *pValue;
  }

  log.info("Looking for debugSymbolsFile property setting...");
  if(auto pValue = src.tryGet!Path("debugSymbolsFile", fallbacks)) {
    log.info("Found debugSymbolsFile property setting.");
    link.debugSymbolsFile = *pValue;
  }

  // TODO

  return link;
}

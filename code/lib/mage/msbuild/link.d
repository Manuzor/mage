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

auto createLink(ref cpp.Config cfg, ref in VSInfo info, ref Environment env)
{
  // TODO Split this up so it becomes more readable and understandable...

  auto link = Link();

  auto _link = log.forcedBlock("Link +++ +++ +++ +++ +++ +++ +++ +++");

  env.prettyPrint();

  if(auto var = env.first("linkTargets"))
  {
    auto targets = var.get!(Target[]);

    // Here's the idea:
    // 1. Check for the existance of linkTargets (above).
    // 2. Iterate all targets and see whether their configurations match one of ours.
    // 2.1.1 First, check for ExternalTarget types. These are pre-built binaries, specifying only a set of configurations and libs for them.
    // 2.1.2 Set a linker dependency for the first matching configuration and continue with the loop.
    // 2.2.1 Check for a vcxproj file property on the target. If it is a dependency of ours, this property is set and contains the outputFile.
    // 2.2.2 Check for a matching config and use that outputFile as our dependency.

    auto _ = log.Block("Processing Link Targets");

    foreach(target; targets)
    {
      log.info("Target: %s", target.toString());
      if(typeid(target) == typeid(ExternalTarget))
      {
        if(auto targetCfgs = env.first("configurations"))
        {
          foreach(ref Properties cfgProp; *targetCfgs)
          {
            if(isMatch(cfg, cfgProp))
            {
              auto libPath = cfgProp["lib"].get!Path;
              link.dependencies ~= libPath.normalizedData;
              break;
            }
            log.trace("Config doesn't match: %s", cfgProp.values);
          }
        }
        else
        {
          log.warning(`No "configurations" property found.`);
        }
        continue;
      }
      auto otherProj = target.properties.tryGet("%s_vcxproj".format(info.genName));
      if(otherProj is null)
      {
        log.warning(`Link target "%s" can not be added to linker dependencies at this time. `
                    `You might have a cyclic dependency.`.format(typeid(target)));
        continue;
      }
      foreach(otherCfg; otherProj.get!(cpp.Project*).configs)
      {
        if(isMatch(cfg, otherCfg))
        {
          log.info("Adding linker dependency: %s", otherCfg.outputFile);
          link.dependencies ~= otherCfg.link.dependencies[];
          link.dependencies ~= otherCfg.outputFile.normalizedData;
          break;
        }
      }
    }
  }

  if(auto var = env.first("debugSymbols")) {
    link.debugSymbols = var.get!bool;
  }

  log.trace("Looking for debugSymbolsFile property setting...");
  if(auto var = env.first("debugSymbolsFile")) {
    log.trace("Found debugSymbolsFile property setting.");
    link.debugSymbolsFile = var.get!Path;
  }

  // TODO

  return link;
}

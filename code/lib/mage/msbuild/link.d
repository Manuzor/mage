module mage.msbuild.link;

import mage;
import mage.msbuild : VSInfo;
import mage.msbuild.cpp;
import mage.util.option;

import std.range;
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

auto createLink(ref MSBuildConfig cfg, ref in VSInfo info, ref Environment env)
{
  // TODO Split this up so it becomes more readable and understandable...

  auto link = Link();

  auto _link = log.forcedBlock("Link +++ +++ +++ +++ +++ +++ +++ +++");

  env.prettyPrint();

  if(auto var = env.first("linkTargets"))
  {
    auto linkTargets = var.get!(Target[]);

    // Here's the idea:
    // 1. Check for the existance of linkTargets (above).
    // 2. Iterate all linkTargets and see whether their configurations match one of ours.
    // 2.1.1 First, check for ExternalTarget types. These are pre-built binaries, specifying only a set of configurations and libs for them.
    // 2.1.2 Set a linker dependency for the first matching configuration and continue with the loop.
    // 2.2.1 Check for a vcxproj file property on the target. If it is a dependency of ours, this property is set and contains the outputFile.
    // 2.2.2 Check for a matching config and use that outputFile as our dependency.

    auto _ = log.Block("Processing Link Targets");

    foreach(ref linkTarget; linkTargets)
    {
      auto linkTargetName = linkTarget["name"].toString();
      log.info("Target: %s", linkTargetName);

      auto linkTargetEnv = Environment("%s_ltenv".format(linkTargetName), linkTarget.properties, G.env);
      linkTargetEnv.prettyPrint();

      auto configMatches = matchingConfigurations(env, linkTargetEnv).filter!(a => a[0].name == cfg.name);

      if(configMatches.empty) {
        log.error("No matching configurations found between `%s' and `%s'.", env["name"].toString(), linkTargetName);
      }
      else {
        auto __ = log.Block("Matching configs");
        foreach(ref match; configMatches)
        {
          auto ___ = log.Block("Match");
          match[0].properties.prettyPrint();
          match[1].properties.prettyPrint();
        }
      }

      if(linkTarget.isExternal)
      {
        foreach(ref match; configMatches)
        {
          log.trace(`External link dependency config: %s`, *match[1]);
          auto libPath = (*match[1])["lib"].get!Path;
          if(!libPath.isAbsolute) {
            libPath = env["mageFilePath"].get!Path.parent ~ libPath;
          }
          link.dependencies ~= libPath.normalizedData;
        }
      }
      else
      {
        auto pProj = linkTarget.tryGet("%s_vcxproj".format(info.genName));
        if(pProj is null)
        {
          log.warning(`Link target "%s" can not be added to linker dependencies at this time. `
                      `You might have a cyclic dependency.`.format(linkTargetName));
          continue;
        }

        auto proj = pProj.get!(MSBuildProject*);
        foreach(ref match; configMatches)
        {
          // Find the matching msbuild project's config.
          auto vcxprojConfig = proj.configs.find!(a => a.name == match[1].name);
          link.dependencies ~= vcxprojConfig.front.link.dependencies[];
          link.dependencies ~= vcxprojConfig.front.outputFile.normalizedData;
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

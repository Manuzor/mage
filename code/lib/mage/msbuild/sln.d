module mage.msbuild.sln;

import mage;
import mage.msbuild : VSInfo;
import cpp = mage.msbuild.cpp;


void generateFile(ref in VSInfo info, cpp.Project[] projects, in Path slnPath)
{
  auto _ = log.Block(`Generate .sln File "%s"`, slnPath);
  log.trace("The original list of projects: %s", projects.map!(a => a.name));

  // Prioritize those that have the "isStartup" flag set.
  projects.partition!( a => a.isStartup );

  log.trace("The sorted list of projects: %s", projects.map!(a => a.name));

  // Collect all possible configurations.
  string[string] cfgs;
  foreach(proj; projects)
  {
    foreach(cfg; proj.configs)
    {
      auto cfgString = "%s|%s".format(cfg.name, cfg.architecture);
      cfgs[cfgString] = cfgString;
    }
  }

  import mage.util.stream;
  if(!slnPath.parent.exists) {
    slnPath.parent.mkdir();
  }
  auto stream = FileStream(slnPath);
  stream.indentString = "\t";

  auto __ = log.Block("Writing .sln File.");

  // Header
  stream.writeln(`Microsoft Visual Studio Solution File, Format Version %s0`.format(info.toolsVersion));
  stream.writeln(`# Visual Studio %s`.format(info.year));

  foreach(proj; projects)
  {
    auto typeID = "{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}";
    auto projGuidString = "{%s}".format(proj.guid).toUpper();
    auto _projBlock = log.forcedBlock("Processing project %s %s", proj.name, projGuidString);
    auto projFilePath = Path(proj.name) ~ "%s.vcxproj".format(proj.name);
    stream.writeln(`Project("%s") = "%s", "%s", "%s"`.format(typeID, proj.name, projFilePath, projGuidString));
    stream.indent();
    scope(exit) {
      stream.dedent();
      stream.writeln("EndProject");
    }

    {
      stream.writeln(`ProjectSection(ProjectDependencies) = postProject`);
      stream.indent();
      scope(exit) {
        stream.dedent();
        stream.writeln("EndProjectSection");
      }
      auto allDeps = proj.target.properties["dependencies"];
      auto deps = allDeps.get!(Target[]).filter!(a => typeid(a) is typeid(ExternalTarget));
      auto vcxprojPropertyName = "%s_vcxproj".format(info.genName);
      auto projDeps = deps.map!(a => a.properties[vcxprojPropertyName].get!(cpp.Project*));
      log.info("Deps: %s", projDeps.map!(a => "%s {%s}".format(a.name, a.guid.toString().toUpper())));
      foreach(ref projDep; projDeps)
      {
        auto guidString = "{%s}".format(projDep.guid).toUpper();
        log.info("Writing project dep: %s", guidString);
        stream.writeln("%s = %s".format(guidString, guidString));
      }
    }
  }

  // Global
  {
    stream.writeln("Global");
    stream.indent();
    scope(exit) {
      stream.dedent();
      stream.writeln("EndGlobal");
    }

    {
      stream.writeln("GlobalSection(SolutionConfigurationPlatforms) = preSolution");
      stream.indent();
      scope(exit) {
        stream.dedent();
        stream.writeln("EndGlobalSection");
      }
      foreach(cfg, _; cfgs) {
        stream.writeln("%s = %s".format(cfg, cfg));
      }
    }

    {
      stream.writeln("GlobalSection(ProjectConfigurationPlatforms) = postSolution");
      stream.indent();
      scope(exit) {
        stream.dedent();
        stream.writeln("EndGlobalSection");
      }
      // TODO
      //stream.writeln("# TODO");
      foreach(proj; projects) {
        auto guidString = "{%s}".format(proj.guid).toUpper();
        foreach(cfg; proj.configs) {
          auto cfgString = "%s|%s".format(cfg.name, cfg.architecture);
          stream.writeln("%s.%s.ActiveCfg = %s".format(guidString, cfgString, cfgString));
          stream.writeln("%s.%s.Build.0 = %s".format(guidString, cfgString, cfgString));
        }
      }
    }
    {
      stream.writeln("GlobalSection(ExtensibilityGlobals) = postSolution");
      stream.indent();
      scope(exit) {
        stream.dedent();
        stream.writeln("EndGlobalSection");
      }
    }
    {
      stream.writeln("GlobalSection(ExtensibilityAddIns) = postSolution");
      stream.indent();
      scope(exit) {
        stream.dedent();
        stream.writeln("EndGlobalSection");
      }
    }
  } // Global
}

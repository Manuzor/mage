/// Common code for Visual Studio generators.
module mage.gen.vsCommon;

import mage;

import mage.util.option;
import mage.util.reflection;
import mage.msbuild;
import cpp = mage.msbuild.cpp;
import vcxproj = mage.msbuild.vcxproj;
import sln = mage.msbuild.sln;

import std.format : format;
import std.conv : to;
import std.uuid;


class VSGeneratorBase : IGenerator
{
  protected VSInfo info;

  this()
  {
    info.supportedLanguages ~= "cpp";
  }

  override void generate(Target[] targets)
  {
    cpp.Project[] projects;
    auto slnName = *G.first("name").enforce("Global property `name' must be set.");
    auto _generateBlock = log.Block(`Generating for project "%s"`, slnName);

  targetProcessing:
    foreach(target; targets)
    {
      auto targetName = target.properties["name"].get!string();
      auto _ = log.Block(`Processing target "%s"`.format(targetName));

      auto targetEnv = Environment("%s_env".format(targetName), target.properties, G.env);

      auto targetType = targetEnv.first("type").get!string();
      log.trace(`Target type is "%s"`, targetType);
      if(targetType == "none") {
        log.trace(`Skipping target.`);
        continue;
      }

      string lang;
      {
        auto varLang = targetEnv.first("language");
        if(!varLang.hasValue()) {
          log.error("The `language' property has to be set either as a global property, or on a per-Target basis.");
          assert(0);
        }
        lang = varLang.get!string();
      }
      log.info(`Language "%s"`.format(lang));
    languageProcessing:
      foreach(supportedLang; info.supportedLanguages)
      {
        if(lang != supportedLang) {
          continue languageProcessing;
        }

        // Consolidate all "includePaths" in the target properties.
        Path[] allIncludePaths = targetEnv.all("includePaths").map!(a => a.get!(Path[])).joiner().array();
        log.info("Include paths: %(\n...| - %s%)", allIncludePaths);
        target.properties["includePaths"] = allIncludePaths;
        auto proj = cpp.createProject(info, target);
        proj.toolsVersion = info.toolsVersion;
        if(auto pValue = target.properties.tryGet("toolsVersion")) {
          proj.toolsVersion = pValue.get!string;
        }
        projects ~= proj;
        target.properties["%s_vcxproj".format(info.genName)] = &projects[$-1];
        continue targetProcessing;
      }

      assert(0, `Unsupported language: "%s"; Supported languages: [%-(%s, %)]`.format(lang, info.supportedLanguages));
    }

    foreach(proj; projects)
    {
      auto filePath = Path(proj.name) ~ "%s.vcxproj".format(proj.name);
      vcxproj.generateFile(proj, filePath);
    }

    // Generate .sln file
    sln.generateFile(info, projects, Path("%s.sln".format(slnName)));
  }
}

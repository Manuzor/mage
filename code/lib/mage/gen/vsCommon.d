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
    auto slnName = *globalProperties.tryGet!string("name")
                                    .enforce("Global name must be set.");
    auto _generateBlock = log.Block(`Generating for project "%s"`, slnName);

    auto defaultLang = defaultProperties.tryGet!string("language");
    assert(defaultLang, `[bug] Missing default property "language" (usually "none").`);
  targetProcessing:
    foreach(target; targets)
    {
      auto _ = log.Block(`Processing target "%s"`.format(target.properties.get!string("name")));

      auto targetType = target.properties.get!string("type", globalProperties, defaultProperties);
      log.trace(`Target type is "%s"`, targetType);
      if(targetType == "none") {
        log.trace(`Skipping target.`);
        continue;
      }

      auto langPtr = target.properties.tryGet!string("language", globalProperties, defaultProperties);
      if(langPtr is null)
      {
        log.error(`The "language" property has to be set either as a global property, or on a per-Target basis.`);
        assert(0);
      }
      auto lang = *langPtr;
      if(langPtr is defaultLang) {
        log.warning(`No explicit "language" property set for target "%s". Falling back to global settings.`.format(target, lang));
      }
      log.info(`Language "%s"`.format(lang));
    languageProcessing:
      foreach(supportedLang; info.supportedLanguages)
      {
        if(lang != supportedLang) {
          continue languageProcessing;
        }

        Path[][] all = target.properties.getAll!(Path[])("includePaths", globalProperties);
        Path[] allIncludePaths = all.joiner().array();
        log.info("Include paths: %(\n...| - %s%)", allIncludePaths);
        target.properties.set!"includePaths" = allIncludePaths;
        auto proj = cpp.createProject(info, target);
        proj.toolsVersion = info.toolsVersion;
        if(auto pValue = target.properties.tryGet!string("toolsVersion")) {
          proj.toolsVersion = *pValue;
        }
        proj.target = target;
        projects ~= proj;
        target.properties.set("%s_vcxproj".format(info.genName), &projects[$-1]);
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

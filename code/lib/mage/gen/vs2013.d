module mage.gen.vs2013;

import mage;
import xml = mage.util.xml;
import std.format : format;
import std.conv : to;

mixin RegisterGenerator!(VS2013Generator, "vs2013");

class VS2013Generator : IGenerator
{
  override void generate(Target[] targets)
  {
    foreach(target; targets) {
      logf("Target: %s", target.to!string);
      logf("Source Files: %(\n  %s%)", target.sourceFiles.get!(const(Path)[]));

      CppProject proj;
      proj.configs.length = 2;

      // Debug Win32
      with(proj.configs[0]) {
        name = "Debug";
        platform = "Win32";
        type = "Application";
        useDebugLibs = "true";
        platformToolset = "v120";
        wholeProgramOptimization = null;
        characterSet = "Unicode";
        linkIncremental = "true";
        with(clCompile) {
          pch = "";
          warningLevel = "Level 3";
          optimization = "Disabled";
          preprocessorDefinitions = [
            "WIN32",
            "_DEBUG",
            "_CONSOLE",
            "_LIB"
          ];
          inheritPreprocessorDefinitions = true;
        }
        with(link) {
          subSystem = "Console";
          genDebugInfo = "true";
        }
      }
      // Release Win32
      with(proj.configs[1]) {
        name = "Release";
        platform = "Win32";
        type = "Application";
        useDebugLibs = "false";
        platformToolset = "v120";
        wholeProgramOptimization = "true";
        characterSet = "Unicode";
        linkIncremental = "false";
        with(clCompile) {
          pch = "";
          warningLevel = "Level 3";
          optimization = "MaxSpeed";
          functionLevelLinking = "true";
          intrinsicFunctions = "true";
          preprocessorDefinitions = [
            "WIN32",
            "NDEBUG",
            "_CONSOLE",
            "_LIB"
          ];
          inheritPreprocessorDefinitions = true;
        }
        with(link) {
          subSystem = "Console";
          genDebugInfo = "true";
          enableCOMDATFolding = "true";
          optimizeReferences = "true";
        }
      }
      proj.generateVcxproj(Path("%s.vcxproj".format(target.name.get!string)));
    }
  }
}

void generateVcxproj(in CppProject proj, in Path outFile)
{
  import mage.util.stream : FileStream;

  xml.Doc doc;
  doc.append(proj);
  log("Writing vcxproj file to: %s".format(outFile));
  auto s = FileStream(outFile);
  xml.serialize(s, doc);
}

struct CppProject
{
  string name;
  CppConfig[] configs;
  Path[] headers;
  Path[] cpps;
  Path[] otherFiles;
}

struct CppConfig
{
  string name;
  string platform;
  string type;
  string useDebugLibs;
  string platformToolset;
  string characterSet;
  string wholeProgramOptimization;
  string linkIncremental;
  ClCompile clCompile;
  Link link;
}

struct ClCompile
{
  string warningLevel;
  string pch;
  string optimization;
  string functionLevelLinking;
  string intrinsicFunctions;
  string[] preprocessorDefinitions;
  bool inheritPreprocessorDefinitions;
}

xml.Element* append(P)(ref P parent, in CppProject proj)
  if(xml.isSomeParent!P)
{
  auto c = parent.child("Project");
  with(c) {
    attr("DefaultTargets", "Build");
    attr("ToolsVersion", "12.0");
    attr("xmlns", "http://schemas.microsoft.com/developer/msbuild/2003");
    with(child("ItemGroup")) {
      attr("Label", "ProjectConfigurations");
      foreach(cfg; proj.configs) {
        with(child("ProjectConfiguration")) {
          attr("Include", "%s|%s".format(cfg.name, cfg.platform));
          child("Configuration").text(cfg.name);
          child("Platform").text(cfg.platform);
        }
      }
    }
    with(child("PropertyGroup")) {
      attr("Label", "Globals");
      child("ProjectGuid").text(`{76793D1E-7BA3-4DBD-A492-2B831B56D616}`);
      child("Keyword").text("Win32Proj");
      child("RootNamespace").text("one");
    }
    with(child("Import")) {
      attr("Project", `$(VCTargetsPath)\Microsoft.Cpp.Default.props`);
    }
    foreach(cfg; proj.configs) {
      with(child("PropertyGroup")) {
        attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.platform));
        attr("Label", "Configuration");
        assert(cfg.type, "Need a configuration type!");
        child("ConfigurationType").text(cfg.type);
        if(cfg.useDebugLibs) {
          child("UseDebugLibraries").text(cfg.useDebugLibs);
        }
        if(cfg.platformToolset) {
          child("PlatformToolset").text(cfg.platformToolset);
        }
        if(cfg.wholeProgramOptimization) {
          child("WholeProgramOptimization").text(cfg.wholeProgramOptimization);
        }
        if(cfg.characterSet) {
          child("CharacterSet").text(cfg.characterSet);
        }
      }
    }
    with(child("Import")) {
      attr("Project", `$(VCTargetsPath)\Microsoft.Cpp.props`);
    }
    with(child("ImportGroup")) {
      attr("Label", "ExtensionSettings");
    }
    with(child("ImportGroup")) {
      attr("Label", "PropertySheets");
      attr("Condition", "'$(Configuration)|$(Platform)'=='Debug|Win32'");
      with(child("Import")) {
        attr("Project", `$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props`);
        attr("Condition", `exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')`);
        attr("Label", `LocalAppDataPlatform`);
      }
    }
    with(child("ImportGroup")) {
      attr("Label", "PropertySheets");
      attr("Condition", `'$(Configuration)|$(Platform)'=='Release|Win32'`);
      with(child("Import")) {
        attr("Project", `$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props`);
        attr("Condition", `exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')`);
        attr("Label", `LocalAppDataPlatform`);
      }
    }
    with(child("PropertyGroup")) {
      attr("Label", "UserMacros");
    }
    foreach(cfg; proj.configs) {
      with(child("PropertyGroup")) {
        attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.platform));
        child("LinkIncremental").text(cfg.linkIncremental);
      }
    }
    // Item definition groups
    foreach(cfg; proj.configs) {
      auto n = child("ItemDefinitionGroup");
      with(n) {
        attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.platform));
        (*n).append(cfg.clCompile);
        (*n).append(cfg.link);
      }
    }
    with(child("ItemGroup")) {}
    with(child("Import")) {
      attr("Project", `$(VCTargetsPath)\Microsoft.Cpp.targets`);
    }
    with(child("ImportGroup")) {
      attr("Label", `ExtensionTargets`);
    }
  } // /Project
  return c;
}

xml.Element* append(P)(ref P parent, in ClCompile cl)
  if(xml.isSomeParent!P)
{
  auto n = parent.child("ClCompile");
  with(n) {
    child("PrecompiledHeader").text(cl.pch);
    child("WarningLevel").text(cl.warningLevel);
    child("Optimization").text(cl.optimization);
    if(cl.functionLevelLinking) child("FunctionLevelLinking").text(cl.functionLevelLinking);
    if(cl.intrinsicFunctions) child("IntrinsicFunctions").text(cl.intrinsicFunctions);
    auto defs = cl.preprocessorDefinitions.dup;
    if(cl.inheritPreprocessorDefinitions) {
      defs ~= "%(PreprocessorDefinitions)";
    }
    child("PreprocessorDefinitions").text("%-(%s;%)".format(defs));
  }
  return n;
}

struct Link
{
  string subSystem;
  string genDebugInfo;
  string enableCOMDATFolding;
  string optimizeReferences;
}

xml.Element* append(P)(ref P parent, in Link lnk)
  if(xml.isSomeParent!P)
{
  auto n = parent.child("Link");
  with(n) {
    child("SubSystem").text(lnk.subSystem);
    child("GenerateDebugInformation").text(lnk.genDebugInfo);
    if(lnk.enableCOMDATFolding) child("EnableCOMDATFolding").text(lnk.enableCOMDATFolding);
    if(lnk.optimizeReferences) child("OptimizeReferences").text(lnk.optimizeReferences);
  }
  return n;
}

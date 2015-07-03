module mage.gen.vs2013;

import mage;
import xml = mage.util.xml;
import std.format : format;
import std.conv : to;
import mage.util.option;
import mage.util.reflection;

mixin RegisterGenerator!(VS2013Generator, "vs2013");

class VS2013Generator : IGenerator
{
  override void generate(Target[] targets)
  {
    foreach(target; targets)
    {
      auto proj = cppProject(target);
      proj.generateVcxproj(Path("%s.vcxproj".format(target.name.get!string())));
    }
  }

  CppProject cppProject(Target target)
  {
    auto sourceFiles = target.sourceFiles.get!(const(Path)[]);
    Log.info("Source Files: %-(%s, %)".format(sourceFiles));

    const(Properties)[] cfgs = target.properties.tryGet("configurations", globalProperties, defaultProperties)
                                                .enforce("No configurations found")
                                                .get!(const(Properties)[]);
    CppProject proj;
    foreach(ref cfgProps; cfgs)
    {
      CppConfig cfg;
      cfg.setNameFrom(cfgProps).enforce("A configuration needs a name!");
      Log.info("Configuration: %s".format(cfg.name));
      cfg.setArchitectureFrom(cfgProps, globalProperties, defaultProperties).enforce("A configuration needs an architecture!");
      Log.info("Architecture: %s".format(cfg.architecture));
      cfg.setTypeFrom(target.properties);
      cfg.setUseDebugLibsFrom(cfgProps, globalProperties, defaultProperties);
      cfg.platformToolset = "v120";
      cfg.characterSet = "Unicode";
      cfg.wholeProgramOptimization = true;
      cfg.linkIncremental = true;
      cfg.setClCompileFrom(cfgProps, globalProperties, defaultProperties);
      cfg.setLinkFrom(cfgProps, globalProperties, defaultProperties);

      proj.configs.length += 1;
      proj.configs[$-1] = cfg;
    }
    return proj;
  }
}

void generateVcxproj(in CppProject proj, in Path outFile)
{
  import mage.util.stream : FileStream;

  xml.Doc doc;
  doc.append(proj);
  Log.info("Writing vcxproj file to: %s".format(outFile));
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
  string architecture;
  string type;
  Option!bool useDebugLibs;
  string platformToolset;
  string characterSet;
  Option!bool wholeProgramOptimization;
  Option!bool linkIncremental;
  ClCompile clCompile;
  Link link;


  static shared string[string] architectureMap;

  /// Translate a general mage architecture name to a MSBuild one.
  static string trPlatform(string architectureName) {
    auto mapped = architectureName in architectureMap;
    return *mapped.enforce("Unsupported architecture: %s".format(architectureName));
  }

  static string trWarningLevel(int level) {
    return "Level %s".format(level);
  }

  static string trOptimization(int level) {
    try {
      return [ "Disabled", "MinSize", "MaxSpeed", "Full" ][level];
    }
    catch(core.exception.RangeError) {
      Log.warning("Unsupported warning level '%'".format(level));
    }
    return null;
  }
}

shared static this()
{
  CppConfig.architectureMap["x86"]    = "Win32";
  CppConfig.architectureMap["x86_64"] = "x64";
}

/// Set the config name from some properties.
bool setNameFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet("name", fallbacks);
  if(pValue is null) {
    return false;
  }
  cfg.name = pValue.get!(const(string));
  return true;
}

unittest
{
  CppConfig cfg;
  Properties props;
  assert(cfg.setNameFrom(props) == false);
  props.name = "foo";
  assert(cfg.setNameFrom(props) == true);
  assert(cfg.name == "foo");

  assert(!__traits(compiles, cfg.setNameFrom()));
}

/// Set the config name from some properties.
/// Returns: True if the given properties contain a architecture field
bool setArchitectureFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet("architecture", fallbacks);
  if(pValue is null) {
    return false;
  }
  auto architectureName = pValue.get!(const(string));
  cfg.architecture = CppConfig.trPlatform(architectureName);
  return true;
}

unittest
{
  CppConfig cfg;
  Properties props;
  assert(cfg.setArchitectureFrom(props) == false);
  props.architecture = "x86_64";
  assert(cfg.setArchitectureFrom(props) == true);
  assert(cfg.architecture == "x64");
  props.architecture = "x86";
  assert(cfg.setArchitectureFrom(props) == true);
  assert(cfg.architecture == "Win32");
}

bool setTypeFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet("type", fallbacks);
  if(pValue is null) {
    return false;
  }
  auto typeName = pValue.get!(const(string))();
  switch(typeName) {
    case "executable":
      cfg.type = "Application";
      break;
    case "library":
    {
      auto libType = src.tryGet("libType", fallbacks)
                        .enforce("")
                        .get!(const(LibraryType))();
      final switch(libType)
      {
        case LibraryType.Static: assert(0, "Not implemented");
        case LibraryType.Shared: assert(0, "Not implemented");
      }
    }
    default: assert(0, "Not implemented");
  }

  return true;
}

unittest
{
  CppConfig cfg;
  Properties props;
  assert(cfg.setTypeFrom(props) == false);
  props.type = "executable";
  assert(cfg.setTypeFrom(props) == true);
  assert(cfg.type == "Application");
}

/// Tries for the property "useDebugLibs". If it is not found,
/// and the "name" property contains the string "release"
/// (case insensitive), the debug libs will not be used.
bool setUseDebugLibsFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet("useDebugLibs", fallbacks);
  if(pValue !is null) {
    cfg.useDebugLibs = pValue.get!(const(bool))();
    return true;
  }
  // If "use debug libs" was not explicitly given, try to see if the
  // string "release" is contained in the name. If it is, we will
  // not use the debug libs.
  pValue = src.tryGet("name", fallbacks);
  if(pValue is null) {
    return false;
  }
  import std.uni : toLower;
  auto name = pValue.get!(const(string))();
  bool isRelease = name.canFind!((a, b) => a.toLower() == b.toLower())("release");
  cfg.useDebugLibs = !isRelease;
  return true;
}

unittest
{
  CppConfig cfg;
  Properties props;
  assert(cfg.setUseDebugLibsFrom(props) == false);
  props.name = "Release";
  assert(cfg.setUseDebugLibsFrom(props) == true);
  assert(cfg.useDebugLibs.unwrap() == false);
  props.name = "Debug";
  assert(cfg.setUseDebugLibsFrom(props) == true);
  assert(cfg.useDebugLibs.unwrap() == true);
}

bool setClCompileFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pCompilerProps = src.tryGet("compiler", fallbacks);
  if(pCompilerProps is null) {
    return false;
  }
  auto props = pCompilerProps.get!(const(Properties))();
  with(cfg) {
    if(auto pValue = props.tryGet("warningLevel")) {
      clCompile.warningLevel = CppConfig.trWarningLevel(pValue.get!(const(int))());
    }
    if(auto pValue = props.tryGet("pch")) {
      assert(0, "Not implemented");
    }
    if(auto pValue = props.tryGet("optimization")) {
      clCompile.optimization = CppConfig.trOptimization(pValue.get!(const(int))());
    }
    if(auto pValue = props.tryGet("functionLevelLinking")) {
      clCompile.functionLevelLinking = pValue.get!(const(bool))();
    }
    if(auto pValue = props.tryGet("intrinsicFunctions")) {
      clCompile.intrinsicFunctions = pValue.get!(const(bool))();
    }
    if(auto pValue = props.tryGet("defines")) {
      clCompile.defines = pValue.get!(const(string[]))().dup;
    }
    if(auto pValue = props.tryGet("inheritDefines")) {
      clCompile.inheritDefines = pValue.get!(const(bool))();
    }
  }
  return true;
}

bool setLinkFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pLinkerProps = src.tryGet("linker", fallbacks);
  if(pLinkerProps is null) {
    return false;
  }

  // TODO

  return true;
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
          attr("Include", "%s|%s".format(cfg.name, cfg.architecture));
          child("Configuration").text(cfg.name);
          child("Platform").text(cfg.architecture);
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
        attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.architecture));
        attr("Label", "Configuration");
        assert(cfg.type, "Need a configuration type!");
        child("ConfigurationType").text(cfg.type);
        if(cfg.useDebugLibs) {
          child("UseDebugLibraries").text(cfg.useDebugLibs.unwrap().to!string());
        }
        if(cfg.platformToolset) {
          child("PlatformToolset").text(cfg.platformToolset);
        }
        if(cfg.wholeProgramOptimization) {
          child("WholeProgramOptimization").text(cfg.wholeProgramOptimization.unwrap().to!string());
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
        attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.architecture));
        if(cfg.linkIncremental) {
          child("LinkIncremental").text(cfg.linkIncremental.unwrap().to!string());
        }
      }
    }
    // Item definition groups
    foreach(cfg; proj.configs) {
      auto n = child("ItemDefinitionGroup");
      with(n) {
        attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.architecture));
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

struct ClCompile
{
  string warningLevel;
  string pch;
  string optimization;
  Option!bool functionLevelLinking;
  Option!bool intrinsicFunctions;
  string[] defines;
  bool inheritDefines = true;
}

xml.Element* append(P)(ref P parent, in ClCompile cl)
  if(xml.isSomeParent!P)
{
  auto n = parent.child("ClCompile");
  with(n) {
    if(cl.pch) {
      child("PrecompiledHeader").text(cl.pch);
    }
    if(cl.warningLevel) {
      child("WarningLevel").text(cl.warningLevel);
    }
    if(cl.optimization) {
      child("Optimization").text(cl.optimization);
    }
    if(cl.functionLevelLinking)  {
      child("FunctionLevelLinking").text(cl.functionLevelLinking.unwrap().to!string());
    }
    if(cl.intrinsicFunctions) {
      child("IntrinsicFunctions").text(cl.intrinsicFunctions.unwrap().to!string());
    }
    auto defs = cl.defines.dup;
    if(cl.inheritDefines) {
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
    if(lnk.subSystem) {
      child("SubSystem").text(lnk.subSystem);
    }
    if(lnk.genDebugInfo) {
      child("GenerateDebugInformation").text(lnk.genDebugInfo);
    }
    if(lnk.enableCOMDATFolding) {
      child("EnableCOMDATFolding").text(lnk.enableCOMDATFolding);
    }
    if(lnk.optimizeReferences) {
      child("OptimizeReferences").text(lnk.optimizeReferences);
    }
  }
  return n;
}

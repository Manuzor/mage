module mage.gen.vs2013;

import mage;
import xml = mage.util.xml;
import std.format : format;
import std.conv : to;
import std.uuid;
import mage.util.option;
import mage.util.reflection;

mixin RegisterGenerator!(VS2013Generator, "vs2013");

class VS2013Generator : IGenerator
{
  static string[] supportedLanguages;

  shared static this()
  {
    supportedLanguages ~= "cpp";
  }

  override void generate(Target[] targets)
  {
    CppProject[] projects;
    auto slnName = globalProperties.tryGet("name")
                                   .enforce("Global name must be set.")
                                   .get!(const(string))();
    auto _generateBlock = Log.Block(`Generating for project "%s"`, slnName);

    auto defaultLang = defaultProperties.tryGet("language");
    assert(defaultLang, `[bug] Missing global property "language".`);
    targetProcessing: foreach(target; targets)
    {
      auto _ = Log.Block(`Processing target "%s"`.format(target.name));

      auto langPtr = target.properties.tryGet("language", globalProperties, defaultProperties);
      auto lang = langPtr.get!(const(string));
      if(langPtr is defaultLang) {
        Log.warning(`No explicit "language" property set for target "%s". Falling back to global settings.`.format(target, lang));
      }
      Log.info(`Language "%s"`.format(lang));
      languageProcessing: foreach(supportedLang; supportedLanguages)
      {
        if(lang != supportedLang) {
          continue languageProcessing;
        }

        auto proj = cppProject(target);
        projects ~= proj;
        continue targetProcessing;
      }

      assert(0, `Unsupported language: "%s"; Supported languages: [%-(%s, %)]`.format(lang, supportedLanguages));
    }

    // Generate the vcxproj files
    foreach(proj; projects) {
      auto filePath = Path(proj.name) ~ "%s.vcxproj".format(proj.name);
      generateVcxproj(proj, filePath);
    }

    // Generate .sln file
    generateSln(projects, Path("%s.sln".format(slnName)));
  }
}

void generateSln(CppProject[] projects, in Path slnPath)
{
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
  
  // Header
  stream.writeln(`Microsoft Visual Studio Solution File, Format Version 12.00`);
  stream.writeln(`# Visual Studio 2013`);

  foreach(proj; projects) {
    auto typeID = "{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}";
    auto projGuidString = "{%s}".format(proj.guid).toUpper();
    auto projFilePath = Path(proj.name) ~ "%s.vcxproj".format(proj.name);
    stream.writeln(`Project("%s") = "%s", "%s", "%s"`.format(typeID, proj.name, projFilePath, projGuidString));
    stream.indent();
    scope(exit) {
      stream.dedent();
      stream.writeln("EndProject");
    }

    stream.writeln(`ProjectSection(ProjectDependencies) = postProject`);
    stream.indent();
    scope(exit) {
      stream.dedent();
      stream.writeln("EndProjectSection");
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

CppProject cppProject(Target target)
{
  auto name = target.properties.tryGet("name")
                               .enforce("Target must have a name!")
                               .get!(const(string));
  const(Properties)[] cfgs = target.properties.tryGet("configurations", globalProperties, defaultProperties)
                                              .enforce("No configurations found")
                                              .get!(const(Properties)[]);
  auto proj = CppProject(name);
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
    cfg.setWholeProgramOptimizationFrom(cfgProps, globalProperties, defaultProperties);
    cfg.setLinkIncrementalFrom(cfgProps, globalProperties, defaultProperties);
    cfg.setClCompileFrom(cfgProps, globalProperties, defaultProperties);
    cfg.setLinkFrom(cfgProps, globalProperties, defaultProperties);
    cfg.setFilesFrom(cfgProps, target.properties, globalProperties, defaultProperties);

    proj.configs.length += 1;
    proj.configs[$-1] = cfg;
  }
  return proj;
}

void generateVcxproj(in CppProject proj, in Path outFile)
{
  import mage.util.stream : FileStream;

  xml.Doc doc;
  doc.append(proj);
  Log.info("Writing vcxproj file to: %s".format(outFile));
  if(!outFile.parent.exists) {
    outFile.parent.mkdir();
  }
  auto s = FileStream(outFile);
  xml.serialize(s, doc);
}

struct CppProject
{
  string name;
  UUID guid;
  CppConfig[] configs;
  Path[] headers;
  Path[] cpps;
  Path[] otherFiles;

  @disable this();

  this(string name)
  {
    this.name = name;
    this.guid = randomUUID();
  }
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
  Path[] headerFiles;
  Path[] cppFiles;


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
    Log.warning(`Property "name" not found.`);
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
    Log.warning(`Property "architecture" not found.`);
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
    Log.warning(`Property "type" not found.`);
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
    Log.warning(`No "useDebugLibs" Property "name" not found.`);
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

bool setWholeProgramOptimizationFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet("wholeProgramOptimization", fallbacks);
  if(pValue is null) {
    Log.warning(`Property "wholeProgramOptimization" not found.`);
    return false;
  }
  if(cfg.useDebugLibs) {
    Log.warning(`When using debug libs, the option "wholeProgramOptimization" `
                `cannot be set. Visual Studio itself forbids that. Ignoring the setting for now.`);
    return false;
  }
  cfg.wholeProgramOptimization = pValue.get!(const(bool));
  return true;
}

bool setLinkIncrementalFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet("linkIncremental", fallbacks);
  if(pValue is null) {
    Log.warning(`Property "linkIncremental" not found.`);
    return false;
  }
  // TODO Check which options are not compatible with the incremental linking option.
  cfg.linkIncremental = pValue.get!(const(bool));
  return true;
}

bool setClCompileFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pCompilerProps = src.tryGet("compiler", fallbacks);
  if(pCompilerProps is null) {
    Log.warning(`Property "compiler" not found.`);
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
    Log.warning(`Property "linker" not found.`);
    return false;
  }

  // TODO

  return true;
}

bool setFilesFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pFiles = src.tryGet("sourceFiles", fallbacks);
  if(pFiles is null) {
    Log.warning(`Property "sourceFiles" not found.`);
    return false;
  }

  auto pMageFilePath = src.tryGet("mageFilePath", fallbacks);
  if(pMageFilePath is null) {
    Log.warning(`Property "mageFilePath" not found.`);
    return false;
  }

  auto filesRoot = pMageFilePath.get!(const(Path))().parent;
  auto files = pFiles.get!(const(Path[]));
  foreach(file; files.map!(a => cast()a))
  {
    auto _block = Log.Block("Processing file: %s", file);
    if(!file.isAbsolute) {
      file = filesRoot ~ file;
      Log.trace("Made path absolute: %s", file);
    }
    if(file.extension == ".h") {
      cfg.headerFiles ~= file;
    }
    else if(file.extension == ".cpp") {
      cfg.cppFiles ~= file;
    }
    else {
      Log.warning("Unknown file type: %s", file.extension);
    }
  }
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
    foreach(cfg; proj.configs) {

      if(cfg.cppFiles.length)
      {
        with(child("ItemGroup"))
        {
          attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.architecture));
          foreach(file; cfg.cppFiles) {
            with(child("ClCompile")) {
              attr("Include", file.windowsData);
            }
          }
        }
      }

      if(cfg.headerFiles.length)
      {
        with(child("ItemGroup"))
        {
          attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.architecture));
          foreach(file; cfg.headerFiles) {
            with(child("ClInclude")) {
              attr("Include", file.windowsData);
            }
          }
        }
      }
    }
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

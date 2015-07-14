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
    auto slnName = *globalProperties.tryGet!string("name")
                                    .enforce("Global name must be set.");
    auto _generateBlock = log.Block(`Generating for project "%s"`, slnName);

    auto defaultLang = defaultProperties.tryGet!string("language");
    assert(defaultLang, `[bug] Missing default property "language" (usually "none").`);
    targetProcessing: foreach(target; targets)
    {
      auto _ = log.Block(`Processing target "%s"`.format(target.properties.tryGet!string("name")));

      auto targetType = target.properties.get!string("type", globalProperties, defaultProperties);
      log.trace(`Target type is "%s"`, targetType);
      if(targetType == "none") {
        log.trace(`Skipping target.`);
        continue;
      }

      auto langPtr = target.properties.tryGet!string("language", globalProperties, defaultProperties);
      auto lang = *langPtr;
      if(langPtr is defaultLang) {
        log.warning(`No explicit "language" property set for target "%s". Falling back to global settings.`.format(target, lang));
      }
      log.info(`Language "%s"`.format(lang));
      languageProcessing: foreach(supportedLang; supportedLanguages)
      {
        if(lang != supportedLang) {
          continue languageProcessing;
        }

        Path[][] all = target.properties.getAll!(Path[])("includePaths", globalProperties);
        Path[] allIncludePaths = all.joiner().array();
        log.info("Include paths: %(\n...| - %s%)", allIncludePaths);
        target.properties.set!"includePaths" = allIncludePaths;
        auto proj = cppProject(target);
        proj.target = target;
        projects ~= proj;
        target.properties.set!"vs2013vcxproj" = &projects[$-1];
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
      auto deps = proj.target.properties.get!(Target[])("dependencies");
      log.info("Deps: %s", deps.map!(a => "%s {%s}".format(a.properties.get!string("name"), a.properties.get!(CppProject*)("vs2013vcxproj").guid.toString().toUpper())));
      auto projDeps = deps.map!(a => a.properties.get!(CppProject*)("vs2013vcxproj"));
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

CppProject cppProject(Target target)
{
  auto name = *target.properties.tryGet!string("name")
                                .enforce("Target must have a name!");
  auto cfgs = *target.properties.tryGet!(Properties[])("configurations", globalProperties, defaultProperties)
                                .enforce("No configurations found");
  auto proj = CppProject(name);
  foreach(ref cfgProps; cfgs)
  {
    CppConfig cfg;
    cfg.setNameFrom(cfgProps, target.properties).enforce("A configuration needs a name!");
    log.info("Configuration: %s".format(cfg.name));
    cfg.setArchitectureFrom(cfgProps, target.properties, globalProperties, defaultProperties).enforce("A configuration needs an architecture!");
    log.info("Architecture: %s".format(cfg.architecture));
    cfg.setTypeFrom(target.properties);
    cfg.setUseDebugLibsFrom(cfgProps, target.properties, globalProperties, defaultProperties);
    cfg.platformToolset = "v120";
    cfg.characterSet = "Unicode";
    cfg.setWholeProgramOptimizationFrom(cfgProps, target.properties, globalProperties, defaultProperties);
    cfg.setLinkIncrementalFrom(cfgProps, target.properties, globalProperties, defaultProperties);
    cfg.setClCompileFrom(cfgProps, target.properties, globalProperties, defaultProperties);
    cfg.setLinkFrom(cfgProps, target.properties, globalProperties, defaultProperties);
    cfg.setFilesFrom(cfgProps, target.properties, target.properties, globalProperties, defaultProperties);

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
  log.info("Writing vcxproj file to: %s".format(outFile));
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
  Target target;

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
      log.warning("Unsupported warning level '%'".format(level));
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
  auto pValue = src.tryGet!string("name", fallbacks);
  if(pValue is null) {
    log.warning(`Property "name" not found.`);
    return false;
  }
  cfg.name = *pValue;
  return true;
}

unittest
{
  CppConfig cfg;
  Properties props;
  assert(cfg.setNameFrom(props) == false);
  props.set!"name" = "foo";
  assert(cfg.setNameFrom(props) == true);
  assert(cfg.name == "foo");

  assert(!__traits(compiles, cfg.setNameFrom()));
}

/// Set the config name from some properties.
/// Returns: True if the given properties contain a architecture field
bool setArchitectureFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet!string("architecture", fallbacks);
  if(pValue is null) {
    log.warning(`Property "architecture" not found.`);
    return false;
  }
  cfg.architecture = CppConfig.trPlatform(*pValue);
  return true;
}

unittest
{
  CppConfig cfg;
  Properties props;
  assert(cfg.setArchitectureFrom(props) == false);
  props.set!"architecture" = "x86_64";
  assert(cfg.setArchitectureFrom(props) == true);
  assert(cfg.architecture == "x64");
  props.set!"architecture" = "x86";
  assert(cfg.setArchitectureFrom(props) == true);
  assert(cfg.architecture == "Win32");
}

bool setTypeFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet!string("type", fallbacks);
  if(pValue is null) {
    log.warning(`Property "type" not found.`);
    return false;
  }
  switch(*pValue) {
    case "executable":
      cfg.type = "Application";
      break;
    case "library":
    {
      auto libType = src.tryGet!LibraryType("libType", fallbacks)
                        .enforce(`A "library" needs a "libType" property of type "mage.target.LibraryType".`);
      final switch(*libType)
      {
        case LibraryType.Static:
          cfg.type = "StaticLibrary";
          break;
        case LibraryType.Shared: assert(0, "Not implemented (case LibraryType.Shared)");
      }
      break;
    }
    default: assert(0, "Not implemented (Config type)");
  }

  return true;
}

unittest
{
  CppConfig cfg;
  Properties props;
  assert(cfg.setTypeFrom(props) == false);
  props.set!"type" = "executable";
  assert(cfg.setTypeFrom(props) == true);
  assert(cfg.type == "Application");
}

/// Tries for the property "useDebugLibs". If it is not found,
/// and the "name" property contains the string "release"
/// (case insensitive), the debug libs will not be used.
bool setUseDebugLibsFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet!bool("useDebugLibs", fallbacks);
  if(pValue !is null) {
    cfg.useDebugLibs = *pValue;
    return true;
  }
  // If "use debug libs" was not explicitly given, try to see if the
  // string "release" is contained in the name. If it is, we will
  // not use the debug libs.
  auto name = cfg.name;
  if(name.empty) {
    // Name not set on config yet. Let's see if we can find the name in the properties.
    auto pName = src.tryGet!string("name");
    if(pName is null) {
      return false;
    }
    name = *pName;
  }
  bool isRelease = name.canFind!((a, b) => a.toLower() == b.toLower())("release");
  cfg.useDebugLibs = !isRelease;
  return true;
}

unittest
{
  CppConfig cfg;
  Properties props;
  assert(cfg.setUseDebugLibsFrom(props) == false);
  assert(cfg.useDebugLibs.isNone);
  props.set!"name" = "Release";
  assert(cfg.setUseDebugLibsFrom(props) == true);
  assert(cfg.useDebugLibs.isSome);
  assert(cfg.useDebugLibs.unwrap() == false);
  cfg.useDebugLibs.clear();
  props.set!"name" = "Debug";
  assert(cfg.setUseDebugLibsFrom(props) == true);
  assert(cfg.useDebugLibs.isSome);
  assert(cfg.useDebugLibs.unwrap() == true);
}

bool setWholeProgramOptimizationFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet!bool("wholeProgramOptimization", fallbacks);
  if(pValue is null) {
    log.warning(`Property "wholeProgramOptimization" not found.`);
    return false;
  }
  if(cfg.useDebugLibs) {
    log.warning(`When using debug libs, the option "wholeProgramOptimization" `
                `cannot be set. Visual Studio itself forbids that. Ignoring the setting for now.`);
    return false;
  }
  cfg.wholeProgramOptimization = *pValue;
  return true;
}

bool setLinkIncrementalFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet!bool("linkIncremental", fallbacks);
  if(pValue is null) {
    log.warning(`Property "linkIncremental" not found.`);
    return false;
  }
  // TODO Check which options are not compatible with the incremental linking option.
  cfg.linkIncremental = *pValue;
  return true;
}

bool setClCompileFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  with(cfg) {
    if(auto pValue = src.tryGet!(Path[])("includePaths", fallbacks)) {
      clCompile.includePaths = *pValue;
      log.trace("Found includePaths: ", clCompile.includePaths);
    }
    else
    {
      log.trace("No includePaths property found.");
    }
    if(auto pValue = src.tryGet!bool("inheritIncludePaths", fallbacks)) {
      clCompile.inheritIncludePaths = *pValue;
    }
    if(auto pValue = src.tryGet!int("warningLevel", fallbacks)) {
      clCompile.warningLevel = CppConfig.trWarningLevel(*pValue);
    }
    if(auto pValue = src.tryGet!string("pch", fallbacks)) {
      assert(0, "Not implemented (handling of pch property)");
    }
    if(auto pValue = src.tryGet!int("optimization", fallbacks)) {
      clCompile.optimization = CppConfig.trOptimization(*pValue);
    }
    if(auto pValue = src.tryGet!bool("functionLevelLinking", fallbacks)) {
      clCompile.functionLevelLinking = *pValue;
    }
    if(auto pValue = src.tryGet!bool("intrinsicFunctions", fallbacks)) {
      clCompile.intrinsicFunctions = *pValue;
    }
    if(auto pValue = src.tryGet!(string[])("defines", fallbacks)) {
      clCompile.defines = (*pValue).dup;
    }
    if(auto pValue = src.tryGet!bool("inheritDefines", fallbacks)) {
      clCompile.inheritDefines = *pValue;
    }
  }
  return true;
}

bool setLinkFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  // TODO

  return true;
}

bool setFilesFrom(P...)(ref CppConfig cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pFiles = src.tryGet!(Path[])("sourceFiles", fallbacks);
  if(pFiles is null) {
    log.warning(`Property "sourceFiles" not found.`);
    return false;
  }

  auto pMageFilePath = src.tryGet!Path("mageFilePath", fallbacks);
  if(pMageFilePath is null) {
    log.warning(`Property "mageFilePath" not found.`);
    return false;
  }

  auto filesRoot = (*pMageFilePath).parent;
  auto files = *pFiles;
  foreach(file; files.map!(a => cast()a))
  {
    auto _block = log.Block("Processing file: %s", file);
    if(!file.isAbsolute) {
      file = filesRoot ~ file;
      log.trace("Made path absolute: %s", file);
    }
    if(file.extension == ".h") {
      cfg.headerFiles ~= file;
    }
    else if(file.extension == ".cpp") {
      cfg.cppFiles ~= file;
    }
    else {
      log.warning("Unknown file type: %s", file.extension);
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
  const(Path)[] includePaths;
  bool inheritIncludePaths = true;
  string[] defines;
  bool inheritDefines = true;
}

xml.Element* append(P)(ref P parent, in ClCompile cl)
  if(xml.isSomeParent!P)
{
  auto n = parent.child("ClCompile");
  with(n) {
    if(!cl.includePaths.empty) {
      auto paths = cl.includePaths.map!(a => normalizedData(a.exists ? a.resolved() : a)).array;
      if(cl.inheritIncludePaths) {
        paths ~= "%(AdditionalIncludeDirectories)";
      }
      child("AdditionalIncludeDirectories").text("%-(%s;%)".format(paths));
    }
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
    if(!cl.defines.empty) {
      auto defs = cl.defines.dup;
      if(cl.inheritDefines) {
        defs ~= "%(PreprocessorDefinitions)";
      }
      child("PreprocessorDefinitions").text("%-(%s;%)".format(defs));
    }
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

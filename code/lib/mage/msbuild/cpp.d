module mage.msbuild.cpp;

import mage;
import mage.msbuild : VSInfo, trPlatform;
import mage.msbuild.clcompile;
import mage.msbuild.link;
import mage.util.option;

import std.typetuple : allSatisfy;
import std.uuid;


struct Project
{
  string name;
  UUID guid;
  string toolsVersion;
  Config[] configs;
  Path[] headers;
  Path[] cpps;
  Path[] otherFiles;
  Target target;

  /// Decides whether this project is the first to show up in the sln file.
  bool isStartup = false;

  @disable this();

  this(string name)
  {
    this.name = name;
    this.guid = randomUUID();
  }
}

struct Config
{
  string name;
  string architecture;
  string type;
  Path outputFile;
  Path intermediatesDir;
  Option!bool useDebugLibs;
  string platformToolset;
  string characterSet;
  Option!bool wholeProgramOptimization;
  Option!bool linkIncremental;
  ClCompile clCompile;
  Link link;
  Path[] headerFiles;
  Path[] cppFiles;
}


string trWarningLevel(int level) {
  return "Level %s".format(level);
}

string trOptimization(int level) {
  try {
    return [ "Disabled", "MinSize", "MaxSpeed", "Full" ][level];
  }
  catch(core.exception.RangeError) {
    log.warning("Unsupported warning level '%'".format(level));
  }
  return null;
}

string trType2FileExt(string type)
{
  try {
    return [ "Application" : ".exe", "StaticLibrary" : ".lib" ][type];
  }
  catch(core.exception.RangeError) {
    log.warning(`Unsupported config type "%s"`.format(type));
  }
  return null;
}

bool isMatch(in Config self, in Config other)
{
  return other.name == self.name && other.architecture == self.architecture;
}

bool isMatch(in Config self, in Properties rhs)
{
  if(auto pRhs = rhs.tryGet!string("name")) {
    if(*pRhs != self.name) {
      return false;
    }
  }
  if(auto pRhs = rhs.tryGet!string("architecture")) {
    if(*pRhs != self.architecture) {
      return false;
    }
  }
  return true;
}


Project createProject(ref in VSInfo info, Target target)
{
  auto name = *target.properties.tryGet!string("name")
                                .enforce("Target must have a name!");
  Properties localDefaults;
  localDefaults.set!"outputDir" = Path("$(SolutionDir)$(Platform)$(Configuration)");
  localDefaults.set!"characterSet" = "Unicode";

  auto cfgs = *target.properties.tryGet!(Properties[])("configurations", globalProperties, localDefaults, defaultProperties)
                                .enforce("No configurations found");
  auto proj = Project(name);
  proj.isStartup = target.properties.has("isStartup");

  foreach(ref cfgProps; cfgs)
  {
    proj.configs.length += 1;
    auto cfg = &proj.configs[$-1];

    (*cfg).extractNameFrom(cfgProps, target.properties).enforce("A configuration needs a name!");
    log.info("Configuration: %s".format(cfg.name));
    (*cfg).extractArchitectureFrom(cfgProps, target.properties, globalProperties, localDefaults, defaultProperties).enforce("A configuration needs an architecture!");
    log.info("Architecture: %s".format(cfg.architecture));
    (*cfg).extractTypeFrom(target.properties);
    (*cfg).extractUseDebugLibsFrom(cfgProps, target.properties, globalProperties, localDefaults, defaultProperties);
    cfg.platformToolset = info.platformToolset;
    if(auto pValue = target.properties.tryGet!string("platformToolset")) {
      cfg.platformToolset = *pValue;
    }
    (*cfg).extractCharacterSetFrom(cfgProps, globalProperties, localDefaults, defaultProperties);
    (*cfg).extractWholeProgramOptimizationFrom(cfgProps, target.properties, globalProperties, localDefaults, defaultProperties);
    (*cfg).extractOutputFileFrom(proj, cfgProps, target.properties, globalProperties, localDefaults, defaultProperties);
    (*cfg).extractIntermediatesDirFrom(proj, cfgProps, target.properties, globalProperties, localDefaults, defaultProperties);
    (*cfg).extractLinkIncrementalFrom(cfgProps, target.properties, globalProperties, localDefaults, defaultProperties);
    (*cfg).extractFilesFrom(cfgProps, target.properties, target.properties, globalProperties, localDefaults, defaultProperties);

    cfg.clCompile = createClCompile(cfgProps, target.properties, globalProperties, localDefaults, defaultProperties);
    cfg.link = createLink(info, *cfg, cfgProps, target.properties, globalProperties, localDefaults, defaultProperties);
  }
  return proj;
}


bool extractFilesFrom(P...)(ref Config cfg, in Properties src, in P fallbacks)
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
    auto _block = log.Block(`Processing file "%s"`, file);
    if(!file.isAbsolute) {
      file = filesRoot ~ file;
      log.trace(`Made path absolute "%s"`, file);
    }
    if(file.extension == ".h") {
      cfg.headerFiles ~= file;
    }
    else if(file.extension == ".cpp") {
      cfg.cppFiles ~= file;
    }
    else {
      log.warning(`Unknown file type "%s"`, file.extension);
    }
  }
  return true;
}

/// Set the config name from some properties.
bool extractNameFrom(P...)(ref Config cfg, in Properties src, in P fallbacks)
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

bool extractArchitectureFrom(P...)(ref Config cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet!string("architecture", fallbacks);
  if(pValue is null) {
    log.trace(`Property "architecture" not found.`);
    return false;
  }
  cfg.architecture = trPlatform(*pValue);
  return true;
}

bool extractTypeFrom(P...)(ref Config cfg, in Properties src, in P fallbacks)
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

void extractCharacterSetFrom(P...)(ref Config cfg, in Properties src, in P fallbacks)
{
  auto pValue = src.tryGet!string("characterSet", fallbacks);
  if(pValue) {
    // TODO Check for correct values.
    cfg.characterSet = *pValue;
  }
}

bool extractWholeProgramOptimizationFrom(P...)(ref Config cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet!bool("wholeProgramOptimization", fallbacks);
  if(pValue is null) {
    log.trace(`Property "wholeProgramOptimization" not found.`);
    return false;
  }
  if(cfg.useDebugLibs) {
    log.trace(`When using debug libs, the option "wholeProgramOptimization" ` ~
              `cannot be set. Visual Studio itself forbids that. Ignoring the setting for now.`);
    return false;
  }
  cfg.wholeProgramOptimization = *pValue;
  return true;
}

bool extractOutputFileFrom(P...)(ref Config cfg, ref Project proj, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  const(Path)* pPath;
  
  pPath = src.tryGet!Path("outputFile", fallbacks);
  if(pPath)
  {
    cfg.outputFile = *pPath;
    return true;
  }

  pPath = src.tryGet!Path("outputDir", fallbacks);
  if(pPath)
  {
    cfg.outputFile = *pPath ~ (proj.name ~ trType2FileExt(cfg.type));
    return true;
  }

  log.warning(`Neither "outputFile" nor "outputDir" found.`);
  return false;
}

bool extractIntermediatesDirFrom(P...)(ref Config cfg, ref Project proj, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  if(auto pPath = src.tryGet!Path("intermediatesDir", fallbacks))
  {
    cfg.intermediatesDir = *pPath;
    return true;
  }
  else if(src.has("intermediateDir", fallbacks)) {
    log.warning(`Found property "intermediateDir". Did you mean "intermediatesDir" instead?`);
  }

  return false;
}

bool extractLinkIncrementalFrom(P...)(ref Config cfg, in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  auto pValue = src.tryGet!bool("linkIncremental", fallbacks);
  if(pValue is null) {
    log.trace(`Property "linkIncremental" not found.`);
    return false;
  }
  // TODO Check which options are not compatible with the incremental linking option.
  cfg.linkIncremental = *pValue;
  return true;
}

/// Tries for the property "useDebugLibs". If it is not found,
/// and the "name" property contains the string "release"
/// (case insensitive), the debug libs will not be used.
bool extractUseDebugLibsFrom(P...)(ref Config cfg, in Properties src, in P fallbacks)
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

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
  if(auto varName = rhs.tryGet("name")) {
    if(*varName != self.name) {
      return false;
    }
  }
  if(auto pArch = rhs.tryGet("architecture")) {
    if(*pArch != self.architecture) {
      return false;
    }
  }
  return true;
}


Project createProject(ref in VSInfo info, Target target)
{
  string name;
  {
    auto varName = target.properties["name"];
    if(!varName.hasValue()) {
      log.error("Target must have a `name' property!");
      assert(0);
    }
    name = varName.get!string();
  }
  Properties localDefaults;
  localDefaults["outputDir"] = Path("$(SolutionDir)$(Platform)$(Configuration)");
  localDefaults["characterSet"] = "Unicode";

  auto projEnv = Environment("%s_proj_env".format(name), target.properties, *G.env[0], localDefaults, *G.env[1]);

  auto proj = Project(name);
  proj.isStartup = (p){ return p && p.get!bool; }(target.properties.tryGet("isStartup"));
  proj.target = target;
  proj.toolsVersion = info.toolsVersion;

  auto cfgs = projEnv.first("configurations")
                     .enforce("No `configurations' found.");
  foreach(ref Properties cfgProps; *cfgs)
  {
    proj.configs.length += 1;
    auto cfg = &proj.configs[$-1];

    auto env = Environment(projEnv.name ~ "_cfg", cfgProps, projEnv.env);

    Properties fallback;
    // TODO Fill `fallback'.
    auto fallbackEnv = Environment(env.name ~ "_fallback", fallback);
    fallbackEnv["characterSet"] = "Unicode";
    fallbackEnv["wholeProgramOptimization"] = false;
    fallbackEnv["intermediatesDir"] = Path("$(SolutionDir)temp/$(TargetName)_$(Platform)_$(Configuration)");
    fallbackEnv["linkIncremental"] = false;
    env.internal = &fallbackEnv;

    cfg.name = env.configName();
    log.info("Configuration: %s".format(cfg.name));

    cfg.architecture = env.configArchitecture();
    log.info("Architecture: %s".format(cfg.architecture));

    cfg.type = env.configType();
    cfg.useDebugLibs = env.configUseDebugLibgs(cfg.name);
    cfg.platformToolset = env.configPlatformToolset(info);
    cfg.characterSet = env.configCharacterSet();
    cfg.wholeProgramOptimization = env.configWholeProgramOptimization();
    cfg.outputFile = env.configOutputFile(proj, *cfg);
    cfg.intermediatesDir = env.configIntermediatesDir();
    cfg.linkIncremental = env.configLinkIncremental();
    env.configFiles(cfg.headerFiles, cfg.cppFiles);

    sanitize(*cfg);

    cfg.clCompile = createClCompile(*cfg, env);
    cfg.link = createLink(*cfg, info, env);
  }

  return proj;
}


private auto required(ref Environment env, string propName)
{
  return env.first(propName).enforce("Missing required property `%s'.".format(propName));
}

private auto optional(ref Environment env, string propName)
{
  auto pVar = env.first(propName);
  if(pVar is null || !pVar.hasValue()) {
    log.trace("Missing optional property `%s'.", propName);
    assert(env.internal, "Missing fallback environment.");
    pVar = env.internal.first(propName);
    assert(pVar, "Missing fallback value.");
  }
  return pVar;
}


string configName(ref Environment env)
{
  return env.required("name")
            .get!string;
}

string configArchitecture(ref Environment env)
{
  auto arch = env.required("architecture");
  return trPlatform(arch.get!string);
}

string configType(ref Environment env)
{
  auto type = env.required("type")
                 .get!string;
  switch(type) {
    case "executable": return "Application";
    case "library":
    {
      auto libType = env.required("libType")
                        .get!LibraryType;
      final switch(libType)
      {
        case LibraryType.Static: return "StaticLibrary";
        case LibraryType.Shared: assert(0, "Not implemented.");
      }
    }
    default: break;
  }

  assert(0, "Unknown config type: %s".format(type));
}

string configCharacterSet(ref Environment env)
{
  auto varCharset = env.optional("characterSet");
  // TODO Check for correct values.
  return varCharset.get!string;
}

bool configWholeProgramOptimization(ref Environment env)
{
  auto varValue = env.optional("wholeProgramOptimization");
  return varValue.get!bool;
}

Path configOutputFile(ref Environment env, ref Project proj, ref cpp.Config cfg)
{
  auto pVar = env.first("outputFile");
  if(pVar) {
    return pVar.get!Path;
  }

  pVar = env.first("outputDir")
            .enforce("Neither `outputFile' not `outputDir' was found, "
                     "but need at least one of them.");
  return pVar.get!Path ~ (proj.name ~ trType2FileExt(cfg.type));
}

Path configIntermediatesDir(ref Environment env)
{
  auto pVar = env.optional("intermediatesDir");
  return pVar.get!Path;
}

bool configLinkIncremental(ref Environment env)
{
  auto pVar = env.optional("linkIncremental");
  return pVar.get!bool;
}

/// Params:
///   cfgName = If `env' does not contain the property "useDebugLibs",
///             and this argument contains the string "debug" (ignoring the case),
///             this function will yield $(D true).
bool configUseDebugLibgs(ref Environment env, string cfgName)
{
  auto pVar = env.first("useDebugLibs");
  if(pVar) {
    return pVar.get!bool;
  }

  bool isRelease = cfgName.canFind!((a, b) => a.toLower() == b.toLower())("release");
  return !isRelease;
}

string configPlatformToolset(ref Environment env, ref in VSInfo info)
{
  auto pVar = env.first("platformToolset");
  if(pVar) {
    return pVar.get!string;
  }
  return info.platformToolset;
}

void configFiles(ref Environment env, ref Path[] headerFiles, ref Path[] cppFiles)
{
  auto files = env.required("sourceFiles").get!(Path[]);
  auto mageFilePath = env.required("mageFilePath").get!Path;
  auto filesRoot = mageFilePath.parent;
  foreach(ref file; files)
  {
    auto _block = log.Block(`Processing file "%s"`, file);
    if(!file.isAbsolute)
    {
      file = filesRoot ~ file;
      log.trace(`Mage path absolute "%s"`, file);
    }

    auto ext = file.extension;
    if(ext == ".h" || ext == ".hpp")
    {
      headerFiles ~= file;
    }
    else if(ext == ".cpp" || ext == ".cxx")
    {
      cppFiles ~= file;
    }
    else
    {
      log.warning(`Unknown file extension: %s`, ext);
    }
  }
}

void sanitize(ref Config cfg)
{
  if(cfg.useDebugLibs && cfg.wholeProgramOptimization) {
    log.trace(`When using debug libs, the option "wholeProgramOptimization" ` ~
              `cannot be set. Visual Studio itself forbids that. Ignoring it for now.`);
    cfg.wholeProgramOptimization = false;
  }

  // TODO Check which options are not compatible with linkIncremental in visual studio.

  // TODO More.
}

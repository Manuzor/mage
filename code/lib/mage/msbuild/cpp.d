module mage.msbuild.cpp;

import mage;
import mage.msbuild : VSInfo, trPlatform;
import mage.msbuild.clcompile;
import mage.msbuild.link;
import mage.util.option;

import std.typetuple : allSatisfy;
import std.uuid;


struct MSBuildProject
{
  string name;
  UUID guid;
  string toolsVersion;
  MSBuildConfig[] configs;
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

struct MSBuildConfig
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


MSBuildProject createProject(ref in VSInfo info, Target target)
{
  string name;
  {
    auto varName = target.properties["name"];
    if(!varName.hasValue())
    {
      log.error("Target must have a `name' property!");
      assert(0);
    }
    name = varName.get!string();
  }

  auto _= log.Block(`Create Cpp MSBuildProject for "%s"`, name);

  auto localDefaults = Properties("%s_defaults".format(name));
  localDefaults["outputDir"] = Path("$(SolutionDir)$(Platform)$(Configuration)");
  localDefaults["characterSet"] = "Unicode";

  target.properties.prettyPrint();

  auto projEnv = Environment("%s_proj_env".format(name), target.properties, *G.env[0], localDefaults, *G.env[1]);

  auto proj = MSBuildProject(name);
  if(auto var = target.properties.tryGet("isStartup")) {
    proj.isStartup = var.get!bool;
  }
  proj.target = target;
  proj.toolsVersion = info.toolsVersion;

  auto cfgs = projEnv.first("configurations")
                     .enforce("No `configurations' found.");
  foreach(ref Config cfg; *cfgs)
  {
    proj.configs.length += 1;
    auto projCfg = &proj.configs[$-1];

    import std.traits;
    pragma(msg, fullyQualifiedName!(typeof(cfg)));
    auto env = Environment(projEnv.name ~ "_cfg", cfg.properties, projEnv.env);

    Properties fallback;
    auto fallbackEnv = Environment(env.name ~ "_fallback", fallback);
    fallbackEnv["characterSet"] = "Unicode";
    fallbackEnv["wholeProgramOptimization"] = false;
    fallbackEnv["intermediatesDir"] = Path("$(SolutionDir)temp/$(TargetName)_$(Platform)_$(Configuration)");
    fallbackEnv["linkIncremental"] = false;
    env.internal = &fallbackEnv;

    projCfg.name = env.configName();
    log.info("Configuration: %s".format(projCfg.name));
    fallback.name = "%s_fallback".format(projCfg.name);

    projCfg.architecture = env.configArchitecture();
    log.info("Architecture: %s".format(projCfg.architecture));

    projCfg.type = env.configType();
    projCfg.useDebugLibs = env.configUseDebugLibgs(projCfg.name);
    projCfg.platformToolset = env.configPlatformToolset(info);
    projCfg.characterSet = env.configCharacterSet();
    projCfg.wholeProgramOptimization = env.configWholeProgramOptimization();
    projCfg.outputFile = env.configOutputFile(proj, *projCfg);
    projCfg.intermediatesDir = env.configIntermediatesDir();
    projCfg.linkIncremental = env.configLinkIncremental();
    env.configFiles(projCfg.headerFiles, projCfg.cppFiles);

    sanitize(*projCfg);

    projCfg.clCompile = createClCompile(*projCfg, env);
    projCfg.link = createLink(*projCfg, info, env);
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

Path configOutputFile(ref Environment env, ref MSBuildProject proj, ref MSBuildConfig cfg)
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
      log.trace(`Made path absolute: %s`, file);
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

void sanitize(ref MSBuildConfig cfg)
{
  auto useDebugLibs = cfg.useDebugLibs && cfg.useDebugLibs.unwrap();
  auto wholeProgramOptimization = cfg.wholeProgramOptimization && cfg.wholeProgramOptimization.unwrap();

  if(useDebugLibs && wholeProgramOptimization) {
    log.trace(`When using debug libs, the option "wholeProgramOptimization" ` ~
              `cannot be set. Visual Studio itself forbids that. Ignoring it for now.`);
    cfg.wholeProgramOptimization = false;
  }

  // TODO Check which options are not compatible with linkIncremental in visual studio.

  // TODO More.
}

module mage.msbuild;

// Generating files
public import mage.msbuild.sln;
public import mage.msbuild.vcxproj;


import std.exception;
import std.format;


static shared string[string] architectureMap;

shared static this()
{
  architectureMap["x86"]    = "Win32";
  architectureMap["x86_64"] = "x64";
}

/// Translate a general mage architecture name to a MSBuild one.
static string trPlatform(string architectureName) {
  auto mapped = architectureName in architectureMap;
  return *mapped.enforce("Unsupported architecture: %s".format(architectureName));
}

struct VSInfo
{
  /// Such as "cpp", "csharp", etc. Is filled by the base generator with defaults.
  string[] supportedLanguages;

  /// The name of the generator that is used to register it with mage, e.g. "vs2013".
  string genName;

  /// For Visual Studio 2013, this would be "2013".
  string year;
  
  /// For Visual Studio 2013, this would be "12.0".
  string toolsVersion;
  
  /// For Visual Studio 2013, this would be "v120".
  string platformToolset;
}

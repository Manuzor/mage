module mage.msbuild.clcompile;

import mage;
import cpp = mage.msbuild.cpp;
import mage.util.option;

import std.typetuple : allSatisfy;


struct ClCompile
{
  string warningLevel;
  string pch;
  string optimization;
  string compileAs;
  Option!bool functionLevelLinking;
  Option!bool intrinsicFunctions;
  const(Path)[] includePaths;
  bool inheritIncludePaths = true;
  string[] defines;
  bool inheritDefines = true;
}

auto createClCompile(P...)(in Properties src, in P fallbacks)
  if(allSatisfy!(isProperties, P))
{
  ClCompile clCompile;
  if(auto pValue = src.tryGet!(Path[])("includePaths", fallbacks))
  {
    clCompile.includePaths = *pValue;
    log.trace(`Found "includePaths": %s`, clCompile.includePaths);
  }
  else
  {
    log.trace("No includePaths property found.");
  }
  if(auto pValue = src.tryGet!bool("inheritIncludePaths", fallbacks)) {
    clCompile.inheritIncludePaths = *pValue;
  }
  if(auto pValue = src.tryGet!int("warningLevel", fallbacks)) {
    clCompile.warningLevel = cpp.trWarningLevel(*pValue);
  }
  if(auto pValue = src.tryGet!string("pch", fallbacks)) {
    assert(0, "Not implemented (handling of pch property)");
  }
  if(auto pValue = src.tryGet!int("optimization", fallbacks)) {
    clCompile.optimization = cpp.trOptimization(*pValue);
  }
  if(auto pValue = src.tryGet!string("language", fallbacks))
  {
    switch(*pValue)
    {
      case "c":   clCompile.compileAs = "CompileAsC";   break;
      case "cpp": clCompile.compileAs = "CompileAsCpp"; break;
      default: assert(0, `Unsupported language: "%s"`.format(*pValue));
    }
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

  return clCompile;
}

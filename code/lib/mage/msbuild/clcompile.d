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

auto createClCompile(ref in cpp.MSBuildConfig cfg, ref Environment env)
{
  ClCompile clCompile;

  if(auto var = env.first("includePaths"))
  {
    clCompile.includePaths = var.get!(Path[]);
    log.trace(`Found "includePaths": %s`, clCompile.includePaths);
  }
  else
  {
    log.trace(`No "includePaths" property found.`);
  }

  if(auto var = env.first("inheritIncludePaths")) {
    clCompile.inheritIncludePaths = var.get!bool;
  }

  if(auto var = env.first("warningLevel")) {
    clCompile.warningLevel = cpp.trWarningLevel(var.get!int);
  }

  if(auto var = env.first("pch")) {
    assert(0, `Not implemented (handling of "pch" property)`);
  }

  if(auto var = env.first("optimization")) {
    clCompile.optimization = cpp.trOptimization(var.get!int);
  }

  if(auto var = env.first("language"))
  {
    switch(var.get!string)
    {
      case "c":   clCompile.compileAs = "CompileAsC";   break;
      case "cpp": clCompile.compileAs = "CompileAsCpp"; break;
      default: assert(0, `Unsupported language: "%s"`.format(var.get!string));
    }
  }

  if(auto var = env.first("functionLevelLinking")) {
    clCompile.functionLevelLinking = var.get!bool;
  }

  if(auto var = env.first("intrinsicFunctions")) {
    clCompile.intrinsicFunctions = var.get!bool;
  }

  if(auto var = env.first("defines")) {
    clCompile.defines = var.get!(string[]).dup;
  }

  if(auto var = env.first("inheritDefines")) {
    clCompile.inheritDefines = var.get!bool;
  }

  return clCompile;
}

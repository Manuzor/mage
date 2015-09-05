module mage.msbuild.vcxproj;

import mage;
import mage.msbuild.clcompile;
import mage.msbuild.link;
import mage.msbuild.cpp;
import xml = mage.util.xml;


void generateFile(in MSBuildProject proj, in Path outFile)
{
  import mage.util.stream : FileStream;

  auto _ = log.Block("Generate .vcxproj in %s", outFile);

  xml.Doc doc;
  log.info("Generate vcxproj xml in memory...");
  doc.append(proj);
  log.info("Writing vcxproj file...");
  if(!outFile.parent.exists) {
    outFile.parent.mkdir();
  }
  auto s = FileStream(outFile);
  xml.serialize(s, doc);
}

// XML
xml.Element* append(P)(ref P parent, in MSBuildProject proj)
  if(xml.isSomeParent!P)
{
  auto c = parent.child("Project");
  with(c)
  {
    attr("DefaultTargets", "Build");
    attr("ToolsVersion", proj.toolsVersion);
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
        // Explicitly add a trailing slash to silence the MSBuild warning MSB8004.
        child("OutDir").text(cfg.outputFile.parent.normalizedData ~ "/");
        child("IntDir").text(cfg.intermediatesDir.normalizedData ~ "/");
        child("TargetName").text(cfg.outputFile.stem);
        child("TargetExt").text(cfg.outputFile.extension);
      }
    }
    // Item definition groups
    foreach(cfg; proj.configs) {
      log.trace("Writing config: %s", cfg.name);
      auto n = child("ItemDefinitionGroup");
      with(n) {
        attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.architecture));
        (*n).append(cfg.clCompile);
        (*n).append(cfg.link);
      }
    }
    foreach(cfg; proj.configs) {

      if(cfg.compilationUnits.length)
      {
        with(child("ItemGroup"))
        {
          attr("Condition", `'$(Configuration)|$(Platform)'=='%s|%s'`.format(cfg.name, cfg.architecture));
          foreach(file; cfg.compilationUnits) {
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

xml.Element* append(P)(ref P parent, ref in ClCompile cl)
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
    if(cl.compileAs) {
      child("CompileAs").text(cl.compileAs);
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

// XML
xml.Element* append(P)(ref P parent, in Link lnk)
  if(xml.isSomeParent!P)
{
  log.trace("Link (%s)", &lnk);
  auto n = parent.child("Link");
  with(n) {
    auto deps = lnk.dependencies.dup;
    if(lnk.inheritDependencies) {
      deps ~= "%(AdditionalDependencies)";
    }
    if(!deps.empty) {
      child("AdditionalDependencies").text("%-(%s;%)".format(deps));
    }

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
    log.info("Writing debugSymbols if available.");
    log.info("Variant value: %s", (cast()lnk.debugSymbols.value).toString());
    if(lnk.debugSymbols) {
      child("GenerateDebugInformation").text(lnk.debugSymbols.unwrap().to!string());
      if(!lnk.debugSymbolsFile.isDot) {
        child("ProgramDatabaseFile").text(lnk.debugSymbolsFile.normalizedData);
      }
    }
  }
  return n;
}

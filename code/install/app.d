module install;

import std.stdio;
import std.algorithm;
import std.range;
import std.array : array;
import getopt = std.getopt;

import mage;

debug {
  bool progress(in Path src, in Path dest) {
    writefln("  %s => %s", src, dest);
    return true;
  }
}
else {
  bool progress(A...)(A a) { return true; }  
}

int main(string[] args) {

  string srcStr;
  string destStr;

  auto getoptResult = getopt.getopt(args,
                                    getopt.config.required,
                                    "src|s",  "The root of the repo.", &srcStr,
                                    "dest|d", "The dir to install to.", &destStr
                                    );

  if(getoptResult.helpWanted) {
    getopt.defaultGetoptPrinter("Install mage to a specified dir.", getoptResult.options);
    return 1;
  }

  auto root = Path(srcStr).asNormalizedPath;
  assert(root.exists, "Source dir does not exist!");
  debug writefln("Source:      %s", root.resolved());
  
  auto install = Path(destStr).asNormalizedPath;
  if(!install.exists) {
    install.mkdir(true);
  }
  else {
    assert(install.isDir, "Install target must either not exist or be a directory!");
  }
  debug writefln("Destination: %s", install.resolved());

  auto thirdParty = root ~ "thirdParty";
  auto output = root ~ "output";
  auto srcCode = root ~ "code";
  auto destImport = install ~ "import";
  if(!destImport.exists) {
    destImport.mkdir(true);
  }
  auto destCode = install ~ "code";
  if(!destCode.exists) {
    destCode.mkdir(true);
  }
  auto destLib = install;
  if(!destLib.exists) {
    destLib.mkdir(true);
  }

  // Code
  (srcCode ~ "lib").copyTo!progress(destImport);
  (srcCode ~ "app").copyTo!progress(destImport);
  (srcCode ~ "install" ~ "wand.d").copyTo!progress(destCode);

  // Binaries/Output
  (output ~ "libmage.lib").copyTo!progress(destLib);
  (output ~ "mage.exe").copyTo!progress(install);

  // Third-party Code
  (thirdParty ~ "pathlib" ~ "code").copyTo!progress(destImport);

  // Third-Party Binaries/Output
  (thirdParty ~ "pathlib" ~ "output").copyTo!progress(destLib);

  return 0;
}

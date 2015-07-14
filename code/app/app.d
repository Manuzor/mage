
import mage;
import std.getopt;
import std.algorithm;
import std.conv;
import std.array : array;

struct CompilationData
{
  /// Name of the compiler
  string compiler = "dmd";

  /// Misc. flags
  string[] flags;

  /// Will be transformed to a ';'-separated list passed to -L
  Path[] libs;

  /// Will be transformed to a ';'-separated list passed to -I
  Path[] importPaths;

  /// Bare arguments passed to the compiler.
  Path[] files;

  /// The versions that are set during compilation.
  string[] versions;

  Path objDir = Path("obj");

  Path outFile;
}

string[] makeCommand(in CompilationData data) {
  return [data.compiler]
    ~ data.files.map!(a => a.normalizedData.to!string).array[]
    ~ data.libs.map!(a => a.normalizedData.to!string).array[]
    ~ format(`-I%-(%s;%)`, data.importPaths.map!(a => a.normalizedData.to!string))
    ~ data.versions.map!(a => format("-version=%s", a)).array
    ~ data.flags[]
  ;
}

void compile(in CompilationData data) {
  import std.process : spawnProcess, wait;

  // Create a command from the compilation data
  auto cmd = data.makeCommand();
  log.info("Compiling: %-(%s %)", cmd);
  log.info("Compiling: %s", cmd);

  // Invoke the full compilation command.
  spawnProcess(cmd).wait();
}

enum string mageFileSuffix = q{
enum M_mageFilePath = `%s`;
pragma(msg, "Compiling " ~ M_mageFilePath);
mixin M_MageFileMixin;
};

// foo/MageFile => foo.d
// foo/bar/MageFile => foo/bar.d
auto transformMageFile(in Path srcRoot, in Path mageFile, in Path outDir) {
  auto base = mageFile.resolved().relativeTo(srcRoot.resolved().parent).parent;
  import std.stdio;
  log.info("srcRoot: %s | base: %s", srcRoot, base);
  auto dest = outDir ~ format("%s.d", base);
  if(!dest.parent.exists) {
    dest.parent.mkdir(true);
  }
  mageFile.copyFileTo(dest);
  dest.appendFile(mageFileSuffix.format(mageFile.resolved().normalizedData));
  return dest;
}

void dumpManifest(in string[string] manifest, in Path outFile) {
  import std.json;

  JSONValue j = manifest;
  outFile.writeFile(j.toPrettyString());
}

void dumpGeneratorConfig(in string[string] cfg, in Path outFile) {
  import std.json;

  JSONValue j = cfg;
  outFile.writeFile(j.toPrettyString());
}


int main(string[] args)
{
  string tempStr;
  string[] generators;
  auto helpInfo = getopt(args,
                         "temp", "The temp dir.", &tempStr,
                         "G", "The generator to use.", &generators);
  auto tempDir = Path(tempStr);
  if(!tempDir.exists) {
    tempDir.mkdir(true);
  }
  else {
    assert(tempDir.isDir, "Specified temp dir must be a directory! (does not have to exist yet)");
  }

  if(helpInfo.helpWanted) {
    defaultGetoptPrinter("Mage launcher.", helpInfo.options);
    return 1;
  }

  if(args.length != 2) {
    defaultGetoptPrinter("Invalid number of arguments. Expected exactly 1 argument (source dir).", helpInfo.options);
    return 2;
  }

  auto sourceDir = Path(args[1]);
  if(!sourceDir.exists) {
    log.error("Given source directory does not exist: %s".format(sourceDir));
  }

  auto mageFiles = sourceDir.glob("MageFile", SpanMode.breadth).array;

  if(mageFiles.empty) {
    log.error("Unable to find any MageFile in: %s".format(sourceDir));
    return 3;
  }

  log.info("MageFiles: %(\n  %s%)", mageFiles);

  string[string] manifest;
  auto outDir = tempDir ~ "src";
  Path[] transformed;
  foreach(f; mageFiles) {
    auto t = transformMageFile(sourceDir, f, outDir);
    manifest[t.to!string] = f.to!string;
    transformed ~= t;
  }

  dumpManifest(manifest, tempDir ~ "MageSourceManifest.json");
  log.info("Manifest: %s", manifest);

  CompilationData data;
  debug data.flags ~= "-debug";
  debug data.flags ~= "-gc";
  debug data.flags ~= "-w";
  version(X86)         data.flags ~= "-m32";
  else version(X86_64) data.flags ~= "-m64";
  else static assert(0, "Unsupported platform.");
  data.libs ~= Path("lib").glob("*.lib").array;
  data.importPaths ~= [cwd() ~ "import"];
  data.files ~= Path("code") ~ "wand.d";
  data.files ~= transformed[];
  data.versions ~= "<dummy>";
  auto genPath = Path("mage.cfg");
  genPath.writeFile("%s\n".format(sourceDir.normalizedData)); // Clear the file.
  foreach(g; generators) {
    data.versions[$-1] = "MageGen_%s".format(g);
    data.outFile = Path("wand-%s".format(g));
    compile(data);
    genPath.appendFile("%s\n".format(g));
  }

  return 0;
}

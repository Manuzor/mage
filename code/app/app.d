
import mage;
import std.stdio;
import std.getopt;
import std.algorithm;
import std.conv;
import std.array : array;

auto mageSourceTemplate = Path("code") ~ "MageSource.d.template";

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
}

string[] makeCommand(in CompilationData data) {
  return [data.compiler]
    ~ data.files.map!(a => a.normalizedData.to!string).array[]
    ~ data.libs.map!(a => a.normalizedData.to!string).array[]
    ~ format(`-I%-(%s;%)`, data.importPaths.map!(a => a.normalizedData.to!string))
    ~ data.flags[]
  ;
}

void compile(in CompilationData data) {
  import std.process : spawnProcess, wait;

  // Create a command from the compilation data
  auto cmd = data.makeCommand();
  writefln("Compiling: %-(%s %)", cmd);
  writefln("Compiling: %s", cmd);

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
  import std.file : appendToFile = append;
  //auto base = mageFile.parent.resolved().relativeTo(srcRoot.resolved()).to!string;
  auto base = mageFile.resolved().relativeTo(srcRoot.resolved().parent).parent;
  import std.stdio;
  writefln("srcRoot: %s | base: %s", srcRoot, base);
  auto dest = outDir ~ format("%s.d", base);
  if(!dest.parent.exists) {
    dest.parent.mkdir(true);
  }
  mageFile.copyFileTo(dest);
  dest.normalizedData.appendToFile(mageFileSuffix.format(mageFile.resolved().normalizedData));
  return dest;
}

void dumpManifest(in string[string] manifest, in Path outFile) {
  import std.json;
  import std.file : writeToFile = write;

  JSONValue j = manifest;
  outFile.normalizedData.writeToFile(j.toPrettyString());
}


int main(string[] args)
{
  string tempStr;
  auto helpInfo = getopt(args,
                         "temp", "The temp dir.", &tempStr);
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
  auto mageFiles = sourceDir.glob("MageFile", SpanMode.breadth).array;

  if(mageFiles.empty) {
    writefln("Unable to find any MageFile.");
    return 3;
  }

  writefln("MageFiles: %(\n  %s%)", mageFiles);

  string[string] manifest;
  auto outDir = tempDir ~ "src";
  Path[] transformed;
  foreach(f; mageFiles) {
    auto t = transformMageFile(sourceDir, f, outDir);
    manifest[t.to!string] = f.to!string;
    transformed ~= t;
  }

  dumpManifest(manifest, tempDir ~ "MageSourceManifest.json");
  writefln("Manifest: %s", manifest);

  CompilationData data;
  //data.flags ~= "-m64";
  data.libs ~= Path("lib").glob("*.lib").array;
  data.importPaths ~= [cwd() ~ "import"];
  data.files ~= Path("code") ~ "wand.d";
  data.files ~= transformed[];

  compile(data);

  return 0;
}

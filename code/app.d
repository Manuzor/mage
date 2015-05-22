
import mage;

int main(string[] args)
{
  import std.stdio;
  import std.getopt;

  string sourceDir;
  auto helpInfo = getopt(args,
                         "source-dir", "The source dir.", &sourceDir);

  if(helpInfo.helpWanted) {
    defaultGetoptPrinter("Some info.", helpInfo.options);
    return 1;
  }

  return 0;
}

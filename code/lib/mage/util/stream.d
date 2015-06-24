module mage.util.stream;

import mage;

mixin template StreamWriteln()
{
  string newLine = "\n";
  int indentation = 0;
  string indentString = "  ";

  /// Increase indentation. Does not write.
  void indent() {
    ++indentation;
  }

  /// Decrease indentation to a minimum of 0. Does not write.
  void dedent() {
    import std.algorithm : max;
    indentation = max(indentation - 1, 0);
  }

  void writeln(string s = null)
  {
    if(s) this.write(s);
    this.write(this.newLine);
    foreach(i; 0..this.indentation) {
      this.write(this.indentString);
    }
  }
}

unittest {
  struct S { mixin StreamWriteln; void write(...){} }
  S s;
  assert(s.indentation == 0);
  s.dedent();
  assert(s.indentation == 0);
  s.indent();
  assert(s.indentation == 1);
  s.indent();
  assert(s.indentation == 2);
  s.dedent();
  assert(s.indentation == 1);
  s.dedent();
  assert(s.indentation == 0);
  s.dedent();
  assert(s.indentation == 0);
}

struct FileStream
{
  import std.stdio : File;

  File file;

  mixin StreamWriteln;

  this(Path p, string mode = "wb") {
    file = p.open(mode);
  }

  void write(string s)
  {
    file.write(s);
  }
}

struct StringStream
{
  string content;

  mixin StreamWriteln;

  this(string initial = "") {
    content = initial;
  }

  void write(string s)
  {
    content ~= s;
  }
}

struct StdoutStream
{
  import io = std.stdio;

  mixin StreamWriteln;

  void write(string s)
  {
    io.write(s);
  }
}

module mage.util.stream;

import mage;

mixin template StreamWrite()
{
  string newLine = "\n";
  int indentLevel = 0;
  string indentString = "  "; /// Set this to null to disable indentation, even when indent() is called.
  bool isDirty = false;

  @property bool isIndentEnabled() const { return this.indentString !is null; }

  /// Increase indentation. Does not write.
  void indent()
  {
    ++indentLevel;
  }

  /// Decrease indentation to a minimum of 0. Does not write.
  void dedent() {
    import std.algorithm : max;
    indentLevel = max(indentLevel - 1, 0);
  }

  void write(string s)
  {
    import std.array;
    if(this.isDirty && this.indentString !is null && this.indentLevel > 0) {
      this.writeImpl(this.indentString.replicate(this.indentLevel));
    }
    this.isDirty = false;
    this.writeImpl(s);
  }

  void writeln(string s)
  {
    this.write(s);
    this.writeln();
  }

  void writeln() {
    this.write(this.newLine);
    this.isDirty = true;
  }
}

unittest {
  struct S { mixin StreamWrite; void writeImpl(A...)(A){} }
  S s;
  assert(s.indentLevel == 0);
  s.dedent();
  assert(s.indentLevel == 0);
  s.indent();
  assert(s.indentLevel == 1);
  s.indent();
  assert(s.indentLevel == 2);
  s.dedent();
  assert(s.indentLevel == 1);
  s.dedent();
  assert(s.indentLevel == 0);
  s.dedent();
  assert(s.indentLevel == 0);
}

/// Note: Untested.
struct ScopedIndentation(SomeStream)
{
  int amount;
  SomeStream* stream;

  @disable this();

  this(ref SomeStream stream, int amount = 1)
  {
    this.stream = &stream;
    this.amount = amount;
    while (amount) {
      stream.indent();
      --amount;
    }
  }

  ~this()
  {
    while(this.amount) {
      stream.dedent();
      --this.amount;
    }
  }
}

struct FileStream
{
  import std.stdio : File;

  File file;

  mixin StreamWrite;

  this(Path p, string mode = "wb") {
    file = p.open(mode);
  }

  private void writeImpl(string s)
  {
    file.write(s);
  }
}

struct StringStream
{
  string content;

  mixin StreamWrite;

  this(string initial = "") {
    content = initial;
  }

  private void writeImpl(string s)
  {
    content ~= s;
  }
}

unittest
{
  auto ss = StringStream();
  assert(ss.content == "");
  ss.writeln("hello");
  assert(ss.content == "hello\n");
  ss.indent();
  assert(ss.content == "hello\n");
  ss.write("world");
  assert(ss.content == "hello\n  world");
  ss.dedent();
  assert(ss.content == "hello\n  world");
  ss.writeln(" and goodbye");
  assert(ss.content == "hello\n  world and goodbye\n", `"%s"`.format(ss.content));
  ss.write("...");
  assert(ss.content == "hello\n  world and goodbye\n...");
}

struct StdoutStream
{
  import io = std.stdio;

  mixin StreamWrite;

  private void writeImpl(string s)
  {
    io.write(s);
  }
}

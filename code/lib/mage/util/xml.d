/*
Building XML with RAII techniques.
*/
module mage.util.xml;
import mage;
import mage.util.stream;
import mage.util.mem;

import std.format : format;

struct Text
{
  Element* parent;
  string content;
}

struct Attribute
{
  string key;
  string value;
}

struct Element
{
  Doc* doc;
  Element* parent;
  string name;
  Element*[] children;
  Attribute*[] attributes;

  Element* child(string name)
  {
    auto c = doc.mem.allocate!Element(doc, &this, name);
    children ~= c;
    return c;
  }

  Attribute* attr(in string key, in string value)
  {
    foreach(a; attributes) {
      if(a.key == key) {
        a.value = value;
        return a;
      }
    }
    auto a = doc.mem.allocate!Attribute(key, value);
    attributes ~= a;
    return a;
  }

  Text* text(in string content)
  {
    return null;
  }
}

struct Doc
{
  Block!(4.KiB) mem;

  string xmlVersion = "1.0";
  string xmlEncoding = "UTF-8";
  Element*[] children;

  Element* child(string name) {
    auto n = mem.allocate!Element(&this, null, name);
    children ~= n;
    return n;
  }
}


unittest {
  Doc doc;
  with(doc) {
    with(child("Project")) {
      attr("DefaultTargets", "Build");
      attr("ToolsVersion", "12.0");
      attr("xmlns", "http://schemas.microsoft.com/developer/msbuild/2003");
      with(child("ItemGroup")) {
        attr("Label", "ProjectConfigurations");
        with(child("ProjectConfiguration")) {
          attr("Include", "Debug|Win32");
          with(child("Configuration")) {
            text("Debug");
          }
          with(child("Platform")) {
            text("Win32");
          }
        }
      }
    }
  }
}

void serialize(S)(ref S stream, ref Doc doc)
{
  stream.write(`<?xml version="%s" encoding="%s"?>`.format(doc.xmlVersion, doc.xmlEncoding));
  foreach(c; doc.children) {
    stream.serialize(*c);
  }
  stream.writeln();
}

void serialize(S)(ref S stream, ref Element n)
{
  import std.stdio : stdout = write;
  
  stream.writeln();
  stream.write("<%s".format(n.name));
  foreach(a; n.attributes) {
    stream.write(" ");
    stream.serialize(*a);
  }
  if(n.children.length > 0)
  {
    stream.write(">");
    stream.indent();
    foreach(c; n.children) {
      stream.serialize(*c);
    }
    stream.dedent();
    stream.writeln();
    stream.write("<%s/>".format(n.name));
  }
  else {
    stream.write("/>");
  }
}

void serialize(S)(ref S stream, ref Attribute a)
{
  stream.write(`%s="%s"`.format(a.key, a.value));
}

struct StdoutStream
{
  mixin StreamWriteln;

  void write(string s)
  {
    import std.stdio : write;
    write(s);
  }
}

unittest {
  Doc doc;
  with(doc) {
    foreach(i; 0..3)
    {
      with(child("A")) {
        attr("id", "a%s".format(i));
        attr("name", "the-a");
        with(child("B")) {
          attr("name", "the-b");
          with(child("C1")) {
            attr("name", "the-c");
          }
          with(child("C2")) {
            attr("name", "the-other-c");
          }
        }
      }
    }
  }
  //StringStream s;
  //s.writeln();
  StdoutStream l;
  //l.newLine = "\\n\n";
  //l.indentString = "=>";
  l.serialize(doc);
  //log(s.content);
}

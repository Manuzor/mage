module mage.util.properties;

import mage;
import mage.util.option;
import std.variant;
import std.typetuple : allSatisfy;

class MissingKeyError : core.exception.Error
{
  @safe pure nothrow this(string key, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
  {
    super(`Missing key "` ~ key ~ `".`, file, line, next);
  }
}


struct Properties
{
  string name = "<anonymous>";

  /// Dynamic property storage.
  /// Note: This member is public on purpose.
  Variant[string] values;

  inout(Variant)* tryGet(in string key, lazy Variant* otherwise = null) inout
  {
    auto val = key in this.values;
    if(val) {
      return val;
    }

    return cast(typeof(return))otherwise;
  }

  ref inout(Variant) opIndex(in string key) inout
  {
    auto val = this.tryGet(key);
    if(val) {
      return *val;
    }
    throw new MissingKeyError(key);
  }

  void opIndexAssign(T)(auto ref T value, string key)
  {
    this.values[key] = value;
  }

  string toString() const
  {
    return "Properties(%s)".format(this.name);
  }

  void prettyPrint() const
  {
    auto _ = log.Block(this.toString());

    foreach(key, ref value; this.values) {
      log.info("%s: %s", key, (cast()value).toString());
    }
  }
}

/// set/get
unittest
{
  import std.exception : assertThrown;

  auto props = Properties("props");
  props["name"] = "hello";
  assert(props["name"].get!string() == "hello");
  props["custom"] = 1337;
  assert(props["custom"].get!int() == 1337);
  props["asdfghjkl"] = 42;
  assert(props["asdfghjkl"].convertsTo!int());
  assert(props["asdfghjkl"].get!int() == 42);
  //struct IntValue { int value; }
  //assert(props["asdfghjkl"].coerce!IntValue().value == 42);

  assertThrown!MissingKeyError(props["iDontExist"].get!float());
  assert(props.tryGet("iDontExist", null) is null);
  {
    Variant fallback;
    assert(props.tryGet("iDontExist", &fallback) == &fallback);
  }

  // Overwrite.
  props["name"] = "world";
  assert(props["name"].get!string() == "world");
}


import std.traits : Unqual;
enum isProperties(T) = is(Unqual!T == Properties);


struct Environment
{
  Properties*[] env;
  string name;
  Environment* internal = null;

  /// Construct an environment with a name and the given properties.
  /// Example: Properties p1, p2, p3, p4; Environment("theName", p1, [ &p3, &p4 ], p2);
  this(Props...)(string name, auto ref Props props)
  {
    this.name = name;
    foreach(ref prop; props) {
      static if(isInputRange!(typeof(prop)))
      {
        foreach(p; prop) {
          static assert(is(typeof(p) == Properties*), "The array you pass must contain Properties*, not " ~ typeof(p).stringof);
          this.env ~= p;
        }
      }
      else
      {
        static assert(isProperties!(typeof(prop)));
        this.env ~= &prop;
      }
    }
  }

  /// Pointer to the first occurrence of `key' in this environment.
  inout(Variant)* first(in string key, lazy Variant* otherwise = null) inout
  {
    auto all = this.all(key);
    auto result = all.empty ? otherwise : all.front;
    return cast(typeof(return))result;
  }

  /// Return: A range containing $(D Variant*).
  auto all(in string key)
  {
    return this.env.map!(a => a.tryGet(key, null)) // Properties* => Variant*
                   .filter!(a => a !is null);      // Allow no null values.
  }

  /// Return: A range containing $(D Variant*).
  auto all(in string key) const
  {
    return this.env.map!(a => a.tryGet(key, null)) // Properties* => Variant*
                   .filter!(a => a !is null);      // Allow no null values.
  }

  ref inout(Variant) opIndex(in string key) inout
  {
    auto val = this.first(key);
    enforce!MissingKeyError(val, `Missing key "%s" in environment "%s".`
                                 .format(key, this.name));
    return *val;
  }

  /// Set a value in env[0].
  void opIndexAssign(T)(auto ref T value, in string key)
  {
    assert(this.env.length > 0, `Environment "%s" is empty!`.format(this.name));
    (*this.env[0])[key] = value;
  }

  string toString() const
  {
    return "Environment(%s)".format(this.name);
  }

  void prettyPrint() const
  {
    auto _ = log.Block(this.toString());

    foreach(p; this.env)
    {
      assert(p);
      p.prettyPrint();
    }

    if(this.internal) {
      this.internal.prettyPrint();
    }
  }
}

unittest
{
  import std.exception;

  auto p1 = Properties("p1");
  auto p2 = Properties("p2");
  auto p3 = Properties("p3");
  auto p4 = Properties("p4");
  auto env = Environment("env", p1, p2, p3, p4);
  p1["something"] = "hello";
  p2["something"] = " ";
  // p3 left empty on purpose.
  p4["something"] = "world";
  assert(env.first("something").get!string() == "hello");
  assert(env.all("something").map!(a => a.get!string()).equal(["hello", " ", "world"]));

  assert(env.first("foo") is null);
  assertThrown!MissingKeyError(env["foo"] == 3.1415f);
  env["foo"] = 3.1415f;
  assert(env["foo"].get!float == 3.1415f);
  assert(p1["foo"].get!float == 3.1415f);
  assert(p2.tryGet("foo") is null);
  assert(p3.tryGet("foo") is null);
  assert(p4.tryGet("foo") is null);

  p3["bar"] = null;
  assert(env.first("bar") !is null);
  assert(env["bar"].get!(typeof(null)) is null);
  assert(p1.tryGet("bar") is null);
  assert(p2.tryGet("bar") is null);
  assert(p3.tryGet("bar") !is null);
  assert(p4.tryGet("bar") is null);
}

mixin template PropertiesOperators(alias memberName)
{
  inout(Variant)* tryGet(string key) inout {
    return memberName.tryGet(key);
  }

  void opIndexAssign(T)(auto ref T value, string key) {
    memberName[key] = value;
  }

  ref inout(Variant) opIndex(string key) inout {
    return memberName[key];
  }
}

unittest
{
  static struct Wrapper
  {
    Properties props;
    mixin PropertiesOperators!props;
  }

  Wrapper w;
  w["foo"] = 123;
  assert(w["foo"].get!int == 123);
  assert(w["foo"] == 123);
  assert(w.tryGet("bar") is null);
  w["bar"] = "hello world";
  assert(w.tryGet("bar") !is null);
  assert(*w.tryGet("bar") == "hello world");
}
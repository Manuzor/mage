module mage.util.properties;

import mage;
import mage.util.option;
import std.variant;
import std.typetuple : allSatisfy;
import core.exception : RangeError;


struct Properties
{
  string name = "<none>";

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
    return this.values[key];
  }

  void opIndexAssign(T)(auto ref T value, string key)
  {
    this.values[key] = value;
  }

  string opCast(CastTarget : string)() const
  {
    import std.conv : to;
    return "Properties(%s: %s)".format(this.name, this.values);
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

  assertThrown!RangeError(props["iDontExist"].get!float());
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
    enforce!RangeError(val, `Missing key "%s" in environment "%s".`
                            .format(key, this.name));
    return *val;
  }

  /// Set a value in env[0].
  void opIndexAssign(T)(auto ref T value, in string key)
  {
    assert(this.env.length > 0, `Environment "%s" is empty!`.format(this.name));
    (*this.env[0])[key] = value;
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
  assertThrown!RangeError(env["foo"] == 3.1415f);
  env["foo"] = 3.1415f;
  assert(env["foo"].get!float == 3.1415f);
  assert(p1["foo"].get!float == 3.1415f);
  assert(p2.tryGet("foo") is null);
  assert(p3.tryGet("foo") is null);
  assert(p4.tryGet("foo") is null);
}

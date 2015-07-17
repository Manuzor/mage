module mage.config;
import mage;
import std.variant;

mixin template CommonProperties()
{
  string name;
  Path[] sourceFiles;
}

struct Properties
{
  /// Dynamic property storage.
  /// Note: This member is public on purpose.
  Variant[string] _values;

  /// Returns: Pointer to the argument value. May be null.
  /// Note: This method makes use of std.VariantN.peek,
  ///       i.e. the type T you pass must match the containing type exactly (=> short != int).
  auto tryGet(T, Args...)(in string key, auto ref inout Args fallbacks) inout
  {
    auto val = key in _values;
    if(val) {
      return val.peek!T();
    }
    foreach(ref other; fallbacks)
    {
      val = key in other._values;
      if(val) {
        return val.peek!T();
      }
    }
    return null;
  }

  auto get(T, Args...)(in string key, auto ref Args fallbacks)
  {
    auto val = key in _values;
    if(val) {
      return val.get!T();
    }
    foreach(ref other; fallbacks)
    {
      val = key in other._values;
      if(val) {
        return val.get!T();
      }
    }
    throw new Exception(`Key "%s" does not exist.`.format(key));
  }

  /// Creates an array of all occurences of $(D key) in this instance and all $(D others).
  auto getAll(T, Args...)(in string key, auto ref Args others)
  {
    T[] result;

    auto val = this.tryGet!T(key);
    if(val) {
      result ~= *val;
    }

    foreach(ref other; others)
    {
      val = other.tryGet!T(key);
      if(val) {
        result ~= *val;
      }
    }

    return result;
  }

  void set(T)(in string key, T value)
  {
    _values[key] = value;
  }

  @property void set(string key, T)(T value)
  {
    this.set(key, value);
  }

  bool convertsTo(T, Args...)(in string key, auto ref in Args fallbacks) const
  {
    auto val = key in _values;
    if(val && val.convertsTo!T()) {
      return true;
    }
    foreach(ref other; fallbacks)
    {
      val = key in other._values;
      if(val && val.convertsTo!T()) {
        return true;
      }
    }
    return false;
  }

  bool has(Args...)(in string key, auto ref in Args fallbacks) const
  {
    auto val = key in _values;
    if(val && val.hasValue())
    {
      return true;
    }
    foreach(ref other; fallbacks)
    {
      val = key in other._values;
      if(val && val.hasValue())
      {
        return true;
      }
    }
    return false;
  }

  bool has(T, Args...)(in string key, auto ref in Args fallbacks) const
  {
    auto val = key in _values;
    if(val && val.hasValue() && val.convertsTo!T())
    {
      return true;
    }
    foreach(ref other; fallbacks)
    {
      val = key in other._values;
      if(val && val.hasValue() && val.convertsTo!T())
      {
        return true;
      }
    }
    return false;
  }
}

///
unittest
{
  import std.exception : assertThrown;

  // set/get
  {
    Properties props;
    props.set!"name" = "hello";
    assert(props.get!string("name") == "hello");
    props.set!"custom" = 1337;
    assert(props.get!int("custom") == 1337);
    props.set!"asdfghjkl" = 42;
    assert(props.get!int("asdfghjkl") == 42);

    assertThrown(props.get!int("iDontExist"));
  }

  // tryGet
  {
    Properties p1, p2, p3;

    assert(p1.tryGet!int("needle") is null);
    assert(p2.tryGet!int("needle") is null);
    assert(p3.tryGet!int("needle") is null);
    
    p1.set!"needle" = 1;
    p2.set!"needle" = 2;
    p3.set!"needle" = 3;

    // Beware: tryGet inly accepts the exact type that is stored.
    assert(p1.tryGet!float("needle") is null);
    assert(*p1.tryGet!int("needle", p2, p3) == 1);
    assert(*p2.tryGet!int("needle", p1, p3) == 2);
    assert(*p3.tryGet!int("needle", p1, p2) == 3);

    p3.set!"blubb" = "abc";
    assert(*p1.tryGet!string("blubb", p2, p3) == "abc");

  }

  // getAll
  {
    Properties p1, p2, p3, p4;
    p1.set!"something" = "hello";
    p2.set!"something" = " ";
    p3.set!"something" = "world";
    assert(p1.getAll!string("something", p2, p3, p4).equal(["hello", " ", "world"]));
  }
}

enum isProperties(T) = is(T == Properties);


// Globals

__gshared Properties globalProperties;
__gshared Properties defaultProperties;

shared static this()
{
  // Default configurations if targets don't set any.
  Properties[] cfgs;
  cfgs.length = 2;
  cfgs[0].set!"name" = "Debug";
  cfgs[0].set!"architecture" = "x86";
  cfgs[0].set!"debugSymbols" = true;
  cfgs[1].set!"name" = "Release";
  cfgs[1].set!"architecture" = "x86";
  defaultProperties.set!"configurations" = cfgs;
  defaultProperties.set!"language" = "none";
  defaultProperties.set!"type" = "none";

  globalProperties.set!"sourceRootPath" = Path();
  globalProperties.set!"genRootPath" = Path();
}

unittest
{
  assert(defaultProperties.get!(Properties[])("configurations")[0].get!string("name") == "Debug");
  assert(defaultProperties.get!(Properties[])("configurations")[0].get!string("architecture") == "x86");
  assert(defaultProperties.get!(Properties[])("configurations")[1].get!string("name") == "Release");
  assert(defaultProperties.get!(Properties[])("configurations")[1].get!string("architecture") == "x86");
  assert(defaultProperties.get!string("language") == "none");
}

@property Path sourceRootPath()
{
  return globalProperties.get!Path("sourceRootPath");
}

@property Path genRootPath()
{
  return globalProperties.get!Path("genRootPath");
}

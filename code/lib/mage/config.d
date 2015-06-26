module mage.property;
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
  Variant[string] _values;
  
  @property void opDispatch(string key, T)(in T value) {
    _values[key] = value;
  }

  @property ref inout(Variant) opDispatch(string key)() inout {
    return *enforce(tryGet(key), "Key does not exist. To check whether it does, use tryGet(<key>).");
  }

  inout(Variant)* tryGet(Args...)(in string key, auto ref inout Args fallbacks) inout
  {
    auto val = key in _values;
    if(val) {
      return val;
    }
    foreach(ref other; fallbacks)
    {
      val = key in other._values;
      if(val) {
        return val;
      }
    }
    return null;
  }
}

///
unittest
{
  Properties props;
  props.name = "hello";
  assert(props.name == "hello");
  props.custom = 1337;
  assert(props.custom == 1337);
  props.asdfghjkl = 42;
  assert(props.asdfghjkl == 42);

  import std.exception : assertThrown;
  assertThrown(props.iDontExist);

  // tryGet
  {
    Properties p1, p2, p3;
    p1.needle = 1;
    p2.needle = 2;
    p3.needle = 3;

    assert(*p1.tryGet("needle", p2, p3) == 1);
    assert(*p2.tryGet("needle", p1, p3) == 2);
    assert(*p3.tryGet("needle", p1, p2) == 3);

    p3.blubb = "abc";
    assert(*p1.tryGet("blubb", p2, p3) == "abc");
  }
}

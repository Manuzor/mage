module mage.util.option;
import mage;
import mage.util.conv;

struct Option(T) {
  alias WrappedType = T;
  alias WrapperType = VariantN!(T.sizeof, T, const(T), immutable(T));

  WrapperType value;

  /// Whether this option has some value.
  bool isSome() const { return value.hasValue(); }

  /// Whether this option does not have some value.
  bool isNone() const { return !isSome(); }

  /// Implicit conversion to bool.
  bool opCast(T : bool)() const { return isSome(); }

  auto ref inout(T) unwrap() inout {
    return *enforce(value.peek!(T)(), "This option has nothing to unwrap.");
  }

  void opAssign(U : T)(auto ref U t) {
    value = t;
  }
}


unittest
{
  import std.exception;

  Option!int opt;
  assert(opt.isNone);
  assert(!opt.isSome);
  assert(!opt);
  assertThrown(opt.unwrap());
  opt = 42;
  assert(!opt.isNone);
  assert(opt.isSome);
  assert(opt);
  assert(opt.unwrap() == 42);
}

string toString(T)(in ref Option!T opt) {
  if(opt.isSome) {
    return "Option!%s(%s)".format(T.stringof, opt.unwrap());
  }
  return "Option!%s()".format(T.stringof);
}

unittest
{
  Option!int opt;
  assert(opt.toString() == "Option!int()");
  opt = 42;
  assert(opt.toString() == "Option!int(42)");
}

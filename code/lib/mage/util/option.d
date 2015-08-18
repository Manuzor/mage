module mage.util.option;
import mage;

struct Option(T) {
  alias WrappedType = T;
  alias WrapperType = VariantN!(T.sizeof, T);

  /// The underlying value wrapped in a `std.VariantN`.
  WrapperType value;

  this(U)(auto ref U u) {
    this.value = cast(WrappedType)u;
  }

  /// Whether this option has some value.
  bool isSome() inout { return this.value.hasValue(); }

  /// Whether this option does not have some value.
  bool isNone() inout { return !this.isSome(); }

  /// Clear the option so it no longer has a value.
  void clear() { this.value = WrapperType(); }

  /// Implicit conversion to bool. Equivalent to isSome().
  bool opCast(CastTargetType : bool)() inout { return this.isSome(); }

  /// Return the wrapped value. Throws an exception if there is no value.
  auto ref inout(WrappedType) unwrap(string msg = null) inout {
    return *this.value.peek!(WrappedType).enforce(msg ? msg : "This option has nothing to unwrap.");
  }

  void opAssign(U : WrappedType)(auto ref U u) {
    this.value = cast(WrappedType)u;
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
  opt.clear();
  assert(opt.isNone);
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

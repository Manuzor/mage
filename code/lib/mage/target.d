module mage.target;
import mage;
import std.variant;

/// Base class for all targets.
abstract class Target
{
  Properties _properties;

  @property ref inout(Properties) properties() inout {
    return _properties;
  }

  final @property void opDispatch(string key, T)(in T v) {
    properties().opDispatch!(key)(v);
  }

  final @property ref inout(Variant) opDispatch(string key)() inout {
    return properties().opDispatch!(key)();
  }

  /// Context sensitive configure step.
  void configure(in Properties context) {}
}


class Executable : Target
{
  this() {
    properties.type = "executable";
  }
}


enum LibraryType
{
  Static,
  Shared
}

class Library : Target
{
  this(LibraryType libType) {
    properties.type = "library";
    properties.libType = libType;
  }
}


interface ITargetFactory
{
  abstract @property Path filePath() const;
  abstract Target create();
}

__gshared ITargetFactory[] targetFactories;

class TargetFactory(T) : ITargetFactory
{
  import std.stdio;
private:
  Path _filePath;

public:

  override @property Path filePath() const { return _filePath; }

  alias TargetType = T;
  
  this(Path filePath) {
    _filePath = filePath;
  }

  override Target create() {
    return new TargetType();
  }
}

mixin template registerMageFile(alias T, alias filePath)
{
  shared static this()
  {
    import mage.util.reflection;
    pragma(msg, "[mage] Reflecting module: " ~ T.stringof);
    foreach(m; __traits(allMembers, T))
    {
      static if(!__traits(compiles, typeof(__traits(getMember, T, m))))
      {
        static if(__traits(compiles, ResolveType!(__traits(getMember, T, m))))
        {
          alias Type = ResolveType!(__traits(getMember, T, m));
          static if(is(Type : Target))
          {
            pragma(msg, "[mage]   Found a target! " ~ Type.stringof);
            static if(!__traits(compiles, new Type())) {
              pragma(msg, "[mage]   WARNING: Target is not instantiable with `new`.");
            }
            targetFactories ~= new TargetFactory!Type(Path(filePath));
          }
        }
      }
    }
  }
}

mixin template M_MageFileMixin()
{
  class MageFileInstance{}

  // The parent of MageFileInstance is the module.
  mixin registerMageFile!(__traits(parent, MageFileInstance), M_mageFilePath);
}

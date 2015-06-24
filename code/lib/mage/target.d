module mage.target;

import pathlib;

interface ITarget
{
  abstract @property auto ref inout(Path[]) sourceFiles() inout;
  abstract @property auto ref inout(string) name() inout;
}


mixin template TargetCommonMixin()
{
  string _name;
  Path[] _sourceFiles;

  this() {}

  override string toString() const {
    return name;
  }

@property:
override:
  auto ref inout(Path[]) sourceFiles() inout { return _sourceFiles; }
  auto ref inout(string) name() inout { return _name; }
}


class Executable : ITarget
{
  mixin TargetCommonMixin;
}


enum LibraryType
{
  Static,
  Shared
}

class Library : ITarget
{
  mixin TargetCommonMixin;

  LibraryType libType = LibraryType.Static;

  this(LibraryType libType) {
    this.libType = libType;
  }
}


interface ITargetFactory
{
  abstract @property Path filePath() const;
  abstract ITarget create();
}

__gshared ITargetFactory[] targetFactories;

class TargetWrapper(T) : ITargetFactory
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

  override ITarget create() {
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
          static if(is(Type : ITarget))
          {
            pragma(msg, "[mage]   Found a target! " ~ Type.stringof);
            static if(!__traits(compiles, new Type())) {
              pragma(msg, "[mage]   WARNING: Target is not instantiable with `new`.");
            }
            targetFactories ~= new TargetWrapper!Type(Path(filePath));
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

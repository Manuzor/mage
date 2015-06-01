module mage;

// Externals
public import pathlib;

// Internals
public import mage.target;


class Magician
{
  this(){}
}

interface ITargetFactory
{
  abstract @property Path filePath() const;
  abstract ITarget create();
}

__gshared ITargetFactory[] targetFactories;

class TargetWrapper(TargetType) : ITargetFactory
{
  import std.stdio;
private:
  Path m_filePath;

public:

  override @property Path filePath() const { return m_filePath; }

  alias WrappedType = TargetType;
  
  this(Path filePath) {
    import std.conv : to;
    m_filePath = filePath;
    writefln("Created wrapper for " ~ TargetType.stringof ~ ": " ~ m_filePath.to!string);
  }

  override ITarget create() {
    writefln("Creating " ~ TargetType.stringof);
    return new TargetType();
  }
}

template ResolveType(T)
{
  alias ResolveType = T;
}

mixin template registerMageFile(alias T, alias filePath) {
  shared static this() {
    pragma(msg, "[mage] Reflecting module: " ~ T.stringof);
    foreach(m; __traits(allMembers, T)) {
      static if(!__traits(compiles, typeof(__traits(getMember, T, m)))) {
        static if(__traits(compiles, ResolveType!(__traits(getMember, T, m)))) {
          alias Type = ResolveType!(__traits(getMember, T, m));
          static if(is(Type == class)) {
            if(Type.stringof != "MageFileInstance") {
              pragma(msg, "[mage]   Found a class: " ~ Type.stringof);
              foreach(uda; __traits(getAttributes, Type)) {
                static if(is(uda == Target)) {
                  pragma(msg, "[mage]     Found a target! " ~ uda.stringof);
                  static if(!__traits(compiles, new Type())) {
                    pragma(msg, "[mage] WARNING: Target is not instantiable with `new`.");
                  }
                  targetFactories ~= new TargetWrapper!Type(Path(filePath));
                }
                else {
                  pragma(msg, "[mage]     Found some UDA: " ~ uda.stringof);
                }
              }
            }
          }
          else {
            pragma(msg, "[mage]   Found something: " ~ Type.stringof);
          }
        }
      }
      else {
        alias Type = typeof(__traits(getMember, T, m));
        pragma(msg, "[mage]   Module member: " ~ Type.stringof);
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

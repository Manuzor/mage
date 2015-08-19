module mage.target;
import mage;
import std.variant;


//debug = PragmaMsg;


/// Base class for all targets.
abstract class Target
{
  Properties _properties;
  const(Properties)* context;

  this()
  {
    properties.name = typeid(this).toString();

    // Useful for targets that only do some global config.
    properties["type"] = "none";
    // TODO Source file properties.
  }

  @property ref inout(Properties) properties() inout {
    return _properties;
  }

  void configure() {}

  override string toString() const
  {
    auto var = this.properties["name"];
    if(var.hasValue())
    {
      return (cast()var).get!string;
    }
    import std.conv : to;
    return typeid(this).to!string();
  }
}


abstract class Executable : Target
{
  this() {
    properties["type"] = "executable";
  }
}


enum LibraryType
{
  Static,
  Shared
}

abstract class Library : Target
{
  this(LibraryType libType)
  {
    this.properties["type"] = "library";
    this.properties["libType"] = libType;
  }
}

abstract class StaticLibrary : Library
{
  this() { super(LibraryType.Static); }
}

abstract class SharedLibrary : Library
{
  this() { super(LibraryType.Shared); }
}


/// Used for third-party inclusion.
class ExternalTarget : Target {}


/// Helper to add link targets.
void addLinkTarget(ref Properties props, Target target)
{
  Target[] targets;
  if(auto pValue = props.tryGet("linkTargets"))
  {
    targets = pValue.get!(Target[]);
  }
  targets ~= target;
  props["linkTargets"] = targets;
}


/// User-defined Attribute (UDA) to decorate a dependency field with.
struct Dependency
{
}


interface ITargetWrapper
{
  abstract @property Path filePath() const;
  abstract @property string targetName() const;
  abstract @property const(TypeInfo) wrappedTypeInfo() const;
  abstract @property const(TypeInfo)[] dependencies() const;
  abstract void setDependencyInstance(Target target, Target dependency);
  abstract Target create();
}

__gshared ITargetWrapper[] wrappedTargets;

class TargetWrapper(TargetType) : ITargetWrapper
{
  import std.stdio;
private:
  alias DependencySetter = void function(Target, Target);

  Path _filePath;
  DependencySetter[TypeInfo] _dependencies;

public:
  override @property Path filePath() const { return _filePath; }
  override @property string targetName() const { return TargetType.stringof; }
  override @property const(TypeInfo) wrappedTypeInfo() const { return typeid(TargetType); }
  override @property const(TypeInfo)[] dependencies() const { return _dependencies.keys; }
  override void setDependencyInstance(Target target, Target dependency)
  {
    log.info("Finding %s...", typeid(dependency));
    _dependencies[typeid(dependency)](target, dependency);
  }

  this(Path filePath) {
    import mage.util.reflection;
    _filePath = filePath;
    debug(PragmaMsg) { pragma(msg, `[mage] Scanning Target "` ~ TargetType.stringof ~ `" members for dependencies.`); }
    foreach(m; __traits(allMembers, TargetType))
    {
      debug(PragmaMsg) { pragma(msg, "[mage]   Member: " ~ m); }
      alias Member = Resolve!(__traits(getMember, TargetType, m));
      static if(__traits(compiles, typeof(Member)))
      {
        foreach(uda; __traits(getAttributes, Member))
        {
          debug(PragmaMsg) { pragma(msg, "[mage]     UDA: " ~ uda.stringof); }
          if(is(uda == Dependency))
          {
            static assert(is(typeof(Member) : Target), `Only "Target" types may be decorated with "@Dependency".`);
            debug(PragmaMsg) { pragma(msg, "[mage] +++ Collecting dependency: " ~ typeof(Member).stringof); }
            this._dependencies[typeid(typeof(Member))] = (t, d) // Setter for the member dependency instances
            {
              mixin("(cast(TargetType)t)." ~ m ~ " = cast(typeof(TargetType." ~ m ~ "))d;");
            };
          }
        }
      }
    }
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
    debug(PragmaMsg) { pragma(msg, "[mage] Reflecting module: " ~ T.stringof); }
    foreach(m; __traits(allMembers, T))
    {
      debug(PragmaMsg) { pragma(msg, "[mage]   Checking member: " ~ m); }
      static if(!__traits(compiles, typeof(__traits(getMember, T, m))))
      {
        debug(PragmaMsg) { pragma(msg, "[mage]     Got one further!"); }
        static if(__traits(compiles, ResolveType!(__traits(getMember, T, m))))
        {
          debug(PragmaMsg) { pragma(msg, "[mage]       One more down!"); }
          alias Type = ResolveType!(__traits(getMember, T, m));
          static if(is(Type : Target))
          {
            debug(PragmaMsg) { pragma(msg, "[mage]   Found a target! " ~ Type.stringof); }
            static if(!__traits(compiles, new Type())) {
              debug(PragmaMsg) { pragma(msg, "[mage]   WARNING: Target is not instantiable with `new`."); }
            }
            log.info("Wrapping " ~ Type.stringof);
            wrappedTargets ~= new TargetWrapper!Type(Path(filePath));
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

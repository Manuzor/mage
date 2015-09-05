module mage.target;
import mage;
import std.variant;
import std.typecons : tuple;
public import std.typecons : Tuple;


//debug = PragmaMsg;


/// Base class for all targets.
abstract class Target
{
  Properties _properties;
  MagicContext context;

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

  mixin PropertiesOperators!_properties;

  @property bool isExternal() const { return false; }

  void configure() {}

  override string toString() const
  {
    auto var = this["name"];
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
    this["type"] = "library";
    this["libType"] = libType;
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
abstract class ExternalTarget : Target
{
  final override @property bool isExternal() const { return true; }
}


/// Helper to add link targets.
void addLinkTarget(Target target, Target linkTarget)
{
  if(linkTarget.tryGet("libType") is null)
  {
    log.error("Missing `libType' property; Cannot add `%s' as link target.", linkTarget);
    return;
  }

  Target[] targets;
  if(auto pValue = target.tryGet("linkTargets"))
  {
    targets = pValue.get!(Target[]);
  }
  targets ~= linkTarget;
  log.trace("Link targets of `%s': %s", target, targets);
  target["linkTargets"] = targets;
}

struct Config
{
  auto properties = Properties("<anonymousConfig>");

  this(string name) {
    this.name = name;
  }

  this(string name, string architecture)
  {
    this.name = name;
    this.architecture = architecture;
  }

  @property string name() const { return (cast()this["name"]).get!string; }
  @property void name(string theName) { this["name"] = theName; }

  @property string architecture() const { return (cast()this["architecture"]).get!string; }
  @property void architecture(string theArch) { this["architecture"] = theArch; }

  mixin PropertiesOperators!properties;

  string toString() const {
    return "Config(`%s', `%s')".format(this.name, this.architecture);
  }
}

bool isMatch(ref in Config cfg1, ref in Config cfg2)
{
  return cfg1.name == cfg2.name && cfg1.architecture == cfg2.architecture;
}

auto matchingConfigurations(Config[] configs1, Config[] configs2)
{
  Tuple!(Config*, Config*)[] result;
  foreach(ref cfg; configs1)
  {
    foreach(ref otherCfg; configs2)
    {
      if(cfg.isMatch(otherCfg)) {
        result ~= tuple(&cfg, &otherCfg);
      }
    }
  }
  return result;
}

auto matchingConfigurations(ref Environment env1, ref Environment env2)
{
  auto configs1 = env1.first("configurations");
  auto configs2 = env2.first("configurations");
  return matchingConfigurations(configs1.get!(Config[]), configs2.get!(Config[]));
}

auto matchingConfigurations(Target t1, Target t2)
{
  auto env1 = Environment("matchingConfigurations_t1", t1.properties);
  auto env2 = Environment("matchingConfigurations_t2", t2.properties);
  return matchingConfigurations(env1, env2);
}

unittest
{
  import std.range;

  Config[] l;
  l.length = 3;
  l[0].name = "a";
  l[0].architecture = "x86";
  l[1].name = "b";
  l[1].architecture = "x86";
  l[2].name = "c";
  l[2].architecture = "x86";

  Config[] r;
  r.length = 3;
  r[0].name = "c";
  r[0].architecture = "x86";
  r[1].name = "z";
  r[1].architecture = "x86";
  r[2].name = "a";
  r[2].architecture = "x86";

  auto matches = matchingConfigurations(l, r);
  assert(matches.length == 2);
  assert(matches.front[0].name == "a");
  assert(matches.front[1].name == "a");
  matches.popFront();
  assert(matches.front[0].name == "c");
  assert(matches.front[1].name == "c");
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

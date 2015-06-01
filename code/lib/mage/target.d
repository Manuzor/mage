module mage.target;

import pathlib;

public __gshared ITarget[] targets;

interface ITarget
{
  string toString() const;
}


mixin template TargetCommonMixin()
{
  string name;
  Path[] sourceFiles;


  this() {
  }

  override string toString() const {
    return name;
  }
}


// UDA
struct Target
{
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

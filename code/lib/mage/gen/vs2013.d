module mage.gen.vs2013;

import mage;
import mage.gen.vsCommon;
import xml = mage.util.xml;
import std.format : format;
import std.conv : to;
import std.uuid;
import mage.util.option;
import mage.util.reflection;

mixin RegisterGenerator!(VS2013Generator, "vs2013");

class VS2013Generator : VSGeneratorBase
{
  @property override string name() const { return "vs2013"; }
  @property override string year() const { return "2013"; }
  @property override string toolsVersion() const { return "12.0"; }
  @property override string platformToolset() const { return "v120"; }
}

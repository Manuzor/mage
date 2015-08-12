module mage.gen.vs2013;

import mage;
import mage.gen.vsCommon;

mixin RegisterGenerator!(VS2013Generator, "vs2013");

class VS2013Generator : VSGeneratorBase
{
  this()
  {
    this.info.genName = "vs2013";
    this.info.year = "2013";
    this.info.toolsVersion = "12.0";
    this.info.platformToolset = "v120";
  }
}

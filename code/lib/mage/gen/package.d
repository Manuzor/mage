module mage.gen;

// Built-in generators
public import mage.gen.vs2013;

import mage.target;

interface IGenerator
{
  void generate(ITarget target);
}

IGenerator[string] generatorRegistry;

void registerGenerator(in string name, IGenerator generator) {
  generatorRegistry[name] = generator;
}

mixin template RegisterGenerator(alias Name, G)
{
  shared static this()
  {
    registerGenerator(Name, new G());
  }
}

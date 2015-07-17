module mage.gen;

// Built-in generators
public import mage.gen.vs2013;

import mage.target;

interface IGenerator
{
  abstract void generate(Target[] target);
}

IGenerator[string] generatorRegistry;

void registerGenerator(in string name, IGenerator generator) {
  generatorRegistry[name] = generator;
}

mixin template RegisterGenerator(G, Name...)
{
  shared static this()
  {
    auto g = new G();
    foreach(name; Name) {
      registerGenerator(name, g);
    }
  }
}

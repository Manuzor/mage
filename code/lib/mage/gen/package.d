module mage.gen;

// Built-in generators
public import mage.gen.vs2013;

import mage.target;

interface IGenerator
{
  void generate(ITarget target);
}

// T = Actual generator type.
private template GeneratorWrapper(T)
{
  class GeneratorWrapper : IGenerator
  {
    T m_impl;

    this(T impl) {
      m_impl = impl;
    }

    override void generate(ITarget target) {
      m_impl.generate(target);
    }
  }
}

IGenerator[string] generatorRegistry;

void registerGenerator(T)(in string name, T generator) {
  generatorRegistry[name] = new GeneratorWrapper!T(generator);
}

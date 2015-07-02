module mage.util.reflection;

public import std.typetuple : allSatisfy;


template ResolveType(T)
{
  alias ResolveType = T;
}

template Resolve(alias T)
{
  alias Resolve = T;
}

module mage.config;
import mage;
import mage.util.properties;


__gshared static auto G = Environment("GlobalEnv");


private class GlobalEnvironment
{
  auto globals = Properties("globals");
  auto defaults = Properties("globalDefaults");
}

private __gshared static auto _G = new GlobalEnvironment();


shared static this()
{
  import mage.target : Config;
  
  _G.globals["sourceRootPath"] = Path();
  _G.globals["genRootPath"] = Path();
  G.env ~= &_G.globals;

  // Default configurations if targets don't set any.
  auto dbg = Config("Debug", "x86");
  dbg["debugSymbols"] = true;

  auto rel = Config("Release", "x86");
  
  _G.defaults["configurations"] = [ dbg, rel ];
  _G.defaults["language"] = "none";
  _G.defaults["type"] = "none";
  G.env ~= &_G.defaults;
}

unittest
{
  assert(G.first("configurations").get!(Config[])[0].name == "Debug");
  assert(G.first("configurations").get!(Config[])[0].architecture == "x86");
  assert(G.first("configurations").get!(Config[])[0]["name"].get!string() == "Debug");
  assert(G.first("configurations").get!(Config[])[0]["architecture"].get!string() == "x86");
  assert(G.first("configurations").get!(Config[])[0]["debugSymbols"].get!bool() == true);

  assert(G.first("configurations").get!(Config[])[1].name == "Release");
  assert(G.first("configurations").get!(Config[])[1].architecture == "x86");
  assert(G.first("configurations").get!(Config[])[1]["name"].get!string() == "Release");
  assert(G.first("configurations").get!(Config[])[1]["architecture"].get!string() == "x86");

  assert(G.first("language").get!string() == "none");
  assert(G.first("type").get!string() == "none");
}

@property Path sourceRootPath()
{
  return G.first("sourceRootPath").get!Path();
}

@property Path genRootPath()
{
  return G.first("genRootPath").get!Path();
}

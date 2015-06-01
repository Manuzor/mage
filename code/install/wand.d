module wand;

import mage;
import helloworld;

int main(string[] args) {
  log("Running wand.");

  foreach(targetFactory; targetFactories) {
    with(ScopedChdir(targetFactory.filePath.parent)) {
      auto target = targetFactory.create();
      logf("Target: %s", target.toString());
    }
  }
  return 0;
}

import appf.appf;

import std.stdio;

int main(string[] args) {
  auto app = new AppF(args);
  auto win = app.makeWindow().name("MyWindow").show();
  return app.loop();
}

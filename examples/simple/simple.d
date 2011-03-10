import appf.appf;

import std.stdio;

class MyHandler : EmptyHandler {
  override void onEvent(Window win, MouseEvent e) {
    writefln("MouseEvent for win:%s at:%s", win.name, e.pos);
  }
}

int main(string[] args) {
  auto app = new AppF(args);
  auto handler = new MyHandler;
  auto win1 = app.makeWindow(Rect(40, 40, 200, 200), handler);
  win1.name("Window1");
  win1.show();
  auto win2 = app
    .makeWindow()
    .handler(handler)
    .name("Window2")
    .show()
    .moveResize(Rect(Pos(240, 40), Size(200, 200)))
    ;

  return app.loop();
}

import appf.appf, appf.window, guip._;
import std.stdio;

class MyHandler : WindowHandler {
  override void onEvent(Event e, Window win) {
    visitEvent(e, this, win);
  }

  void visit(T)(T e, Window win) {
    writefln("%s for win:%s e:%s", typeid(T), win.name, e);
  }
}

int main() {
  auto app = new AppF();
  auto handler = new MyHandler;
  auto win1 = app.mkWindow(IRect(IPoint(40, 40), ISize(200, 200)), handler);
  win1.name("Window1");
  win1.show();
  auto win2 = app.mkWindow().handler(handler).name("Window2")
    .show().moveResize(IRect(IPoint(240, 40), ISize(200, 200)));
  return app.loop();
}

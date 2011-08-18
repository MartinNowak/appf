import appf._, guip._;
import std.stdio;

class MyHandler : WindowHandler {
  override void onInputEvent(InputEvent e) {
    final switch (e.type) {
    case InputEvent.Type.None:
      assert(0);
    case InputEvent.Type.Button:
      writeln("onInputEvent: ", e.ebutton.tupleof); break;
    case InputEvent.Type.Mouse:
      writeln("onInputEvent: ", e.emouse.tupleof); break;
    case InputEvent.Type.Key:
      writeln("onInputEvent: ", e.ekey.tupleof); break;
    case InputEvent.Type.Drag:
      writeln("onInputEvent: ", e.edrag.tupleof); break;
    case InputEvent.Type.Drop:
      writeln("onInputEvent: ", e.edrop.tupleof); break;
    }
  }

  override void onResize(IRect area) {
    writefln("onResize: %s", area);
  }

  override void onRefreshWindow(Window win, IRect area) {
    writefln("onRefreshWindow: win: %s area: %s", win, area);
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

module appf.event;

import std.algorithm;
import guip.event, guip.point, guip.rect, guip.size;

version (Posix) {
  version = xlib;
  import x11.xlib;
} else {
  static assert(0);
}

version (xlib) {
  Button buttonDetail(uint button) {
    Button btn;
    switch (button) {
    case ButtonName.Button1: btn.left = true; break;
    case ButtonName.Button2: btn.middle = true; break;
    case ButtonName.Button3: btn.right = true; break;
    case ButtonName.Button4: btn.wheelup = true; break;
    case ButtonName.Button5: btn.wheeldown = true; break;
    default: assert(0);
    }
    return btn;
  }

  Button buttonState(uint state) {
    Button btn;
    btn.left = (state & ButtonMask.Button1Mask) != 0;
    btn.middle = (state & ButtonMask.Button2Mask) != 0;
    btn.right = (state & ButtonMask.Button3Mask) != 0;
    return btn;
  }

  // TODO: needs keycode->char translation
  Key keyDetail(uint keycode) {
    return Key(keycode);
  }

  Mod modState(uint state) {
    Mod mod;
    mod.shift = (state & KeyOrButtonMask.ShiftMask) != 0;
    mod.ctrl = (state & KeyOrButtonMask.ControlMask) != 0;
    mod.alt = (state & KeyOrButtonMask.Mod1Mask) != 0;
    mod.numlock = (state & KeyOrButtonMask.Mod2Mask) != 0;
    return mod;
  }

  struct ToXEvent {
    XDisplay* dpy;
    Window hwnd;

    this(XDisplay* dpy, Window hwnd) {
      this.dpy = dpy;
      this.hwnd = hwnd;
    }

    XEvent visit(RedrawEvent e) {
      XEvent xe;
      xe.type = EventType.Expose;
      xe.xexpose.type = EventType.Expose;
      xe.xexpose.display = dpy;
      xe.xexpose.window = hwnd;
      xe.xexpose.x = e.area.left;
      xe.xexpose.y = e.area.top;
      xe.xexpose.width = e.area.width;
      xe.xexpose.height = e.area.height;
      return xe;
    }
  }

  XEvent toPlatformEvent(Event e, XDisplay* dpy, Window hwnd) {
    auto conv = ToXEvent(dpy, hwnd);
    return visitEvent(e, conv);
  }

  EventMask xemask(uint type) {
    switch (type) {
    case EventType.Expose:
      return EventMask.ExposureMask;
    default:
      assert(0);
    }
  }
}

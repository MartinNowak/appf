module appf.event;

import std.algorithm;
public import guip.event, guip.point, guip.rect, guip.size;

version (Posix) {
  version = xlib;
  import xlib = xlib.xlib;
} else {
  static assert(0);
}

version (xlib) {
  Button buttonDetail(uint button) {
    Button btn;
    btn.left = button == xlib.Button1;
    btn.middle = button == xlib.Button2;
    btn.right = button == xlib.Button3;
    return btn;
  }

  Button buttonState(uint state) {
    Button btn;
    btn.left = (state & xlib.Button1Mask) != 0;
    btn.middle = (state & xlib.Button2Mask) != 0;
    btn.right = (state & xlib.Button3Mask) != 0;
    return btn;
  }

  Mod modState(uint state) {
    Mod mod;
    mod.shift = (state & xlib.ShiftMask) != 0;
    mod.ctrl = (state & xlib.ControlMask) != 0;
    mod.alt = (state & xlib.Mod1Mask) != 0;
    mod.numlock = (state & xlib.Mod2Mask) != 0;
    return mod;
  }

  struct ToXEvent {
    xlib.Display* dpy;
    xlib.Window hwnd;

    this(xlib.Display* dpy, xlib.Window hwnd) {
      this.dpy = dpy;
      this.hwnd = hwnd;
    }

    xlib.XEvent visit(RedrawEvent e) {
      xlib.XEvent xe;
      xe.type = xlib.Expose;
      xe.xexpose.type = xlib.Expose;
      xe.xexpose.display = dpy;
      xe.xexpose.window = hwnd;
      xe.xexpose.x = e.area.left;
      xe.xexpose.y = e.area.top;
      xe.xexpose.width = e.area.width;
      xe.xexpose.height = e.area.height;
      return xe;
    }
  }

  xlib.XEvent toPlatformEvent(Event e, xlib.Display* dpy, xlib.Window hwnd) {
    auto conv = ToXEvent(dpy, hwnd);
    return visitEvent(e, conv);
  }

  uint xemask(uint type) {
    switch (type) {
    case xlib.Expose:
      return xlib.ExposureMask;
    default:
      return xlib.NoEventMask;
    }
  }
}

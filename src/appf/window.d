module appf.window;

public import appf.event;
import std.conv, std.exception;

interface WindowHandler {
  void onEvent(MouseEvent e);
  void onEvent(KeyEvent e);
  void onEvent(RedrawEvent e, Window win);
  void onClose();
}

version (Posix) {
  version = xlib;
  import xlib = xlib.xlib;
} else {
  static assert(0);
}

version (xlib) {
/**
 * Window class provides an OS independent abstraction of a window.
 */
class Window {
  alias xlib.Window PlatformHandle;
  WindowHandler handler;
  WindowConf conf;
  PlatformHandle hwnd;

  this(WindowHandler handler, Rect rect, WindowConf conf) {
    this.handler = handler;
    this.conf = conf;
    this.hwnd = createWindow(rect);
  }

  /**
   * Returns:
   *     the current window title
   */
  @property string name() {
    const(char*) name;
    scope(exit) if (name !is null) xlib.XFree(cast(void*)name);
    if (xlib.XFetchName(this.conf.dpy, this.hwnd, &name))
      return to!string(name);
    else
      return "";
  }

  /**
   * Changes the window title
   * Parameters:
   *     title = the new window title
   */
  @property ref Window name(string title) {
    xlib.XStoreName(this.conf.dpy, this.hwnd, "MyWindow");
    return this;
  }

  /**
   * Makes the window visible
   */
  ref Window show() {
    xlib.XMapWindow(this.conf.dpy, this.hwnd);
    return this;
  }

  /**
   * Makes the window invisible
   */
  ref Window hide() {
    xlib.XUnmapWindow(this.conf.dpy, this.hwnd);
    return this;
  }

  /**
   * Resizes the window while leaving the top left corner at it's
   * current position.
   * Parameters:
   *     size = the new window size
   */
  ref Window resize(Size size) {
    return this;
  }

  /**
   * Moves the window.
   * Parameters:
   *     pos = the new position of the top left corner
   */
  ref Window move(Pos pos) {
    return this;
  }

  /**
   * Returns:
   *     the OS specific handle of this window
   */
  @property PlatformHandle platformHandle() const {
    return this.hwnd;
  }

private:

  xlib.Window createWindow(Rect r) {
    auto dpy = this.conf.dpy;
    auto scr = this.conf.scr;

    auto rootwin = xlib.XRootWindow(dpy, scr);
    enum border = 0;
    return xlib.XCreateSimpleWindow(dpy, rootwin, r.pos.x, r.pos.y,
      r.size.w, r.size.h, border,
      xlib.XBlackPixel(dpy, scr), xlib.XWhitePixel(dpy, scr));
  }
}

package:

struct WindowConf {
  xlib.Display* dpy;
  int scr;

  void init() {
    this.dpy = enforce(xlib.XOpenDisplay(null),
      new Exception("ERROR: Could not open default display"));
    this.scr = xlib.XDefaultScreen(this.dpy);
  }
}

enum EventMask =
  xlib.ExposureMask |
  xlib.ButtonPressMask |
  xlib.ButtonReleaseMask |
  xlib.PointerMotionMask |
    //    xlib.PointerMotionHintMask |
  xlib.KeyPressMask |
  xlib.KeyReleaseMask |
  xlib.StructureNotifyMask |
  xlib.VisibilityChangeMask;

enum AtomT {
  WM_PROTOCOLS,
  WM_DELETE_WINDOW,
    //WM_TAKE_FOCUS,
  NET_WM_PING,
}

struct MessageLoop {
  WindowConf conf;
  xlib.Atom[AtomT.max + 1] atoms;
  Window[Window.PlatformHandle] windows;

  this(WindowConf conf) {
    enforce(conf.dpy);
    this.conf = conf;
    foreach(i, name; __traits(allMembers, AtomT)) {
      auto atom = xlib.XInternAtom(this.conf.dpy, name.ptr, xlib.Bool.False);
      this.atoms[i] = atom;
    }
  }

  void addWindow(Window win) {
    enforce(this.conf.dpy == win.conf.dpy);

    enforce(!(win.platformHandle in this.windows));
    this.windows[win.platformHandle] = win;
    initWindow(win);
  }

  bool removeWindow(Window win) {
    if (this.hasWindow(win)) {
      this.windows.remove(win.hide().platformHandle);
      return true;
    } else {
      return false;
    }
  }

  bool hasWindow(Window win) {
    if (win is null)
      return false;
    auto p = (win.platformHandle in this.windows);
    return p is null ? false : enforce(p == win);
  }

  bool dispatchMessage() {
    if (!this.windows.length)
      return false;

    xlib.XEvent e;
    xlib.XNextEvent(this.conf.dpy, &e);

    switch (e.type) {
    case xlib.ClientMessage:
      if (e.xclient.message_type == this.atoms[AtomT.WM_PROTOCOLS]) {
        if (e.xclient.data.l[0] == this.atoms[AtomT.WM_DELETE_WINDOW])
          return false;
        else if (e.xclient.data.l[0] == this.atoms[AtomT.NET_WM_PING]) {
          // TODO: xlib.XSendMessage(rootwindow ...)
        }
      }
      break;


    default:
    }
    return true;
  }

  void initWindow(Window win) {
    xlib.XSelectInput(this.conf.dpy, win.platformHandle, EventMask);
    auto status = xlib.XSetWMProtocols(this.conf.dpy, win.platformHandle,
      this.atoms.ptr, cast(int)this.atoms.length);
    enforce(status == 1);
  }
}

} // version xlib

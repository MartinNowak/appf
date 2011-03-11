module appf.window;

public import appf.event;
import std.conv, std.exception, std.string, std.typecons;

/**
 * Interface to manage window events
 */
interface WindowHandler {
  bool onEvent(Window win, MouseEvent e);
  void onEvent(Window win, KeyEvent e);
  void onEvent(Window win, RedrawEvent e);
  void onClose(Window win);
}

/**
 * Empty implementation of WindowHandler can be used to only override
 * some functions.
 */
alias BlackHole!WindowHandler EmptyHandler;

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
  WindowHandler _handler;
  WindowConf conf;
  PlatformHandle hwnd;
  Window[PlatformHandle] subwins;

  this(WindowConf conf, WindowHandler handler, Rect rect) {
    this(conf, handler);
    this.hwnd = createWindow(null, rect);
  }

  private this(WindowConf conf, WindowHandler handler) {
    this.handler = handler;
    this.conf = conf;
  }

  /**
   * Creates a new sub window of this window. The window is invisible
   * until it's show() method was called.
   * Parameters:
   *     rect = the initial position and size of the window in parent coordinates
   *     handler = instance of WindowHandler to handle Input/Redraw requests
   * Returns:
   *     the newly created window
   */
  Window makeSubWindow(Rect rect=Rect(0, 0, 400, 300), WindowHandler handler=null) {
    enforce(!rect.empty);
    auto sub = new Window(this.conf, handler);
    sub.hwnd = createWindow(this, rect);
    this.subwins[sub.hwnd] = sub;
    return sub;
  }

  /**
   * Returns the installed WindowHandler.
   */
  @property WindowHandler handler() {
    return this._handler;
  }

  /**
   * Sets a new WindowHandler.
   */
  @property ref Window handler(WindowHandler handler) {
    this._handler = handler;
    return this;
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
    xlib.XStoreName(this.conf.dpy, this.hwnd, toStringz(title));
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
   * Returns:
   *     the current area of this window in parent coordinates
   */
  @property Rect area() {
    xlib.XWindowAttributes attr;
    xlib.XGetWindowAttributes(this.conf.dpy, this.hwnd, &attr);
    return Rect(attr.x, attr.y, attr.width, attr.height);
  }

  /**
   * Resizes the window while leaving the top left corner at it's
   * current position.
   * Parameters:
   *     size = the new window size
   */
  ref Window resize(Size size) {
    xlib.XResizeWindow(this.conf.dpy, this.hwnd, size.w, size.h);
    return this;
  }

  /**
   * Moves the window.
   * Parameters:
   *     pos = the new position of the top left corner
   */
  ref Window move(Pos pos) {
    xlib.XMoveWindow(this.conf.dpy, this.hwnd, pos.x, pos.y);
    return this;
  }

  /**
   * Moves and resizes the window.
   * Parameters:
   *     rect = the new position and size of the window
   */
  ref Window moveResize(Rect rect) {
    xlib.XMoveResizeWindow(this.conf.dpy, this.hwnd, rect.pos.x, rect.pos.y, rect.size.w, rect.size.h);
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

  xlib.Window createWindow(Window parent, Rect r) {
    auto dpy = this.conf.dpy;
    auto scr = this.conf.scr;

    auto rootwin = parent is null ? xlib.XRootWindow(dpy, scr) : parent.platformHandle;
    enum border = 2;
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
  _NET_WM_PING,
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
        if (e.xclient.data.l[0] == this.atoms[AtomT.WM_DELETE_WINDOW]) {
          this.removeWindow(this.windows.get(e.xclient.window, null));
          return this.windows.length > 0;
        } else if (e.xclient.data.l[0] == this.atoms[AtomT._NET_WM_PING]) {
          assert(this.conf.dpy == e.xclient.display);
          e.xclient.window = xlib.XRootWindow(this.conf.dpy, this.conf.scr);
          xlib.XSendEvent(e.xclient.display, e.xclient.window, xlib.Bool.False,
            xlib.SubstructureRedirectMask | xlib.SubstructureNotifyMask, &e);
        }
      }
      break;

    case xlib.Expose:
      if (e.xexpose.count < 1) {
        auto area = Rect(e.xexpose.x, e.xexpose.y, e.xexpose.width, e.xexpose.height);
        auto win = this.windows[e.xexpose.window];
        this.sendEvent(win, RedrawEvent(area));
      }
      break;

    case xlib.ButtonPress:
    case xlib.ButtonRelease:
      auto win = this.windows[e.xbutton.window];
      this.recurseMouseEvent(win, e.xbutton);
      break;

    case xlib.MotionNotify:
      auto win = this.windows[e.xmotion.window];
      this.recurseMouseEvent(win, e.xmotion);
      break;

    default:
    }
    return true;
  }

  void recurseMouseEvent(XEventT)(Window win, XEventT xe) {
    while(this.sendEvent(win, MouseEvent(Pos(xe.x, xe.y))) && xe.subwindow) {
      win = win.subwins[xe.subwindow];
      xe.window = xe.subwindow;
      xlib.XQueryPointer(this.conf.dpy, xe.window, &xe.root, &xe.subwindow,
        &xe.x_root, &xe.y_root, &xe.x, &xe.y, &xe.state);
    }
  }

  bool sendEvent(EventT)(Window win, EventT event)
  if(is(typeof(win.handler.onEvent(win, event)) : bool))
  {
    return win.handler !is null ? win.handler.onEvent(win, event) : true;
  }

  void sendEvent(EventT)(Window win, EventT event)
  if(!is(typeof(win.handler.onEvent(win, event)) : bool))
  {
    if (win.handler !is null) win.handler.onEvent(win, event);
  }

  void initWindow(Window win) {
    xlib.XSelectInput(this.conf.dpy, win.platformHandle, EventMask);
    auto status = xlib.XSetWMProtocols(this.conf.dpy, win.platformHandle,
      this.atoms.ptr, cast(int)this.atoms.length);
    enforce(status == 1);
  }
}

} // version xlib

module appf.window;

import appf.event;
import std.conv, std.exception, std.string;
import guip._;

/**
 * Interface to manage window events
 */
interface WindowHandler {
  void onEvent(Event e, Window win);
}

version (Posix) {
  version = xlib;
  import xlib = xlib.xlib;
  import xutil = xlib.xutil;
} else {
  static assert(0);
}

/**
 * Policy specifying empty event queue behviour
 */
enum OnEmpty { Block, Return }

version (xlib) {
/**
 * Window class provides an OS independent abstraction of a window.
 */
class Window {
  alias xlib.Window PlatformHandle;
  WindowHandler _handler;
  WindowConf conf;
  PlatformHandle hwnd;
  xlib.GC gc;

  this(WindowConf conf, WindowHandler handler, IRect rect) {
    this(conf, handler);
    this.hwnd = createWindow(null, rect);
    this.gc = xlib.XCreateGC(this.conf.dpy, this.hwnd, 0, null);
  }

  private this(WindowConf conf, WindowHandler handler) {
    this.handler = handler;
    this.conf = conf;
  }

  ~this() {
    xlib.XFreeGC(this.conf.dpy, this.gc);
    xlib.XDestroyWindow(this.conf.dpy, this.hwnd);
  }

  /**
   * Creates a new sub window of this window. The window is invisible
   * until it's show() method was called. No events are dispatched to
   * subwindows.
   * Parameters:
   *     rect = the initial position and size of the window in parent coordinates
   * Returns:
   *     the newly created window
   */
  Window makeSubWindow(IRect rect=IRect(400, 300)) {
    enforce(!rect.empty);
    auto sub = new Window(this.conf, null);
    sub.hwnd = createWindow(this, rect);
    sub.gc = xlib.XCreateGC(sub.conf.dpy, sub.hwnd, 0, null);
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
    if (this.handler !is null)
      this.handler.onEvent(Event(StateEvent(VisibilityEvent(true))), this);
    return this;
  }

  /**
   * Makes the window invisible
   */
  ref Window hide() {
    if (this.handler !is null)
      this.handler.onEvent(Event(StateEvent(VisibilityEvent(false))), this);
    xlib.XUnmapWindow(this.conf.dpy, this.hwnd);
    return this;
  }

  /**
   * Returns:
   *     the current area of this window in parent coordinates
   */
  @property IRect area() {
    xlib.XWindowAttributes attr;
    xlib.XGetWindowAttributes(this.conf.dpy, this.hwnd, &attr);
    return IRect().setXYWH(attr.x, attr.y, attr.width, attr.height);
  }

  /**
   * Resizes the window while leaving the top left corner at it's
   * current position.
   * Parameters:
   *     size = the new window size
   */
  ref Window resize(ISize size) {
    xlib.XResizeWindow(this.conf.dpy, this.hwnd, size.width, size.height);
    return this;
  }

  /**
   * Moves the window.
   * Parameters:
   *     pos = the new position of the top left corner
   */
  ref Window move(IPoint pos) {
    xlib.XMoveWindow(this.conf.dpy, this.hwnd, pos.x, pos.y);
    return this;
  }

  /**
   * Moves and resizes the window.
   * Parameters:
   *     rect = the new position and size of the window
   */
  ref Window moveResize(IRect rect) {
    xlib.XMoveResizeWindow(this.conf.dpy, this.hwnd,
      rect.left, rect.top, rect.width, rect.height);
    return this;
  }

  /**
   * Returns:
   *     the OS specific handle of this window
   */
  @property PlatformHandle platformHandle() const {
    return this.hwnd;
  }

  /**
   * Blits a region from the bitmap onto the window
   * Parameters:
   *    src = the bitmap to take bits from
   *    srcPos = the position in the bitmap to take bits from
   *    dstPos = the posistion in the window to blit to
   *    size = the width and height to blit
   */
  void blitToWindow(in Bitmap bitmap, in IPoint srcPos, in IPoint dstPos, in ISize size) {
    auto dpy = this.conf.dpy;
    auto scr = this.conf.scr;

    auto visual = xlib.XDefaultVisual(dpy, scr);
    auto depth = xlib.XDefaultDepth(dpy, scr);
    auto xi = xlib.XCreateImage(dpy, visual, 24, xlib.ZPixmap,
                                0, (cast(Bitmap)bitmap).getBuffer!byte().ptr,
                                bitmap.width, bitmap.height, 8, 0);
    assert(srcPos.x + size.width <= xi.width, to!string(srcPos) ~ "sz:" ~ to!string(size));
    assert(srcPos.y + size.height <= xi.height);
    xlib.XPutImage(dpy, this.hwnd, this.gc, xi, srcPos.x, srcPos.y, dstPos.x, dstPos.y,
                   size.width, size.height);
    xi.data = null; //! data is owned by bitmap buffer
    xutil.XDestroyImage(xi);
  }

  /**
   * Posts an event to this window's event loop
   * Parameters:
   *     e = the event to post
   */
  void sendEvent(Event e) {
    auto xe = toPlatformEvent(e, this.conf.dpy, this.hwnd);
    xlib.XSendEvent(this.conf.dpy, this.hwnd, xlib.Bool.True,
      xemask(xe.type), &xe);
  }

private:

  xlib.Window createWindow(Window parent, IRect r) {
    auto dpy = this.conf.dpy;
    auto scr = this.conf.scr;

    auto rootwin = parent is null ? xlib.XRootWindow(dpy, scr) : parent.platformHandle;
    enum border = 2;
    return xlib.XCreateSimpleWindow(dpy, rootwin, r.left, r.top,
      r.width, r.height, border,
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
  xlib.StructureNotifyMask
  //  xlib.VisibilityChangeMask
 ;

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

  bool dispatchMessage(OnEmpty doThis = OnEmpty.Block) {
    if (!this.windows.length)
      return false;

    xlib.XEvent e;
    if (doThis == OnEmpty.Return) {
      if (!xlib.XPending(this.conf.dpy))
        return true;
    }
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
        auto area = IRect().setXYWH(
          e.xexpose.x, e.xexpose.y, e.xexpose.width, e.xexpose.height);
        this.sendEvent(e.xexpose.window, Event(RedrawEvent(area)));
      }
      break;

    case xlib.ButtonPress:
      this.sendEvent(e.xbutton.window, Event(buttonEvent(e.xbutton, true)));
      break;

    case xlib.ButtonRelease:
      this.sendEvent(e.xbutton.window, Event(buttonEvent(e.xbutton, false)));
      break;

    case xlib.KeyPress:
      this.sendEvent(e.xkey.window, Event(keyEvent(e.xkey, true)));
      break;

    case xlib.KeyRelease:
      this.sendEvent(e.xkey.window, Event(keyEvent(e.xkey, false)));
      break;

    case xlib.MotionNotify:
      this.sendEvent(e.xmotion.window, Event(mouseEvent(e.xmotion)));
      break;

    case xlib.MapNotify:
      std.stdio.writeln("map notify");
      break;

    case xlib.ConfigureNotify:
      xlib.XConfigureEvent conf = e.xconfigure;
      xlib.XExposeEvent exp;

    loop: while (xlib.XPending(this.conf.dpy)) {
      xlib.XEvent peek;
        xlib.XPeekEvent(this.conf.dpy, &peek);
        switch (peek.type) {
        case xlib.ConfigureNotify:
          xlib.XNextEvent(this.conf.dpy, &peek);
          assert(peek.type == xlib.ConfigureNotify);
          conf = peek.xconfigure;
          break;
        case xlib.Expose:
          xlib.XNextEvent(this.conf.dpy, &peek);
          assert(peek.type == xlib.Expose);
          exp = peek.xexpose;
          break;
        default:
          break loop;
        }
      }

      auto area = IRect().setXYWH(
        conf.x, conf.y, conf.width, conf.height);
      this.sendEvent(conf.window, Event(ResizeEvent(area)));
      if (exp.type == xlib.Expose) {
        area = IRect().setXYWH(
            exp.x, exp.y, exp.width, exp.height);
        this.sendEvent(exp.window, Event(RedrawEvent(area)));
      }

    default:
    }
    return true;
  }

  static ButtonEvent buttonEvent(xlib.XButtonEvent xe, bool isdown) {
    auto pos = IPoint(xe.x, xe.y);
    auto btn = buttonDetail(xe.button);
    auto mod = modState(xe.state);
    return ButtonEvent(pos, isdown, btn, mod);
  }

  static KeyEvent keyEvent(xlib.XKeyEvent xe, bool isdown) {
    auto pos = IPoint(xe.x, xe.y);
    auto key = keyDetail(xe.keycode);
    auto mod = modState(xe.state);
    return KeyEvent(pos, isdown, key, mod);
  }

  static MouseEvent mouseEvent(xlib.XMotionEvent xe) {
    auto pos = IPoint(xe.x, xe.y);
    auto btn = buttonState(xe.state);
    auto mod = modState(xe.state);
    return MouseEvent(pos, btn, mod);
  }

  void sendEvent(Window.PlatformHandle hwnd, Event event)
  {
    auto win = hwnd in this.windows;
    if (win !is null && win.handler !is null)
      win.handler.onEvent(event, *win);
  }

  void initWindow(Window win) {
    xlib.XSelectInput(this.conf.dpy, win.platformHandle, EventMask);
    auto status = xlib.XSetWMProtocols(this.conf.dpy, win.platformHandle,
      this.atoms.ptr, cast(int)this.atoms.length);
    enforce(status == 1);
  }
}

} // version xlib

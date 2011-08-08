module appf.window;

import appf.event;
import std.algorithm, std.conv, std.exception, std.string, std.traits;
import guip._;

/**
 * Interface to manage window events
 */
interface WindowHandler {
  void onEvent(Event e, Window win);
}

version (Posix) {
  version = xlib;
  import x11.xlib;
} else {
  static assert(0);
}

/**
 * Policy specifying empty event queue behaviour
 */
enum OnEmpty { Block, Return }

version (xlib) {
/**
 * Window class provides an OS independent abstraction of a window.
 */
class Window {
  alias x11.xlib.Window PlatformHandle;
  WindowHandler _handler;
  WindowConf conf;
  PlatformHandle hwnd;
  GC gc;

  this(WindowConf conf, WindowHandler handler, IRect rect) {
    this(conf, handler);
    this.hwnd = createWindow(null, rect);
    this.gc = XCreateGC(this.conf.dpy, this.hwnd, 0, null);
  }

  private this(WindowConf conf, WindowHandler handler) {
    this.handler = handler;
    this.conf = conf;
  }

  ~this() {
    XFreeGC(this.conf.dpy, this.gc);
    XDestroyWindow(this.conf.dpy, this.hwnd);
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
  Window mkSubWindow(IRect rect=IRect(400, 300)) {
    enforce(!rect.empty);
    auto sub = new Window(this.conf, null);
    sub.hwnd = createWindow(this, rect);
    sub.gc = XCreateGC(sub.conf.dpy, sub.hwnd, 0, null);
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
    char* name;
    scope(exit) if (name !is null) XFree(cast(void*)name);
    if (XFetchName(this.conf.dpy, this.hwnd, &name))
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
    XStoreName(this.conf.dpy, this.hwnd, toStringz(title));
    return this;
  }

  /**
   * Makes the window visible
   */
  ref Window show() {
    XMapWindow(this.conf.dpy, this.hwnd);
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
    XUnmapWindow(this.conf.dpy, this.hwnd);
    return this;
  }

  /**
   * Returns:
   *     the current area of this window in parent coordinates
   */
  @property IRect area() {
    XWindowAttributes attr;
    XGetWindowAttributes(this.conf.dpy, this.hwnd, &attr);
    return IRect().setXYWH(attr.x, attr.y, attr.width, attr.height);
  }

  /**
   * Resizes the window while leaving the top left corner at it's
   * current position.
   * Parameters:
   *     size = the new window size
   */
  ref Window resize(ISize size) {
    XResizeWindow(this.conf.dpy, this.hwnd, size.width, size.height);
    return this;
  }

  /**
   * Moves the window.
   * Parameters:
   *     pos = the new position of the top left corner
   */
  ref Window move(IPoint pos) {
    XMoveWindow(this.conf.dpy, this.hwnd, pos.x, pos.y);
    return this;
  }

  /**
   * Moves and resizes the window.
   * Parameters:
   *     rect = the new position and size of the window
   */
  ref Window moveResize(IRect rect) {
    XMoveResizeWindow(this.conf.dpy, this.hwnd,
      rect.left, rect.top, rect.width, rect.height);
    return this;
  }

  /**
   * Sets the current input focus to this window
   */
  void grabInputFocus() {
    XSetInputFocus(this.conf.dpy, this.hwnd,
                   InputFocusRevertTo.RevertToNone, CurrentTime);
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

    auto visual = XDefaultVisual(dpy, scr);
    auto depth = XDefaultDepth(dpy, scr);
    auto xi = XCreateImage(dpy, visual, 24, ImageFormat.ZPixmap,
                                0, (cast(Bitmap)bitmap).getBuffer!byte().ptr,
                                bitmap.width, bitmap.height, 8, 0);
    assert(srcPos.x + size.width <= xi.width, to!string(srcPos) ~ "sz:" ~ to!string(size));
    assert(srcPos.y + size.height <= xi.height);
    XPutImage(dpy, this.hwnd, this.gc, xi, srcPos.x, srcPos.y, dstPos.x, dstPos.y,
                   size.width, size.height);
    xi.data = null; //! data is owned by bitmap buffer
    enforce(xi.f.destroy_image(xi));
  }

  /**
   * Posts an event to this window's event loop
   * Parameters:
   *     e = the event to post
   */
  void sendEvent(Event e) {
    auto xe = toPlatformEvent(e, this.conf.dpy, this.hwnd);
    XSendEvent(this.conf.dpy, this.hwnd, Bool.True,
      xemask(xe.type), &xe);
  }

private:

  PlatformHandle createWindow(Window parent, IRect r) {
    auto dpy = this.conf.dpy;
    auto scr = this.conf.scr;

    auto rootwin = parent is null ? XRootWindow(dpy, scr) : parent.platformHandle;
    enum border = 2;
    return XCreateSimpleWindow(dpy, rootwin, r.left, r.top,
      r.width, r.height, border,
      XBlackPixel(dpy, scr), XWhitePixel(dpy, scr));
  }
}

package:

struct WindowConf {
  XDisplay* dpy;
  int scr;

  void init() {
    this.dpy = enforce(XOpenDisplay(null),
      new Exception("ERROR: Could not open default display"));
    this.scr = XDefaultScreen(this.dpy);
  }
}

enum DefaultEvents =
  EventMask.ExposureMask |
  EventMask.ButtonPressMask |
  EventMask.ButtonReleaseMask |
  EventMask.FocusChangeMask |
  EventMask.PointerMotionMask |
    //    EventMask.PointerMotionHintMask |
  EventMask.KeyPressMask |
  EventMask.KeyReleaseMask |
  EventMask.StructureNotifyMask
  //  EventMask.VisibilityChangeMask
 ;

enum AtomT {
  WM_PROTOCOLS,
  WM_DELETE_WINDOW,
    //WM_TAKE_FOCUS,
  _NET_WM_PING,

  XdndEnter,
  XdndPosition,
  XdndStatus,
  XdndLeave,
  XdndDrop,
  XdndFinished,
  XdndTypeList,
  XdndActionList,

  XdndSelection,

  XdndAware,
  XdndProxy,

  XdndActionCopy,
  XdndActionLink,
  XdndActionMove,
  XdndActionPrivate,

  XA_STRING,
  UTF8_STRING,
}

enum Mime : string {
  TextPlain = "text/plain",
  UriList = "text/uri-list",
}

enum XDND_VERSION = 4;
enum AnyPropertyType = cast(Atom)0;
enum XA_ATOM = cast(Atom)4;
enum XA_STRING = cast(Atom)31;

struct Property {
  ubyte[] data;
  int format;
  ulong nitems;
  Atom type;
}

Property readProperty(XDisplay* dpy, Window.PlatformHandle w, Atom property) {
  Property res;
  ubyte* ret;
  ulong remain;
  XGetWindowProperty(dpy, w, property, 0, -1, Bool.False, AnyPropertyType,
                     &res.type, &res.format, &res.nitems, &remain, &ret);
  size_t nbytes = (res.format / 8) * res.nitems;
  static if (size_t.sizeof == 8) {
    if (res.format == 32)
      nbytes = (nbytes & 0x7) ? (nbytes / 8 + 1) * 8 : nbytes;
  }
  res.data.length = nbytes;
  res.data[] = ret[0 .. nbytes];
  XFree(ret);
  return res;
}

struct MessageLoop {
  WindowConf conf;
  Atom[AtomT.max + 1] atoms;
  Atom[Mime] mimeAtoms;
  Window[Window.PlatformHandle] windows;
  XDNDState xdndState;
  ButtonDownState btnDownState;

  this(WindowConf conf) {
    enforce(conf.dpy);
    this.conf = conf;
    foreach(i, name; __traits(allMembers, AtomT)) {
      auto atom = XInternAtom(this.conf.dpy, toStringz(name), Bool.False);
      this.atoms[i] = atom;
    }
    foreach(e; EnumMembers!Mime) {
      auto atom = XInternAtom(this.conf.dpy, toStringz(e), Bool.False);
      this.mimeAtoms[e] = atom;
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
    return p is null ? false : enforce(*p == win);
  }

  // TODO: take Display* from events rather than from conf
  bool dispatchMessage(OnEmpty doThis = OnEmpty.Block) {
    if (!this.windows.length)
      return false;

    XEvent e;
    if (doThis == OnEmpty.Return) {
      if (!XPending(this.conf.dpy))
        return true;
    }
    XNextEvent(this.conf.dpy, &e);

    switch (e.type) {
    case EventType.ClientMessage:
      if (e.xclient.format != 32 || e.xclient.message_type == 0)
        break;

      // WM protocols
      // http://standards.freedesktop.org/wm-spec/1.3/ar01s06.html
      if (e.xclient.message_type == this.atoms[AtomT.WM_PROTOCOLS]) {
        if (e.xclient.data.l[0] == this.atoms[AtomT.WM_DELETE_WINDOW]) {
          this.removeWindow(this.windows.get(e.xclient.window, null));
          return this.windows.length > 0;
        } else if (e.xclient.data.l[0] == this.atoms[AtomT._NET_WM_PING]) {
          assert(this.conf.dpy == e.xclient.display);
          e.xclient.window = XRootWindow(this.conf.dpy, this.conf.scr);
          XSendEvent(e.xclient.display, e.xclient.window, Bool.False,
            EventMask.SubstructureRedirectMask | EventMask.SubstructureNotifyMask, &e);
        }

      // XDND handling
      // http://www.freedesktop.org/wiki/Specifications/XDND#ClientMessages
      } else if (e.xclient.message_type == this.atoms[AtomT.XdndEnter]) {
        assert(xdndState == xdndState.init);

        auto srcVer = cast(ubyte)((e.xclient.data.l[1] >>> 24) & 0xf);
        if (srcVer > XDND_VERSION)
          break;

        xdndState.sourceWin = cast(Window.PlatformHandle)(e.xclient.data.l[0]);
        xdndState.targetWin = e.xclient.window;
        if (e.xclient.data.l[1] & 0x1) {
          auto types = readProperty(this.conf.dpy, xdndState.sourceWin,
                                    this.atoms[AtomT.XdndTypeList]);
          if (types.format != 32 || types.type != XA_ATOM)
            break;
          xdndState.types = cast(Atom[])types.data;
        } else {
          auto types = e.xclient.data.l[2 .. 5];
          auto zcnt = find!q{a==0}(types).length;
          xdndState.types = cast(Atom[])types[0 .. $ - zcnt].dup;
        }

      } else if (e.xclient.message_type == this.atoms[AtomT.XdndPosition]) {
        assert(xdndState.targetWin == e.xclient.window);

        bool accept;
        if (xdndState.files is null) {
          auto tstamp = e.xclient.data.l[3];

          if (!xdndState.pendingConversion &&
              canFind(xdndState.types, this.mimeAtoms[Mime.UriList])) {

            XConvertSelection(this.conf.dpy, this.atoms[AtomT.XdndSelection],
                              this.mimeAtoms[Mime.UriList], this.atoms[AtomT.XdndSelection],
                              xdndState.targetWin, tstamp);
            xdndState.pendingConversion = true;
          }
        } else {
          auto pos = e.xclient.data.l[2];
          auto rootwin = XRootWindow(this.conf.dpy, this.conf.scr);

          int rx = (pos & 0xFFFF0000) >> 16;
          int ry = pos & 0xFFFF;

            int tx, ty;
          Window.PlatformHandle childRet;
          XTranslateCoordinates(
              this.conf.dpy, rootwin, xdndState.targetWin,
              rx, ry, &tx, &ty,
              &childRet);
          xdndState.pos = IPoint(tx, ty);
          this.sendEvent(xdndState.targetWin, Event(DragEvent(xdndState.pos, xdndState.files)));
          accept = true;
        }

        XClientMessageEvent resp;
        resp.type = EventType.ClientMessage;
        resp.window = xdndState.sourceWin;
        resp.format = 32;
        resp.message_type = this.atoms[AtomT.XdndStatus];
        resp.data.l[0] = e.xclient.window;
        resp.data.l[1] = accept ? 0x1 : 0x0; // flags
        resp.data.l[2] = e.xclient.data.l[2]; // coords (x << 16 | y)
        resp.data.l[3] = (2 << 16) | 2; // (w << 16 | h)
        resp.data.l[4] = accept ? this.atoms[AtomT.XdndActionCopy] : 0; // accepted action
        XSendEvent(this.conf.dpy, xdndState.sourceWin,
                   Bool.False, EventMask.NoEventMask, cast(XEvent*)&resp);

      } else if (e.xclient.message_type == this.atoms[AtomT.XdndLeave]) {
        assert(xdndState.targetWin == e.xclient.window);

        XDeleteProperty(this.conf.dpy, xdndState.targetWin, this.atoms[AtomT.XdndSelection]);
        xdndState = xdndState.init;

      } else if (e.xclient.message_type == this.atoms[AtomT.XdndDrop]) {
        assert(xdndState.targetWin == e.xclient.window);

        XDeleteProperty(this.conf.dpy, xdndState.targetWin, this.atoms[AtomT.XdndSelection]);

        bool accept = xdndState.files !is null;
        if (accept)
          this.sendEvent(xdndState.targetWin,
                         Event(DropEvent(xdndState.pos, xdndState.files))
          );

        XClientMessageEvent resp;
        resp.type = EventType.ClientMessage;
        resp.window = xdndState.sourceWin;
        resp.format = 32;
        resp.message_type = this.atoms[AtomT.XdndFinished];
        resp.data.l[0] = e.xclient.window;
        resp.data.l[1] = accept ? 0x1 : 0x0; // flags
        resp.data.l[2] = accept ? this.atoms[AtomT.XdndActionCopy] : 0; // accepted action
        XSendEvent(this.conf.dpy, xdndState.sourceWin,
                   Bool.False, EventMask.NoEventMask, cast(XEvent*)&resp);

        xdndState = xdndState.init;

      // unhandled client message
      } else {
        foreach(i, name; __traits(allMembers, AtomT)) {
          if (e.xclient.message_type == this.atoms[i]) {
            std.stdio.writeln("unhandled client message ", name);
            break;
          }
        }
      }
      break;

    case EventType.SelectionNotify:
      if (e.xselection.selection == this.atoms[AtomT.XdndSelection]) {
        auto prop = readProperty(this.conf.dpy, e.xselection.requestor,
                                 this.atoms[AtomT.XdndSelection]);
        if (prop.format != 8 || prop.type != this.mimeAtoms[Mime.UriList])
          break;
        xdndState.files = split(cast(string)prop.data);
        xdndState.pendingConversion = false;
      }
      break;

    case EventType.Expose:
      if (e.xexpose.count < 1) {
        auto area = IRect().setXYWH(
          e.xexpose.x, e.xexpose.y, e.xexpose.width, e.xexpose.height);
        this.sendEvent(e.xexpose.window, Event(RedrawEvent(area)));
      }
      break;

    case EventType.ButtonPress:
      auto be = buttonEvent(e.xbutton, true);
      be.isdouble = storeButtonDownState(e.xbutton, be);
      this.sendEvent(e.xbutton.window, Event(be));
      break;

    case EventType.ButtonRelease:
      auto be = buttonEvent(e.xbutton, false);
      be.isdouble = btnDownState.be.isdouble;
      this.sendEvent(e.xbutton.window, Event(be));
      break;

    case EventType.FocusIn:
      this.sendEvent(e.xfocus.window, Event(StateEvent(FocusEvent(true))));
      break;

    case EventType.FocusOut:
      this.sendEvent(e.xfocus.window, Event(StateEvent(FocusEvent(false))));
      break;

    case EventType.KeyPress:
      this.sendEvent(e.xkey.window, Event(keyEvent(e.xkey, true)));
      break;

    case EventType.KeyRelease:
      this.sendEvent(e.xkey.window, Event(keyEvent(e.xkey, false)));
      break;

    case EventType.MotionNotify:
      this.sendEvent(e.xmotion.window, Event(mouseEvent(e.xmotion)));
      break;

    case EventType.MapNotify:
      std.stdio.writeln("map notify");
      break;

    case EventType.ConfigureNotify:
      XConfigureEvent conf = e.xconfigure;
      XExposeEvent exp;

    loop: while (XPending(this.conf.dpy)) {
      XEvent peek;
        XPeekEvent(this.conf.dpy, &peek);
        switch (peek.type) {
        case EventType.ConfigureNotify:
          XNextEvent(this.conf.dpy, &peek);
          assert(peek.type == EventType.ConfigureNotify);
          conf = peek.xconfigure;
          break;
        case EventType.Expose:
          XNextEvent(this.conf.dpy, &peek);
          assert(peek.type == EventType.Expose);
          exp = peek.xexpose;
          break;
        default:
          break loop;
        }
      }

      auto area = IRect().setXYWH(
        conf.x, conf.y, conf.width, conf.height);
      this.sendEvent(conf.window, Event(ResizeEvent(area)));
      if (exp.type == EventType.Expose) {
        area = IRect().setXYWH(
            exp.x, exp.y, exp.width, exp.height);
        this.sendEvent(exp.window, Event(RedrawEvent(area)));
      }
      break;

    default:
      std.stdio.writeln("unhandled event type ", e.type);
    }
    return true;
  }

  static ButtonEvent buttonEvent(XButtonEvent xe, bool isdown) {
    auto pos = IPoint(xe.x, xe.y);
    auto btn = buttonDetail(xe.button);
    auto mod = modState(xe.state);
    auto be = ButtonEvent(pos, btn, mod);
    be.isdown = isdown;
    return be;
  }

  static KeyEvent keyEvent(XKeyEvent xe, bool isdown) {
    auto pos = IPoint(xe.x, xe.y);
    auto key = keyDetail(xe.keycode);
    auto mod = modState(xe.state);
    auto ke = KeyEvent(pos, key, mod);
    ke.isdown = isdown;
    return ke;
  }

  static MouseEvent mouseEvent(XMotionEvent xe) {
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
    XSelectInput(this.conf.dpy, win.platformHandle, DefaultEvents);
    auto status = XSetWMProtocols(this.conf.dpy, win.platformHandle,
      this.atoms.ptr, cast(int)this.atoms.length);

    enforce(status == 1);

    auto atm = cast(Atom)XDND_VERSION;
    auto ret = XChangeProperty(this.conf.dpy, win.platformHandle,
                               this.atoms[AtomT.XdndAware], XA_ATOM, 32,
                               PropertyMode.PropModeReplace, cast(ubyte*)&atm, 1);
  }

  bool storeButtonDownState(XButtonEvent xe, ButtonEvent be) {
    enum DBL_MS = 400;
    enum DBL_DIST = 5.0;

    if (xe.window == btnDownState.window
        && xe.time - btnDownState.time < DBL_MS
        && distance(be.pos, btnDownState.be.pos) < DBL_DIST
        && be.button == btnDownState.be.button
        && be.mod == btnDownState.be.mod) {
        // reset state so next mouse down is not recognized as double
        // but leave double mark for release
        btnDownState = btnDownState.init;
        btnDownState.be.isdouble = true;
        return true;
      } else {
        btnDownState.window = xe.window;
        btnDownState.time = xe.time;
        be.isdouble = false;
        btnDownState.be = be;
        return false;
    }
  }
}

struct XDNDState {
  Window.PlatformHandle sourceWin, targetWin;
  IPoint pos;
  Atom[] types;
  bool pendingConversion;
  string[] files;
}

struct ButtonDownState {
  Window.PlatformHandle window;
  Time time;
  ButtonEvent be;
}

} // version xlib

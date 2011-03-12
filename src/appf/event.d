module appf.event;

import std.algorithm, std.bitmanip, std.conv, std.typetuple, std.variant;
public import guip.point, guip.rect, guip.size;

version (Posix) {
  version = xlib;
  import xlib = xlib.xlib;
} else {
  static assert(0);
}

alias TypeTuple!(StateEvent, MouseEvent, KeyEvent, RedrawEvent, ResizeEvent) EventTypes;
alias Algebraic!(EventTypes) Event;

void visitEvent(Visitor, Args...)(Event e, Visitor visitor, Args args) {
  foreach(T; EventTypes) {
    static if(is(typeof(visitor.visit(e.get!(T), args)))) {
      if (e.type == typeid(T))
        visitor.visit(e.get!(T), args);
    }
  }
}

struct StateEvent {
  bool visible;
}

struct MouseEvent {
  IPoint pos;
  Button button;
  Mod mod;
}

struct KeyEvent {
  IPoint pos;
  Key key;
  Mod mod;
}

struct RedrawEvent {
  IRect area;
}

struct ResizeEvent {
  IRect area;
}

struct Button {
  mixin(bitfields!(
          bool, "left", 1,
          bool, "middle", 1,
          bool, "right", 1,
          uint, "", 5));
}

struct Mod {
  mixin(bitfields!(
          bool, "shift", 1,
          bool, "ctrl", 1,
          bool, "alt", 1,
          bool, "numlock", 1,
          uint, "", 4));
}

struct Key {
  uint num;
  @property dchar character() const {
    return cast(dchar)this.num;
  }
}

version (xlib) {
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
}

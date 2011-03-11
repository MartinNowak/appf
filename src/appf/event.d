module appf.event;

import std.algorithm, std.bitmanip, std.conv, std.typetuple, std.variant;

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
  Pos pos;
  Button button;
  Mod mod;
}

struct KeyEvent {
  Pos pos;
  Key key;
  Mod mod;
}

struct RedrawEvent {
  Rect area;
}

struct ResizeEvent {
  Rect area;
}

struct Pos {
  @property string toString() const {
    return "Pos x:" ~ to!string(x) ~ " y:" ~ to!string(y);
  }
  int x, y;
}

struct Size {
  @property string toString() const {
    return "Size w:" ~ to!string(w) ~ " h:" ~ to!string(h);
  }
  int w, h;
}

struct Rect {
  this(int x, int y, uint w, uint h) {
    this(Pos(x, y), Size(w, h));
  }

  this(Pos pos, Size size) {
    this.pos = pos;
    this.size = size;
  }

  @property string toString() const {
    return "Rect pos:" ~ to!string(pos) ~ " size:" ~ to!string(size);
  }

  @property bool empty() const {
    return this.size.w <= 0 || this.size.h <= 0;
  }

  bool hitTest(in Pos pos) const {
    return pos.x >= this.pos.x && pos.x - this.pos.x < this.size.w
      && pos.y >= this.pos.y && pos.y - this.pos.y < this.size.h;
  }

  Rect intersection(in Rect rect) {
    Rect res;
    res.pos.x = max(this.pos.x, rect.pos.x);
    res.pos.y = max(this.pos.y, rect.pos.y);
    res.size.w = min(this.pos.x + this.size.w, rect.pos.x + rect.size.w) - res.pos.x;
    res.size.h = min(this.pos.y + this.size.h, rect.pos.y + rect.size.h) - res.pos.y;
    return res.empty ? Rect.init : res;
  }

  Pos pos;
  Size size;
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

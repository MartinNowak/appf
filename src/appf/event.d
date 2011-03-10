module appf.event;

import std.bitmanip;

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

struct Pos {
  int x, y;
}

struct Size {
  int w, h;
}

struct Rect {
  this(int x, int y, uint w, uint h) {
    this.pos = Pos(x, y);
    this.size = Size(w, h);
  }

  @property bool empty() const {
    return this.size.w * this.size.h == 0;
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
          bool, "alt", 1,
          bool, "ctrl", 1,
          bool, "shift", 1,
          uint, "", 5));
}

struct Key {
  uint num;
  @property dchar character() const {
    return cast(dchar)this.num;
  }
}

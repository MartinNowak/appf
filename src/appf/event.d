module appf.event;

import std.bitmanip, std.conv;

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

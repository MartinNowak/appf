module appf.event;

import std.algorithm, std.bitmanip;
import guip.point, guip.rect, guip.size;

version (Posix) {
  version = xlib;
  import deimos.X11.Xlib;
} else {
  static assert(0);
}


union InputEvent {
  enum Type { None, Button, Mouse, Key, Drag, Drop }
  struct { Type type; IPoint pos; }
  ButtonEvent ebutton;
  MouseEvent emouse;
  KeyEvent ekey;
  DragEvent edrag;
  DropEvent edrop;
}

struct ButtonEvent {
  this(IPoint pos, Button button, Mod mod) {
    this.pos = pos; this.button = button; this.mod = mod;
  }
  @property bool isPress() const {
    return this.isdown && !this.isdouble;
  }
  @property bool isRelease() const {
    return !this.isdown && !this.isdouble;
  }
  @property bool isDoublePress() const {
    return this.isdown && this.isdouble;
  }
  @property bool isDoubleRelease() const {
    return !this.isdown && this.isdouble;
  }
  InputEvent.Type type = InputEvent.Type.Button;
  IPoint pos;
  Button button;
  Mod mod;
  mixin(bitfields!(
            bool, "isdown", 1,
            bool, "isdouble", 1,
            bool, "isping", 1, // used for debug tools
            uint, "", 5));
}

struct MouseEvent {
  this(IPoint pos, Button button, Mod mod) {
    this.pos = pos; this.button = button; this.mod = mod;
  }
  InputEvent.Type type = InputEvent.Type.Mouse;
  IPoint pos;
  Button button;
  Mod mod;
}

struct KeyEvent {
  this(IPoint pos, Key key, Mod mod, bool isdown) {
    this.pos = pos; this.key = key; this.mod = mod; this.isdown = isdown;
  }
  @property bool isPress() const {
    return this.isdown;
  }
  @property bool isRelease() const {
    return !this.isdown;
  }
  InputEvent.Type type = InputEvent.Type.Key;
  IPoint pos;
  Key key;
  Mod mod;
  bool isdown;
}

struct DragEvent {
  this(IPoint pos, string[] files) { this.pos = pos; this.files = files; }
  InputEvent.Type type = InputEvent.Type.Drag;
  IPoint pos;
  string[] files;
}

struct DropEvent {
  this(IPoint pos, string[] files) { this.pos = pos; this.files = files; }
  InputEvent.Type type = InputEvent.Type.Drop;
  IPoint pos;
  string[] files;
}

/**
   a bitfield representing pressed buttons
 */
struct Button {
  @property bool any() const {
    return this.left || this.middle || this.right || this.wheelup || this.wheeldown;
  }

  mixin(bitfields!(
          bool, "left", 1,
          bool, "middle", 1,
          bool, "right", 1,
          bool, "wheelup", 1,
          bool, "wheeldown", 1,
          uint, "", 3));
}

/**
   a bitfield representing pressed modifiers
 */
struct Mod {
  @property bool any() const {
    return this.shift || this.ctrl || this.alt;
  }

  mixin(bitfields!(
          bool, "shift", 1,
          bool, "ctrl", 1,
          bool, "alt", 1,
          bool, "numlock", 1,
          uint, "", 4));
}

/**
   translates a key to it's corresponding character
 */
struct Key {
  uint num;
  @property dchar character() const {
    return cast(dchar)this.num;
  }
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
    mod.shift = (state & KeyMask.ShiftMask) != 0;
    mod.ctrl = (state & KeyMask.ControlMask) != 0;
    mod.alt = (state & KeyMask.Mod1Mask) != 0;
    mod.numlock = (state & KeyMask.Mod2Mask) != 0;
    return mod;
  }
}

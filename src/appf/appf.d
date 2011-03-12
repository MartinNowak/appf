module appf.appf;

public import appf.window;
import std.exception, std.stdio;

/**
 * Application main class
 */
class AppF {
  /**
   * Parameters:
   *     args = arguments to dmain
   */
  this() {
    this.winconf.init();
    this.msgLoop = MessageLoop(this.winconf);
  }

  /**
   * Dispatches a single message to any created windows.
   * Returns:
   *     false if the last window was closed
   */
  bool dispatch() {
    return msgLoop.dispatchMessage();
  }

  /**
   * Infinitely dispatches messages to any created windows until the
   * last window is closed.
   * Returns:
   *     zero upon successful exit
   */
  int loop() {
    while (this.dispatch()) {}
    return 0;
  }

  /**
   * Creates a new window. The window is invisible until it's show() method was called.
   * Parameters:
   *     rect = the initial position and size of the window
   *     handler = instance of WindowHandler to handle Input/Redraw requests
   * Returns:
   *     the newly created window
   */
  Window makeWindow(IRect rect=IRect(400, 300), WindowHandler handler=null) {
    enforce(!rect.empty);
    auto win = new Window(this.winconf, handler, rect);
    this.msgLoop.addWindow(win);
    return win;
  }

  /**
   * Hides and destroys the passed in window.
   * Parameters:
   *     win = the window to destroy
   */
  void destroyWindow(ref Window win) {
    scope(exit) { delete win; win = null; }
    enforce(this.msgLoop.removeWindow(win));
  }

private:

  MessageLoop msgLoop;
  WindowConf winconf;
}

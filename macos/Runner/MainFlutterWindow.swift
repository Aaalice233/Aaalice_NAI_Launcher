import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    guard AppDelegate.acquirePrimaryInstanceLock() else {
      AppDelegate.notifyExistingPrimary()
      DispatchQueue.main.async { NSApp.terminate(nil) }
      super.awakeFromNib()
      return
    }
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.title = "Aaalice NAI Launcher"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

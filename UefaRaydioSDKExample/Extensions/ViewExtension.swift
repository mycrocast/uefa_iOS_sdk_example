import Foundation
import SwiftUI

extension View {
  func onAppCameToForeground(perform action: @escaping () -> Void) -> some View {
    self.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
       action()
    }
  }

  func onAppWentToBackground(perform action: @escaping () -> Void) -> some View {
    self.onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
      action()
    }
  }
}

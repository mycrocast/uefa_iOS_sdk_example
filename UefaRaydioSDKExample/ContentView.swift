import SwiftUI
import SwiftRaydioSDK

struct ContentView: View {
    
    @StateObject
    var model = MainModel()
    
    var body: some View {
        ZStack {
            List {
                ForEach(model.streams, id: \.streamId) {
                    stream in
                    StreamCell(liveStream: stream, isPlaying: model.activeStream == stream.streamId) {
                        stream in
                        model.onStreamPressed(stream)
                    }
                }
            }
            if (model.streams.count == 0) {
                Text("No streams available")
                    .font(.title)
            }
        }.onAppear() {
            self.model.onAppear()
        }.onAppWentToBackground {
            self.model.onWentToBackground()
        }.onAppCameToForeground {
            self.model.onWentToForeground()
        }
    }
}

#Preview {
    ContentView()
}

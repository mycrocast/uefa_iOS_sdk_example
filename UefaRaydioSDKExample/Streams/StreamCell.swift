import SwiftUI
import SwiftRaydioSDK

struct StreamCell: View {
    
    // TODO remove optional value
    var liveStream: Stream?
    var isPlaying: Bool = false
    var callback: (_ streamid: String) -> Void
    
    var body: some View {
        VStack {
            Group {
                Text(liveStream!.title)
                    .font(.system(size: 32))
                    .padding()
                Image(systemName: isPlaying ? "pause.cirle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 100)

                HStack {
                    Spacer()
                    Text(liveStream!.language)
                        .font(.system(size: 24))
                    Spacer()
                }
                .padding()
            }.foregroundColor(.white)
        }
        .background(.black.opacity(0.85))
        .cornerRadius(15)
        .padding()
        .onTapGesture {
            self.callback(self.liveStream!.streamId)
        }
    }
}

#Preview {
    StreamCell(liveStream: nil) { stream in
        
    }
}

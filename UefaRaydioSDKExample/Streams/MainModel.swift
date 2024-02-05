import Foundation
import SwiftUI
import SwiftRaydioSDK
import Combine
import AVFoundation;
import MediaPlayer

class MainModel: ObservableObject {
    
    /// used to observe network changes
    @Injected(\.networkMonitor)
    private var networkMonitor: NetworkMonitorProviding
    
    private var cancelable: Set<AnyCancellable> = []
    
    var groups: [StreamGroup] = []
    
    @Published
    var streams: [Stream] = []
    
    @Published
    var activeStream: String? = nil
    
    var sdk: RaydioSDKProviding
    
    init() {
        self.sdk = RaydioSDK.shared.start(235617)
        self.sdk.sdkStateDelegate = self
        
        var streams = self.sdk.raydioStreams
        streams.delegate = self
        self.sdk.logDelegate = self
        self.sdk.listenerStateDelegate = self
        
        self.sdk.connect()
        
        self.networkMonitor.networkChanged$
            .sink { [weak self]
            networkAvailable in
                if let this = self {
                    if (networkAvailable) {
                        this.sdk.onConnectionReestablished()
                        return
                    }
                    this.sdk.onConnectionLost()
                }
            
            }.store(in: &self.cancelable)
    }
    
    
    func onAppear() {
        if (self.sdk.skdState == .connected) {
            self.sdk.requestStreams()
        }
    }
    
    private func convertGroupsToStream() {
        DispatchQueue.main.async {
            self.streams = []
            for group in self.groups {
                for entry in group.entries {
                    let stream = Stream(streamId: entry.streamId, muted: entry.isMuted, title: group.title, language: entry.language)
                    self.streams.append(stream)
                }
            }
        }
    }
    
    func onWentToBackground() {
        self.sdk.onBackgroundEntered()
    }
    
    func onWentToForeground() {
     self.sdk.onForegroundEntered()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
    }
    
    func onStreamPressed(_ streamId: String) {
        self.configureAudioSession()
        if let activeStream = self.activeStream {
            self.sdk.pause()
            self.activeStream = nil
            if (activeStream == streamId) {
                return
            }
        }
        self.activeStream = streamId
        self.sdk.play(streamId)
    }
}

// react to receiving streams and updates to streams
extension MainModel: StreamGroupDelegate {
    
    func onNewGroup(_ group: SwiftRaydioSDK.StreamGroup) {
        DispatchQueue.main.async {
            self.groups.append(group)
            self.convertGroupsToStream()
        }
    }
    
    func onGroupUpdated(_ group: SwiftRaydioSDK.StreamGroup) {
        DispatchQueue.main.async {
            let index = self.groups.firstIndex {
                element in
                return group.title == element.title
            }
            
            if let index = index {
                self.groups[index] = group
                self.convertGroupsToStream()
            }
        }
    }
    
    func onGroupRemoved(_ group: SwiftRaydioSDK.StreamGroup) {
        DispatchQueue.main.async {
            let index = self.groups.firstIndex {
                element in
                return group.title == element.title
            }
            
            if let index = index {
                self.groups.remove(at: index)
                self.convertGroupsToStream()
            }
        }
    }
    
    func onGroupsReceived(_ groups: [SwiftRaydioSDK.StreamGroup]) {
        DispatchQueue.main.async {
            self.groups.removeAll()
            self.groups.append(contentsOf: groups)
            self.convertGroupsToStream()
        }
    }
}

// here you could log the logs provided by the sdk
extension MainModel: LogDelegate {
    
    func onSystemErrorLog(_ systemError: SwiftRaydioSDK.SystemErrorLog) {
        print(systemError)
    }
    
    func onInformationLog(_ information: SwiftRaydioSDK.InformationLog) {
        print(information)
    }
    
    func onErrorLog(_ error: SwiftRaydioSDK.ErrorLog) {
        print(error)
    }
    
    func onInteractionLog(_ interaction: SwiftRaydioSDK.InteractionLog) {
        print(interaction)
    }
}

// react to listen state changes
// you could update now playing
// update the ui and so on
extension MainModel: ListenStateDelegate {
    func onListenStageChanged(_ playState: SwiftRaydioSDK.RaydioPlayState) {
        if (playState == .playing) {
            DispatchQueue.main.async {
                self.activeStream = self.sdk.activeStream
                self.setupRemoteControl()
                
                let index = self.sdk.raydioStreams.groups.firstIndex {
                    group in
                    group.entries.contains {
                        entry in entry.streamId == self.activeStream
                    }
                }
                var title = "Livestream"
                if let index = index {
                    let group = self.sdk.raydioStreams.groups[index]
                    title = group.title
                }
                
                var nowPlaying = [String: Any]()
                nowPlaying[MPMediaItemPropertyTitle] = title
                nowPlaying[MPNowPlayingInfoPropertyIsLiveStream] = 1
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
            }
        }
        if (playState != .playing) {
            DispatchQueue.main.async {
                self.activeStream = nil
            }
        }
    }
    
    private func setupRemoteControl() {
        let remote = MPRemoteCommandCenter.shared()
        remote.pauseCommand.addTarget { [unowned self]  event in
            self.sdk.pause()
            return .success
        }
        
        remote.playCommand.addTarget { [unowned self] event in
            if let activeStream = self.sdk.activeStream {
                self.sdk.play(activeStream)
            }
            return .success
        }
        
        remote.seekForwardCommand.isEnabled = false
        remote.seekBackwardCommand.isEnabled = false
        remote.nextTrackCommand.isEnabled = false
        remote.previousTrackCommand.isEnabled = false
    }
}

// listen to state changes of the sdk
// when the sdk is connected, request the streams
// when the disconnect state occurs and network is available, reconnect
extension MainModel: RaydioSDKStateDelegate {
    func onRaydioSDKStateChanged(_ state: SwiftRaydioSDK.RaydioSDKState) {
        if (state == .connected) {
            self.sdk.requestStreams()
            return
        }
        
        if (state == .disconnected && self.networkMonitor.networkAvailable) {
            self.sdk.reconnect()
        }
    }
}

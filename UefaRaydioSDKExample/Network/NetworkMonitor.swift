import Foundation
import Network
import Combine

protocol NetworkMonitorProviding {
    var networkChanged$: AnyPublisher<Bool, Never> {get}
    var networkAvailable: Bool {get}
}

class NetworkMonitor: NetworkMonitorProviding {
    public var networkChanged$: AnyPublisher<Bool, Never> {
        get {
            self.networkChanged.eraseToAnyPublisher()
        }
    }
    
    private (set) public var networkAvailable: Bool = false
    
    private let monitor = NWPathMonitor()
    
    private var usedInterface: NWInterface.InterfaceType?
    private var networkChanged: PassthroughSubject<Bool, Never> = PassthroughSubject<Bool, Never>()
    
    init() {
        self.monitor.pathUpdateHandler = {
            path in
            if (path.status != .satisfied) {
                self.networkAvailable = false
                self.networkChanged.send(false)
                return
            }
            
            if (path.status == .satisfied) {
                guard let usedInterface = self.usedInterface else {
                    self.networkAvailable = true
                    self.usedInterface = self.determinePathInterface(path)
                    self.networkChanged.send(true)
                    return
                }
                let interface = self.determinePathInterface(path)
                if (self.networkAvailable && interface == self.usedInterface) {
                    return
                }
                self.networkAvailable = true
                self.usedInterface = self.determinePathInterface(path)
                self.networkChanged.send(true)
            }
        }
        self.startMonitoring()
    }
    
    private func determinePathInterface(_ path: NWPath) -> NWInterface.InterfaceType {
        if (path.usesInterfaceType(.cellular)) {
            return .cellular
        }
        if (path.usesInterfaceType(.wifi)) {
            return .wifi
        }
        if (path.usesInterfaceType(.wiredEthernet)) {
            return .wiredEthernet
        }
        return .other
        
    }
    
    private func startMonitoring() {
        let queue = DispatchQueue(label: "Monitor")
        self.monitor.start(queue: queue)
    }
}

private struct NetworkMonitorProvidingKey: InjectionKey {
    static var currentValue: NetworkMonitorProviding = NetworkMonitor()
}

extension InjectedValues {
    var networkMonitor: NetworkMonitorProviding {
        get { Self[NetworkMonitorProvidingKey.self] }
        set { Self[NetworkMonitorProvidingKey.self] = newValue }
    }
}

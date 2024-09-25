//
//  SCHomeViewControllerModel.swift
//  Cleaner App
//
//  Created by Vusal Nuriyev 2 on 12.09.24.
//

import SwiftUI
import Combine
import Network
import CoreTelephony

enum SCUtility: String, CaseIterable {
    case photos
    case videos
    case contacts
    
    var image: ImageResource {
        switch self {
        case .photos:
            return .image
        case .videos:
            return .clapperboard
        case .contacts:
            return .contact
        }
    }
}

enum SCInternetConnectionStatus: String {
    case connected = "Connected"
    case loading = "Loading"
    case notConnected = "Not connected"
}

class SCHomeViewModel: ObservableObject {
    
    @Published var internetConnectionStatus: SCInternetConnectionStatus = .loading
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var isCharging: Bool = false
    @Published var isPresentingInfoView: Bool = false
    @Published var cellularSignalStrength: Int = 0
    
    private var batteryLevelSubscriber: AnyCancellable?
    private var monitor: NWPathMonitor?
    private var telephonyInfo = CTTelephonyNetworkInfo()
    
    init() {
        checkInternetConnection()
        setupBatteryMonitoring()
    }
    
    // MARK: - Public
    
    // MARK: - Internet Connection Check
    
    public func checkInternetConnection() {
        monitor = NWPathMonitor()
        let queue = DispatchQueue.global(qos: .background)
        monitor?.start(queue: queue)
        
        monitor?.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self.internetConnectionStatus = .connected
                } else {
                    self.internetConnectionStatus = .notConnected
                }
            }
        }
    }
    
    public func batteryStateDescription() -> String {
        switch batteryState {
        case .charging:
            return "Charging"
        case .full:
            return "Full"
        case .unplugged:
            return "Unplugged"
        case .unknown:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Private
    
    @objc private func batteryStateDidChange(notification: Notification) {
        batteryState = UIDevice.current.batteryState
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        
        logBatteryStatus()
    }
    
    private func logBatteryStatus() {
        print("Battery State: \(batteryStateDescription())")
    }
    
    // MARK: - Battery Monitoring
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryState = UIDevice.current.batteryState
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        
        NotificationCenter.default.addObserver(self, selector: #selector(batteryStateDidChange), name: UIDevice.batteryStateDidChangeNotification, object: nil)
        
        logBatteryStatus()
    }
}

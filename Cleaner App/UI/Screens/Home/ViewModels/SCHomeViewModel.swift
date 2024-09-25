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
    @Published var batteryLevel: Float = 0.0
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
    
    // MARK: - Internet Connection Check
    
    func checkInternetConnection() {
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
    
    // MARK: - Battery Monitoring
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        
        NotificationCenter.default.addObserver(self, selector: #selector(batteryLevelDidChange), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(batteryStateDidChange), name: UIDevice.batteryStateDidChangeNotification, object: nil)
        
        logBatteryStatus()
    }
    
    @objc private func batteryLevelDidChange(notification: Notification) {
        batteryLevel = UIDevice.current.batteryLevel
    }
    
    @objc private func batteryStateDidChange(notification: Notification) {
        isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
    }
    
    func logBatteryStatus() {
        let rawBatteryLevel = UIDevice.current.batteryLevel
        print("Raw Battery Level: \(rawBatteryLevel)")
        let batteryPercentage = Int(round(rawBatteryLevel * 100))
        print("Battery Level: \(batteryPercentage)%")
        print("Battery State: \(UIDevice.current.batteryState)")
    }
}

//
//  NotificationSystem.swift
//  SceneIt
//
//  Created by Claude on 8/2/25.
//  Copyright © 2025 dannyfrancken. All rights reserved.
//

import Foundation
import os.log

// MARK: - Notification Names

enum NotificationName: String, CaseIterable {
    case startCamera = "com.dannyfrancken.sceneit.start-camera"
    case stopCamera = "com.dannyfrancken.sceneit.stop-camera"
    case enableOverlay = "com.dannyfrancken.sceneit.enable-overlay"
    case disableOverlay = "com.dannyfrancken.sceneit.disable-overlay"
    case changeEffect = "com.dannyfrancken.sceneit.change-effect"
    case updateSettings = "com.dannyfrancken.sceneit.update-settings"
}

// MARK: - Notification Manager

class NotificationManager {
    static let shared = NotificationManager()
    private let logger = Logger(subsystem: "com.dannyfrancken.sceneit", category: "NotificationManager")
    
    private init() {}
    
    // MARK: - Sending Notifications
    
    func postNotification(named notificationName: NotificationName) {
        logger.info("[SceneIt] Posting notification: \(notificationName.rawValue)")
        
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName.rawValue as NSString),
            nil,
            nil,
            true
        )
    }
    
    func postNotification(named notificationName: NotificationName, userInfo: [String: Any]) {
        logger.info("[SceneIt] Posting notification with data: \(notificationName.rawValue)")
        
        // Store userInfo in UserDefaults for IPC (CFNotifications don't support userInfo)
        let key = "notification_data_\(notificationName.rawValue)"
        UserDefaults(suiteName: "group.com.dannyfrancken.sceneit")?.set(userInfo, forKey: key)
        
        postNotification(named: notificationName)
    }
    
    // MARK: - Receiving Notifications
    
    func startListening(observer: UnsafeRawPointer, callback: @escaping CFNotificationCallback) {
        logger.info("[SceneIt] Starting notification listeners...")
        
        for notificationName in NotificationName.allCases {
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                observer,
                callback,
                notificationName.rawValue as CFString,
                nil,
                .deliverImmediately
            )
            logger.debug("[SceneIt] Added listener for: \(notificationName.rawValue)")
        }
    }
    
    func stopListening(observer: UnsafeRawPointer) {
        logger.info("[SceneIt] Stopping notification listeners...")
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer)
    }
    
    // MARK: - Data Retrieval
    
    func getUserInfo(for notificationName: NotificationName) -> [String: Any]? {
        let key = "notification_data_\(notificationName.rawValue)"
        return UserDefaults(suiteName: "group.com.dannyfrancken.sceneit")?.dictionary(forKey: key)
    }
}

// MARK: - Notification Handler Protocol

protocol NotificationHandler: AnyObject {
    func handleNotification(_ notificationName: NotificationName)
}

// MARK: - Extension Notification Manager

class ExtensionNotificationManager {
    weak var handler: NotificationHandler?
    private let logger = Logger(subsystem: "com.dannyfrancken.sceneit.extension", category: "NotificationManager")
    
    init(handler: NotificationHandler) {
        self.handler = handler
        startNotificationListeners()
    }
    
    deinit {
        stopNotificationListeners()
    }
    
    private func startNotificationListeners() {
        logger.info("[SceneIt Extension] Starting notification listeners...")
        
        let observer = Unmanaged.passUnretained(self).toOpaque()
        
        NotificationManager.shared.startListening(observer: observer) { _, observer, name, _, _ in
            guard let observer = observer,
                  let name = name else { return }
            
            let manager = Unmanaged<ExtensionNotificationManager>.fromOpaque(observer).takeUnretainedValue()
            let notificationName = String(name.rawValue)
            
            manager.logger.info("[SceneIt Extension] Received notification: \(notificationName)")
            
            if let notification = NotificationName(rawValue: notificationName) {
                manager.handler?.handleNotification(notification)
            }
        }
    }
    
    private func stopNotificationListeners() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        NotificationManager.shared.stopListening(observer: observer)
    }
}
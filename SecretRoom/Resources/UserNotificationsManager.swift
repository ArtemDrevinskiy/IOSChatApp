//
//  UserNotificationsManager.swift
//  SecretRoom
//
//  Created by Dr.Drexa on 03.10.2021.
//

import Foundation
import UserNotifications

final class UserNotificationsManager {
    static let shared = UserNotificationsManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private var isNotificationsAuthorized = false
    
    private func getNoticationStatus() {
        notificationCenter.getNotificationSettings { settings in
            self.isNotificationsAuthorized = settings.authorizationStatus == .authorized
        }
    }
    
    private func requestNotificationsAuth() {
        guard !isNotificationsAuthorized else {
            return
        }
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        notificationCenter.requestAuthorization(options: options) { allowed, error in
            if !allowed {
                print("ERROR: \(String(describing: error))")
            }
            self.isNotificationsAuthorized = allowed
        }
    }
}

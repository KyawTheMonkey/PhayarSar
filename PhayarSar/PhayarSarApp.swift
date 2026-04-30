//
//  PhayarSarApp.swift
//  PhayarSar
//
//  Created by Kyaw Zay Ya Lin Tun on 03/12/2023.
//

import SwiftUI
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import DesignKit
import LocalisationKit

var langDict: [String: [String: String]] = [:]

//@main
struct PhayarSarApp: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
  
  @StateObject private var preferences = UserPreferences()
  @StateObject private var worshipPlanRepo = WorshipPlanRepository()
  @StateObject private var dailyPrayingTimeRepository = DailyPrayingTimeRepository()
  @StateObject private var remoteConfigManager = RemoteConfigManager()
  @StateObject private var localisationManager = LocalisationManager.shared
  
  private let coreDataStack = CoreDataStack.shared
  
  init() {
    let appear = UINavigationBarAppearance()
    
    let atters: [NSAttributedString.Key: Any] = [
      .font: UIFont(name: "DMSerifDisplay-Regular", size: 18)!
    ]
    
    let largeTitleAtters: [NSAttributedString.Key: Any] = [
      .font: UIFont(name: "DMSerifDisplay-Regular", size: 26)!
    ]
    
    appear.largeTitleTextAttributes = largeTitleAtters
    appear.titleTextAttributes = atters
    UINavigationBar.appearance().standardAppearance = appear
    UINavigationBar.appearance().compactAppearance = appear
    UINavigationBar.appearance().scrollEdgeAppearance = appear
  }
}

extension PhayarSarApp {
  
  var body: some Scene {
    WindowGroup {
      Group {
        if remoteConfigManager.hasFetched {
          if preferences.hasAppLangChosen == nil {
            NavigationView {
              ChooseLanguageScreen()
            }
          } else {
            TabScreen()
          }
        } else {
          LaunchScreen()
            .onAppear {
              delay(0.5) {
                remoteConfigManager.fetch()
              }
            }
        }
      }
      .environmentObject(preferences)
      .environmentObject(worshipPlanRepo)
      .environmentObject(dailyPrayingTimeRepository)
      .environmentObject(remoteConfigManager)
      .environmentObject(localisationManager)
      .environment(\.language, localisationManager.currentLanguage)
      .environment(\.managedObjectContext, coreDataStack.viewContext)
      .preferredColorScheme(preferences.appTheme.colorScheme)
    }
  }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    langDict = Bundle.main.decode([String: [String: String]].self, from: "Language.json")
    
    
    UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .sound, .badge]) { success, error in
        if let error {
          print(error)
        }
      }
    
    // Set up firebase
    FirebaseApp.configure()
    
    // Set up push-notification
    UNUserNotificationCenter.current().delegate = self
    
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(
      options: authOptions,
      completionHandler: { _, _ in }
    )

    application.registerForRemoteNotifications()
    
    Messaging.messaging().delegate = self
    
    Messaging.messaging().token { token, error in
      if let error = error {
        print("Error fetching FCM registration token: \(error)")
      } else if let token = token {
        print("FCM registration token: \(token)")
      }
    }
    
    return true
  }
  
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }
  
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
  }
  
  func application(_ application: UIApplication,
                   didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    completionHandler(.newData)
  }
}

extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")

    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: .fcmToken,
      object: nil,
      userInfo: dataDict
    )
  }
}

extension Notification.Name {
  static let fcmToken: Self = .init(rawValue: "FCMToken")
}

//
//  RateMeController.swift
//  Pods
//
//  Created by Benjamin Chrobot on 5/17/17.
//  Copyright © 2017 Treble Media, Inc. All rights reserved.
//

import Foundation
import SystemConfiguration
import CFNetwork
import StoreKit

@objc public protocol RateMeControllerDelegate: class {
    @objc optional func rateMeControllerShouldDisplayAlert(_ controller: RateMeController) -> Bool
    @objc optional func rateMeControllerDidDisplayAlert(_ controller: RateMeController)
    @objc optional func rateMeControllerDidDeclineToRate(_ controller: RateMeController)
    @objc optional func rateMeControllerDidOptToRate(_ controller: RateMeController)
    @objc optional func rateMeControllerDidOptToRemindLater(_ controller: RateMeController)
    @objc optional func rateMeControllerWillPresentModalView(_ controller: RateMeController,
                                                             animated: Bool)
    @objc optional func rateMeControllerDidDismissModalView(_ controller: RateMeController,
                                                            animated: Bool)
}

@objc public class RateMeController: NSObject {

    // MARK: - Public Properties

    public weak var delegate: RateMeControllerDelegate?

    public static var appId: String?
    public static var daysUntilPrompt: Int = 30
    public static var usesUntilPrompt: Int = 20
    public static var significantEventsUntilPrompt: Int = -1
    public static var timeBeforeReminding: TimeInterval = 1
    public static var isDebug: Bool = false
    public static var usesAnimation: Bool = true
    public static var alwaysUseMainBundle: Bool = false

    public static var alertTitle: String?
    public static var alertMessage: String?
    public static var alertCancelTitle: String?
    public static var alertRateTitle: String?
    public static var alertRateLaterTitle: String?

    // MARK: - Private Properties

    private static let shared = RateMeController()

    private var statusBarStyle: UIStatusBarStyle?
    private var isModalOpen: Bool = false
    private var ratingAlert: UIAlertController?

    private let eventQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    // MARK: - Initialization

    private override init() {
        super.init()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appWillResignActive(_:)),
                                               name: .UIApplicationWillResignActive,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public Methods

    static var bundle: Bundle {
        if RateMeController.alwaysUseMainBundle {
            return Bundle.main
        }

        if let bundleURL = Bundle.main.url(forResource: "Appirater", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL) {
            return bundle
        }

        return Bundle.main
    }

    public static func appWillResignActive() {
        if RateMeController.isDebug {
            NSLog("APPIRATER appWillResignActive")
        }
        RateMeController.shared.hideRatingAlert()
    }

    public static func appEnteredForeground(canPromptForRating: Bool) {
        RateMeController.shared.eventQueue.addOperation {
            RateMeController.shared.incrementAndRate(canPromptForRating: canPromptForRating)
        }
    }

    public static func userDidSignificantEvent(canPromptForRating: Bool) {
        RateMeController.shared.eventQueue.addOperation {
            RateMeController.shared.incrementSignificantEventAndRate(canPromptForRating: canPromptForRating)
        }
    }

    static func showPrompt() {
        RateMeController.tryToShowPrompt()
    }

    public static func appLaunched(canPromptForRating: Bool = true) {
        DispatchQueue.global(qos: .utility).async {
            if RateMeController.isDebug {
                DispatchQueue.main.async {
                    RateMeController.shared.showRatingAlert()
                }
            } else {
                RateMeController.shared.incrementAndRate(canPromptForRating: canPromptForRating)
            }
        }
    }

    // MARK: - Private Methods

    private var doesOpenInAppStore: Bool {
        if let systemVersion = Float(UIDevice.current.systemVersion) {
            return systemVersion >= 7.0
        }

        NSLog("error even though: %@", UIDevice.current.systemVersion)
        return false
    }

    private var isConnectedToNetwork: Bool {
        return true
    }

    private var isRatingAlertAppropriate: Bool {
        return isConnectedToNetwork
            && !userHasDeclinedToRate
            && !userHasRatedCurrentVersion
            && ratingAlert?.presentingViewController == nil
    }

    private var isRatingConditionsMet: Bool {
        if RateMeController.isDebug {
            return true
        }

        let userDefaults = UserDefaults.standard

        let firstLaunchTimestamp = userDefaults.double(forKey: Constants.firstUseDate)
        let dateOfFirstLaunch = Date(timeIntervalSince1970: firstLaunchTimestamp)
        let timeSinceFirstLaunch = Date().timeIntervalSince(dateOfFirstLaunch)
        let timeUntilRate: TimeInterval = 60 * 60 * 24 * Double(RateMeController.daysUntilPrompt)
        if timeSinceFirstLaunch < timeUntilRate {
            return false
        }

        // Check if the app has been used enough
        let useCount = userDefaults.integer(forKey: Constants.useCount)
        if useCount < RateMeController.usesUntilPrompt {
            return false
        }

        // Check if the user has done enough significant events
        let significantEventCount = userDefaults.integer(forKey: Constants.significantEventCount)
        if significantEventCount < RateMeController.significantEventsUntilPrompt {
            return false
        }

        // if the user wanted to be reminded later, has enough time passed?
        let reminderRequestTimestamp = userDefaults.double(forKey: Constants.reminderRequestDate)
        let reminderRequestDate = Date(timeIntervalSince1970: reminderRequestTimestamp)
        let timeSinceReminderRequest = Date().timeIntervalSince(reminderRequestDate)
        let timeUntilReminder = 60 * 60 * 24 * RateMeController.timeBeforeReminding
        if timeSinceReminderRequest < timeUntilReminder {
            return false
        }

        return true
    }

    private var currentAppVersion: String {
        return Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as! String
    }

    private var userHasDeclinedToRate: Bool {
        return UserDefaults.standard.bool(forKey: Constants.declinedToRate)
    }

    private var userHasRatedCurrentVersion: Bool {
        return UserDefaults.standard.bool(forKey: Constants.ratedCurrentVersion)
    }

    private func showPrompt(withChecks: Bool, displayRateLaterButton: Bool) {
        if !withChecks || isRatingAlertAppropriate {
            showRatingAlert(displayRateLaterButton: displayRateLaterButton)
        }
    }

    private func showRatingAlert(displayRateLaterButton: Bool = true) {
        if let shouldDisplayAlert = delegate?.rateMeControllerShouldDisplayAlert,
            !shouldDisplayAlert(self) {
            return
        }

        guard let presenter = UIApplication.shared.keyWindow?.rootViewController else { return }

        let title = RateMeController.alertTitle ?? Constants.kMessageTitle
        let message = RateMeController.alertMessage ?? Constants.kMessage
        ratingAlert = UIAlertController(title: title,
                                        message: message,
                                        preferredStyle: .alert)

        let rateTitle = RateMeController.alertRateTitle ?? Constants.kRateButton
        let rateAction = UIAlertAction(title: rateTitle, style: .default) { [unowned self] _ in
            self.rateApp()
            self.delegate?.rateMeControllerDidOptToRate?(self)
        }
        ratingAlert!.addAction(rateAction)

        if displayRateLaterButton {
            let rateLaterTitle = RateMeController.alertRateLaterTitle ?? Constants.kRateLater
            let rateLaterAction = UIAlertAction(title: rateLaterTitle, style: .default) { [unowned self] _ in
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Constants.reminderRequestDate)
                UserDefaults.standard.synchronize()
                self.delegate?.rateMeControllerDidOptToRemindLater?(self)
            }
            ratingAlert!.addAction(rateLaterAction)
        }

        let cancelTitle = RateMeController.alertCancelTitle ?? Constants.kCancelButton
        let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { [unowned self] _ in
            UserDefaults.standard.set(true, forKey: Constants.declinedToRate)
            UserDefaults.standard.synchronize()
            self.delegate?.rateMeControllerDidDeclineToRate?(self)
        }
        ratingAlert!.addAction(cancelAction)

        presenter.present(ratingAlert!, animated: true)
        delegate?.rateMeControllerDidDisplayAlert?(self)
    }

    private func incrementUseCount() {
        // Get the version number that we've been tracking
        var trackingVersion: String! = UserDefaults.standard.string(forKey: Constants.currentVersion)
        if trackingVersion == nil {
            trackingVersion = currentAppVersion
            UserDefaults.standard.set(trackingVersion, forKey: Constants.currentVersion)
        }

        if RateMeController.isDebug {
            NSLog("APPIRATER Tracking version: %@", trackingVersion);
        }

        if trackingVersion == currentAppVersion {
            // Check if the first use date has been set. if not, set it.
            var timeInterval = UserDefaults.standard.double(forKey: Constants.firstUseDate)
            if timeInterval == 0 {
                timeInterval = Date().timeIntervalSince1970
                UserDefaults.standard.set(timeInterval, forKey: Constants.firstUseDate)
            }

            // Increment the use count
            var useCount = UserDefaults.standard.integer(forKey: Constants.useCount)
            useCount += 1
            UserDefaults.standard.set(useCount, forKey: Constants.useCount)
            if RateMeController.isDebug {
                NSLog("APPIRATER Use count: %d", useCount)
            }
        } else {
            // It's a new version of the app, so restart tracking
            let firstUseDate = Date().timeIntervalSince1970
            restartTracking(firstUseDate: firstUseDate, useCount: 1, significantEventCount: 0)
        }

        UserDefaults.standard.synchronize()
    }

    private func incrementSignificantEventCount() {
        // Get the version number that we've been tracking
        var trackingVersion: String! = UserDefaults.standard.string(forKey: Constants.currentVersion)
        if trackingVersion ==  nil {
            trackingVersion = currentAppVersion
            UserDefaults.standard.set(trackingVersion, forKey: Constants.currentVersion)
        }

        if RateMeController.isDebug {
            NSLog("APPIRATER Tracking version: %@", trackingVersion);
        }

        if trackingVersion == currentAppVersion {
            // Check if the first use date has been set. if not, set it.
            var timeInterval = UserDefaults.standard.double(forKey: Constants.firstUseDate)
            if timeInterval == 0 {
                timeInterval = Date().timeIntervalSince1970
                UserDefaults.standard.set(timeInterval, forKey: Constants.firstUseDate)
            }

            // Increment the significant event count
            var sigEventCount = UserDefaults.standard.integer(forKey: Constants.significantEventCount)
            sigEventCount += 1
            UserDefaults.standard.set(sigEventCount, forKey: Constants.significantEventCount)
            if RateMeController.isDebug {
                NSLog("APPIRATER Significant event count: %d", sigEventCount)
            }
        } else {
            // It's a new version of the app, so restart tracking
            restartTracking(firstUseDate: 0, useCount: 0, significantEventCount: 1)
        }

        UserDefaults.standard.synchronize()
    }

    private func restartTracking(firstUseDate: TimeInterval, useCount: Int, significantEventCount: Int) {
        UserDefaults.standard.set(currentAppVersion, forKey: Constants.currentVersion)
        UserDefaults.standard.set(firstUseDate, forKey: Constants.firstUseDate)
        UserDefaults.standard.set(useCount, forKey: Constants.useCount)
        UserDefaults.standard.set(significantEventCount, forKey: Constants.significantEventCount)
        UserDefaults.standard.set(false, forKey: Constants.ratedCurrentVersion)
        UserDefaults.standard.set(false, forKey: Constants.declinedToRate)
        UserDefaults.standard.set(0, forKey: Constants.reminderRequestDate)

        UserDefaults.standard.synchronize()
    }

    private func incrementAndRate(canPromptForRating: Bool) {
        incrementUseCount()

        if canPromptForRating && isRatingConditionsMet && isRatingAlertAppropriate {
            DispatchQueue.main.async { [weak self] in
                self?.showRatingAlert()
            }
        }
    }

    private func incrementSignificantEventAndRate(canPromptForRating: Bool) {
        incrementSignificantEventCount()

        if canPromptForRating && isRatingConditionsMet && isRatingAlertAppropriate {
            DispatchQueue.main.async { [weak self] in
                self?.showRatingAlert()
            }
        }
    }

    private func hideRatingAlert() {
        if ratingAlert?.presentingViewController != nil {
            if RateMeController.isDebug {
                NSLog("APPIRATER Hiding Alert")
            }

            ratingAlert?.dismiss(animated: false)
        }
    }

    static func forceShowPrompt(displayRateLaterButton: Bool) {
        RateMeController.shared.showPrompt(withChecks: false,
                                           displayRateLaterButton: displayRateLaterButton)
    }

    private static func tryToShowPrompt() {
        RateMeController.shared.showPrompt(withChecks: true, displayRateLaterButton: true)
    }

    private func showPromptWithChecks(withChecks: Bool, displayRateLaterButton: Bool) {
        if !withChecks || isRatingAlertAppropriate {
            showRatingAlert(displayRateLaterButton: displayRateLaterButton)
        }
    }

    private func rateApp() {
        UserDefaults.standard.set(true, forKey: Constants.ratedCurrentVersion)
        UserDefaults.standard.synchronize()

        // Use the in-app StoreKit view if available (iOS 6) and imported. This works in the simulator.
        // if (![Appirater sharedInstance].openInAppStore && NSStringFromClass([SKStoreProductViewController class]) != nil) {
        if RateMeController.shared.doesOpenInAppStore && (NSClassFromString("SKStoreProductViewController") != nil) {
            let storeViewController = SKStoreProductViewController()
            let appIdInt = Int(RateMeController.appId!)!

            storeViewController.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: appIdInt])
            storeViewController.delegate = self

            delegate?.rateMeControllerWillPresentModalView?(self, animated: RateMeController.usesAnimation)

            Util.getRootViewController()?.present(storeViewController, animated: true) {
                self.isModalOpen = true
            }
        } else {
            //Use the standard openUrl method if StoreKit is unavailable.
            #if TARGET_IPHONE_SIMULATOR
                NSLog("APPIRATER NOTE: iTunes App Store is not supported on the iOS simulator. Unable to open App Store page.");
            #else
                let systemVersion = UIDevice.current.systemVersion
                let appId = RateMeController.appId!
                let reviewUrl = Util.templateReviewURL(for: systemVersion, appId: appId)

                UIApplication.shared.openURL(reviewUrl)
            #endif
        }
    }

    fileprivate func closeModal() {
        if isModalOpen {
            isModalOpen = false

            var presentingController = UIApplication.shared.keyWindow!.rootViewController!
            presentingController = Util.topMostViewController(for: presentingController)

            presentingController.dismiss(animated: RateMeController.usesAnimation) {
                let animated = RateMeController.usesAnimation
                self.delegate?.rateMeControllerDidDismissModalView?(self, animated: animated)
            }

            statusBarStyle = nil
        }
    }

    // MARK: - Actions

    @objc private func appWillResignActive(_ notification: Notification) {
        if RateMeController.isDebug {
            NSLog("APPIRATER appWillResignActive")
        }

        hideRatingAlert()
    }
}

// MARK: - SKStoreProductViewControllerDelegate

extension RateMeController: SKStoreProductViewControllerDelegate {
    public func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        closeModal()
    }
}

//
//  Constants.swift
//  Pods
//
//  Created by Benjamin Chrobot on 5/17/17.
//
//

import Foundation

struct Constants {

    // MARK: - Keys

    static let firstUseDate = "kAppiraterFirstUseDate"
    static let useCount = "kAppiraterUseCount"
    static let significantEventCount = "kAppiraterSignificantEventCount"
    static let currentVersion = "kAppiraterCurrentVersion"
    static let ratedCurrentVersion = "kAppiraterRatedCurrentVersion"
    static let declinedToRate = "kAppiraterDeclinedToRate"
    static let reminderRequestDate = "kAppiraterReminderRequestDate"

    static let templateReviewURL = "itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa"
        + "/viewContentsUserReviews?type=Purple+Software&id=APP_ID"
    static let templateReviewURLiOS7 = "itms-apps://itunes.apple.com/app/idAPP_ID"
    static let templateReviewURLiOS8 = "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa"
        + "/viewContentsUserReviews?id=APP_ID&onlyLatestVersion=true&pageNumber=0&sortOrdering=1"
        + "&type=Purple+Software"

    // MARK: - Default Values

    /// Your app's name.
    ///
    /// Tries for localized app name, bundle display name, bundle name, and then defaults to unknown
    static let kAppName: String = {
        let localizedAppName = Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
        let bundleDisplayName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
        let bundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String

        return localizedAppName ?? ( bundleDisplayName ?? (bundleName ?? "(unknown)"))
    }()

    /// This is the message your users will see once they've passed the day+launches threshold.
    static let kMessage: String = {
        let localizedMessage = NSLocalizedString("If you enjoy using %@, would you mind taking a "
            + "moment to rate it? It won't take more than a minute. Thanks for your support!",
                                                 tableName: "AppiraterLocalizable",
                                                 bundle: RateMeController.bundle,
                                                 value: "",
                                                 comment: "")
        return String(format: localizedMessage, kAppName)
    }()

    /// This is the title of the message alert that users will see.
    static let kMessageTitle: String = {
        let localizedMessageTitle = NSLocalizedString("Rate %@",
                                                      tableName: "AppiraterLocalizable",
                                                      bundle: RateMeController.bundle,
                                                      value: "",
                                                      comment: "")
        return String(format: localizedMessageTitle, kAppName)
    }()

    /// The text of the button that rejects reviewing the app.
    static let kCancelButton: String = {
        return NSLocalizedString("No, Thanks",
                                 tableName: "AppiraterLocalizable",
                                 bundle: RateMeController.bundle,
                                 value: "",
                                 comment: "")
    }()

    /// Text of button that will send user to app review page.
    static let kRateButton: String = {
        let localizedRateButton = NSLocalizedString("Rate %@",
                                                    tableName: "AppiraterLocalizable",
                                                    bundle: RateMeController.bundle,
                                                    value: "",
                                                    comment: "")
        return String(format: localizedRateButton, kAppName)
    }()

    /// Text for button to remind the user to review later.
    static let kRateLater: String = {
        return NSLocalizedString("Remind me later",
                                 tableName: "AppiraterLocalizable",
                                 bundle: RateMeController.bundle,
                                 value: "",
                                 comment: "")
    }()
}

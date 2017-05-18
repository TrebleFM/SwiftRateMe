//
//  Util.swift
//  Pods
//
//  Created by Benjamin Chrobot on 5/18/17.
//
//

import Foundation

struct Util {

    // MARK: - Internal Methods

    static func getRootViewController() -> UIViewController? {
        guard var normalWindow = UIApplication.shared.keyWindow else { return nil }

        if normalWindow.windowLevel != UIWindowLevelNormal {
            let windows = UIApplication.shared.windows
            for window in windows {
                if window.windowLevel == UIWindowLevelNormal {
                    normalWindow = window
                    break
                }
            }
        }

        // iOS 8+ deep traverse
        return Util.iterateSubViewsForViewController(parentView: normalWindow)

        /*
         UIWindow *window = [[UIApplication sharedApplication] keyWindow];
         if (window.windowLevel != UIWindowLevelNormal) {
         NSArray *windows = [[UIApplication sharedApplication] windows];
         for(window in windows) {
         if (window.windowLevel == UIWindowLevelNormal) {
         break;
         }
         }
         }

         return [Appirater iterateSubViewsForViewController:window]; // iOS 8+ deep traverse
         */
    }

    @available(iOS 6.0, *)
    static func iterateSubViewsForViewController(parentView: UIView) -> UIViewController? {
        for subView in parentView.subviews {
            let responder = subView.next
            if let responder = responder as? UIViewController {
                return Util.topMostViewController(for: responder)
            }

            if let found = Util.iterateSubViewsForViewController(parentView: subView) {
                return found
            }
        }

        return nil
        /*
         for (UIView *subView in [parentView subviews]) {
         UIResponder *responder = [subView nextResponder];
         if([responder isKindOfClass:[UIViewController class]]) {
         return [self topMostViewController: (UIViewController *) responder];
         }
         id found = [Appirater iterateSubViewsForViewController:subView];
         if( nil != found) {
         return found;
         }
         }
         return nil;
         */
    }

    @available(iOS 6.0, *)
    static func topMostViewController(for viewController: UIViewController) -> UIViewController {
        var isPresenting = false
        var controller = viewController

        repeat {
            // This path is called only on iOS 6+, so -presentedViewController is fine here.
            let presented = controller.presentedViewController
            isPresenting = presented != nil

            if let presented = presented  {
                controller = presented
            }

        } while isPresenting

        return controller
    }

    static func templateReviewURL(for osVersion: String, appId: String) -> URL {
        let templateString = reviewUrlTemplateString(for: osVersion)
        let urlString = templateString.replacingOccurrences(of: "APP_ID", with: appId)

        return URL(string: urlString)!
    }

    // MARK: - Private Methods

    private static func reviewUrlTemplateString(for osVersion: String) -> String {
        if let systemVersion = Float(UIDevice.current.systemVersion) {
            if systemVersion >= 7.0 && systemVersion < 8.0 {
                // iOS 7 needs a different templateReviewURL
                // @see https://github.com/arashpayan/appirater/issues/131
                // Fixes condition @see https://github.com/arashpayan/appirater/issues/205
                return Constants.templateReviewURLiOS7
            } else if systemVersion >= 8.0 {
                // iOS 8 needs a different templateReviewURL
                // also @see https://github.com/arashpayan/appirater/issues/182
                return Constants.templateReviewURLiOS8
            }
        }

        return Constants.templateReviewURL
    }

}

//
//  WeiboHandler.swift
//  NBus
//
//  Created by nuomi1 on 2021/1/18.
//  Copyright © 2021 nuomi1. All rights reserved.
//

import Foundation

// swiftlint:disable file_length

public class WeiboHandler {

    public let endpoints: [Endpoint] = [
        Endpoints.Weibo.timeline,
    ]

    public let platform: Platform = Platforms.weibo

    public var isInstalled: Bool {
        guard let url = URL(string: "sinaweibo://") else {
            assertionFailure()
            return false
        }

        return UIApplication.shared.canOpenURL(url)
    }

    private var isSupported: Bool {
        guard let url = URL(string: "weibosdk3.3://") else {
            assertionFailure()
            return false
        }

        return UIApplication.shared.canOpenURL(url)
    }

    private var shareCompletionHandler: Bus.ShareCompletionHandler?
    private var oauthCompletionHandler: Bus.OauthCompletionHandler?

    public let appID: String
    public let universalLink: URL
    private let redirectLink: URL

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
        return dateFormatter
    }()

    private lazy var iso8601DateFormatter: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter
    }()

    public init(appID: String, universalLink: URL, redirectLink: URL) {
        self.appID = appID
        self.universalLink = universalLink
        self.redirectLink = redirectLink
    }
}

extension WeiboHandler: ShareHandlerType {

    // swiftlint:disable cyclomatic_complexity function_body_length

    public func share(
        message: MessageType,
        to endpoint: Endpoint,
        options: [Bus.ShareOptionKey: Any],
        completionHandler: @escaping Bus.ShareCompletionHandler
    ) {
        guard isInstalled else {
            completionHandler(.failure(.missingApplication))
            return
        }

        guard isSupported else {
            completionHandler(.failure(.unsupportedApplication))
            return
        }

        guard canShare(message: message.identifier, to: endpoint) else {
            completionHandler(.failure(.unsupportedMessage))
            return
        }

        shareCompletionHandler = completionHandler

        let uuidString = UUID().uuidString

        var transferObjectItems: [String: Any] = [:]
        var messageItems: [String: Any] = [:]

        transferObjectItems["__class"] = "WBSendMessageToWeiboRequest"
        transferObjectItems["requestID"] = uuidString

        messageItems["__class"] = "WBMessageObject"

        switch message {
        case let message as TextMessage:
            messageItems["text"] = message.text

        case let message as ImageMessage:
            messageItems["imageObject"] = imageItems(
                data: message.data
            )

        case let message as AudioMessage:
            messageItems["mediaObject"] = webPageItems(
                link: message.link,
                title: message.title,
                description: message.description,
                thumbnail: message.thumbnail
            )

        case let message as VideoMessage:
            messageItems["mediaObject"] = webPageItems(
                link: message.link,
                title: message.title,
                description: message.description,
                thumbnail: message.thumbnail
            )

        case let message as WebPageMessage:
            messageItems["mediaObject"] = webPageItems(
                link: message.link,
                title: message.title,
                description: message.description,
                thumbnail: message.thumbnail
            )

        default:
            assertionFailure()
            completionHandler(.failure(.unsupportedMessage))
            return
        }

        transferObjectItems["message"] = messageItems

        setPasteboard(with: transferObjectItems, in: .general)

        guard let url = generateGeneralUniversalLink(uuidString: uuidString) else {
            assertionFailure()
            completionHandler(.failure(.invalidParameter))
            return
        }

        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { result in
            if !result {
                completionHandler(.failure(.unknown))
            }
        }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    private func canShare(message: Message, to endpoint: Endpoint) -> Bool {
        switch endpoint {
        case Endpoints.Weibo.timeline:
            return [
                Messages.text,
                Messages.image,
                Messages.audio,
                Messages.video,
                Messages.webPage,
            ].contains(message)
        default:
            assertionFailure()
            return false
        }
    }

    private func imageItems(
        data: Data
    ) -> [String: Any] {
        var imageItems: [String: Any] = [:]

        imageItems["imageData"] = data

        return imageItems
    }

    private func webPageItems(
        link: URL,
        title: String?,
        description: String?,
        thumbnail: Data?
    ) -> [String: Any] {
        var webPageItems: [String: Any] = [:]

        webPageItems["__class"] = "WBWebpageObject"
        webPageItems["description"] = description
        webPageItems["objectID"] = UUID().uuidString
        webPageItems["thumbnailData"] = thumbnail
        webPageItems["title"] = title
        webPageItems["webpageUrl"] = link.absoluteString

        return webPageItems
    }
}

extension WeiboHandler: OauthHandlerType {

    public func oauth(
        options: [Bus.OauthOptionKey: Any],
        completionHandler: @escaping Bus.OauthCompletionHandler
    ) {
        guard isInstalled else {
            completionHandler(.failure(.missingApplication))
            return
        }

        guard isSupported else {
            completionHandler(.failure(.unsupportedApplication))
            return
        }

        oauthCompletionHandler = completionHandler

        let uuidString = UUID().uuidString

        var transferObjectItems: [String: Any] = [:]

        transferObjectItems["__class"] = "WBAuthorizeRequest"
        transferObjectItems["redirectURI"] = redirectLink.absoluteString
        transferObjectItems["requestID"] = uuidString

        setPasteboard(with: transferObjectItems, in: .general)

        guard let url = generateGeneralUniversalLink(uuidString: uuidString) else {
            assertionFailure()
            completionHandler(.failure(.invalidParameter))
            return
        }

        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { result in
            if !result {
                completionHandler(.failure(.unknown))
            }
        }
    }
}

extension WeiboHandler {

    private var appNumber: String {
        appID.trimmingCharacters(in: .letters)
    }

    private var bundleID: String? {
        Bundle.main.bus.identifier
    }

    private var sdkShortVersion: String {
        "3.3"
    }

    private var sdkVersion: String {
        "003233000"
    }
}

extension WeiboHandler {

    private func setPasteboard(
        with transferObjectItems: [String: Any],
        in pasteboard: UIPasteboard
    ) {
        guard
            let bundleID = bundleID
        else {
            assertionFailure()
            return
        }

        var userInfoItems: [String: Any] = [:]
        var appItems: [String: Any] = [:]

        userInfoItems["startTime"] = dateFormatter.string(from: Date())

        appItems["appKey"] = appNumber
        appItems["bundleID"] = bundleID
        appItems["universalLink"] = universalLink.absoluteString

        setPasteboard(
            transferObjectItems: transferObjectItems,
            userInfoItems: userInfoItems,
            appItems: appItems,
            in: pasteboard
        )
    }

    private func setPasteboard(
        transferObjectItems: [String: Any],
        userInfoItems: [String: Any],
        appItems: [String: Any],
        in pasteboard: UIPasteboard
    ) {
        let transferObjectData = NSKeyedArchiver.archivedData(withRootObject: transferObjectItems)
        let userInfoData = NSKeyedArchiver.archivedData(withRootObject: userInfoItems)
        let appData = NSKeyedArchiver.archivedData(withRootObject: appItems)
        let sdkVersionData = Data(sdkVersion.utf8)

        var pbItems: [[String: Any]] = []

        pbItems.append(["transferObject": transferObjectData])
        pbItems.append(["userInfo": userInfoData])
        pbItems.append(["app": appData])
        pbItems.append(["sdkVersion": sdkVersionData])

        pasteboard.items = pbItems
    }
}

extension WeiboHandler {

    private func generateGeneralUniversalLink(uuidString: String) -> URL? {
        guard
            let bundleID = bundleID
        else {
            return nil
        }

        var components = URLComponents()

        components.scheme = "https"
        components.host = "open.weibo.com"
        components.path = "/weibosdk/request"

        var urlItems: [String: String] = [:]

        urlItems["lfid"] = bundleID
        urlItems["luicode"] = "10000360"
        urlItems["newVersion"] = sdkShortVersion
        urlItems["objId"] = uuidString
        urlItems["sdkversion"] = sdkVersion
        urlItems["urltype"] = "link"

        components.queryItems = urlItems.map { key, value in
            URLQueryItem(name: key, value: value)
        }

        return components.url
    }
}

extension WeiboHandler: OpenURLHandlerType {

    public func openURL(_ url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            assertionFailure()
            return
        }

        switch components.host {
        case "response" where components.path == "":
            handleGeneral()
        default:
            assertionFailure()
        }
    }
}

extension WeiboHandler: OpenUserActivityHandlerType {

    public func openUserActivity(_ userActivity: NSUserActivity) {
        guard
            let url = userActivity.webpageURL,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            assertionFailure()
            return
        }

        switch components.path {
        case universalLink.appendingPathComponent("weibosdk/response").path:
            handleGeneral()
        default:
            assertionFailure()
        }
    }
}

extension WeiboHandler {

    private func handleGeneral() {
        guard
            let infos = getPlist(from: .general)
        else {
            assertionFailure()
            return
        }

        let response = infos["__class"] as? String

        switch response {
        case "WBSendMessageToWeiboResponse":
            handleShare(with: infos)
        case "WBAuthorizeResponse":
            handleOauth(with: infos)
        default:
            assertionFailure()
        }
    }
}

extension WeiboHandler {

    private func handleShare(with infos: [String: Any]) {
        let statusCode = infos["statusCode"] as? Int

        switch statusCode {
        case 0:
            shareCompletionHandler?(.success(()))
        case -1:
            shareCompletionHandler?(.failure(.userCancelled))
        default:
            assertionFailure()
            shareCompletionHandler?(.failure(.unknown))
        }
    }

    private func handleOauth(with infos: [String: Any]) {
        let statusCode = infos["statusCode"] as? Int

        switch statusCode {
        case 0:
            let accessToken = infos["accessToken"] as? String
            let expirationDate = (infos["expirationDate"] as? Date).map {
                iso8601DateFormatter.string(from: $0)
            }
            let refreshToken = infos["refreshToken"] as? String
            let userID = infos["userID"] as? String

            let parameters = [
                OauthInfoKeys.accessToken: accessToken,
                OauthInfoKeys.expirationDate: expirationDate,
                OauthInfoKeys.refreshToken: refreshToken,
                OauthInfoKeys.userID: userID,
            ]
            .bus
            .compactMapContent()

            if !parameters.isEmpty {
                oauthCompletionHandler?(.success(parameters))
            } else {
                assertionFailure()
                oauthCompletionHandler?(.failure(.unknown))
            }
        case -1:
            oauthCompletionHandler?(.failure(.userCancelled))
        default:
            assertionFailure()
            oauthCompletionHandler?(.failure(.unknown))
        }
    }
}

extension WeiboHandler {

    private func getPlist(from pasteboard: UIPasteboard) -> [String: Any]? {
        guard
            let itemData = pasteboard.data(forPasteboardType: "transferObject"),
            let infos = NSKeyedUnarchiver.unarchiveObject(with: itemData) as? [String: Any]
        else {
            return nil
        }

        return infos
    }
}

extension WeiboHandler {

    public enum OauthInfoKeys {

        public static let accessToken = Bus.OauthInfoKeys.Weibo.accessToken

        public static let expirationDate = Bus.OauthInfoKeys.Weibo.expirationDate

        public static let refreshToken = Bus.OauthInfoKeys.Weibo.refreshToken

        public static let userID = Bus.OauthInfoKeys.Weibo.userID
    }
}

//
//  WechatHandler.swift
//  NBus
//
//  Created by nuomi1 on 2021/1/27.
//  Copyright © 2021 nuomi1. All rights reserved.
//

import Foundation

// swiftlint:disable file_length

public class WechatHandler {

    public let endpoints: [Endpoint] = [
        Endpoints.Wechat.friend,
        Endpoints.Wechat.timeline,
        Endpoints.Wechat.favorite,
    ]

    public let platform: Platform = Platforms.wechat

    public var isInstalled: Bool {
        guard let url = URL(string: "weixin://") else {
            assertionFailure()
            return false
        }

        return UIApplication.shared.canOpenURL(url)
    }

    private var isSupported: Bool {
        guard let url = URL(string: "weixinULAPI://") else {
            assertionFailure()
            return false
        }

        return UIApplication.shared.canOpenURL(url)
    }

    private var shareCompletionHandler: Bus.ShareCompletionHandler?
    private var oauthCompletionHandler: Bus.OauthCompletionHandler?

    public let appID: String
    public let universalLink: URL

    @BusUserDefaults(key: ShareOptionKeys.signToken)
    private var signToken: String?

    private var lastMessageData: Data?

    public init(appID: String, universalLink: URL) {
        self.appID = appID
        self.universalLink = universalLink
    }
}

extension WechatHandler: ShareHandlerType {

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

        guard
            let scene = scene(endpoint)
        else {
            assertionFailure()
            completionHandler(.failure(.invalidParameter))
            return
        }

        shareCompletionHandler = completionHandler

        var pasteBoardItems: [String: Any] = [:]

        pasteBoardItems["command"] = "1010"
        pasteBoardItems["scene"] = scene

        if let message = message as? MediaMessageType {
            pasteBoardItems["title"] = message.title
            pasteBoardItems["description"] = message.description
            pasteBoardItems["thumbData"] = message.thumbnail
        }

        switch message {
        case let message as TextMessage:
            pasteBoardItems["command"] = "1020"

            pasteBoardItems["title"] = message.text

        case let message as ImageMessage:
            pasteBoardItems["objectType"] = "2"

            pasteBoardItems["fileData"] = message.data

        case let message as AudioMessage:
            pasteBoardItems["objectType"] = "3"

            pasteBoardItems["mediaDataUrl"] = message.dataLink?.absoluteString
            pasteBoardItems["mediaUrl"] = message.link.absoluteString

        case let message as VideoMessage:
            pasteBoardItems["objectType"] = "4"

            pasteBoardItems["mediaUrl"] = message.link.absoluteString

        case let message as WebPageMessage:
            pasteBoardItems["objectType"] = "5"

            pasteBoardItems["mediaUrl"] = message.link.absoluteString

        case let message as FileMessage:
            pasteBoardItems["objectType"] = "6"

            pasteBoardItems["fileData"] = message.data
            pasteBoardItems["fileExt"] = message.fileExtension

        case let message as MiniProgramMessage:
            pasteBoardItems["objectType"] = "36"

            pasteBoardItems["appBrandPath"] = message.path
            pasteBoardItems["appBrandUserName"] = message.miniProgramID
            pasteBoardItems["disableForward"] = false
            pasteBoardItems["hdThumbData"] = message.thumbnail
            pasteBoardItems["mediaUrl"] = message.link.absoluteString
            pasteBoardItems["miniprogramType"] = miniProgramType(message.miniProgramType)
            pasteBoardItems["withShareTicket"] = false

        default:
            assertionFailure()
            completionHandler(.failure(.unsupportedMessage))
            return
        }

        setPasteboard(with: pasteBoardItems, in: .general, saveData: true)

        guard let url = generateShareUniversalLink() else {
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
        case Endpoints.Wechat.friend:
            return [
                Messages.text,
                Messages.image,
                Messages.audio,
                Messages.video,
                Messages.webPage,
                Messages.file,
                Messages.miniProgram,
            ].contains(message)
        case Endpoints.Wechat.timeline:
            return [
                Messages.text,
                Messages.image,
                Messages.audio,
                Messages.video,
                Messages.webPage,
            ].contains(message)
        case Endpoints.Wechat.favorite:
            return [
                Messages.text,
                Messages.image,
                Messages.audio,
                Messages.video,
                Messages.webPage,
                Messages.file,
            ].contains(message)
        default:
            assertionFailure()
            return false
        }
    }

    private func scene(_ endpoint: Endpoint) -> String? {
        let result: Int

        switch endpoint {
        case Endpoints.Wechat.friend:
            result = 0 // WXSceneSession
        case Endpoints.Wechat.timeline:
            result = 1 // WXSceneTimeline
        case Endpoints.Wechat.favorite:
            result = 2 // WXSceneFavorite
        default:
            return nil
        }

        return "\(result)"
    }

    private func miniProgramType(_ miniProgramType: MiniProgramMessage.MiniProgramType) -> Int {
        let result: Int

        switch miniProgramType {
        case .release:
            result = 0 // WXMiniProgramTypeRelease
        case .test:
            result = 1 // WXMiniProgramTypeTest
        case .preview:
            result = 2 // WXMiniProgramTypePreview
        }

        return result
    }
}

extension WechatHandler: OauthHandlerType {

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

        var pasteBoardItems: [String: Any] = [:]

        pasteBoardItems["command"] = "0"

        setPasteboard(with: pasteBoardItems, in: .general)

        guard let url = generateOauthUniversalLink() else {
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

extension WechatHandler {

    private var bundleID: String? {
        Bundle.main.bus.identifier
    }

    private var contextID: String? {
        let timestamp = Date().timeIntervalSince1970
        return "\(timestamp)".bus.sha1
    }

    private var oldText: String? {
        UIPasteboard.general.bus.oldText
    }

    private var sdkVersion: String {
        "1.8.7.1"
    }
}

extension WechatHandler {

    private func setPasteboard(
        with pasteBoardItems: [String: Any],
        in pasteboard: UIPasteboard,
        saveData: Bool = false
    ) {
        var pasteBoardItems = pasteBoardItems

        pasteBoardItems["isAutoResend"] = false
        pasteBoardItems["result"] = "1"
        pasteBoardItems["returnFromApp"] = "0"
        pasteBoardItems["sdkver"] = sdkVersion
        pasteBoardItems["universalLink"] = universalLink.absoluteString

        var pbItems: [String: Any] = [:]

        pbItems[appID] = pasteBoardItems
        pbItems["old_text"] = oldText

        guard
            let pbData = generatePasteboardData(with: pbItems)
        else {
            assertionFailure()
            return
        }

        setPasteboard(with: pbData, in: .general)

        if saveData, signToken == nil {
            lastMessageData = pbData
        }
    }

    private func setPasteboard(with data: Data, in pasteboard: UIPasteboard) {
        pasteboard.setData(data, forPasteboardType: "content")
    }

    private func generatePasteboardData(with pasteBoardItems: [String: Any]) -> Data? {
        try? PropertyListSerialization.data(
            fromPropertyList: pasteBoardItems,
            format: .binary,
            options: .zero
        )
    }
}

extension WechatHandler {

    private func generateShareUniversalLink() -> URL? {
        guard
            var components = generateGeneralUniversalLink()
        else {
            return nil
        }

        components.path = "/app/\(appID)/sendreq/"

        if let signToken = signToken {
            components.queryItems?.append(
                URLQueryItem(name: "wechat_auth_token", value: signToken)
            )
        }

        return components.url
    }

    private func generateOauthUniversalLink() -> URL? {
        guard
            var components = generateGeneralUniversalLink()
        else {
            return nil
        }

        components.path = "/app/\(appID)/auth/"

        components.queryItems?.append(
            URLQueryItem(name: "scope", value: "snsapi_userinfo")
        )

        return components.url
    }

    private func generateGeneralUniversalLink() -> URLComponents? {
        guard
            let bundleID = bundleID,
            let contextID = contextID
        else {
            return nil
        }

        var components = URLComponents()

        components.scheme = "https"
        components.host = "help.wechat.com"

        var urlItems: [String: String] = [:]

        urlItems["wechat_app_bundleId"] = bundleID
        urlItems["wechat_auth_context_id"] = contextID

        components.queryItems = urlItems.map { key, value in
            URLQueryItem(name: key, value: value)
        }

        return components
    }

    private func generateShareURLScheme() -> URL? {
        guard
            var components = generateGeneralURLScheme()
        else {
            return nil
        }

        components.path = "/\(appID)/sendreq/"

        return components.url
    }

    private func generateGeneralURLScheme() -> URLComponents? {
        guard
            let bundleID = bundleID
        else {
            return nil
        }

        var components = URLComponents()

        components.scheme = "weixin"
        components.host = "app"

        var urlItems: [String: String] = [:]

        urlItems["wechat_app_bundleId"] = bundleID

        components.queryItems = urlItems.map { key, value in
            URLQueryItem(name: key, value: value)
        }

        return components
    }
}

extension WechatHandler: OpenURLHandlerType {

    public func openURL(_ url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            assertionFailure()
            return
        }

        switch components.host {
        case "resendContextReqByScheme" where components.path == "":
            handleSignTokenFailure()
        case "platformId=wechat" where components.path == "":
            handleGeneral()
        case "oauth" where components.path == "":
            handleOauth(with: components)
        case "" where components.path == "":
            handleGeneral()
        default:
            assertionFailure()
        }
    }
}

extension WechatHandler: OpenUserActivityHandlerType {

    public func openUserActivity(_ userActivity: NSUserActivity) {
        guard
            let url = userActivity.webpageURL,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            assertionFailure()
            return
        }

        switch components.path {
        case universalLink.appendingPathComponent("\(appID)/refreshToken").path:
            handleSignToken(with: components)
        case universalLink.appendingPathComponent("\(appID)/").path + "/":
            handleGeneral()
        case universalLink.appendingPathComponent("\(appID)/oauth").path:
            handleOauth(with: components)
        default:
            assertionFailure()
        }
    }
}

extension WechatHandler {

    private func handleSignToken(with components: URLComponents) {
        guard
            let infos = components.queryItems,
            let signTokenItem = infos.first(where: { $0.name == "wechat_auth_token" }),
            let signToken = signTokenItem.value,
            let pbData = lastMessageData
        else {
            assertionFailure()
            shareCompletionHandler?(.failure(.invalidParameter))
            return
        }

        self.signToken = signToken

        setPasteboard(with: pbData, in: .general)
        lastMessageData = nil

        guard let url = generateShareUniversalLink() else {
            assertionFailure()
            shareCompletionHandler?(.failure(.invalidParameter))
            return
        }

        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { [weak self] result in
            if !result {
                self?.shareCompletionHandler?(.failure(.unknown))
            }
        }
    }

    private func handleSignTokenFailure() {
        guard
            let pbData = lastMessageData
        else {
            assertionFailure()
            shareCompletionHandler?(.failure(.invalidParameter))
            return
        }

        setPasteboard(with: pbData, in: .general)
        lastMessageData = nil

        guard let url = generateShareURLScheme() else {
            assertionFailure()
            shareCompletionHandler?(.failure(.invalidParameter))
            return
        }

        UIApplication.shared.open(url) { [weak self] result in
            if !result {
                self?.shareCompletionHandler?(.failure(.unknown))
            }
        }
    }

    private func handleGeneral() {
        guard let infos = getPlist(from: .general) else {
            assertionFailure()
            return
        }

        let command = infos["command"] as? String

        switch command {
        case "2020":
            handleShare(with: infos)
        case "2030":
            handleOauth(with: infos)
        default:
            assertionFailure()
        }
    }
}

extension WechatHandler {

    private func handleShare(with infos: [String: Any]) {
        let result = infos["result"] as? String

        switch result {
        case "0":
            shareCompletionHandler?(.success(()))
        case "-2":
            shareCompletionHandler?(.failure(.userCancelled))
        default:
            assertionFailure()
            shareCompletionHandler?(.failure(.unknown))
        }
    }

    private func handleOauth(with infos: [String: Any]) {
        let result = infos["result"] as? String

        switch result {
        case "-4", "-2":
            oauthCompletionHandler?(.failure(.userCancelled))
        default:
            assertionFailure()
            oauthCompletionHandler?(.failure(.unknown))
        }
    }

    private func handleOauth(with components: URLComponents) {
        guard
            let items = components.queryItems,
            let codeItem = items.first(where: { $0.name == "code" }),
            let code = codeItem.value
        else {
            assertionFailure()
            oauthCompletionHandler?(.failure(.invalidParameter))
            return
        }

        let parameters = [
            OauthInfoKeys.code: code,
        ]
        .bus
        .compactMapContent()

        if !parameters.isEmpty {
            oauthCompletionHandler?(.success(parameters))
        } else {
            assertionFailure()
            oauthCompletionHandler?(.failure(.unknown))
        }
    }
}

extension WechatHandler {

    private func getPlist(from pasteboard: UIPasteboard) -> [String: Any]? {
        guard
            let itemData = pasteboard.data(forPasteboardType: "content"),
            let infos = try? PropertyListSerialization.propertyList(from: itemData, format: nil) as? [String: Any]
        else {
            return nil
        }

        return infos[appID] as? [String: Any]
    }
}

extension WechatHandler {

    public enum ShareOptionKeys {

        public static let signToken = Bus.ShareOptionKey(rawValue: "com.nuomi1.bus.wechatHandler.signToken")
    }
}

extension WechatHandler {

    public enum OauthInfoKeys {

        public static let code = Bus.OauthInfoKeys.Wechat.code
    }
}

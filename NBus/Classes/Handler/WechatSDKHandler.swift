//
//  WechatSDKHandler.swift
//  NBus
//
//  Created by nuomi1 on 2020/8/24.
//  Copyright © 2020 nuomi1. All rights reserved.
//

import Foundation

public class WechatSDKHandler {

    public let endpoints: [Endpoint] = [
        Endpoints.Wechat.friend,
        Endpoints.Wechat.timeline,
        Endpoints.Wechat.favorite,
    ]

    public let platform: Platform = Platforms.wechat

    public var isInstalled: Bool {
        WXApi.isWXAppInstalled()
    }

    private var shareCompletionHandler: Bus.ShareCompletionHandler?
    private var oauthCompletionHandler: Bus.OauthCompletionHandler?

    public let appID: String
    public let universalLink: URL

    public var logHandler: Bus.LogHandler = { message, _, _, _ in
        #if DEBUG
            print(message)
        #endif
    }

    private var helper: Helper!

    public init(appID: String, universalLink: URL) {
        self.appID = appID
        self.universalLink = universalLink

        helper = Helper(master: self)

        #if DEBUG
            WXApi.startLog(by: .detail) { [weak self] message in
                self?.log(message)
            }
        #endif

        WXApi.registerApp(
            appID,
            universalLink: universalLink.absoluteString
        )
    }
}

extension WechatSDKHandler: LogHandlerProxyType {}

extension WechatSDKHandler: ShareHandlerType {

    // swiftlint:disable cyclomatic_complexity function_body_length

    public func share(
        message: MessageType,
        to endpoint: Endpoint,
        options: [Bus.ShareOptionKey: Any] = [:],
        completionHandler: @escaping Bus.ShareCompletionHandler
    ) {
        guard isInstalled else {
            completionHandler(.failure(.missingApplication))
            return
        }

        guard canShare(message: message.identifier, to: endpoint) else {
            completionHandler(.failure(.unsupportedMessage))
            return
        }

        shareCompletionHandler = completionHandler

        let request = SendMessageToWXReq()
        request.scene = Int32(scene(endpoint).rawValue)

        let mediaMessage = WXMediaMessage()

        if let message = message as? MediaMessageType {
            mediaMessage.title = message.title ?? ""
            mediaMessage.description = message.description ?? ""
            mediaMessage.thumbData = message.thumbnail
        }

        switch message {
        case let message as TextMessage:
            request.text = message.text
            request.bText = true

        case let message as ImageMessage:
            let imageObject = WXImageObject()
            imageObject.imageData = message.data

            mediaMessage.mediaObject = imageObject

        case let message as AudioMessage:
            let audioObject = WXMusicObject()
            audioObject.musicUrl = message.link.absoluteString
            audioObject.musicDataUrl = message.dataLink?.absoluteString ?? ""

            mediaMessage.mediaObject = audioObject

        case let message as VideoMessage:
            let videoObject = WXVideoObject()
            videoObject.videoUrl = message.link.absoluteString

            mediaMessage.mediaObject = videoObject

        case let message as WebPageMessage:
            let webPageObject = WXWebpageObject()
            webPageObject.webpageUrl = message.link.absoluteString

            mediaMessage.mediaObject = webPageObject

        case let message as FileMessage:
            let fileObject = WXFileObject()
            fileObject.fileData = message.data
            fileObject.fileExtension = message.fileExtension

            mediaMessage.mediaObject = fileObject

        case let message as MiniProgramMessage:
            let miniProgramObject = WXMiniProgramObject()
            miniProgramObject.webpageUrl = message.link.absoluteString
            miniProgramObject.userName = message.miniProgramID
            miniProgramObject.path = message.path
            miniProgramObject.miniProgramType = miniProgramType(message.miniProgramType)
            miniProgramObject.hdImageData = message.thumbnail

            mediaMessage.mediaObject = miniProgramObject

        default:
            assertionFailure()
            completionHandler(.failure(.unsupportedMessage))
            return
        }

        request.message = mediaMessage

        WXApi.send(request) { result in
            if !result {
                completionHandler(.failure(.invalidMessage))
            }
        }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length

    private func canShare(message: Message, to endpoint: Endpoint) -> Bool {
        switch endpoint {
        case Endpoints.Wechat.friend:
            return true
        case Endpoints.Wechat.timeline:
            return ![Messages.file, Messages.miniProgram].contains(message)
        case Endpoints.Wechat.favorite:
            return ![Messages.miniProgram].contains(message)
        default:
            assertionFailure()
            return false
        }
    }

    private func scene(_ endpoint: Endpoint) -> WXScene {
        switch endpoint {
        case Endpoints.Wechat.friend:
            return WXSceneSession
        case Endpoints.Wechat.timeline:
            return WXSceneTimeline
        case Endpoints.Wechat.favorite:
            return WXSceneFavorite
        default:
            assertionFailure()
            return WXSceneSession
        }
    }

    private func miniProgramType(_ miniProgramType: MiniProgramMessage.MiniProgramType) -> WXMiniProgramType {
        switch miniProgramType {
        case .release:
            return .release
        case .test:
            return .test
        case .preview:
            return .preview
        }
    }
}

extension WechatSDKHandler: OauthHandlerType {

    public func oauth(
        options: [Bus.OauthOptionKey: Any] = [:],
        completionHandler: @escaping Bus.OauthCompletionHandler
    ) {
        guard isInstalled else {
            completionHandler(.failure(.missingApplication))
            return
        }

        oauthCompletionHandler = completionHandler

        let request = SendAuthReq()
        request.scope = "snsapi_userinfo"

        let viewController = (options[OauthOptionKeys.viewController] as? UIViewController) ?? UIViewController()

        WXApi.sendAuthReq(
            request,
            viewController: viewController,
            delegate: helper
        ) { result in
            if !result {
                completionHandler(.failure(.unknown))
            }
        }
    }
}

extension WechatSDKHandler: OpenURLHandlerType {

    public func openURL(_ url: URL) {
        WXApi.handleOpen(url, delegate: helper)
    }
}

extension WechatSDKHandler: OpenUserActivityHandlerType {

    public func openUserActivity(_ userActivity: NSUserActivity) {
        WXApi.handleOpenUniversalLink(userActivity, delegate: helper)
    }
}

extension WechatSDKHandler {

    public enum OauthOptionKeys {

        public static let viewController = Bus.OauthOptionKey(rawValue: "com.nuomi1.bus.wechatSDKHandler.viewController")
    }
}

extension WechatSDKHandler {

    public enum OauthInfoKeys {

        public static let code = Bus.OauthInfoKey(rawValue: "com.nuomi1.bus.wechatSDKHandler.code")
    }
}

extension WechatSDKHandler {

    fileprivate class Helper: NSObject, WXApiDelegate {

        weak var master: WechatSDKHandler?

        required init(master: WechatSDKHandler) {
            self.master = master
        }

        func onReq(_ req: BaseReq) {
            assertionFailure("\(req)")
        }

        func onResp(_ resp: BaseResp) {
            switch resp {
            case let response as SendMessageToWXResp:
                switch response.errCode {
                case WXSuccess.rawValue:
                    master?.shareCompletionHandler?(.success(()))
                default:
                    master?.shareCompletionHandler?(.failure(.unknown))
                }
            case let response as SendAuthResp:
                switch (response.errCode, response.code) {
                case let (WXSuccess.rawValue, code):
                    let parameters = [
                        OauthInfoKeys.code: code,
                    ]
                    .compactMapContent()

                    if !parameters.isEmpty {
                        master?.oauthCompletionHandler?(.success(parameters))
                    } else {
                        master?.oauthCompletionHandler?(.failure(.unknown))
                    }
                default:
                    master?.oauthCompletionHandler?(.failure(.unknown))
                }
            default:
                assertionFailure("\(resp)")
            }
        }
    }
}

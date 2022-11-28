import Vapor

func routes(_ app: Application) throws {
    app.get { (req) in
        return index(request: req)
    }
    app.get("index.html") { (req) in
        return index(request: req)
    }
    func index(request req: Request) -> EventLoopFuture<View> {
        return req.view.render("index", [
            "title": "Swift AST Explorer",
            "defaultSampleCode": defaultSampleCode,
            "defaultSampleCode2": defaultSampleCode,
            "swiftVersion": swiftVersion,
        ])
    }

    app.get("healthz") { _ in ["status": "pass"] }

    app.get("*") { (req) -> EventLoopFuture<View> in
        let pattern = try! NSRegularExpression(pattern: #"^\/([a-f0-9]{32})$"#, options: [.caseInsensitive])
        let matches = pattern.matches(in: req.url.path, options: [], range: NSRange(location: 0, length: NSString(string: req.url.path).length))
        guard matches.count == 1 && matches[0].numberOfRanges == 2 else {
            throw Abort(.notFound)
        }
        let gistId = NSString(string: req.url.path).substring(with: matches[0].range(at: 1))

        let promise = req.eventLoop.makePromise(of: View.self)
        req.client.get(
            URI(string: "https://api.github.com/gists/\(gistId)"), headers: HTTPHeaders([("User-Agent", "Swift AST Explorer")])
        ).whenComplete {
            switch $0 {
            case .success(let response):
                guard let body = response.body else {
                    promise.fail(Abort(.notFound))
                    return
                }
                guard
                    let contents = try? JSONSerialization.jsonObject(with: Data(body.readableBytesView), options: []) as? [String: Any],
                    let files = contents["files"] as? [String: Any],
                    let filename = files.keys.first, let file = files[filename] as? [String: Any],
                    let content = file["content"] as? String else {
                    promise.fail(Abort(.notFound))
                    return
                }

                return req.view.render(
                    "index", [
                        "title": "Swift AST Explorer",
                        "defaultSampleCode": content,
                        "swiftVersion": swiftVersion,
                        "defaultSampleCode2": content,
                    ]
                )
                .cascade(to: promise)
            case .failure(let error):
                promise.fail(error)
            }
        }

        return promise.futureResult
    }

    app.on(.POST, "update", body: .collect(maxSize: "10mb")) { (req) -> EventLoopFuture<SyntaxResponse> in
        let parameter = try req.content.decode(RequestParameter.self)

        let promise = req.eventLoop.makePromise(of: SyntaxResponse.self)
        DispatchQueue.global().async {
            do {
                promise.succeed(try Parser.parse(code: parameter.code))
            } catch {
                promise.fail(error)
            }
        }

        return promise.futureResult
    }
}

let swiftVersion = Environment.get("SWIFT_VERSION") ?? ""

private struct RequestParameter: Decodable {
    let code: String
}

private let defaultSampleCode = #"""
import CommonUI
import Localization

protocol AppOnboardingViewModelMapping {
    func map(shouldRefreshTextPager: Bool, page: Int) -> AppOnboardingViewModel
}

final class AppOnboardingViewModelMapper: AppOnboardingViewModelMapping {
    private let localize: (String) -> String

    init(localize: @escaping (String) -> String = { Localization.localize($0) }) {
        self.localize = localize
    }

    func map(shouldRefreshTextPager: Bool,
             page: Int) -> AppOnboardingViewModel {
        .init(shouldRefreshTextPager: shouldRefreshTextPager,
              loginTitle: loginTitle,
              titleModel: [sellModel, buyModel, useModel, shippingModel, payModel],
              imageModel: images,
              currentPage: page)
    }

    private var loginTitle: NSAttributedString {
        let accountText = localize("pre_registration_slider_log_in_description")
        let loginText = localize("pre_registration_slider_log_in_description_link")
        let text = "\(accountText) \(loginText)"
        let accountRange = NSString(string: text).range(of: accountText)
        let loginRange = NSString(string: text).range(of: loginText)

        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttributes([NSAttributedString.Key.font: Stylesheet.font(.body), NSAttributedString.Key.foregroundColor: Stylesheet.color(.grey1)], range: accountRange)
        attributedString.addAttributes([NSAttributedString.Key.font: Stylesheet.font(.bodyHighlighted), NSAttributedString.Key.foregroundColor: Stylesheet.color(.walla)], range: loginRange)
        return attributedString
    }

    private func titleModelFor(page: Int) -> AppOnboardingTextPagerViewModel {
        let models = [sellModel, buyModel, useModel, shippingModel, payModel]
        return models[page]
    }

    private var sellModel: AppOnboardingTextPagerViewModel {
        .init(title: localize("pre_registration_slider_sell_message_title"),
              subtitle: localize("pre_registration_slider_sell_message_description"))
    }

    private var buyModel: AppOnboardingTextPagerViewModel {
        .init(title: localize("pre_registration_slider_buy_message_title"),
              subtitle: localize("pre_registration_slider_buy_message_description"))
    }

    private var useModel: AppOnboardingTextPagerViewModel {
        .init(title: localize("pre_registration_slider_use_your_way_message_title"),
              subtitle: localize("pre_registration_slider_use_your_way_message_description"))
    }

    private var shippingModel: AppOnboardingTextPagerViewModel {
        .init(title: localize("pre_registration_slider_shipping_message_title"),
              subtitle: localize("pre_registration_slider_shipping_message_description"))
    }

    private var payModel: AppOnboardingTextPagerViewModel {
        .init(title: localize("pre_registration_slider_pay_safely_message_title"),
              subtitle: localize("pre_registration_slider_pay_safely_message_description"))
    }

    private var images: [AppOnboardingImagePagerViewModel] {
        [sellImage, buyImage, useYourWayImage, shippingImage, paySafeImage].map { AppOnboardingImagePagerViewModel(image: $0) }
    }

    private var sellImage: WallaAsset {
        .preRegistrationSell
    }

    private var buyImage: WallaAsset {
        .preRegistrationBuy
    }

    private var useYourWayImage: WallaAsset {
        .preRegistrationUseYourWay
    }

    private var shippingImage: WallaAsset {
        .preRegistrationShipping
    }

    private var paySafeImage: WallaAsset {
        .preRegistratrionPaySafe
    }
}

"""#

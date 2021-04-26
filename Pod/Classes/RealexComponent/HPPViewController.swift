//
//  HPPViewController.swift
//  rxp-ios
//

import UIKit
import WebKit

/// The delegate callbacks which allow the HPPManager to receive back the results from the WKWebView.
@objc protocol HPPViewControllerDelegate {
    @objc optional func HPPViewControllerWillDismiss()
    @objc optional func HPPViewControllerCompletedWithResult(_ result: String)
    @objc optional func HPPViewControllerFailedWithError(_ error: NSError?)
}

/// The Web View Controller which encapsulates the management of the webivew and the interaction with the HPP web page.
class HPPViewController: UIViewController, WKNavigationDelegate,  WKUIDelegate, WKScriptMessageHandler {

    var webView: WKWebView?
    var delegate:HPPViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        initialiseWebView()

        let cancelButton = UIBarButtonItem(
            title: "Cancel",
            style: UIBarButtonItemStyle.plain,
            target: self,
            action: #selector(HPPViewController.closeView)
        )
        navigationItem.leftBarButtonItem = cancelButton
    }

    /// Initialises the WKWebview.
    fileprivate func initialiseWebView() {

        let viewScriptString = "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);"
        let viewScript = WKUserScript(source: viewScriptString,
                                      injectionTime: .atDocumentEnd,
                                      forMainFrameOnly: true)

        let userContentController = WKUserContentController()
        userContentController.addUserScript(viewScript)
        userContentController.add(self, name: "callbackHandler")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView?.backgroundColor = .white

        webView?.navigationDelegate = self;
        view = self.webView
    }

    /// Called if the user taps the cancel button.
    @objc func closeView() {
        delegate?.HPPViewControllerWillDismiss!()
        dismiss(animated: true, completion: nil)
    }

    /// Loads the network request and displays the result in the webview.
    /// - Parameter request: The network request to be loaded.
    func loadRequest (_ request: URLRequest) {
        let session = URLSession.shared
        let dataTask = session.dataTask(
            with: request,
            completionHandler: { data, response, error in

                DispatchQueue.main.async {

                    if error != nil {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false

                        self.delegate?.HPPViewControllerFailedWithError!(error as NSError?)
                        self.dismiss(animated: true, completion: nil)
                    }
                    else if data?.count == 0 {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false

                        self.delegate?.HPPViewControllerFailedWithError!(nil)
                        self.dismiss(animated: true, completion: nil)
                    }
                    else {
                        let htmlString = String(data: data!, encoding: String.Encoding.utf8)
                        self.webView!.loadHTMLString(htmlString!, baseURL: request.url)
                    }
                }
        })
        dataTask.resume()
    }

    // MARK: - WKWebView Delegate Callbacks

    /// Start the network activity indicator when the web view is loading
    func webView(_ webView: WKWebView,
                 didStartProvisionalNavigation navigation: WKNavigation) {
        // Start the network activity indicator when the web view is loading
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }

    /// Stop the network activity indicator when the loading finishes
    func webView(_ webView: WKWebView,
                 didFinish navigation: WKNavigation) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }

    /// Stop the network activity indicator when the loading fails and report back to HPPManager
    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {

        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        self.delegate?.HPPViewControllerFailedWithError!(error as NSError?)
    }

    /// Allow all requests to be loaded
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        decisionHandler(.allow)
    }

    /// Allow all navigation actions
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        decisionHandler(.allow)
    }

    // MARK: - Javascript Message Callback

    /// Delegate callback which receives any massages from the Javascript bridge
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {

        if let messageString = message.body as? String {
            self.delegate?.HPPViewControllerCompletedWithResult!(messageString)
        } else {
            print("Something went wrong")
            self.delegate?.HPPViewControllerFailedWithError!(nil)
        }

        self.dismiss(animated: true, completion: nil)
    }
}

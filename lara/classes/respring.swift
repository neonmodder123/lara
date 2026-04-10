//
//  respring.swift
//  lara
//
//  Created by neonmodder123 on 10.04.26.
//

import SwiftUI
import SafariServices

struct respring {
    static func showRespringPage() {
        guard let url = URL(string: "https://neonmodder123.github.io/respring") else { return }
        let safariVC = SFSafariViewController(url: url)
        safariVC.modalPresentationStyle = .overFullScreen
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(safariVC, animated: true)
        }
    }
}

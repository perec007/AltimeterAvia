//
//  L10n.swift
//  AltimeterAvia
//
//  Локализация: английский и русский.
//

import Foundation

enum L10n {
    static func loc(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
    
    static func loc(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), arguments: arguments)
    }
}

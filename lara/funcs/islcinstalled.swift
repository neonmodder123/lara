//
//  islcinstalled.swift
//  lara
//
//  Created by ruter on 30.03.26.
//

import Foundation
import MachO

func islcinstalled() -> Bool {
    let executablePath = Bundle.main.executablePath?.lowercased() ?? ""
    if executablePath.contains("/documents/applications/") {
        globallogger.log("\nlivecontainer detected: yeah (guest executable path)")
        return true
    }

    let count = _dyld_image_count()

    for i in 0..<count {
        guard let cName = _dyld_get_image_name(i) else {
            continue
        }

        let lower = String(cString: cName).lowercased()
        if lower.contains("livecontainershared") ||
            lower.contains("/livecontainer.app/") ||
            lower.contains("/liveprocess.app/") ||
            lower.contains("tweakinjector.dylib") ||
            lower.contains("tweakloader.dylib") {
            globallogger.log("\nlivecontainer detected: yeah (\(lower))")
            return true
        }
    }

    globallogger.log("\nlivecontainer detected: nah")
    return false
}

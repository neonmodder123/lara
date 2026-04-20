//
//  CCView.swift
//  lara
//
//  Created by ruter on 16.04.26.
//

import SwiftUI

struct CCView: View {
    @ObservedObject private var mgr = laramgr.shared
    @State private var patchResult: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("do it now") {
                        patchResult = installRespringCC()
                        mgr.logmsg(patchResult)
                    }
                    .disabled(!mgr.vfsready)

                    Button("Respring") {
                        mgr.respring()
                    }
                    .disabled(!mgr.sbxready && !mgr.vfsready && !mgr.dsready)
                           
                    if !patchResult.isEmpty {
                        Text(patchResult)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("RespringCC")
                } footer: {
                    Text("Uses lara's respring helper.")
                }
            }
            .navigationTitle("Control Center")
        }
    }

    private func installRespringCC() -> String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.roooot.laraapp"
        let targetPlistSize = Int(mgr.vfssize(path: respringcc.moduleInfoPlistPath))
        guard let infoPlist = respringcc.makeInfoPlist(bundleIdentifier: bundleIdentifier, targetSize: targetPlistSize > 0 ? targetPlistSize : nil) else {
            return "failed to generate Info.plist"
        }

        var lines: [String] = []
        lines.append("patching \(respringcc.moduleBasePath)")
        lines.append("Info.plist: \(sbxwrite(path: respringcc.moduleInfoPlistPath, data: infoPlist))")

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: respringcc.moduleBasePath)
            let lprojs = files.filter { $0.hasSuffix(".lproj") }
            for lproj in lprojs {
                let stringsPath = "\(respringcc.moduleBasePath)/\(lproj)/InfoPlist.strings"
                let stringsSize = Int(mgr.vfssize(path: stringsPath))
                let data: Data
                if stringsSize > 0 {
                    var buf = [UInt8](repeating: 0, count: stringsSize)
                    let bytes = Array("xxx".utf8)
                    for i in 0..<min(bytes.count, buf.count) {
                        buf[i] = bytes[i]
                    }
                    data = Data(buf)
                } else {
                    data = Data("xxx".utf8)
                }
                let result = sbxwrite(path: stringsPath, data: data)
                lines.append("\(lproj)/InfoPlist.strings: \(result)")
            }
            if lprojs.isEmpty {
                lines.append("no .lproj found (skipped strings)")
            }
        } catch {
            lines.append("failed to enumerate module directory: \(error.localizedDescription)")
        }

        lines.append("done (open Control Center and tap Magnifier)")
        return lines.joined(separator: "\n")
    }
    
    private func sbxread(path: String, maxSize: Int) -> Data? {
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            if data.count > maxSize {
                return data.prefix(maxSize)
            }
            return data
        } catch {
            return nil
        }
    }

    private func sbxwrite(path: String, data: Data) -> String {
        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        if fd == -1 {
            return vfsfallback(path: path, data: data, reason: "open failed: errno=\(errno) \(String(cString: strerror(errno)))")
        }
        defer { close(fd) }

        let result = data.withUnsafeBytes { ptr in
            write(fd, ptr.baseAddress, ptr.count)
        }

        if result == -1 {
            return vfsfallback(path: path, data: data, reason: "write failed: errno=\(errno) \(String(cString: strerror(errno)))")
        }

        return "ok (\(result) bytes)"
    }

    private func vfsfallback(path: String, data: Data, reason: String) -> String {
        guard mgr.vfsready else {
            return reason + " | vfs not ready"
        }
        let ok = mgr.vfsoverwritewithdata(target: path, data: data)
        return ok ? "ok (vfs overwrite)" : reason + " | vfs overwrite failed"
    }
}

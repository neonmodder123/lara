//
//  Logger.swift
//  mowiwewgewawt
//  bacon why would you do that
//  teehee :3
//  yeah yeah teehee all you want 
//
//  I love that you just straight skidded this from jessi lmfao
//
//  Created by roooot on 15.11.25.
//

import Foundation
import Darwin
import Combine
import SwiftUI

let globallogger = Logger()

class Logger: ObservableObject {
    @Published var logs: [String] = []
    private var lastwasdivider = false
    private var pendingdivider = false
    private var stdoutpipe: Pipe?
    private var panding = ""
    private var ogstdout: Int32 = -1
    private var ogstderr: Int32 = -1
    private var logFileURL: URL?
    private var logFileHandle: FileHandle?
    private let ignoredLogSubstrings = [
        "Faulty glyph",
        "outline detected - replacing with a space/null glyph",
        "Gesture: System gesture gate timed out",
        "tcp_output [",
        "Error Domain=",
        "NSError"
    ]

    init() {
        setupLogFile()
    }

    func log(_ message: String) {
        DispatchQueue.main.async {
            if self.pendingdivider {
                self.divider()
                self.pendingdivider = false
            }
            
            if self.lastwasdivider || self.logs.isEmpty {
                self.logs.append(message)
            } else {
                self.logs[self.logs.count - 1] += "\n" + message
            }

            self.lastwasdivider = false
        }

        appendToFile([message])
        emit(message)
    }

    func divider() {
        DispatchQueue.main.async {
            self.lastwasdivider = true
        }
    }
    
    func enclosedlog(_ message: String) {
        DispatchQueue.main.async {
            if !self.lastwasdivider && !self.logs.isEmpty {
                self.divider()
            }
            
            if self.lastwasdivider || self.logs.isEmpty {
                self.logs.append(message)
            } else {
                self.logs[self.logs.count - 1] += "\n" + message
            }
            
            self.lastwasdivider = false
            self.pendingdivider = true
        }
    }
    
    func flushdivider() {
        DispatchQueue.main.async {
            if self.pendingdivider {
                self.divider()
                self.pendingdivider = false
            }
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.lastwasdivider = false
            self.pendingdivider = false
        }
        if let url = logFileURL {
            try? logFileHandle?.close()
            try? "".write(to: url, atomically: true, encoding: .utf8)
            logFileHandle = try? FileHandle(forWritingTo: url)
        }
    }

    func capture() {
        if stdoutpipe != nil { return }

        let pipe = Pipe()
        stdoutpipe = pipe

        ogstdout = dup(STDOUT_FILENO)
        ogstderr = dup(STDERR_FILENO)

        setvbuf(stdout, nil, _IOLBF, 0)
        setvbuf(stderr, nil, _IOLBF, 0)

        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { return }
            guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            self?.appendraw(chunk)
        }
    }

    private func appendraw(_ chunk: String) {
        var text = panding + chunk
        var lines = text.components(separatedBy: "\n")
        panding = lines.removeLast()
        if !lines.isEmpty {
            let filtered = lines.filter { !shouldIgnore($0) }
            DispatchQueue.main.async {
                self.logs.append(contentsOf: filtered)
            }
            appendToFile(filtered)
            for line in filtered {
                emit(line)
            }
        }
    }

    private func emit(_ message: String) {
        if shouldIgnore(message) { return }
        guard ogstdout != -1 else { return }
        let line = message + "\n"
        line.withCString { ptr in
            _ = Darwin.write(ogstdout, ptr, strlen(ptr))
        }
    }

    private func shouldIgnore(_ message: String) -> Bool {
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        for fragment in ignoredLogSubstrings {
            if message.contains(fragment) {
                return true
            }
        }
        return false
    }

    private func setupLogFile() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("lara.log")
        logFileURL = url
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [
                FileAttributeKey.protectionKey: FileProtectionType.none
            ])
        } else {
            try? FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.none], ofItemAtPath: url.path)
            if let existing = try? String(contentsOf: url, encoding: .utf8), !existing.isEmpty {
                let lines = existing.components(separatedBy: "\n").filter {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                if !lines.isEmpty {
                    self.logs = lines
                    self.lastwasdivider = true
                }
            }
        }
        logFileHandle = try? FileHandle(forWritingTo: url)
        try? logFileHandle?.seekToEnd()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let separator = "--- session started: \(formatter.string(from: Date())) ---"
        self.logs.append(separator)
        self.lastwasdivider = true
        if let data = (separator + "\n").data(using: .utf8) {
            try? logFileHandle?.write(contentsOf: data)
            try? logFileHandle?.synchronize()
        }
    }

    private func appendToFile(_ lines: [String]) {
        guard let handle = logFileHandle else { return }
        let filtered = lines.filter { !shouldIgnore($0) }
        guard !filtered.isEmpty else { return }
        let text = filtered.joined(separator: "\n") + "\n"
        if let data = text.data(using: .utf8) {
            try? handle.write(contentsOf: data)
            try? handle.synchronize()
        }
    }
}

struct LogsView: View {
    @ObservedObject var logger: Logger

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(logger.logs.enumerated()), id: \.offset) { _, log in
                    Text(log)
                        .font(.system(size: 13, design: .monospaced))
                        .lineSpacing(1)
                        .onTapGesture {
                            UIPasteboard.general.string = log
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                }
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    
                    Button {
                        let allLogs = logger.logs.joined(separator: "\n\n")
                        UIPasteboard.general.string = allLogs
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    
                    Button {
                        globallogger.clear()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
}

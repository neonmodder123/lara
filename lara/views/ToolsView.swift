//
//  ToolsView.swift
//  lara
//
//  Created by ruter on 04.04.26.
//

import SwiftUI

struct ToolsView: View {
    @State private var isaslr: Bool = aslrstate
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("ASLR:")
                    
                    Spacer()
                    
                    Text(isaslr ? "enabled" : "disabled")
                        .foregroundColor(isaslr ? Color.red : Color.green)
                        .monospaced()
                    
                    Button {
                        isaslr = aslrstate
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                Button {
                    toggleaslr()
                    isaslr = aslrstate
                } label: {
                    Text("Toggle ASLR")
                }
            } header: {
                Text("ASLR")
            } footer: {
                Text("Address Space Layout Randomization. Turning it on may break lara.")
            }
        }
        .navigationTitle("Tools")
    }
}

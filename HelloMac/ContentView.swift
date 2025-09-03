//
//  ContentView.swift
//  HelloMac
//
//  Created by Zachary DeParle on 9/2/25.
//

import SwiftUI

struct ContentView: View {
    @State private var count: Int = 0
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
                .font(.title2)
                .padding(.bottom, 8)

            Text("Count: \(count)")
                .font(.headline)
                .padding(.bottom, 4)

            Button(action: { count += 1 }) {
                Text("Increment")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

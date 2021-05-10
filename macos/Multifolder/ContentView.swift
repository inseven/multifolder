// Copyright (c) 2021 InSeven Limited
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import SwiftUI
import UniformTypeIdentifiers

import Interact

extension String: Identifiable {
    public var id: String { self }
}

extension URL: Identifiable {
    public var id: URL { self }
}

struct FileDropDelegate: DropDelegate {
    @Binding var files: [URL]

    func performDrop(info: DropInfo) -> Bool {
        for item in info.itemProviders(for: [.fileURL]) {
            _ = item.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async {
                        self.files.insert(url, at: 0)
                    }
                }
            }
        }
        return true
    }
}

struct ContentView: View {

    @State var contents: [String: Any]?
    @State var folder = ""
    @State var paths: [URL] = []
    @State var targeted = true
    @State var selection: Set<URL> = Set()

    func relaunchFinder() {
        let script = """
        tell application \"Finder\" to quit
        tell application \"Finder\" to activate
        """
        guard let appleScript = NSAppleScript(source: script) else {
            print("Failed to create script")
            return
        }
        var errorInfo: NSDictionary? = nil
        appleScript.executeAndReturnError(&errorInfo)
        if let error = errorInfo {
            print(error)
        }
    }

    func load(path: String) {
        guard let contents = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            print("Failed to load dictionary")
            return
        }
        guard let searchCritera = contents["SearchCriteria"] as? [String: Any],
              let arrayOfPaths = searchCritera["FXScopeArrayOfPaths"] as? [String] else {
            print("Invalid format")
            return
        }
        self.contents = contents
        self.paths = arrayOfPaths.map { path in
            URL(fileURLWithPath: path)
        }
    }

    var body: some View {
        VStack {
            TextField("Folder Path", text: $folder)
            List(selection: $selection) {
                ForEach(paths) { link in
                    HStack {
                        IconView(url: link, size: CGSize(width: 16, height: 16))
                        Text(link.path)
                    }
                    .contextMenu {
                        Button("Remove") {
                            if selection.contains(link) {
                                paths.removeAll { selection.contains($0) }
                            } else {
                                paths.removeAll { $0 == link }
                            }
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], delegate: FileDropDelegate(files: $paths))
            HStack {
                Button("Save") {
                    guard var contents = contents else {
                        return
                    }
                    guard var searchCritera = contents["SearchCriteria"] as? [String: Any] else {
                        return
                    }
                    searchCritera["FXScopeArrayOfPaths"] = paths.map { $0.path }
                    contents["SearchCriteria"] = searchCritera
                    let dictionary = contents as NSDictionary
                    dictionary.write(toFile: folder, atomically: true)

                    do {
                        try FileManager.default.setAttributes([.extensionHidden: true], ofItemAtPath: folder)
                    } catch {
                        print(error)
                    }

                    // Unfortunately we have to relaunch the Finder to ensure it re-reads the smart folder 😢
                    relaunchFinder()
                }
                .disabled(contents == nil)
            }
            .onChange(of: folder) { folder in
                load(path: folder)
            }
        }
        .padding()
    }
}

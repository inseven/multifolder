//
//  ContentView.swift
//  Smart Folders
//
//  Created by Jason Barrie Morley on 30/04/2021.
//

import SwiftUI
import UniformTypeIdentifiers


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
                    Text(link.path)
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

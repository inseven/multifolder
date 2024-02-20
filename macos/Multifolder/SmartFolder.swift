// Copyright (c) 2021-2024 Jason Morley
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

class CallbackFileWrapper: FileWrapper {

    var callback: () -> Void = {}

    init(regularFileWithContents contents: Data, callback: @escaping () -> Void) {
        super.init(regularFileWithContents: contents)
        self.callback = callback
    }

    required init?(coder inCoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func write(to url: URL, options: FileWrapper.WritingOptions = [], originalContentsURL: URL?) throws {
        try super.write(to: url, options: options, originalContentsURL: originalContentsURL)
        callback()
    }

}

class SmartFolder: FileDocument, ObservableObject {

    static var readableContentTypes: [UTType] = [UTType(filenameExtension: "savedSearch")!]

    @Published var contents: [String: Any] = [:]
    @Published var paths: [URL] = []

    init() {
        // TODO: Disable this somehow!
    }

    required init(configuration: ReadConfiguration) throws {
        print(Self.readableContentTypes)
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let contents = plist as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let searchCritera = contents["SearchCriteria"] as? [String: Any],
              let arrayOfPaths = searchCritera["FXScopeArrayOfPaths"] as? [String] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.contents = contents
        self.paths = arrayOfPaths.map { path in
            URL(fileURLWithPath: path)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard var searchCritera = contents["SearchCriteria"] as? [String: Any] else {
            throw CocoaError(.fileWriteUnknown)
        }
        searchCritera["FXScopeArrayOfPaths"] = paths.map { $0.path }
        contents["SearchCriteria"] = searchCritera
        let dictionary = contents as NSDictionary
        let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
        return CallbackFileWrapper(regularFileWithContents: data) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Finder.shared.relaunch()
            }
        }
    }

}

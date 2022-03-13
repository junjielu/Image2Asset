import ArgumentParser
import Foundation

@main
struct Image2Asset: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "CLI tool to make svg image files into asset catalog.")
        
    @Option(name: [.short, .customLong("input")], help: "Images directory to read.")
    var inputPath: String

    @Option(name: [.short, .customLong("output")], help: "A path to save asset catalog file.")
    var outputPath: String
    
    @Flag(name: .shortAndLong, help: "Print all info while execute.")
    var verbose = false

    mutating func run() throws {
        let fileManager = FileManager.default
        let outputAssetPath = "\(outputPath)/Images.xcassets"
        
        print("👋🏻 Gonna transform all image files info single asset catalog.")
        
        if verbose {
            print("""
            Input: \(inputPath)
            Output: \(outputAssetPath)
            """)
        }
        
        guard fileManager.directoryExistsAtPath(inputPath) else {
            throw RuntimeError("Directory not exists at '\(inputPath)'!")
        }
        
        if fileManager.fileExists(atPath: outputAssetPath) {
            // remove existing first
            print("🔨 removing existing Images.xcassets folder at \(outputAssetPath)")
            try fileManager.removeItem(atPath: outputAssetPath)
        }
        
        // create output folder
        try fileManager.createDirectory(atPath: outputAssetPath, withIntermediateDirectories: true)
        
        // enumerate all files
        print("🔨 Start enumerate all image files.")
        
        let enumerator = fileManager.enumerator(atPath: inputPath)
        
        var fileHandled = 0
        while let file = enumerator?.nextObject() as? String {
            let handled = try copyImageToOutput(sourceFile: file, outputAssetPath: outputAssetPath, fileManager: fileManager)
            
            if handled {
                fileHandled += 1
            }
        }
        
        print("✅ \(fileHandled) files handled.")
    }
    
    func copyImageToOutput(sourceFile: String, outputAssetPath: String, fileManager: FileManager) throws -> Bool {
        guard let sourceUrl = URL(string: sourceFile) else {
            throw RuntimeError("🛑 File name illegal for '\(sourceFile)'!")
        }
        let fileName = sourceUrl.lastPathComponent
        
        // ignore directory and non-svg files.
        guard sourceUrl.pathExtension == "svg" else {
            if verbose {
                print("🚨 just skip source: \(sourceFile)")
            }
            return false
        }
        
        // validate file name.
        guard validate(fileName: fileName) else {
            throw RuntimeError("🛑 File name illegal for '\(fileName)'!")
        }
        
        if verbose {
            print("💡 Start handle \(sourceFile)")
        }
        
        // create .imageset.
        let iconName = iconName(from: sourceUrl)
        let targetDirectoryPath = "\(outputAssetPath)/\(iconName).imageset"
        try fileManager.createDirectory(atPath: targetDirectoryPath, withIntermediateDirectories: true)
        
        // create contents.json
        let contents = Contents(filename: fileName)
        let jsonData = try JSONEncoder().encode(contents)
        let contentsFilePath = "\(targetDirectoryPath)/Contents.json"
        if fileManager.fileExists(atPath: contentsFilePath) {
            try fileManager.removeItem(atPath: contentsFilePath)
        }
        fileManager.createFile(atPath: contentsFilePath, contents: jsonData)
        
        // copy image.
        let sourceImagePath = "\(inputPath)/\(sourceFile)"
        let targetImagePath = "\(targetDirectoryPath)/\(fileName)"
        
        try fileManager.copyItem(atPath: sourceImagePath, toPath: targetImagePath)
        
        return true
    }
    
    func validate(fileName: String) -> Bool {
        return Regex("^[A-Z0-9a-z_]+\\.svg$").test(fileName)
    }
    
    func iconName(from sourceUrl: URL) -> String {
        var urlToRemoveExtension = sourceUrl
        urlToRemoveExtension.deletePathExtension()
        return urlToRemoveExtension.absoluteString
    }
}

struct Contents: Codable {
    struct Image: Codable {
        let filename: String
        let idiom: String
    }
    
    struct Info: Codable {
        let author: String
        let version: Int
        
        static let `default` = Info(author: "xcode", version: 1)
    }
    
    let images: [Image]
    let info: Info
    
    init(filename: String) {
        self.images = [Image(filename: filename, idiom: "universal")]
        self.info = .default
    }
}

struct Regex {
    let regex: String
    
    init(_ regex: String) {
        self.regex = regex
    }
    
    func test(_ testString: String) -> Bool {
        return testString.range(of: regex, options: .regularExpression) != nil
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    var description: String
    
    init(_ description: String) {
        self.description = description
    }
}

extension FileManager {
    fileprivate func directoryExistsAtPath(_ path: String) -> Bool {
        var isDirectory = ObjCBool(true)
        let exists = self.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}

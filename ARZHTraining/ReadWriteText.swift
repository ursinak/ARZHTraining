//
//  ReadWriteText.swift
//  ARZHFile
//
//  Created by Ursina Boos on 21.03.20.
//  Copyright © 2020 Ursina Boos. All rights reserved.
//

import Foundation

class ReadWriteText {
    var DocumentDirURL: URL {
        let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return url
    }

    func fileURL(fileName: String, fileExtension: String) -> URL {
        return DocumentDirURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
    }

    func returnFileURL(fileName: String, fileExtension: String = "mspk") -> URL {
        let url = fileURL(fileName: fileName, fileExtension: fileExtension)
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                print("file exists")
            }

        } catch let error as NSError {
            print("Error:" + error.localizedDescription)
        }
        return url
    }

    func writeFile(writeString: String, fileName: String, fileExtension: String = "txt") {
        let url = fileURL(fileName: fileName, fileExtension: fileExtension)
        do {
            try writeString.write(to: url, atomically: true, encoding: .utf8)
        } catch let error as NSError {
            print("Failed writing to URL: \(String(describing: fileURL)), Error:" + error.localizedDescription)
        }
    }

    func readFile(fileName: String, fileExtension: String = "txt") -> String {
        var readString = ""
        let url = fileURL(fileName: fileName, fileExtension: fileExtension)
        do {
            readString = try String(contentsOf: url)
        } catch let error as NSError {
            print("Failed writing to URL: \(String(describing: fileURL)), Error:" + error.localizedDescription)
        }
        return readString
    }

    func appendFile(writeString: String, fileName: String, fileExtension: String = "txt") {
        let url = fileURL(fileName: fileName, fileExtension: fileExtension)
        do {
//            try writeString.write(to: url, atomically: true, encoding: .utf8)
            if FileManager.default.fileExists(atPath: url.path) {
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(writeString.data(using: .utf8)!)
                    fileHandle.closeFile()
                }
            } else {
                try? writeString.write(to: url, atomically: true, encoding: .utf8)
            }

        } catch let error as NSError {
            print("Failed writing to URL: \(String(describing: fileURL)), Error:" + error.localizedDescription)
        }
    }
}

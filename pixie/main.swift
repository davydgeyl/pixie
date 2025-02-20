//
//  main.swift
//  pixie
//
//  Created by Davyd Geyl.
//

import Foundation
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

func printUsage() {
    print("usage: pixie \"inputImagePath1\" \"inputImagePath2\" [\"outputDiffPath\"]")
    print("       if [\"outputDiffPath\"] is not provided \"inputImagePath1_diff\" will be used.")
}

func checkFileExistance(at path: String) {
    if !FileManager.default.fileExists(atPath: path1) {
        print("File not found: \(path)")
        exit(-1)
    }
}

func computeImageDifference(path1: String, path2: String) -> CGImage? {
    let imageURL = NSURL(fileURLWithPath: path1)
    let image1 = CIImage(contentsOf: imageURL as URL)

    let imageURL2 = NSURL(fileURLWithPath: path2)
    let image2 = CIImage(contentsOf: imageURL2 as URL)

    let currentFilter = CIFilter.colorAbsoluteDifference()

    currentFilter.setValue(image1, forKey: "inputImage")
    currentFilter.setValue(image2, forKey: "inputImage2")

    guard let outputImage = currentFilter.outputImage else { return nil }

    let context = CIContext()
    guard let cgImage = context.createCGImage (outputImage,
                                             from: outputImage.extent) else { return nil }
    return cgImage
}

func shell(launchPath: String, arguments: [String]) -> String {
    let process = Process()
    process.launchPath = launchPath
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()

    let output_from_command = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: String.Encoding.utf8)!

    // remove the trailing new-line char
    if output_from_command.count > 0 {
        let lastIndex = output_from_command.index(before: output_from_command.endIndex)
        return String(output_from_command[output_from_command.startIndex ..< lastIndex])
    }
    return output_from_command
}


extension CGImage {
    func savePNG(at url: URL) {
        let newRep = NSBitmapImageRep(cgImage: self)
        if let data = newRep.representation(using: .png, properties: [:]) {
            do {
                try data.write(to: url as URL, options: .atomic)
                print("Diff image is written: \(url.relativePath)")
            } catch let error as NSError {
                print(error)
            }
        }
    }
}

if CommandLine.arguments.count < 3 {
    printUsage()
    exit(-1)
}

let path1 = CommandLine.arguments[1]
let path2 = CommandLine.arguments[2]

var outputURL: URL?

if CommandLine.arguments.count == 4 {
    outputURL = NSURL(fileURLWithPath:CommandLine.arguments[3]) as URL
} else {
    let url = NSURL(fileURLWithPath: path2)
    let fileName = url.lastPathComponent
    if let pathExtension = url.pathExtension,
        let file1NameNoExtension = fileName?.replacingOccurrences(of: pathExtension, with: "").replacingOccurrences(of: ".", with: "") {

        let outputFileName = file1NameNoExtension + "_diff"

        outputURL = url.deletingLastPathComponent?.appendingPathComponent(outputFileName).appendingPathExtension(pathExtension)
    }
}

checkFileExistance(at: path1)
checkFileExistance(at: path2)

if let image = computeImageDifference(path1: path1, path2: path2),
   let outputURL = outputURL {
    image.savePNG(at: outputURL)
    let _ = shell(launchPath: "/usr/bin/open", arguments: [outputURL.path])
    exit(0)
}

exit(-2)


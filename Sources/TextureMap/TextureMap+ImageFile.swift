//
//  Created by Anton Heestand on 2026-08-29.
//

import Foundation
import CoreGraphics
import CoreImage
import ImageIO

public extension TextureMap {

    static func write(
        ciImage: CIImage,
        to url: URL,
        format: TMImageFileFormat,
        bits: TMBits,
        colorSpace: TMColorSpace,
        compressionQuality: CGFloat
    ) throws {

        let context = CIContext(options: nil)

        switch format {
        case .png:
            try context.writePNGRepresentation(
                of: ciImage,
                to: url,
                format: bits.ciFormat,
                colorSpace: colorSpace.cgColorSpace,
                options: [:]
            )
        case .jpeg:
            try context.writeJPEGRepresentation(
                of: ciImage,
                to: url,
                colorSpace: colorSpace.cgColorSpace,
                options: [
                    kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: compressionQuality
                ]
            )
        case .tiff:
            try context.writeTIFFRepresentation(
                of: ciImage,
                to: url,
                format: bits.ciFormat,
                colorSpace: colorSpace.cgColorSpace,
                options: [:]
            )
        case .heif:
            try writeHEIF(
                ciImage: ciImage,
                to: url,
                bits: bits,
                colorSpace: colorSpace,
                compressionQuality: compressionQuality
            )
        case .openEXR:
            let data: Data = try openEXRData(
                ciImage: ciImage,
                bits: bits,
                colorSpace: colorSpace
            )
            try data.write(to: url)
        }
    }
}

// MARK: - Data

public extension TextureMap {

    static func data(
        ciImage: CIImage,
        format: TMImageFileFormat,
        bits: TMBits,
        colorSpace: TMColorSpace,
        compressionQuality: CGFloat
    ) throws -> Data {

        let context = CIContext(options: nil)

        switch format {
        case .png:
            guard let data: Data = context.pngRepresentation(
                of: ciImage,
                format: bits.ciFormat,
                colorSpace: colorSpace.cgColorSpace,
                options: [:]
            ) else {
                throw TMImageFileError.createDataFailed(format)
            }
            return data
        case .jpeg:
            guard let data: Data = context.jpegRepresentation(
                of: ciImage,
                colorSpace: colorSpace.cgColorSpace,
                options: [
                    kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: compressionQuality
                ]
            ) else {
                throw TMImageFileError.createDataFailed(format)
            }
            return data
        case .tiff:
            guard let data: Data = context.tiffRepresentation(
                of: ciImage,
                format: bits.ciFormat,
                colorSpace: colorSpace.cgColorSpace,
                options: [:]
            ) else {
                throw TMImageFileError.createDataFailed(format)
            }
            return data
        case .heif:
            return try heifData(
                ciImage: ciImage,
                bits: bits,
                colorSpace: colorSpace,
                compressionQuality: compressionQuality
            )
        case .openEXR:
            return try openEXRData(
                ciImage: ciImage,
                bits: bits,
                colorSpace: colorSpace
            )
        }
    }
}

// MARK: - Open EXR

extension TextureMap {

    /// Open EXR Data
    ///
    /// `OpenEXR` is scene referred, the image is encoded in linear light.
    /// Pass a `ciImage` that is already tagged with `colorSpace`, so the values
    /// are written as they are instead of being run through a transfer curve.
    ///
    /// `CIContext.openEXRRepresentation(of:options:)` always encodes half float,
    /// `ImageIO` is used instead to preserve the bit depth of 32 bit graphics.
    static func openEXRData(
        ciImage: CIImage,
        bits: TMBits,
        colorSpace: TMColorSpace
    ) throws -> Data {

        let linearColorSpace: TMColorSpace = try colorSpace.linear
        let context = CIContext(options: nil)

        guard let cgImage: CGImage = context.createCGImage(
            ciImage,
            from: ciImage.extent,
            format: bits.ciFormat,
            colorSpace: linearColorSpace.cgColorSpace
        ) else {
            throw TMImageFileError.createCGImageFailed(.openEXR)
        }

        let data = NSMutableData()

        guard let destination: CGImageDestination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            TMImageFileFormat.openEXR.typeIdentifier,
            1,
            nil
        ) else {
            throw TMImageFileError.createDestinationFailed(.openEXR)
        }

        CGImageDestinationAddImage(destination, cgImage, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw TMImageFileError.createDataFailed(.openEXR)
        }

        return data as Data
    }
}

// MARK: - Error

public enum TMImageFileError: LocalizedError {

    case createCGImageFailed(TMImageFileFormat)
    case createDestinationFailed(TMImageFileFormat)
    case createDataFailed(TMImageFileFormat)

    public var errorDescription: String? {
        switch self {
        case .createCGImageFailed(let format):
            "Texture Map - Image File - Create Core Graphics Image Failed (\(format.rawValue))"
        case .createDestinationFailed(let format):
            "Texture Map - Image File - Create Destination Failed (\(format.rawValue))"
        case .createDataFailed(let format):
            "Texture Map - Image File - Create Data Failed (\(format.rawValue))"
        }
    }
}

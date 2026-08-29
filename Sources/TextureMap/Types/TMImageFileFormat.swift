//
//  Created by Anton Heestand on 2026-08-29.
//

import Foundation
import UniformTypeIdentifiers

/// Image File Format
///
/// The encoding used when writing an image to disk or to data.
public enum TMImageFileFormat: String, CaseIterable, Sendable {

    case png
    case jpeg
    case tiff
    case heif
    case openEXR
}

// MARK: - File Extension

extension TMImageFileFormat {

    /// All file extensions that map to this format.
    public var fileExtensions: [String] {
        switch self {
        case .png:
            ["png"]
        case .jpeg:
            ["jpg", "jpeg"]
        case .tiff:
            ["tiff", "tif"]
        case .heif:
            ["heif", "heic"]
        case .openEXR:
            ["exr"]
        }
    }

    /// The primary file extension for this format.
    public var fileExtension: String {
        fileExtensions[0]
    }

    public init(fileExtension: String) throws {
        let name: String = fileExtension.lowercased()
        guard let format: TMImageFileFormat = Self.allCases.first(where: {
            $0.fileExtensions.contains(name)
        }) else {
            throw TMImageFileFormatError.fileExtensionNotSupported(fileExtension)
        }
        self = format
    }

    public init(url: URL) throws {
        try self.init(fileExtension: url.pathExtension)
    }
}

// MARK: - Type Identifier

extension TMImageFileFormat {

    /// The uniform type identifier used by `ImageIO`.
    ///
    /// `OpenEXR` has no `UTType` constant, it is identified by name.
    public var typeIdentifier: CFString {
        switch self {
        case .png:
            UTType.png.identifier as CFString
        case .jpeg:
            UTType.jpeg.identifier as CFString
        case .tiff:
            UTType.tiff.identifier as CFString
        case .heif:
            UTType.heic.identifier as CFString
        case .openEXR:
            "com.ilm.openexr-image" as CFString
        }
    }
}

// MARK: - Color

extension TMImageFileFormat {

    /// Formats that store scene referred linear light instead of display referred values.
    public var isLinear: Bool {
        self == .openEXR
    }
}

// MARK: - Error

public enum TMImageFileFormatError: LocalizedError {

    case fileExtensionNotSupported(String)

    public var errorDescription: String? {
        switch self {
        case .fileExtensionNotSupported(let fileExtension):
            "Texture Map - Image File Format - File Extension Not Supported (\(fileExtension))"
        }
    }
}

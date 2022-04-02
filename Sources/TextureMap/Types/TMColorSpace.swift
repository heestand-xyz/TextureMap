//
//  Created by Anton Heestand on 2022-04-02.
//

import Foundation
import CoreGraphics
import CoreImage

public enum TMColorSpace: String, Codable, CaseIterable {
    case sRGB
    case displayP3
}

// MARK: Format

public extension TMColorSpace {
    
    var cgColorSpace: CGColorSpace {
        switch self {
        case .sRGB:
            return CGColorSpace(name: CGColorSpace.sRGB)!
        case .displayP3:
            return CGColorSpace(name: CGColorSpace.displayP3)!
        }
    }
}

// MARK: Init

public extension TMColorSpace {
    
    init(cgColorSpace: CGColorSpace) throws {
        
        for colorSpace in TMColorSpace.allCases {
            if colorSpace.cgColorSpace == cgColorSpace {
                self = colorSpace
                return
            }
        }
        
        throw TMColorSpaceError.notSupported(cgColorSpace)
    }
    
    init(cgImage: CGImage) throws {
        
        guard let colorSpace: CGColorSpace = cgImage.colorSpace else {
            throw TMColorSpaceError.notFound
        }
        
        try self.init(cgColorSpace: colorSpace)
    }
    
    init(image: TMImage) throws {

        #if os(macOS)
        guard let cgImage: CGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TMColorSpaceError.cgImageNotFound
        }
        #else
        guard let cgImage: CGImage = image.cgImage else {
            throw TMColorSpaceError.cgImageNotFound
        }
        #endif
        
        try self.init(cgImage: cgImage)
    }
    
    init(ciImage: CIImage) throws {
        
        guard let colorSpace: CGColorSpace = ciImage.colorSpace else {
            throw TMColorSpaceError.notFound
        }
        
        try self.init(cgColorSpace: colorSpace)
    }
    
    #if os(macOS)
    init(bitmap: NSBitmapImageRep) throws {
        
        guard let cgImage: CGImage = bitmap.cgImage else {
            throw TMColorSpaceError.cgImageNotFound
        }
        
        try self.init(cgImage: cgImage)
    }
    #endif
    
}

// MARK: - Image

public extension TMImage {
    
    var colorSpace: TMColorSpace {
        get throws {
            try TMColorSpace(image: self)
        }
    }
}

// MARK: - Error

public extension TMColorSpace {
    
    enum TMColorSpaceError: LocalizedError {
        
        case notFound
        case cgImageNotFound
        case notSupported(CGColorSpace)
        
        public var errorDescription: String? {
            switch self {
            case .notFound:
                return "Texture Map - Color Space - Not Found"
            case .cgImageNotFound:
                return "Texture Map - Color Space - Core Graphics Image Not Found"
            case .notSupported(let colorSpace):
                return "Texture Map - Color Space - Not Supported (\(String(describing: colorSpace.name))"
            }
        }
    }
}

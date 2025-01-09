//
//  Created by Anton Heestand on 2022-04-02.
//

import Foundation
import CoreGraphics
import CoreImage
#if os(macOS)
import AppKit
#endif

public enum TMColorSpace: Equatable, Sendable {
    case linearSRGB
    case nonLinearSRGB
    case linearDisplayP3
    case nonLinearDisplayP3
    case xdr
    case custom(CGColorSpace)
}

// MARK: - Defaults

extension TMColorSpace {
    public static let sRGB: TMColorSpace = .nonLinearSRGB
    public static let displayP3: TMColorSpace = .nonLinearDisplayP3
}

// MARK: - Is

extension TMColorSpace {
    var isSRGB: Bool {
        [.linearSRGB, .nonLinearSRGB].contains(self)
    }
    
    var isDisplayP3: Bool {
        [.linearDisplayP3, .nonLinearDisplayP3].contains(self)
    }
}

// MARK: - Cases

extension TMColorSpace {
    private static var nonCustomCases: [TMColorSpace] {
        [
            .linearSRGB,
            .nonLinearSRGB,
            .linearDisplayP3,
            .nonLinearDisplayP3,
            .xdr
        ]
    }
}

// MARK: - Description

extension TMColorSpace: CustomStringConvertible {
    public var description: String {
        switch self {
        case .linearSRGB:
            return "Linear sRGB"
        case .nonLinearSRGB:
            return "Non Linear sRGB"
        case .linearDisplayP3:
            return "Linear Display P3"
        case .nonLinearDisplayP3:
            return "Non Linear Display P3"
        case .xdr:
            return "XDR"
        case .custom(let cgColorSpace):
            return "Custom: \(cgColorSpace)"
        }
    }
}

// MARK: - CG Color Space

extension TMColorSpace {
    
    public var cgColorSpace: CGColorSpace {
        switch self {
        case .linearSRGB:
            return CGColorSpace(name: CGColorSpace.linearSRGB)!
        case .nonLinearSRGB:
            return CGColorSpace(name: CGColorSpace.sRGB)!
        case .linearDisplayP3:
            return CGColorSpace(name: CGColorSpace.linearDisplayP3)!
        case .nonLinearDisplayP3:
            return CGColorSpace(name: CGColorSpace.displayP3)!
        case .xdr:
            return CGColorSpace(name: CGColorSpace.itur_2100_PQ)! // HLG
        case .custom(let cgColorSpace):
            return cgColorSpace
        }
    }
    
    var coloredCGColorSpace: CGColorSpace {
        if isMonochrome {
            return CGColorSpace(name: CGColorSpace.sRGB)!
        } else {
            return cgColorSpace
        }
    }
}

// MARK: - Monochrome

public extension TMColorSpace {
    
    var isMonochrome: Bool {
        switch self {
        case .linearSRGB, .nonLinearSRGB, .linearDisplayP3, .nonLinearDisplayP3, .xdr:
            return false
        case .custom(let cgColorSpace):
            return cgColorSpace.model == .monochrome
        }
    }
}

// MARK: - Life Cycle

public extension TMColorSpace {
    
    init(cgColorSpace: CGColorSpace) throws {
        
        for nonCustomCase in Self.nonCustomCases {
            if cgColorSpace == nonCustomCase.cgColorSpace {
                self = nonCustomCase
                return
            }
        }
        
        if cgColorSpace.name == CGColorSpace.extendedSRGB {
            self = .nonLinearDisplayP3
            return
        } else if cgColorSpace == CGColorSpace(name: CGColorSpace.itur_2100_PQ)! ||
            cgColorSpace == CGColorSpace(name: CGColorSpace.itur_2100_HLG)! {
            self = .xdr
            return
        } else {
            self = .custom(cgColorSpace)
        }
    }
    
    init(cgImage: CGImage) throws {
        
        guard let colorSpace: CGColorSpace = cgImage.colorSpace else {
            throw TMColorSpaceError.notFound
        }
        
        try self.init(cgColorSpace: colorSpace)
    }
    
    init(image: TMImage) throws {

        #if os(macOS)
        
        if image.representations.isEmpty {
            throw TMColorSpaceError.noRepresentationsFound
        }
        
        let colorSpaces: [TMColorSpace] = try image.representations.map { representation in
            guard let cgImage: CGImage = representation.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw TMColorSpaceError.cgImageNotFound
            }
            return try TMColorSpace(cgImage: cgImage)
        }
        
        if colorSpaces.contains(.linearDisplayP3) {
            
            self = .linearDisplayP3
            
        } else if colorSpaces.contains(.nonLinearDisplayP3) {
            
            self = .nonLinearDisplayP3
            
        } else if colorSpaces.contains(.linearSRGB) {
            
            self = .linearSRGB
            
        } else if colorSpaces.contains(.nonLinearSRGB) {
            
            self = .nonLinearSRGB
            
        } else {
            
            guard let cgImage: CGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw TMColorSpaceError.cgImageNotFound
            }
            
            try self.init(cgImage: cgImage)
        }
        
        #else
        
        guard let cgImage: CGImage = image.cgImage else {
            throw TMColorSpaceError.cgImageNotFound
        }
        
        try self.init(cgImage: cgImage)

        #endif
        
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
        case noRepresentationsFound
        
        public var errorDescription: String? {
            switch self {
            case .notFound:
                return "Texture Map - Color Space - Not Found"
            case .cgImageNotFound:
                return "Texture Map - Color Space - Core Graphics Image Not Found"
            case .notSupported(let colorSpace):
                return "Texture Map - Color Space - Not Supported [\(colorSpace)]"
            case .noRepresentationsFound:
                return "Texture Map - Color Space - No Representations Found"
            }
        }
    }
}

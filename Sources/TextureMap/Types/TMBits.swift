//
//  Created by Anton Heestand on 2021-10-15.
//

import Foundation
import MetalKit

public enum TMBits: Int, Codable, CaseIterable {
  
    case _8 = 8
    case _16 = 16
    
}

// MARK: Format

extension TMBits {
    
    /// Metal Pixel Format
    /// - Parameter swapRedAndBlue: RGBA when `false`, BGRA when `true` *(8 bit only)*
    public func metalPixelFormat(swapRedAndBlue: Bool = false) -> MTLPixelFormat {
        switch self {
        case ._8: return swapRedAndBlue ? .bgra8Unorm : .rgba8Unorm
        case ._16: return .rgba16Float
        }
    }
    
    public var ciFormat: CIFormat {
        switch self {
        case ._8: return .RGBA8
        case ._16: return .RGBAh
        }
    }
    
    public var osType: OSType {
        switch self {
        case ._8: return kCVPixelFormatType_32BGRA
        case ._16: return kCVPixelFormatType_128RGBAFloat
        }
    }
    
}

// MARK: Init

extension TMBits {
    
    public init(metalPixelFormat: MTLPixelFormat) throws {
        var bits: Self?
        for currentBits in Self.allCases {
            if currentBits.metalPixelFormat(swapRedAndBlue: false) == metalPixelFormat {
                bits = currentBits
            } else if currentBits.metalPixelFormat(swapRedAndBlue: true) == metalPixelFormat {
                bits = currentBits
            }
        }
        if let bits: Self = bits {
            self = bits
        } else {
            throw TMBitsError.metalPixelFormatNotSupported(metalPixelFormat)
        }
    }
    
    public init(texture: MTLTexture) throws {
        self = try Self(metalPixelFormat: texture.pixelFormat)
    }
    
    public init(cgImage: CGImage) throws {
        var bits: Self!
        switch cgImage.bitsPerComponent {
        case 8:
            bits = ._8
        case 16:
            bits = ._16
        default:
            throw TMBitsError.bitsPerComponentNotSupported(cgImage.bitsPerComponent)
        }
        self = bits
    }
    
    public init(image: TMImage) throws {
        #if os(macOS)
        guard let cgImage: CGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TMBitsError.cgImageNotFound
        }
        #else
        guard let cgImage: CGImage = image.cgImage else {
            throw TMBitsError.cgImageNotFound
        }
        #endif
        self = try Self(cgImage: cgImage)
    }
    
    public init(ciImage: CIImage) throws {
        guard let cgImage: CGImage = ciImage.cgImage else {
            throw TMBitsError.cgImageNotFound
        }
        self = try Self(cgImage: cgImage)
    }
    
    #if os(macOS)
    public init(bitmap: NSBitmapImageRep) throws {
        guard let cgImage: CGImage = bitmap.cgImage else {
            throw TMBitsError.cgImageNotFound
        }
        self = try Self(cgImage: cgImage)
    }
    #endif
    
}

// MARK: - Image

extension TMImage {
    
    public var bits: TMBits {
        get throws {
            try TMBits(image: self)
        }
    }
}

// MARK: - Error
    
extension TMBits {
    
    public enum TMBitsError: LocalizedError {
        case metalPixelFormatNotSupported(MTLPixelFormat)
        case cgImageNotFound
        case bitsPerComponentNotSupported(Int)
        public var errorDescription: String? {
            switch self {
            case .metalPixelFormatNotSupported(let metalPixelFormat):
                return "Texture Map Bits - Metal Pixel Format (\(metalPixelFormat.rawValue)) Not Supported"
            case .cgImageNotFound:
                return "Texture Map Bits - CGImage Not Found"
            case .bitsPerComponentNotSupported(let bitsPerComponent):
                return "Texture Map Bits - Bits Per Component (\(bitsPerComponent)) Not Supported"
            }
        }
    }
    
}

//
//  Created by Anton Heestand on 2021-10-15.
//

import Foundation
import MetalKit

public enum TMBits: Int, Codable, CaseIterable, Comparable, Sendable {
  
    case _8 = 8
    case _16 = 16
    case _32 = 32
    
    public static func < (lhs: TMBits, rhs: TMBits) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: Format

public extension TMBits {
    
    /// Metal Pixel Format
    /// - Parameter swapRedAndBlue: RGBA when `false`, BGRA when `true` *(8 bit only)*
    func metalPixelFormat(swapRedAndBlue: Bool = false) -> MTLPixelFormat {
        switch self {
        case ._8: return swapRedAndBlue ? .bgra8Unorm : .rgba8Unorm
        case ._16: return .rgba16Float
        case ._32: return .rgba32Float
        }
    }
    
    var ciFormat: CIFormat {
        switch self {
        case ._8: return .RGBA8
        case ._16: return .RGBAh
        case ._32: return .RGBAf
        }
    }
    
    var osType: OSType {
        switch self {
        case ._8: return kCVPixelFormatType_32BGRA // RGBA?
        case ._16: return kCVPixelFormatType_64RGBAHalf
        case ._32: return kCVPixelFormatType_128RGBAFloat
        }
    }
    
}

// MARK: Init

public extension TMBits {
    
    init(metalPixelFormat: MTLPixelFormat) throws {
        
        var bits: Self?
        
        for currentBits in Self.allCases {
            if currentBits.metalPixelFormat(swapRedAndBlue: false) == metalPixelFormat {
                bits = currentBits
                break
            } else if currentBits.metalPixelFormat(swapRedAndBlue: true) == metalPixelFormat {
                bits = currentBits
                break
            }
        }
        
        if bits == nil {
            if metalPixelFormat == .bgra8Unorm_srgb {
                bits = ._8
            } else if [.r32Float, .rg32Float].contains(metalPixelFormat) {
                bits = ._32
            } else if [.r16Float, .rg16Float, .rgba16Unorm].contains(metalPixelFormat) {
                bits = ._16
            } else if metalPixelFormat == .r8Unorm {
                bits = ._8
            } else if metalPixelFormat == .rg8Unorm {
                bits = ._8
            }
        }
        
        if let bits: Self = bits {
            self = bits
        } else {
            throw TMBitsError.metalPixelFormatNotSupported(metalPixelFormat)
        }
    }
    
    init(texture: MTLTexture) throws {
        self = try Self(metalPixelFormat: texture.pixelFormat)
    }
    
    init(cgImage: CGImage) throws {
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
    
    init(image: TMImage) throws {
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
    
    init(ciImage: CIImage) throws {
        guard let cgImage: CGImage = ciImage.cgImage else {
            throw TMBitsError.cgImageNotFound
        }
        self = try Self(cgImage: cgImage)
    }
    
    #if os(macOS)
    init(bitmap: NSBitmapImageRep) throws {
        guard let cgImage: CGImage = bitmap.cgImage else {
            throw TMBitsError.cgImageNotFound
        }
        self = try Self(cgImage: cgImage)
    }
    #endif
    
}

// MARK: - Image

public extension TMImage {
    
    var bits: TMBits {
        get throws {
            try TMBits(image: self)
        }
    }
}

// MARK: - Error
    
public extension TMBits {
    
    enum TMBitsError: LocalizedError {
        
        case metalPixelFormatNotSupported(MTLPixelFormat)
        case cgImageNotFound
        case bitsPerComponentNotSupported(Int)
        
        public var errorDescription: String? {
            switch self {
            case .metalPixelFormatNotSupported(let metalPixelFormat):
                return "Texture Map - Bits - Metal Pixel Format (\(metalPixelFormat.rawValue)) - Not Supported"
            case .cgImageNotFound:
                return "Texture Map - Bits - Core Graphics Image - Not Found"
            case .bitsPerComponentNotSupported(let bitsPerComponent):
                return "Texture Map - Bits - Bits Per Component (\(bitsPerComponent)) - Not Supported"
            }
        }
    }
}

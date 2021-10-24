//
//  Created by Anton Heestand on 2021-10-15.
//

import Foundation
import MetalKit

public struct TextureMap {
    
    private static let metalDevice: MTLDevice = {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("TextureMap: Default metal device not found.")
        }
        return metalDevice
    }()
    
    public static let sRGBColorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    
}

// MARK: Texture

extension TextureMap {
    
    public static func texture(image: TMImage) throws -> MTLTexture {
        
        let cgImage: CGImage = try cgImage(image: image)
        
        return try texture(cgImage: cgImage)
    }
    
    public static func texture(cgImage: CGImage) throws -> MTLTexture {
        
        let loader = MTKTextureLoader(device: metalDevice)
        
        return try loader.newTexture(cgImage: cgImage, options: nil)
    }
    
    public static func texture(ciImage: CIImage, at size: CGSize, colorSpace: CGColorSpace = sRGBColorSpace) throws -> MTLTexture {
        
        let cgImage: CGImage = try cgImage(ciImage: ciImage)
        
        return try texture(cgImage: cgImage)
    }
    
}

// MARK: Image

extension TextureMap {
    
    public static func image(texture: MTLTexture, colorSpace: CGColorSpace = sRGBColorSpace) throws -> TMImage {
                
        let ciImage: CIImage = try ciImage(texture: texture, colorSpace: colorSpace)
        
        let cgImage: CGImage = try cgImage(ciImage: ciImage)
        
        return try image(cgImage: cgImage)
    }
    
    public static func image(cgImage: CGImage) throws -> TMImage {
#if os(macOS)
        return NSImage(cgImage: cgImage, size: cgImage.size)
#else
        return UIImage(cgImage: cgImage)
#endif
    }
    
    public static func image(ciImage: CIImage) throws -> TMImage {
#if os(macOS)
        let cgImage = try cgImage(ciImage: ciImage)
        
        return NSImage(cgImage: cgImage, size: ciImage.extent.size)
#else
        return UIImage(ciImage: ciImage)
#endif
    }
    
}

// MARK: CIImage

extension TextureMap {
    
    public static func ciImage(texture: MTLTexture, colorSpace: CGColorSpace = sRGBColorSpace) throws -> CIImage {
        
        guard let ciImage = CIImage(mtlTexture: texture, options: [.colorSpace: colorSpace]) else {
            throw TMError.createCIImageFailed
        }
        
        return ciImage
    }
    
    public static func ciImage(image: TMImage) throws -> CIImage {
        #if os(macOS)
        guard let data = image.tiffRepresentation else {
            throw TMError.tiffRepresentationNotFound
        }
        guard let ciImage = CIImage(data: data) else {
            throw TMError.createCIImageFailed
        }
        return ciImage
        #else
        guard let ciImage = CIImage(image: image) else {
            throw TMError.createCIImageFailed
        }
        return ciImage
        #endif
    }
    
}

// MARK: CGImage

extension TextureMap {
    
    public static func cgImage(ciImage: CIImage) throws -> CGImage {
        
        let bits = try TMBits(ciImage: ciImage)
        guard let colorSpace = ciImage.colorSpace else {
            throw TMError.ciImageColorSpaceNotFound
        }
        
        let context = CIContext(options: nil)
        
        guard let cgImage: CGImage = context.createCGImage(ciImage, from: ciImage.extent, format: bits.ciFormat, colorSpace: colorSpace) else {
            throw TMError.createCGImageFailed
        }
        
        return cgImage
    }
    
    public static func cgImage(image: TMImage) throws -> CGImage {
#if os(macOS)
        var imageRect = CGRect(origin: .zero, size: image.size)
        
        guard let cgImage: CGImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) else {
            throw TMError.cgImageNotFound
        }
        
        return cgImage
#else
        guard let cgImage: CGImage = image.cgImage else {
            throw TMError.cgImageNotFound
        }
        
        return cgImage
#endif
    }
}

// MARK: Error

extension TextureMap {
    
    public enum TMError: LocalizedError {
        case cgImageNotFound
        case createCGImageFailed
        case createCIImageFailed
        case ciImageColorSpaceNotFound
        case tiffRepresentationNotFound
        public var errorDescription: String? {
            switch self {
            case .cgImageNotFound:
                return "Texture Map - CGImage Not Found"
            case .createCGImageFailed:
                return "Texture Map - Create CGImage Failed"
            case .createCIImageFailed:
                return "Texture Map - Create CIImage Failed"
            case .ciImageColorSpaceNotFound:
                return "Texture Map - CIImage Color Space Not Found"
            case .tiffRepresentationNotFound:
                return "Texture Map - TIFF Representation Not Found"
            }
        }
    }
    
}

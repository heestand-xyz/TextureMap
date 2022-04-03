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
}

// MARK: Errors

extension TextureMap {
    
    public enum TMError: LocalizedError {
        case cgImageNotFound
        case createCGImageFailed
        case createCIImageFailed
        case ciImageColorSpaceNotFound
        case tiffRepresentationNotFound
        case sizeIsZero
        case makeTextureFailed
        case bitmapDataNotFound
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
            case .sizeIsZero:
                return "Texture Map - Size is Zero"
            case .makeTextureFailed:
                return "Texture Map - Make Texture Failed"
            case .bitmapDataNotFound:
                return "Texture Map - Bitmap Data Not Found"
            }
        }
    }
}

// MARK: Empty Texture

extension TextureMap {
    
    public enum TextureUsage {
        case renderTarget
        case write
        var textureUsage: MTLTextureUsage {
            switch self {
            case .renderTarget:
                return MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
            case .write:
                return MTLTextureUsage(rawValue: MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue)
            }
        }
    }
    
    public static func emptyTexture(size: CGSize, bits: TMBits, swapRedAndBlue: Bool = false, usage: TextureUsage = .renderTarget) async throws -> MTLTexture {
        
        try await withCheckedThrowingContinuation { continuation in
        
            DispatchQueue.global(qos: .userInteractive).async {
            
                do {
                
                    let texture = try emptyTexture(size: size, bits: bits, swapRedAndBlue: swapRedAndBlue, usage: usage)
                    
                    DispatchQueue.main.async {
                        continuation.resume(returning: texture)
                    }
                    
                } catch {
                    
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    public static func emptyTexture(size: CGSize, bits: TMBits, swapRedAndBlue: Bool = false, usage: TextureUsage = .renderTarget) throws -> MTLTexture {
        
        guard size.width > 0 && size.height > 0 else {
            throw TMError.sizeIsZero
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: bits.metalPixelFormat(swapRedAndBlue: swapRedAndBlue), width: Int(size.width), height: Int(size.height), mipmapped: true)
        
        descriptor.usage = usage.textureUsage
        
        guard let texture = metalDevice.makeTexture(descriptor: descriptor) else {
            throw TMError.makeTextureFailed
        }
        
        return texture
    }
}

// MARK: Texture

extension TextureMap {
    
    public static func texture(image: TMImage) throws -> MTLTexture {
        
        let cgImage: CGImage = try cgImage(image: image)
        
        return try texture(cgImage: cgImage)
    }
    
    public static func texture(cgImage: CGImage) throws -> MTLTexture {
        
        let loader = MTKTextureLoader(device: metalDevice)
        
        return try loader.newTexture(cgImage: cgImage, options: [.origin: true])
    }
    
    public static func texture(ciImage: CIImage) throws -> MTLTexture {
        
        let cgImage: CGImage = try cgImage(ciImage: ciImage)
        
        return try texture(cgImage: cgImage)
    }
    
    #if os(macOS)
    public static func texture(bitmap: NSBitmapImageRep) throws -> MTLTexture {
        
        guard let data: UnsafeMutablePointer<UInt8> = bitmap.bitmapData else {
            throw TMError.bitmapDataNotFound
        }
        
        let texture: MTLTexture = try emptyTexture(size: bitmap.size, bits: ._8)

        let region = MTLRegionMake2D(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh)

        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bitmap.bytesPerRow)
        
        return texture
    }
    #endif
}

// MARK: Image

extension TextureMap {
    
    public static func image(texture: MTLTexture,
                             colorSpace: TMColorSpace,
                             bits: TMBits) async throws -> TMImage {

        try await withCheckedThrowingContinuation { continuation in
            
            DispatchQueue.global(qos: .userInteractive).async {
                
                do {
                    
                    let image = try image(texture: texture, colorSpace: colorSpace, bits: bits)
                    
                    DispatchQueue.main.async {
                        continuation.resume(returning: image)
                    }
                    
                } catch {
                    
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    public static func image(texture: MTLTexture, colorSpace: TMColorSpace, bits: TMBits) throws -> TMImage {
                
        let ciImage: CIImage = try ciImage(texture: texture, colorSpace: colorSpace)
        
        #if os(macOS)
        
        let cgImage: CGImage = try cgImage(ciImage: ciImage, bits: bits)

        return try image(cgImage: cgImage)
        
        #else
        
        return UIImage(ciImage: ciImage)
        
        #endif
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
    
    public static func ciImage(texture: MTLTexture, colorSpace: TMColorSpace) throws -> CIImage {
        
        guard let ciImage = CIImage(mtlTexture: texture, options: [
            .colorSpace: colorSpace.linearCGColorSpace,
        ]) else {
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
    
    public static func cgImage(ciImage: CIImage, colorSpace: TMColorSpace? = nil, bits: TMBits? = nil) throws -> CGImage {
        
        let bits: TMBits = try bits ?? TMBits(ciImage: ciImage)
     
        guard let colorSpace = colorSpace?.cgColorSpace ?? ciImage.colorSpace else {
            throw TMError.ciImageColorSpaceNotFound
        }
        
        let context = CIContext(options: nil)
        
        guard let cgImage: CGImage = context.createCGImage(ciImage,
                                                           from: ciImage.extent,
                                                           format: bits.ciFormat,
                                                           colorSpace: colorSpace) else {
            #warning("Color Space must be RGB or Monochrome")
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

//
//  Created by Anton Heestand on 2021-10-15.
//

import Foundation
import MetalKit

public struct TextureMap {
    
    static let metalDevice: MTLDevice = {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("TextureMap: Default metal device not found.")
        }
        return metalDevice
    }()
}

// MARK: Errors

public extension TextureMap {
    
    enum TMError: LocalizedError {
        case cgImageNotFound
        case createCGImageFailed
        case createCIImageFailed
        case ciImageColorSpaceNotFound
        case tiffRepresentationNotFound
        case resolutionZero
        case resolutionTooHigh(maximum: Int)
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
            case .resolutionZero:
                return "Texture Map - Resolution Zero"
            case .resolutionTooHigh(let maximum):
                return "Texture Map - Resolution too High (Maximum: \(maximum))"
            case .makeTextureFailed:
                return "Texture Map - Make Texture Failed"
            case .bitmapDataNotFound:
                return "Texture Map - Bitmap Data Not Found"
            }
        }
    }
}

// MARK: Empty Texture

public extension TextureMap {
    
    enum TextureUsage {
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
    
    static func emptyTexture(resolution: CGSize, bits: TMBits, swapRedAndBlue: Bool = false, usage: TextureUsage = .renderTarget) async throws -> MTLTexture {
        
        try await withCheckedThrowingContinuation { continuation in
        
            DispatchQueue.global(qos: .userInteractive).async {
            
                do {
                
                    let texture = try emptyTexture(resolution: resolution, bits: bits, swapRedAndBlue: swapRedAndBlue, usage: usage)
                    
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
    
    static func emptyTexture(resolution: CGSize, bits: TMBits, swapRedAndBlue: Bool = false, usage: TextureUsage = .renderTarget) throws -> MTLTexture {
        
        guard resolution.width > 0 && resolution.height > 0 else {
            throw TMError.resolutionZero
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: bits.metalPixelFormat(swapRedAndBlue: swapRedAndBlue), width: Int(resolution.width), height: Int(resolution.height), mipmapped: true)
        
        descriptor.usage = usage.textureUsage
        
        guard let texture = metalDevice.makeTexture(descriptor: descriptor) else {
            throw TMError.makeTextureFailed
        }
        
        return texture
    }
    
    static func emptyTexture3d(resolution: SIMD3<Int>, bits: TMBits, usage: TextureUsage) throws -> MTLTexture {

        guard resolution.x > 0 && resolution.y > 0 && resolution.z > 0 else {
            throw TMError.resolutionZero
        }
        
        let maximum = 2048
        guard resolution.x <= maximum && resolution.y <= maximum && resolution.z <= maximum else {
            throw TMError.resolutionTooHigh(maximum: maximum)
        }

        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = bits.metalPixelFormat()
        descriptor.textureType = .type3D
        descriptor.width = resolution.x
        descriptor.height = resolution.y
        descriptor.depth = resolution.z
        descriptor.usage = usage.textureUsage

        guard let texture = metalDevice.makeTexture(descriptor: descriptor) else {
            throw TMError.makeTextureFailed
        }

        return texture
    }
}

// MARK: Texture

public extension TextureMap {
    
    static func texture(image: TMImage) throws -> MTLTexture {

        let cgImage: CGImage = try cgImage(image: image)

        return try texture(cgImage: cgImage)
    }
    
    static func texture(cgImage: CGImage) throws -> MTLTexture {

        let loader = MTKTextureLoader(device: metalDevice)

        let texture: MTLTexture = try loader.newTexture(cgImage: cgImage, options: nil)

        return texture
    }
    
    static func texture(ciImage: CIImage) throws -> MTLTexture {
        
        let cgImage: CGImage = try cgImage(ciImage: ciImage)
        
        return try texture(cgImage: cgImage)
    }
    
    #if os(macOS)
    static func texture(bitmap: NSBitmapImageRep) throws -> MTLTexture {
        
        guard let data: UnsafeMutablePointer<UInt8> = bitmap.bitmapData else {
            throw TMError.bitmapDataNotFound
        }
        
        let texture: MTLTexture = try emptyTexture(resolution: bitmap.size, bits: ._8)

        let region = MTLRegionMake2D(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh)

        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bitmap.bytesPerRow)
        
        return texture
    }
    #endif
}

// MARK: Image

public extension TextureMap {
    
    static func image(texture: MTLTexture, colorSpace: TMColorSpace, bits: TMBits) async throws -> TMImage {
        
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
    
    private static func image(texture: MTLTexture, colorSpace: TMColorSpace, bits: TMBits) throws -> TMImage {
                
        let ciImage: CIImage = try ciImage(texture: texture, colorSpace: colorSpace)
        
        let cgImage: CGImage = try cgImage(ciImage: ciImage, bits: bits)

        return try image(cgImage: cgImage)
    }
    
    static func image(cgImage: CGImage) throws -> TMImage {
        #if os(macOS)
        return NSImage(cgImage: cgImage, size: cgImage.size)
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }
    
    static func image(ciImage: CIImage) throws -> TMImage {
        #if os(macOS)
        let cgImage = try cgImage(ciImage: ciImage)
        
        return NSImage(cgImage: cgImage, size: ciImage.extent.size)
        #else
        return UIImage(ciImage: ciImage)
        #endif
    }
}

// MARK: CIImage

public extension TextureMap {
    
    static func ciImage(texture: MTLTexture, colorSpace: TMColorSpace) throws -> CIImage {
        
        guard let ciImage = CIImage(mtlTexture: texture, options: [
            .colorSpace: colorSpace.cgColorSpace
        ]) else {
            throw TMError.createCIImageFailed
        }
        
        return ciImage
    }
    
    static func ciImage(image: TMImage) throws -> CIImage {
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

public extension TextureMap {
    
    static func cgImage(texture: MTLTexture, colorSpace: TMColorSpace, bits: TMBits) throws -> CGImage {
        
        let ciImage = try ciImage(texture: texture, colorSpace: colorSpace)
        
        return try cgImage(ciImage: ciImage, colorSpace: colorSpace, bits: bits)
    }
    
    static func cgImage(ciImage: CIImage, colorSpace: TMColorSpace? = nil, bits: TMBits? = nil) throws -> CGImage {
        
        let bits: TMBits = try bits ?? TMBits(ciImage: ciImage)
     
        guard let cgColorSpace: CGColorSpace = colorSpace?.cgColorSpace ?? ciImage.colorSpace else {
            throw TMError.ciImageColorSpaceNotFound
        }
        
        let context = CIContext(options: nil)
        
        guard let cgImage: CGImage = context.createCGImage(ciImage,
                                                           from: ciImage.extent,
                                                           format: bits.ciFormat,
                                                           colorSpace: cgColorSpace) else {
            throw TMError.createCGImageFailed
        }
        
        return cgImage
    }
    
    static func cgImage(image: TMImage) throws -> CGImage {
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

// MARK: CVPixelBuffer

extension TextureMap {
    
    enum PixelBufferError: LocalizedError {
        
        case cvPixelBufferCreateFailed
        case cvPixelBufferLockBaseAddressFailed
        case cgContextFailed
        
        var errorDescription: String? {
            switch self {
            case .cvPixelBufferCreateFailed:
                return "TextureMap - Pixel Buffer - Create Failed"
            case .cvPixelBufferLockBaseAddressFailed:
                return "TextureMap - Pixel Buffer - Lock Base Address Failed"
            case .cgContextFailed:
                return "TextureMap - Pixel Buffer - Context Failed"
            }
        }
    }
    
    public static func pixelBuffer(texture: MTLTexture, colorSpace: TMColorSpace) throws -> CVPixelBuffer {
        
        let bits = try TMBits(texture: texture)

        let cgImage: CGImage = try cgImage(texture: texture, colorSpace: colorSpace, bits: bits)

        let pixelBuffer: CVPixelBuffer = try pixelBuffer(cgImage: cgImage, colorSpace: colorSpace, bits: bits)

        return pixelBuffer
    }
    
    public static func pixelBuffer(cgImage: CGImage, colorSpace: TMColorSpace, bits: TMBits) throws -> CVPixelBuffer {
        
        var optionalPixelBuffer: CVPixelBuffer?
        
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(bits.osType) as CFNumber,
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!,
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         cgImage.width,
                                         cgImage.height,
                                         bits.osType,
                                         attributes as CFDictionary,
                                         &optionalPixelBuffer)
        
        guard status == kCVReturnSuccess, let pixelBuffer = optionalPixelBuffer else {
            throw PixelBufferError.cvPixelBufferCreateFailed
        }
        
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, flags) else {
            throw PixelBufferError.cvPixelBufferLockBaseAddressFailed
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, flags) }
        
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                      width: cgImage.width,
                                      height: cgImage.height,
                                      bitsPerComponent: bits.rawValue,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: colorSpace.cgColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw PixelBufferError.cgContextFailed
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        return pixelBuffer
    }
}

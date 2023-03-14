//
//  Created by Anton Heestand on 2021-10-15.
//

import Foundation
import VideoToolbox
import MetalKit

public struct TextureMap {
    
    static let metalDevice: MTLDevice = {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("TextureMap: Default metal device not found.")
        }
        return metalDevice
    }()
}

// MARK: Texture

public extension TextureMap {
    
    enum TextureError: LocalizedError {
        
        case vtCreateCGImageFromCVPixelBufferFailed
        case cmSampleBufferGetImageBufferFailed
        
        public var errorDescription: String? {
            switch self {
            case .vtCreateCGImageFromCVPixelBufferFailed:
                return "TextureMap - Texture - VT Create CGImage from CVPixelBuffer Failed"
            case .cmSampleBufferGetImageBufferFailed:
                return "TextureMap - Texture - CMSampleBuffer Get Image Buffer Failed"
            }
        }
    }
    
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
        
        let texture: MTLTexture = try .empty(resolution: bitmap.size, bits: ._8)

        let region = MTLRegionMake2D(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh)

        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: bitmap.bytesPerRow)
        
        return texture
    }
    #endif
    
    static func texture(sampleBuffer: CMSampleBuffer) throws -> MTLTexture {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { throw TextureError.cmSampleBufferGetImageBufferFailed }
        return try texture(pixelBuffer: pixelBuffer)
    }
    
    static func texture(pixelBuffer: CVPixelBuffer) throws -> MTLTexture {
        var cgImage: CGImage!
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        if cgImage == nil {
            throw TextureError.vtCreateCGImageFromCVPixelBufferFailed
        }
        return try texture(cgImage: cgImage)
    }
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
        
        let cgImage: CGImage = try cgImage(ciImage: ciImage, colorSpace: colorSpace, bits: bits)

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
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
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
     
        guard let cgColorSpace: CGColorSpace = colorSpace?.coloredCGColorSpace ?? ciImage.colorSpace else {
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

// MARK: CMSampleBuffer


extension TextureMap {
    
    enum SampleBufferError: LocalizedError {
        
        case failedToCreateSampleBuffer(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .failedToCreateSampleBuffer(let osStatus):
                return "TextureMap - Sample Buffer - Failed to Create (OSStatus: \(osStatus))"
            }
        }
    }
    
    public static func sampleBuffer(texture: MTLTexture, colorSpace: TMColorSpace) throws -> CMSampleBuffer {
        
        let pixelBuffer: CVPixelBuffer = try pixelBuffer(texture: texture, colorSpace: colorSpace)
        
        var sampleBuffer: CMSampleBuffer?
        
        var timingInfo = CMSampleTimingInfo()
        var formatDescription: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &formatDescription)
        
        let osStatus: OSStatus = CMSampleBufferCreateReadyWithImageBuffer(
          allocator: kCFAllocatorDefault,
          imageBuffer: pixelBuffer,
          formatDescription: formatDescription!,
          sampleTiming: &timingInfo,
          sampleBufferOut: &sampleBuffer
        )
        
        guard let sampleBuffer else {
            throw SampleBufferError.failedToCreateSampleBuffer(osStatus)
        }
        
        return sampleBuffer
    }
}

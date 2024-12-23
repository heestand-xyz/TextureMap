//
//  Created by Anton Heestand on 2022-04-01.
//

import Spatial
import CoreGraphics
import Metal
import MetalPerformanceShaders

// MARK: - Image

extension MTLTexture {
    
    public func image(colorSpace: TMColorSpace, bits: TMBits) async throws -> TMImage {
        try TextureMap.image(texture: self, colorSpace: colorSpace, bits: bits)
    }
}

// MARK: - Color Space

extension MTLTexture {
    
    public func convertColorSpace(from fromColorSpace: CGColorSpace, to toColorSpace: CGColorSpace) async throws -> MTLTexture {
        
        let conversionInfo = CGColorConversionInfo(src: fromColorSpace, dst: toColorSpace)
        
        let conversion = MPSImageConversion(device: device,
                                            srcAlpha: .premultiplied,
                                            destAlpha: .premultiplied,
                                            backgroundColor: nil,
                                            conversionInfo: conversionInfo)
        
        guard let commandQueue = TextureMap.metalDevice.makeCommandQueue() else {
            throw TMError.makeCommandQueueFailed
        }
        
        guard let commandBuffer: MTLCommandBuffer = commandQueue.makeCommandBuffer() else {
            throw TMError.makeCommandBufferFailed
        }
        
        let resolution = CGSize(width: width, height: height)
        let bits = try TMBits(texture: self)
        let targetTexture: MTLTexture = try .empty(resolution: resolution, bits: bits, usage: .write)

        conversion.encode(commandBuffer: commandBuffer, sourceTexture: self, destinationTexture: targetTexture)
        
        let _: Void = await withCheckedContinuation { continuation in
            
            commandBuffer.addCompletedHandler { _ in
                
                continuation.resume()
            }
            
            commandBuffer.commit()
        }
        
        return targetTexture
    }
}

// MARK: Empty Texture

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

extension MTLTexture where Self == MTLTexture {
    
    // 2D
    public static func empty(resolution: CGSize, bits: TMBits, sampleCount: Int = 1, swapRedAndBlue: Bool = false, usage: TextureUsage = .renderTarget) throws -> MTLTexture {
        
        guard resolution.width >= 1,
              resolution.height >= 1 else {
            throw TMError.resolutionZero
        }
        
        guard resolution.width <= 16_384,
              resolution.height <= 16_384 else {
            throw TMError.resolutionTooHigh(maximum: 16_384)
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: bits.metalPixelFormat(swapRedAndBlue: swapRedAndBlue), width: Int(resolution.width), height: Int(resolution.height), mipmapped: sampleCount == 1)
        
        descriptor.usage = usage.textureUsage
        descriptor.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
        descriptor.sampleCount = sampleCount
        
        guard let texture = TextureMap.metalDevice.makeTexture(descriptor: descriptor) else {
            throw TMError.makeTextureFailed
        }
        
        return texture
    }
    
    // 3D
    public static func empty3d(resolution: Size3D, bits: TMBits, usage: TextureUsage) throws -> MTLTexture {
        
        let width = Int(resolution.width)
        let height = Int(resolution.height)
        let depth = Int(resolution.depth)
        
        guard width > 0 && height > 0 && depth > 0 else {
            throw TMError.resolutionZero
        }
        
        let maximum = 2048
        guard width <= maximum && height <= maximum && depth <= maximum else {
            throw TMError.resolutionTooHigh(maximum: maximum)
        }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = bits.metalPixelFormat()
        descriptor.textureType = .type3D
        descriptor.width = width
        descriptor.height = height
        descriptor.depth = depth
        descriptor.usage = usage.textureUsage
        
        guard let texture = TextureMap.metalDevice.makeTexture(descriptor: descriptor) else {
            throw TMError.makeTextureFailed
        }
        
        return texture
    }
}

// MARK: - Copy

extension MTLTexture {
    
    public func copy() async throws -> MTLTexture {
        
        let bits = try TMBits(texture: self)
        
        let textureCopy: MTLTexture = try .empty(resolution: CGSize(width: width, height: height), bits: bits)
        
        guard let commandQueue = TextureMap.metalDevice.makeCommandQueue() else {
            throw TMError.makeCommandQueueFailed
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TMError.makeCommandBufferFailed
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TMError.makeBlitCommandEncoderFailed
        }
        
        blitEncoder.copy(from: self, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: width, height: height, depth: 1), to: textureCopy, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))

        blitEncoder.endEncoding()

        let _: Void = await withCheckedContinuation { continuation in
            
            commandBuffer.addCompletedHandler { _ in
                
                continuation.resume()
            }
            
            commandBuffer.commit()
        }
        
        return textureCopy
    }
    
    public func copy(to texture: MTLTexture) async throws {
                        
        guard let commandQueue = TextureMap.metalDevice.makeCommandQueue() else {
            throw TMError.makeCommandQueueFailed
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TMError.makeCommandBufferFailed
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TMError.makeBlitCommandEncoderFailed
        }
        
        blitEncoder.copy(from: self, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: width, height: height, depth: 1), to: texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        
        blitEncoder.endEncoding()
        
        let _: Void = await withCheckedContinuation { continuation in
            
            commandBuffer.addCompletedHandler { _ in
                
                continuation.resume()
            }
            
            commandBuffer.commit()
        }
    }
}

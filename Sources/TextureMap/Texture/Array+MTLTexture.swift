//
//  Created by Anton Heestand on 2022-04-12.
//

import Foundation
import Metal

public enum TMTextureArrayType {
    
    case type3D
    case typeArray
    
    var textureType: MTLTextureType {
        switch self {
        case .type3D:
            return .type3D
        case .typeArray:
            return .type2DArray
        }
    }
}

enum TMTextureArrayError: LocalizedError {
    
    case empty
    case differentResolutions
    case makeCommandQueueFailed
    case makeCommandBufferFailed
    case makeBlitCommandEncoderFailed
    case makeTextureFailed
    
    var errorDescription: String? {
        switch self {
        case .empty:
            return "Texture Map - Texture Array - Empty"
        case .differentResolutions:
            return "Texture Map - Texture Array - Different Resolutions"
        case .makeCommandQueueFailed:
            return "Texture Map - Texture Array - Make Command Queue Failed"
        case .makeCommandBufferFailed:
            return "Texture Map - Texture Array - Make Command Buffer Failed"
        case .makeBlitCommandEncoderFailed:
            return "Texture Map - Texture Array - Make Blit Command Encoder Failed"
        case .makeTextureFailed:
            return "Texture Map - Texture Array - Make Texture Failed"
        }
    }
}

public extension Array where Element == MTLTexture {
    
    func texture(type: TMTextureArrayType) async throws -> MTLTexture {
        
        guard !isEmpty else {
            throw TMTextureArrayError.empty
        }
        
        let width = first!.width
        let height = first!.height
        guard filter({ texture -> Bool in
            texture.width == width && texture.height == height
        }).count == count else {
            throw TMTextureArrayError.differentResolutions
        }
        
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = first!.pixelFormat
        descriptor.textureType = type.textureType
        descriptor.width = width
        descriptor.height = height
        descriptor.mipmapLevelCount = first?.mipmapLevelCount ?? 1
        switch type {
        case .type3D:
            descriptor.depth = count
        case .typeArray:
            descriptor.arrayLength = count
        }
        
        guard let commandQueue: MTLCommandQueue = TextureMap.metalDevice.makeCommandQueue() else {
            throw TMTextureArrayError.makeCommandQueueFailed
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TMTextureArrayError.makeCommandBufferFailed
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TMTextureArrayError.makeBlitCommandEncoderFailed
        }
        
        guard let multiTexture = TextureMap.metalDevice.makeTexture(descriptor: descriptor) else {
            throw TMTextureArrayError.makeTextureFailed
        }
        
        for (i, texture) in enumerated() {
            blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1), to: multiTexture, destinationSlice: type == .type3D ? 0 : i, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: type == .type3D ? i : 0))
        }
        
        blitEncoder.endEncoding()
        
        let _: Void = await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
            commandBuffer.commit()
        }
        
        return multiTexture
    }
}

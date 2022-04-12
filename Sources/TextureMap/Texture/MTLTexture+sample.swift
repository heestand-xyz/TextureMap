//
//  Created by Anton Heestand on 2022-04-11.
//

import Metal

enum TMSampleError: LocalizedError {
    
    case makeCommandQueueFailed
    case makeCommandBufferFailed
    case makeBlitCommandEncoderFailed
    
    public var errorDescription: String? {
        switch self {
        case .makeCommandQueueFailed:
            return "Texture Map - Sample - Make Command Queue Failed"
        case .makeCommandBufferFailed:
            return "Texture Map - Sample - Make Command Buffer Failed"
        case .makeBlitCommandEncoderFailed:
            return "Texture Map - Sample - Make Blit Command Encoder Failed"
        }
    }
}

public extension MTLTexture {
    
    func sample3d(index: Int, axis: TMAxis, bits: TMBits) async throws -> MTLTexture {
        
        let resolution: CGSize = CGSize(width: axis == .x ? depth : width,
                                        height: axis == .y ? depth : height)
        
        guard let commandQueue: MTLCommandQueue = TextureMap.metalDevice.makeCommandQueue() else {
            throw TMSampleError.makeCommandQueueFailed
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TMSampleError.makeCommandBufferFailed
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TMSampleError.makeBlitCommandEncoderFailed
        }
        
        let targetTexture: MTLTexture = try await TextureMap.emptyTexture(resolution: resolution, bits: bits)
        
        let sourceOrigin = MTLOrigin(x: axis == .x ? index : 0,
                                     y: axis == .y ? index : 0,
                                     z: axis == .z ? index : 0)
        
        let sourceSize = MTLSize(width: axis == .x ? 1 : width,
                                 height: axis == .y ? 1 : height,
                                 depth: axis == .z ? 1 : depth)
        
        let destinationOrigin = MTLOrigin(x: 0, y: 0, z: 0)
        
        blitEncoder.copy(from: self,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: sourceOrigin,
                         sourceSize: sourceSize,
                         to: targetTexture,
                         destinationSlice: 0,
                         destinationLevel: 0,
                         destinationOrigin: destinationOrigin)
        
        blitEncoder.endEncoding()
        
        let _: Void = await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
            commandBuffer.commit()
        }
        
        return targetTexture
    }
}
//
//  Created by Anton Heestand on 2022-04-01.
//

import CoreGraphics
import Metal
import MetalPerformanceShaders

extension MTLTexture {
    
    public func image(colorSpace: TMColorSpace, bits: TMBits) async throws -> TMImage {
        try await TextureMap.image(texture: self, colorSpace: colorSpace, bits: bits)
    }
}

enum TMTextureError: LocalizedError {
    
    case makeCommandQueueFailed
    case makeCommandBufferFailed
    
    var errorDescription: String? {
        switch self {
        case .makeCommandQueueFailed:
            return "Texture Map - Texture Array - Make Command Queue Failed"
        case .makeCommandBufferFailed:
            return "Texture Map - Texture Array - Make Command Buffer Failed"
        }
    }
}

extension MTLTexture {
    
    public func convertColorSpace(from fromColorSpace: CGColorSpace, to toColorSpace: CGColorSpace) async throws -> MTLTexture {
        
        let conversionInfo = CGColorConversionInfo(src: fromColorSpace, dst: toColorSpace)
        
        let conversion = MPSImageConversion(device: device,
                                            srcAlpha: .premultiplied,
                                            destAlpha: .premultiplied,
                                            backgroundColor: nil,
                                            conversionInfo: conversionInfo)
        
        guard let commandQueue = TextureMap.metalDevice.makeCommandQueue() else {
            throw TMTextureError.makeCommandQueueFailed
        }
        
        guard let commandBuffer: MTLCommandBuffer = commandQueue.makeCommandBuffer() else {
            throw TMTextureError.makeCommandBufferFailed
        }
        
        let resolution = CGSize(width: width, height: height)
        let bits = try TMBits(texture: self)
        let targetTexture: MTLTexture = try await TextureMap.emptyTexture(resolution: resolution, bits: bits, usage: .write)

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

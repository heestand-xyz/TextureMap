////
////  Created by Anton Heestand on 2022-08-05.
////
//
//import Metal
//
//enum TMTextureConvertError: LocalizedError {
//
//    case textureIsNotMultiSampled
//    case makeCommandQueueFailed
//    case makeCommandBufferFailed
//    case makeBlitCommandEncoderFailed
//    case makeTextureFailed
//
//    public var errorDescription: String? {
//        switch self {
//        case .textureIsNotMultiSampled:
//            return "Texture Map - Texture Convert - Texture is Not Multi Sampled"
//        case .makeCommandQueueFailed:
//            return "Texture Map - Texture Convert - Make Command Queue Failed"
//        case .makeCommandBufferFailed:
//            return "Texture Map - Texture Convert - Make Command Buffer Failed"
//        case .makeBlitCommandEncoderFailed:
//            return "Texture Map - Texture Convert - Make Blit Command Encoder Failed"
//        case .makeTextureFailed:
//            return "Texture Map - Texture Convert - Make Texture Failed"
//        }
//    }
//}
//
//extension MTLTexture {
//
//    public func convertFromMultiSampled() async throws -> MTLTexture {
//
//        guard textureType == .type2DMultisample else {
//            throw TMTextureConvertError.textureIsNotMultiSampled
//        }
//
//        let descriptor = MTLTextureDescriptor()
//        descriptor.pixelFormat = pixelFormat
//        descriptor.textureType = .type2D
//        descriptor.width = width
//        descriptor.height = height
//
//        guard let commandQueue: MTLCommandQueue = TextureMap.metalDevice.makeCommandQueue() else {
//            throw TMTextureConvertError.makeCommandQueueFailed
//        }
//
//        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
//            throw TMTextureConvertError.makeCommandBufferFailed
//        }
//
//        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
//            throw TMTextureConvertError.makeBlitCommandEncoderFailed
//        }
//
//        guard let texture = TextureMap.metalDevice.makeTexture(descriptor: descriptor) else {
//            throw TMTextureConvertError.makeTextureFailed
//        }
//
//        blitEncoder.copy(from: self, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0), sourceSize: MTLSize(width: width, height: height, depth: 1), to: texture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
//
//        blitEncoder.endEncoding()
//
//        let _: Void = await withCheckedContinuation { continuation in
//            commandBuffer.addCompletedHandler { _ in
//                continuation.resume()
//            }
//            commandBuffer.commit()
//        }
//
//        return texture
//    }
//}

//
//  Created by Anton Heestand on 2022-04-02.
//

import Foundation
import CoreGraphics
import MetalKit

public extension TextureMap {
    
    enum TMRawError: LocalizedError {
        
        case unsupportedBits(TMBits)
        case unsupportedOS
        case unsupportedOSVersion
        case failedToMakeCommandBuffer
        case failedToMakeBuffer
        case failedToMakeCommandEncoder

        public var errorDescription: String? {
            switch self {
            case .unsupportedBits(let bits):
                return "Texture Map - Raw - Unsupported Bits (\(bits.rawValue))"
            case .unsupportedOS:
                return "Texture Map - Raw - Unsupported OS"
            case .unsupportedOSVersion:
                return "Texture Map - Raw - Unsupported OS Version"
            case .failedToMakeCommandBuffer:
                return "Texture Map - Raw - Failed to Make Command Buffer"
            case .failedToMakeBuffer:
                return "Texture Map - Raw - Failed to Make Buffer"
            case .failedToMakeCommandEncoder:
                return "Texture Map - Raw - Failed to Make Command Encoder"
            }
        }
    }
    
    static func texture(raw: UnsafeMutablePointer<UInt8>, size: CGSize, on device: MTLDevice) throws -> MTLTexture {
        let bytesPerRow: Int = Int(size.width) * 4
        let capacity: Int = bytesPerRow * Int(size.height)
        let texture = try emptyTexture(size: size, bits: ._8)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(size.width),
                                             height: Int(size.height),
                                             depth: 1))
        raw.withMemoryRebound(to: UInt8.self, capacity: capacity) { rawPointer in
            texture.replace(region: region, mipmapLevel: 0, withBytes: rawPointer, bytesPerRow: bytesPerRow)
        }
        return texture
    }
    
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
    static func texture(raw: UnsafeMutablePointer<Float16>, size: CGSize, on device: MTLDevice) throws -> MTLTexture {
        let bytesPerRow: Int = Int(size.width) * 4
        let capacity: Int = bytesPerRow * Int(size.height)
        let texture = try emptyTexture(size: size, bits: ._16)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(size.width),
                                             height: Int(size.height),
                                             depth: 1))
        raw.withMemoryRebound(to: Float16.self, capacity: capacity) { rawPointer in
            texture.replace(region: region, mipmapLevel: 0, withBytes: rawPointer, bytesPerRow: bytesPerRow)
        }
        return texture
    }
    
    static func raw8(texture: MTLTexture) throws -> [UInt8] {
        let bits = try TMBits(texture: texture)
        guard bits == ._8 else {
            throw TMRawError.unsupportedBits(bits)
        }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<UInt8>(repeating: 0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    static func rawCopy8(texture: MTLTexture, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [UInt8] {
        let bits = try TMBits(texture: texture)
        guard bits == ._8 else {
            throw TMRawError.unsupportedBits(bits)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TMRawError.failedToMakeCommandBuffer
        }
        let bytesPerTexture = MemoryLayout<UInt8>.size * texture.width * texture.height * 4
        let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
        guard let imageBuffer = metalDevice.makeBuffer(length: bytesPerTexture, options: []) else {
            throw TMRawError.failedToMakeBuffer
        }
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TMRawError.failedToMakeCommandEncoder
        }
        blitEncoder.copy(from: texture,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: texture.width, height: texture.height, depth: 1),
                         to: imageBuffer,
                         destinationOffset: 0,
                         destinationBytesPerRow: bytesPerRow,
                         destinationBytesPerImage: 0)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        var raw = Array<UInt8>(repeating: 0, count: texture.width * texture.height * 4)
        memcpy(&raw, imageBuffer.contents(), imageBuffer.length)
        return raw
    }
    
    static func raw3d8(texture: MTLTexture) throws -> [UInt8] {
        let bits = try TMBits(texture: texture)
        guard bits == ._8 else {
            throw TMRawError.unsupportedBits(bits)
        }
        let region = MTLRegionMake3D(0, 0, 0, texture.width, texture.height, texture.depth)
        var raw = Array<UInt8>(repeating: 0, count: texture.width * texture.height * texture.depth * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
            let bytesPerImage = MemoryLayout<UInt8>.size * texture.width * texture.height * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)
        }
        return raw
    }
    
    static func rawCopy3d8(texture: MTLTexture, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [UInt8] {
        let bits = try TMBits(texture: texture)
        guard bits == ._8 else {
            throw TMRawError.unsupportedBits(bits)
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw TMRawError.failedToMakeCommandBuffer
        }
        let bytesPerTexture = MemoryLayout<UInt8>.size * texture.width * texture.height * texture.depth * 4
        let bytesPerGrid = MemoryLayout<UInt8>.size * texture.width * texture.height * 4
        let bytesPerRow = MemoryLayout<UInt8>.size * texture.width * 4
        guard let imageBuffer = metalDevice.makeBuffer(length: bytesPerTexture, options: []) else {
            throw TMRawError.failedToMakeBuffer
        }
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            throw TMRawError.failedToMakeCommandEncoder
        }
        blitEncoder.copy(from: texture,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: texture.width,
                                             height: texture.height,
                                             depth: texture.depth),
                         to: imageBuffer,
                         destinationOffset: 0,
                         destinationBytesPerRow: bytesPerRow,
                         destinationBytesPerImage: bytesPerGrid)
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        var raw = Array<UInt8>(repeating: 0, count: texture.width * texture.height * texture.depth * 4)
        memcpy(&raw, imageBuffer.contents(), imageBuffer.length)
        return raw
    }
    
//    #if !os(macOS) && !targetEnvironment(macCatalyst)
    
    @available(iOS 14.0, *)
    @available(tvOS 14.0, *)
    @available(macOS 11.0, *)
    static func raw16(texture: MTLTexture) throws -> [Float16] {
        let bits = try TMBits(texture: texture)
        guard bits == ._16 else {
            throw TMRawError.unsupportedBits(bits)
        }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<Float16>(repeating: -1.0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float16>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    @available(iOS 14.0, *)
    @available(tvOS 14.0, *)
    @available(macOS 11.0, *)
    static func raw3d16(texture: MTLTexture) throws -> [Float16] {
        let bits = try TMBits(texture: texture)
        guard bits == ._16 else {
            throw TMRawError.unsupportedBits(bits)
        }
        let region = MTLRegionMake3D(0, 0, 0, texture.width, texture.height, texture.depth)
        var raw = Array<Float16>(repeating: -1.0, count: texture.width * texture.height * texture.depth * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float16>.size * texture.width * 4
            let bytesPerImage = MemoryLayout<Float16>.size * texture.width * texture.height * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)
        }
        return raw
    }
    
//    #endif
    
    static func raw32(texture: MTLTexture) throws -> [Float] {
//        let bits = try TMBits(texture: texture)
//        guard bits == ._32 else {
//            throw TMRawError.unsupportedBits(bits)
//        }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<Float>(repeating: -1.0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    static func raw3d32(texture: MTLTexture) throws -> [Float] {
//        let bits = try TMBits(texture: texture)
//        guard bits == ._32 else {
//            throw TMRawError.unsupportedBits(bits)
//        }
        let region = MTLRegionMake3D(0, 0, 0, texture.width, texture.height, texture.depth)
        var raw = Array<Float>(repeating: -1.0, count: texture.width * texture.height * texture.depth * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float>.size * texture.width * 4
            let bytesPerImage = MemoryLayout<Float>.size * texture.width * texture.height * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)
        }
        return raw
    }
    
    static func rawNormalized(texture: MTLTexture, bits: TMBits) async throws -> [CGFloat] {
        
        try await withCheckedThrowingContinuation { continuation in
            
            DispatchQueue.global(qos: .userInteractive).async {
                
                do {
                    
                    let channels = try rawNormalized(texture: texture, bits: bits)
                    
                    DispatchQueue.main.async {
                        continuation.resume(returning: channels)
                    }
                    
                } catch {
                    
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    static func rawNormalized(texture: MTLTexture, bits: TMBits) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try raw8(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
        case ._16:
//            #if !os(macOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 14.0, tvOS 14.0, macOS 11.0, *) {
                raw = try raw16(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
            } else {
                throw TMRawError.unsupportedOSVersion
            }
//            #else
//            throw TMRawError.unsupportedOS
//            #endif
//        case ._32:
//            raw = try raw32(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
        }
        return raw
    }
    
    static func rawNormalizedCopy(texture: MTLTexture, bits: TMBits, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try rawCopy8(texture: texture, on: metalDevice, in: commandQueue).map({ chan -> CGFloat in
                return CGFloat(chan) / (pow(2, 8) - 1)
            })
        default:
            throw TMRawError.unsupportedBits(bits)
        }
        return raw
    }
    
    static func rawNormalized3d(texture: MTLTexture, bits: TMBits) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try raw3d8(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
        case ._16:
//            #if !os(macOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 14.0, tvOS 14.0, macOS 11.0, *) {
                raw = try raw3d16(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
            } else {
                throw TMRawError.unsupportedOSVersion
            }
//            #else
//            throw TMRawError.unsupportedOS
//            #endif
//        case ._32:
//            raw = try raw3d32(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
        }
        return raw
    }
    
    static func rawNormalizedCopy3d(texture: MTLTexture, bits: TMBits, on metalDevice: MTLDevice, in commandQueue: MTLCommandQueue) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try rawCopy3d8(texture: texture, on: metalDevice, in: commandQueue).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
//        case ._16:
//            raw = try rawCopy3d16(texture: texture, on: metalDevice, in: commandQueue).map({ chan -> CGFloat in return CGFloat(chan) })
        default:
            throw TMRawError.unsupportedBits(bits)
        }
        return raw
    }
}

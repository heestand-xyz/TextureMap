//
//  Created by Anton Heestand on 2022-04-02.
//

import Foundation
import Spatial
import CoreGraphics
import MetalKit

public extension TextureMap {
    
    enum TMRawError: LocalizedError {
        
        case badResolution
        case unsupportedBits(TMBits)
        case unsupportedOS
        case unsupportedOSVersion
        case failedToMakeCommandBuffer
        case failedToMakeBuffer
        case failedToMakeCommandEncoder
        
        public var errorDescription: String? {
            switch self {
            case .badResolution:
                return "Texture Map - Raw - Bad Resolution"
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
}

// MARK: - Raw to Texture

public extension TextureMap {
    
    /// 2D
    static func texture(channels: [UInt8], resolution: CGSize, on device: MTLDevice) throws -> MTLTexture {
        let count: Int = channels.count
        guard count == Int(resolution.width) * Int(resolution.height) * 4 else {
            throw TMRawError.badResolution
        }
        var channels: [UInt8] = channels
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        pointer.initialize(from: &channels, count: count)
        return try texture(raw: pointer, resolution: resolution, on: device)
    }
    
    /// 3D
    static func texture3d(channels: [UInt8], resolution: Size3D, on device: MTLDevice) throws -> MTLTexture {
        let count: Int = channels.count
        guard count == Int(resolution.width) * Int(resolution.height) * Int(resolution.depth) * 4 else {
            throw TMRawError.badResolution
        }
        var channels: [UInt8] = channels
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
        pointer.initialize(from: &channels, count: count)
        return try texture3d(raw: pointer, resolution: resolution, on: device)
    }
    
    /// 2D
    static func texture(raw: UnsafePointer<UInt8>, resolution: CGSize, on device: MTLDevice) throws -> MTLTexture {
        guard resolution.width > 0 && resolution.height > 0 else {
            throw TMRawError.badResolution
        }
        let bytesPerRow: Int = Int(resolution.width) * 4
        let capacity: Int = bytesPerRow * Int(resolution.height)
        let texture: MTLTexture = try .empty(resolution: resolution, bits: ._8)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(resolution.width),
                                             height: Int(resolution.height),
                                             depth: 1))
        raw.withMemoryRebound(to: UInt8.self, capacity: capacity) { rawPointer in
            texture.replace(region: region, mipmapLevel: 0, withBytes: rawPointer, bytesPerRow: bytesPerRow)
        }
        return texture
    }
    
    /// 3D
    static func texture3d(raw: UnsafePointer<UInt8>, resolution: Size3D, on device: MTLDevice) throws -> MTLTexture {
        guard resolution.width > 0 && resolution.height > 0 && resolution.depth > 0 else {
            throw TMRawError.badResolution
        }
        let bytesPerRow: Int = Int(resolution.width) * 4
        let bytesPerImage: Int = Int(resolution.width) * Int(resolution.height) * 4
        let capacity: Int = bytesPerImage * Int(resolution.depth)
        let texture: MTLTexture = try .empty3d(resolution: resolution, bits: ._8, usage: .write)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(resolution.width),
                                             height: Int(resolution.height),
                                             depth: Int(resolution.depth)))
        raw.withMemoryRebound(to: UInt8.self, capacity: capacity) { rawPointer in
            texture.replace(region: region, mipmapLevel: 0, slice: 0, withBytes: rawPointer, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage)
        }
        return texture
    }
    
    #if !os(macOS)
    
    /// 2D
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
    static func texture(channels: [Float16], resolution: CGSize, on device: MTLDevice) throws -> MTLTexture {
        let count: Int = channels.count
        guard count == Int(resolution.width) * Int(resolution.height) * 4 else {
            throw TMRawError.badResolution
        }
        var channels: [Float16] = channels
        let pointer = UnsafeMutablePointer<Float16>.allocate(capacity: count)
        pointer.initialize(from: &channels, count: count)
        return try texture(raw: pointer, resolution: resolution, on: device)
    }
    
    /// 3D
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
    static func texture3d(channels: [Float16], resolution: Size3D, on device: MTLDevice) throws -> MTLTexture {
        let count: Int = channels.count
        guard count == Int(resolution.width) * Int(resolution.height) * Int(resolution.depth) * 4 else {
            throw TMRawError.badResolution
        }
        var channels: [Float16] = channels
        let pointer = UnsafeMutablePointer<Float16>.allocate(capacity: count)
        pointer.initialize(from: &channels, count: count)
        return try texture3d(raw: pointer, resolution: resolution, on: device)
    }
    
    /// 2D
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
    static func texture(raw: UnsafePointer<Float16>, resolution: CGSize, on device: MTLDevice) throws -> MTLTexture {
        let bytesPerRow: Int = Int(resolution.width) * 4 * 2
        let capacity: Int = bytesPerRow * Int(resolution.height)
        let texture: MTLTexture = try .empty(resolution: resolution, bits: ._16)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(resolution.width),
                                             height: Int(resolution.height),
                                             depth: 1))
        raw.withMemoryRebound(to: Float16.self, capacity: capacity) { rawPointer in
            texture.replace(region: region, mipmapLevel: 0, withBytes: rawPointer, bytesPerRow: bytesPerRow)
        }
        return texture
    }
    
    /// 3D
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
    static func texture3d(raw: UnsafePointer<Float16>, resolution: Size3D, on device: MTLDevice) throws -> MTLTexture {
        let bytesPerRow: Int = Int(resolution.width) * 4 * 2
        let bytesPerImage: Int = Int(resolution.width) * Int(resolution.height) * 4 * 2
        let capacity: Int = bytesPerImage * Int(resolution.depth)
        let texture: MTLTexture = try .empty3d(resolution: resolution, bits: ._8, usage: .write)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(resolution.width),
                                             height: Int(resolution.height),
                                             depth: Int(resolution.depth)))
        raw.withMemoryRebound(to: Float16.self, capacity: capacity) { rawPointer in
            texture.replace(region: region, mipmapLevel: 0, slice: 0, withBytes: rawPointer, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage)
        }
        return texture
    }
    
    #endif
    
    /// 2D
    static func texture(channels: [Float], resolution: CGSize, on device: MTLDevice) throws -> MTLTexture {
        let count: Int = channels.count
        guard count == Int(resolution.width) * Int(resolution.height) * 4 else {
            throw TMRawError.badResolution
        }
        var channels: [Float] = channels
        let pointer = UnsafeMutablePointer<Float>.allocate(capacity: count)
        pointer.initialize(from: &channels, count: count)
        return try texture(raw: pointer, resolution: resolution, on: device)
    }
    
    /// 3D
    static func texture3d(channels: [Float], resolution: Size3D, on device: MTLDevice) throws -> MTLTexture {
        let count: Int = channels.count
        guard count == Int(resolution.width) * Int(resolution.height) * Int(resolution.depth) * 4 else {
            throw TMRawError.badResolution
        }
        var channels: [Float] = channels
        let pointer = UnsafeMutablePointer<Float>.allocate(capacity: count)
        pointer.initialize(from: &channels, count: count)
        return try texture3d(raw: pointer, resolution: resolution, on: device)
    }
    
    /// 2D
    static func texture(raw: UnsafePointer<Float>, resolution: CGSize, on device: MTLDevice) throws -> MTLTexture {
        let bytesPerRow: Int = Int(resolution.width) * 4 * 4
        let capacity: Int = bytesPerRow * Int(resolution.height)
        let texture: MTLTexture = try .empty(resolution: resolution, bits: ._32)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(resolution.width),
                                             height: Int(resolution.height),
                                             depth: 1))
        raw.withMemoryRebound(to: Float.self, capacity: capacity) { rawPointer in
            texture.replace(region: region, mipmapLevel: 0, withBytes: rawPointer, bytesPerRow: bytesPerRow)
        }
        return texture
    }
    
    /// 3D
    static func texture3d(raw: UnsafePointer<Float>, resolution: Size3D, on device: MTLDevice) throws -> MTLTexture {
        let bytesPerRow: Int = Int(resolution.width) * 4 * 4
        let bytesPerImage: Int = Int(resolution.width) * Int(resolution.height) * 4 * 4
        let capacity: Int = bytesPerImage * Int(resolution.depth)
        let texture: MTLTexture = try .empty3d(resolution: resolution, bits: ._32, usage: .write)
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: Int(resolution.width),
                                             height: Int(resolution.height),
                                             depth: Int(resolution.depth)))
        raw.withMemoryRebound(to: Float.self, capacity: capacity) { rawPointer in
            texture.replace(region: region, mipmapLevel: 0, slice: 0, withBytes: rawPointer, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage)
        }
        return texture
    }
}

// MARK: - Texture to Raw

public extension TextureMap {
    
    /// 2D
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
    
    /// 2D
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
    
    /// 3D
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
    
    /// 3D
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
    
    #if !os(macOS)
    
    /// 2D
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
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

    /// 3D
    @available(iOS 14.0, tvOS 14.0, macOS 11.0, *)
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
    
    #endif
    
    /// 2D
    static func raw32(texture: MTLTexture) throws -> [Float] {
        let bits = try TMBits(texture: texture)
        guard bits == ._32 else {
            throw TMRawError.unsupportedBits(bits)
        }
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        var raw = Array<Float>(repeating: -1.0, count: texture.width * texture.height * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float>.size * texture.width * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return raw
    }
    
    /// 3D
    static func raw3d32(texture: MTLTexture) throws -> [Float] {
        let bits = try TMBits(texture: texture)
        guard bits == ._32 else {
            throw TMRawError.unsupportedBits(bits)
        }
        let region = MTLRegionMake3D(0, 0, 0, texture.width, texture.height, texture.depth)
        var raw = Array<Float>(repeating: -1.0, count: texture.width * texture.height * texture.depth * 4)
        raw.withUnsafeMutableBytes {
            let bytesPerRow = MemoryLayout<Float>.size * texture.width * 4
            let bytesPerImage = MemoryLayout<Float>.size * texture.width * texture.height * 4
            texture.getBytes($0.baseAddress!, bytesPerRow: bytesPerRow, bytesPerImage: bytesPerImage, from: region, mipmapLevel: 0, slice: 0)
        }
        return raw
    }
    
    /// 2D
    static func rawNormalized(texture: MTLTexture, bits: TMBits) async throws -> [CGFloat] {
        
        try await withCheckedThrowingContinuation { continuation in
                
            do {
                
                let channels = try rawNormalized(texture: texture, bits: bits)
                
                continuation.resume(returning: channels)
                
            } catch {
                
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// 2D
    static func rawNormalized(texture: MTLTexture, bits: TMBits) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try raw8(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
        case ._16:
            #if !os(macOS)
            if #available(iOS 14.0, tvOS 14.0, macOS 11.0, *) {
                raw = try raw16(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
            } else {
                throw TMRawError.unsupportedOSVersion
            }
            #else
            throw TMRawError.unsupportedOS
            #endif
        case ._32:
            raw = try raw32(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
        }
        return raw
    }
    
    /// 2D
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
    
    /// 3D
    static func rawNormalized3d(texture: MTLTexture, bits: TMBits) async throws -> [CGFloat] {
        
        try await withCheckedThrowingContinuation { continuation in
            
            do {
                
                let channels = try rawNormalized3d(texture: texture, bits: bits)
                
                continuation.resume(returning: channels)
                
            } catch {
                
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// 3D
    static func rawNormalized3d(texture: MTLTexture, bits: TMBits) throws -> [CGFloat] {
        let raw: [CGFloat]
        switch bits {
        case ._8:
            raw = try raw3d8(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) / (pow(2, 8) - 1) })
        case ._16:
            #if !os(macOS)
            if #available(iOS 14.0, tvOS 14.0, macOS 11.0, *) {
                raw = try raw3d16(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
            } else {
                throw TMRawError.unsupportedOSVersion
            }
            #else
            throw TMRawError.unsupportedOS
            #endif
        case ._32:
            raw = try raw3d32(texture: texture).map({ chan -> CGFloat in return CGFloat(chan) })
        }
        return raw
    }
    
    /// 3D
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

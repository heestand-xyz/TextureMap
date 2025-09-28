//
//  Created by Anton Heestand on 2021-10-15.
//

import Foundation
@preconcurrency import VideoToolbox
import MetalKit
import MetalPerformanceShaders
import IOSurface

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
        
        case noImageDataFound
        case vtCreateCGImageFromCVPixelBufferFailed
        case cmSampleBufferGetImageBufferFailed
        case failedToReadCIImageFromURL
        case vcMetalTextureCacheCouldNotBeCreated
        case cvMetalTextureCacheCreateTextureFromImageFailed
        case cvMetalTextureGetTextureFailed
        case imageToTextureConversionFailed
        case cgContextFailedToCreate
        case makeOfCGImageFailed
        case makeOfIOSurfaceFailed
        case makeOfMTLTextureFailed
        case makeCommandQueueFailed
        case makeCommandBufferFailed
        case makeBlitCommandEncoderFailed
        
        public var errorDescription: String? {
            switch self {
            case .noImageDataFound:
                return "TextureMap - Texture - No Image Data Found"
            case .vtCreateCGImageFromCVPixelBufferFailed:
                return "TextureMap - Texture - VT Create CGImage from CVPixelBuffer Failed"
            case .cmSampleBufferGetImageBufferFailed:
                return "TextureMap - Texture - CMSampleBuffer Get Image Buffer Failed"
            case .failedToReadCIImageFromURL:
                return "TextureMap - Failed to Read CIImage from URL"
            case .vcMetalTextureCacheCouldNotBeCreated:
                return "TextureMap - CV Metal Texture Cache Could Not be Created"
            case .cvMetalTextureCacheCreateTextureFromImageFailed:
                return "TextureMap - CV Metal Texture Cache Create Texture from Image Failed"
            case .cvMetalTextureGetTextureFailed:
                return "TextureMap - CV Metal Texture Get Texture Failed"
            case .imageToTextureConversionFailed:
                return "TextureMap - Image to Texture Conversion Failed"
            case .cgContextFailedToCreate:
                return "TextureMap - CG Context Failed to Create"
            case .makeOfCGImageFailed:
                return "TextureMap - Make of CG Image Failed"
            case .makeOfIOSurfaceFailed:
                return "TextureMap - Make of IO Surface Failed"
            case .makeOfMTLTextureFailed:
                return "TextureMap - Make of Metal Texture Failed"
            case .makeCommandQueueFailed:
                return "TextureMap - Make Command Queue Failed"
            case .makeCommandBufferFailed:
                return "TextureMap - Make Command Buffer Failed"
            case .makeBlitCommandEncoderFailed:
                return "TextureMap - Make Blit Command Encoder Failed"
            }
        }
    }
    
    static func texture(image: TMImage) throws -> MTLTexture {

        guard let data = image.tiffData() else {
            throw TextureError.noImageDataFound
        }
        
        do {
            let loader = MTKTextureLoader(device: metalDevice)
            let texture: MTLTexture = try loader.newTexture(data: data, options: nil)
            return texture
        } catch {
            print("TextureMap - Texture Conversion Failed - Reverting to Backup Method")
            let bits = try TMBits(image: image)
            let colorSpace = try TMColorSpace(image: image)
            let ciImage: CIImage = try ciImage(image: image)
            let width = Int(ciImage.extent.width)
            let height = Int(ciImage.extent.height)
            let bounds = CGRect(x: 0, y: 0, width: width, height: height)
            let ciContext = CIContext(mtlDevice: metalDevice)
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: bits.metalPixelFormat(),
                width: width,
                height: height,
                mipmapped: false
            )
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            guard let texture = metalDevice.makeTexture(descriptor: textureDescriptor) else {
                throw TextureError.imageToTextureConversionFailed
            }
            ciContext.render(ciImage, to: texture, commandBuffer: nil, bounds: bounds, colorSpace: colorSpace.cgColorSpace)
            return texture
        }
    }
    
    static func texture(cgImage: CGImage) throws -> MTLTexture {

        let loader = MTKTextureLoader(device: metalDevice)

        let texture: MTLTexture = try loader.newTexture(cgImage: cgImage, options: nil)

        return texture
    }
    
    static func textureViaContext(cgImage: CGImage) throws -> MTLTexture {
        
        let width = cgImage.width
        let height = cgImage.height
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        guard let texture = Self.metalDevice.makeTexture(descriptor: textureDescriptor) else {
            throw TextureError.imageToTextureConversionFailed
        }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let imageData = UnsafeMutablePointer<UInt8>.allocate(
            capacity: width * height * bytesPerPixel
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: imageData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw TextureError.imageToTextureConversionFailed
        }
        
        context.draw(
            cgImage,
            in: CGRect(
                x: 0,
                y: 0,
                width: width,
                height: height
            )
        )
        
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: imageData,
            bytesPerRow: bytesPerRow
        )

        return texture
    }
    
    static func texture(ciImage: CIImage, colorSpace: TMColorSpace? = nil, bits: TMBits? = nil) throws -> MTLTexture {
        
        let cgImage: CGImage = try cgImage(ciImage: ciImage, colorSpace: colorSpace, bits: bits)
        
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
    
    static func texture(sampleBuffer: CMSampleBuffer, planeIndex: Int = 0) throws -> MTLTexture {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { throw TextureError.cmSampleBufferGetImageBufferFailed }
        return try texture(pixelBuffer: pixelBuffer, planeIndex: planeIndex)
    }
    
    static func texture(pixelBuffer: CVPixelBuffer, planeIndex: Int = 0) throws -> MTLTexture {
        
        var textureCache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, metalDevice, nil, &textureCache)
        if textureCache == nil {
            throw TextureError.vcMetalTextureCacheCouldNotBeCreated
        }

        var metalTexture: CVMetalTexture!
        var width = CVPixelBufferGetWidth(pixelBuffer)
        var height = CVPixelBufferGetHeight(pixelBuffer)
        let osType: OSType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let isGrayscale: Bool = osType == OSType(1278226488)
        let isPRGB: Bool = osType == OSType(1278226534)
        let isVUV: Bool = osType == OSType(875704438)
        let isTwo32: Bool = osType == kCVPixelFormatType_TwoComponent32Float
        let format: MTLPixelFormat
        if isTwo32 {
            format = .rg32Float
        } else if isVUV {
            format = planeIndex == 1 ? .rg8Unorm : .r8Unorm
            if planeIndex == 1 {
                width /= 2
                height /= 2
            }
        } else {
            format = isPRGB ? .rg16Float : isGrayscale ? .r8Unorm : .bgra8Unorm
        }
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, format, width, height, planeIndex, &metalTexture)
        if metalTexture == nil {
            throw TextureError.cvMetalTextureCacheCreateTextureFromImageFailed
        }

        let texture: MTLTexture! = CVMetalTextureGetTexture(metalTexture)
        if texture == nil {
            throw TextureError.cvMetalTextureGetTextureFailed
        }
        
        return texture
    }
}

// MARK: Image

public extension TextureMap {
    
    static func image(texture: MTLTexture, colorSpace: TMColorSpace, bits: TMBits) throws -> TMImage {
                
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
    
    static func write(image: TMImage, to url: URL, bits: TMBits, colorSpace: TMColorSpace) throws {
        let ciImage: CIImage = try ciImage(image: image)
        try write(ciImage: ciImage, to: url, bits: bits, colorSpace: colorSpace)
    }
    
    static func readImage(from url: URL, xdr: Bool = false) throws -> TMImage {
        let ciImage: CIImage = try readImage(from: url, xdr: xdr)
        return try image(ciImage: ciImage)
    }
}

// MARK: CIImage

public extension TextureMap {
    
    static func ciImage(texture: MTLTexture, colorSpace: TMColorSpace) throws -> CIImage {
        
        var options: [CIImageOption : Any] = [:]
        options[.colorSpace] = colorSpace.cgColorSpace
        if colorSpace == .xdr {
            if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *) {
                options[.expandToHDR] = true
                options[.colorSpace] = TMColorSpace.sRGB.cgColorSpace
            }
        }
        
        guard let ciImage = CIImage(mtlTexture: texture, options: options) else {
            throw TMError.createCIImageFailed
        }
        
        return ciImage
    }

    static func ciImage(cgImage: CGImage) -> CIImage {
        CIImage(cgImage: cgImage)
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
    
    static func write(ciImage: CIImage, to url: URL, bits: TMBits, colorSpace: TMColorSpace) throws {
        
        let context = CIContext(options: nil)
        
        try context.writePNGRepresentation(
            of: ciImage,
            to: url,
            format: bits.ciFormat,
            colorSpace: colorSpace.cgColorSpace,
            options: [:])
    }
    
    static func readImage(from url: URL, xdr: Bool = false) throws -> CIImage {
        var options: [CIImageOption: Any] = [:]
        if #available(iOS 17.0, tvOS 17.0, macOS 14.0, *) {
            options[.expandToHDR] = xdr
        }
        guard let ciImage = CIImage(contentsOf: url,
                                    options: options) else {
            throw TextureError.failedToReadCIImageFromURL
        }
        return ciImage
    }
}

// MARK: CGImage

public extension TextureMap {
    
    static func cgImage(texture: MTLTexture, colorSpace: TMColorSpace, bits: TMBits) throws -> CGImage {
        
        let ciImage = try ciImage(texture: texture, colorSpace: colorSpace)
        
        return try cgImage(ciImage: ciImage, colorSpace: colorSpace, bits: bits)
    }
    
    static func copyCGImage(texture: MTLTexture) throws -> CGImage {
        
        let bits = try TMBits(texture: texture)
        let width: Int = texture.width
        let height: Int = texture.height
        let rowBytes: Int = texture.width * 4 * (bits.rawValue / 8)
        let dataSize: Int = rowBytes * height
        var data = [UInt8](repeating: 0, count: dataSize)
        
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(&data, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &data,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bits.rawValue,
                                      bytesPerRow: rowBytes,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo.rawValue) else {
            throw TextureError.cgContextFailedToCreate
        }
        
        guard let cgImage: CGImage = context.makeImage() else {
            throw TextureError.makeOfCGImageFailed
        }
        
        return cgImage
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
    
    static func cgImage(pixelBuffer: CVPixelBuffer) throws -> CGImage {
        var cgImage: CGImage!
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        if cgImage == nil {
            throw TextureError.vtCreateCGImageFromCVPixelBufferFailed
        }
        return cgImage
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
    
    public static func pixelBuffer(texture: MTLTexture) throws -> CVPixelBuffer {
        let width = texture.width
        let height = texture.height
        let bits = try TMBits(texture: texture)
        
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: Int(bits.osType) as CFNumber,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, width, height, bits.osType, attributes as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw PixelBufferError.cvPixelBufferCreateFailed
        }
        let bytesPerRow: Int = CVPixelBufferGetBytesPerRow(buffer)
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw PixelBufferError.cvPixelBufferLockBaseAddressFailed
        }
        
        texture.getBytes(
            baseAddress,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )
        
        return buffer
    }
    
    @available(*, deprecated, renamed: "pixelBuffer(texture:)", message: "Moving from a CGImage based approach to a raw bytes approach.")
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

// MARK: - CGImageSource

extension TextureMap {
    enum ImageSourceError: String, LocalizedError {
        case imageSourceCreateFailed
        case imageNotFound
        case dataProviderNotFound
        case unsupportedAssetFile
        case dataNotFound
        case finalizationFailed
        var errorDescription: String? {
            switch self {
            case .imageSourceCreateFailed:
                "Image source create failed."
            case .imageNotFound:
                "Image not found."
            case .dataProviderNotFound:
                "Data provider not found."
            case .unsupportedAssetFile:
                "Unsupported asset file."
            case .dataNotFound:
                "Data not found."
            case .finalizationFailed:
                "Finalization failed."
            }
        }
    }
    
    public static func cgImageSource(cgImage: CGImage) throws -> CGImageSource {
        guard let dataProvider: CGDataProvider = cgImage.dataProvider else {
            throw ImageSourceError.dataProviderNotFound
        }
        guard let imageSource: CGImageSource = CGImageSourceCreateWithDataProvider(dataProvider, nil) else {
            throw ImageSourceError.imageSourceCreateFailed
        }
        return imageSource
    }
    
    public static func cgImageSource(url: URL) throws -> CGImageSource {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageSourceError.imageSourceCreateFailed
        }
        return imageSource
    }
    
    public static func cgImageSource(data: Data) throws -> CGImageSource {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageSourceError.imageSourceCreateFailed
        }
        return imageSource
    }
    
    public static func cgImageSource(texture: MTLTexture, colorSpace: TMColorSpace, bits: TMBits) throws -> CGImageSource {
        try cgImageSource(cgImage: cgImage(texture: texture, colorSpace: colorSpace, bits: bits))
    }
}

// MARK: - IO Surface

extension TextureMap {
    
    public static func iosurface(texture: MTLTexture) throws -> IOSurfaceRef {
        if let iosurface = texture.iosurface {
            return iosurface
        }
        let bits = try TMBits(texture: texture)
        let channelCount: Int = 4
        let bytesPerElement: Int = (bits.rawValue / 8) * channelCount
        let bytesPerRow: Int = texture.width * bytesPerElement
        let props: [IOSurfacePropertyKey: Any] = [
            .width: texture.width,
            .height: texture.height,
            .bytesPerElement: bytesPerElement,
            .pixelFormat: bits.osType,
            .bytesPerRow: bytesPerRow
        ]
        guard let iosurface = IOSurfaceCreate(props as CFDictionary) else {
            throw TextureError.makeOfIOSurfaceFailed
        }
        return iosurface
    }
    
    public static func textureWithIOSurface(texture: MTLTexture) async throws -> (MTLTexture, IOSurfaceRef) {
        if let iosurface = texture.iosurface {
            return (texture, iosurface)
        }
        let iosurface: IOSurface = try iosurface(texture: texture)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared

        guard let iosurfaceTexture = Self.metalDevice.makeTexture(
            descriptor: descriptor,
            iosurface: iosurface,
            plane: 0
        ) else {
            throw TextureError.makeOfMTLTextureFailed
        }
        
        guard let commandQueue: MTLCommandQueue = Self.metalDevice.makeCommandQueue() else {
            throw TextureError.makeCommandQueueFailed
        }
        guard let commandBuffer: MTLCommandBuffer = commandQueue.makeCommandBuffer()  else {
            throw TextureError.makeCommandBufferFailed
        }
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder()  else {
            throw TextureError.makeBlitCommandEncoderFailed
        }
        blitEncoder.copy(from: texture,
                         sourceSlice: 0,
                         sourceLevel: 0,
                         sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                         sourceSize: MTLSize(width: texture.width,
                                             height: texture.height,
                                             depth: 1),
                         to: iosurfaceTexture,
                         destinationSlice: 0,
                         destinationLevel: 0,
                         destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blitEncoder.endEncoding()
        await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
            commandBuffer.commit()
        }
        return (iosurfaceTexture, iosurface)
    }
}

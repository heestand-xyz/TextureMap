//
//  File.swift
//  
//
//  Created by Anton Heestand on 2022-05-13.
//

import Foundation
import Metal

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
    case makeCommandQueueFailed
    case makeCommandBufferFailed
    case makeBlitCommandEncoderFailed
    case sampleCountNotSupported(Int)
    case pixelFormatDoesNotSupportMultisample(MTLPixelFormat)
    
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
        case .makeCommandQueueFailed:
            return "Texture Map - Texture Array - Make Command Queue Failed"
        case .makeCommandBufferFailed:
            return "Texture Map - Texture Array - Make Command Buffer Failed"
        case .makeBlitCommandEncoderFailed:
            return "Texture Map - Texture Array - Make Blit Command Encoder Failed"
        case .sampleCountNotSupported(let sampleCount):
            return "Texture Map - Sample Count Not Supported (\(sampleCount))"
        case .pixelFormatDoesNotSupportMultisample(let pixelFormat):
            return "Texture Map - Pixel Format Does Not Support Multisample (\(pixelFormat.rawValue))"
        }
    }
}

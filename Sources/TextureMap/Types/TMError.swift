//
//  File.swift
//  
//
//  Created by Anton Heestand on 2022-05-13.
//

import Foundation

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
        }
    }
}

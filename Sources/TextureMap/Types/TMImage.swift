//
//
//  Created by Anton Heestand on 2021-02-23.
//

import Foundation
import SwiftUI
#if !os(macOS)
import MobileCoreServices
#endif
import UniformTypeIdentifiers
import AVFoundation

#if os(macOS)
public typealias TMImage = NSImage
public typealias TMImageView = NSImageView
public extension Image {
    init(tmImage: NSImage) {
        self.init(nsImage: tmImage)
    }
}
#else
public typealias TMImage = UIImage
public typealias TMImageView = UIImageView
public extension Image {
    init(tmImage: UIImage) {
        self.init(uiImage: tmImage)
    }
}
#endif

public extension Bundle {
    
    enum TMImageBundleError: LocalizedError {
        
        case imageNotFound(bundle: Bundle, imageName: String)
        
        public var errorDescription: String? {
            
            switch self {
            case let .imageNotFound(bundle, imageName):
                return "Texture Map - Bundle (\(bundle.bundleIdentifier ?? "unknown")) - Image - Not Found - Name: \"\(imageName)\""
            }
        }
    }
    
    func image(named name: String) throws -> TMImage {
        
        #if os(macOS)
        
        guard let image: NSImage = image(forResource: name) else {
            throw TMImageBundleError.imageNotFound(bundle: self, imageName: name)
        }
        
        return image
        
        #else
        
        guard let image: UIImage = UIImage(named: name, in: self, with: nil) else {
            throw TMImageBundleError.imageNotFound(bundle: self, imageName: name)
        }
        
        return image
        
        #endif
    }
}

public extension TMImage {
    
    var texture: MTLTexture {
        get throws {
            try TextureMap.texture(image: self)
        }
    }
}

#if os(macOS)
public extension NSImage {
    func pngData() -> Data? {
        guard let representation = tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: representation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let representation = tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: representation) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    func heicData(compressionQuality: CGFloat) -> Data? {
        guard let cgImage = self.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, AVFileType.heic as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: compressionQuality]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
    func tiffData() -> Data? {
        tiffRepresentation
    }
}
#else
public extension UIImage {
    func tiffData() -> Data? {
        guard let cgImage
        else { return nil }
        let options: NSDictionary =     [
            kCGImagePropertyOrientation: imageOrientation,
            kCGImagePropertyHasAlpha: true
        ]
        let data = NSMutableData()
        guard let imageDestination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.tiff.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(imageDestination, cgImage, options)
        CGImageDestinationFinalize(imageDestination)
        return data as Data
    }
}
#endif

#if os(macOS)
public extension NSImage {
    var scale: CGFloat {
        guard let pixelsWide: Int = representations.first?.pixelsWide else { return 1.0 }
        let scale: CGFloat = CGFloat(pixelsWide) / size.width
        return scale
    }
}
#endif

#if os(macOS)
public extension NSImage {
    var cgImage: CGImage? {
        var frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        return cgImage(forProposedRect: &frame, context: nil, hints: nil)
    }
}
#else
public extension UIImage {
    convenience init(cgImage: CGImage, size: CGSize) {
        self.init(cgImage: cgImage)
    }
}
#endif

#if !os(macOS)
public extension UIImage {
    convenience init?(contentsOf url: URL) {
        self.init(contentsOfFile: url.path(percentEncoded: false))
    }
}
#endif

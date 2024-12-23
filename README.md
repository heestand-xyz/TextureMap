# TextureMap

### Overview

**Texture Map** is a Swift 6 package for working with images and textures. Covert images or raw data between various formats. Made for iOS, macOS, and visionOS. Powered by Metal.

---

### Features

1. **Cross-Platform Support**: 
   - Provides seamless support for macOS and iOS, utilizing `NSImage` and `UIImage` interchangeably.
2. **High Color Bit Support**
   - Work with `8 bit`, `16 bit` and `32 bit` graphics.   
3. **Image Formats**:
   - Converts between `UIImage`/`NSImage`, `CGImage`, `CIImage`, `CVPixelBuffer`, `CMSampleBuffer` and `MTLTexture`.
   - Cross-platofrm support for getting `TIFF`, `PNG` and `JPG` data.
4. **Metal Texture Utilities**:
   - Create empty textures with specified pixel formats and dimensions.
   - Support for 2D, 3D, and array textures.
   - Texture copying and sampling.
5. **Raw Data Operations**:
   - Extract normalized or raw texture data as `UInt8`, `Float16`, or `Float32`.
   - Create textures from raw data arrays.

---

### Installation

Add **Texture Map** to your project by integrating it as a Swift package. Use the repository URL:

```swift
dependencies: [
    .package(url: "https://github.com/heestand-xyz/TextureMap", from: "2.0.0")
]
```

---

### Requirements

- **Platforms**:
  - iOS 16.0+
  - macOS 13.0+
  - visionOS 1.0+

---

### Usage

#### Convert Image to Texture
```swift
import TextureMap

let image: UIImage = UIImage(named: "Example")!
let texture: MTLTexture = try TextureMap.texture(image: image)
```

#### Extract Raw Data from Texture
```swift
let rawChannels: [UInt8] = try TextureMap.raw8(texture: texture)
```

#### Convert Texture to Image
```swift
let outputImage: UIImage = try await texture.image(colorSpace: .sRGB, bits: ._8)
```

#### Copy a Metal Texture
```swift
let originalTexture: MTLTexture = ... // Your Metal texture

do {
    let copiedTexture: MTLTexture = try await originalTexture.copy()
    print("Copied texture: \(copiedTexture)")
} catch {
    print("Error copying texture: \(error)")
}
```

#### Create a Texture from Raw Normalized Data
```swift
let rawTexture: MTLTexture = ...
let bits: TMBits = ._8

do {
    let normalizedRawData: [CGFloat] = try await TextureMap.rawNormalized(texture: rawTexture, bits: bits)
    print("Normalized raw data: \(normalizedRawData)")
} catch {
    print("Error extracting raw data: \(error)")
}
```

#### Convert Texture Color Space
```swift
let inputTexture: MTLTexture = ...
let fromColorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let toColorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!

do {
    let convertedTexture: MTLTexture = try await inputTexture.convertColorSpace(from: fromColorSpace, to: toColorSpace)
    print("Converted texture: \(convertedTexture)")
} catch {
    print("Error converting texture color space: \(error)")
}
```

---

### Color Spaces

- **`sRGB`**: Standard RGB space.
- **`Display P3`**: Extended gamut for HDR content.
- **`XDR`**: For high bit graphics displayed on XDR compatible displays.

---

### Contributing

Feel free to contribute by submitting pull requests or reporting issues.

---

### License

This library is available under the MIT License.

---
### Acknowledgments

Developed by [Anton Heestand](http://heestand.xyz)

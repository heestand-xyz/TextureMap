//
//  File.swift
//  
//
//  Created by Anton Heestand on 2022-04-01.
//

import Metal
import CoreGraphics

public extension MTLTexture {
    
    func image(colorSpace: TMColorSpace) async throws -> TMImage {
        try await TextureMap.image(texture: self, colorSpace: colorSpace)
    }
}

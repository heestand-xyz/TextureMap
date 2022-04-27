//
//  Created by Anton Heestand on 2022-04-27.
//

import Metal
import CoreVideo
import VideoToolbox

extension CVPixelBuffer {
    
    public func texture() throws -> MTLTexture {
        
        var cgImage: CGImage!
        
        VTCreateCGImageFromCVPixelBuffer(self, options: nil, imageOut: &cgImage)
        
        return try TextureMap.texture(cgImage: cgImage)
    }
}

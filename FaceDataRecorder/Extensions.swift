//
//  GeoData.swift
//  FaceDataRecorder
//
//  Created by 洪健淇 on 2017/11/13.
//  Copyright © 2017年 洪健淇. All rights reserved.
//

import SceneKit
import ARKit

enum CaptureMode {
    case record
    case stream
}

struct CaptureData {
    var vertices: [float3]
    var camTransform: matrix_float4x4
    var faceTransform: matrix_float4x4
    var blendShapes: [ARFaceAnchor.BlendShapeLocation : NSNumber]
    
    var str : String {
        let v = vertices.map{ "\($0.x):\($0.y):\($0.z)" }.joined(separator: "~")
        let ct = camTransform
        let ft = faceTransform
        let cm = "\(ct.columns.0.str):\(ct.columns.1.str):\(ct.columns.2.str):\(ct.columns.3.str)"
        let fm = "\(ft.columns.0.str):\(ft.columns.1.str):\(ft.columns.2.str):\(ft.columns.3.str)"
        let bs = blendShapes.map { "\($0.key.rawValue):\($0.value)" }.joined(separator: "~")
        return "\(cm)~\(fm)~\(v)~\(bs)"
    }
}

extension simd_float4 {
    var str : String {
        return "\(self.x):\(self.y):\(self.z):\(self.w)"
    }
}

extension UIImage {
    convenience init (pixelBuffer: CVPixelBuffer) {
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        self.init(cgImage: cgImage!)
    }
}

import Foundation
import simd

func clamp(_ value: Float, min lower: Float, max upper: Float) -> Float {
    Swift.max(lower, Swift.min(upper, value))
}

func shortestDistanceFromRayToPoint(
    rayOrigin: SIMD3<Float>,
    rayDirection: SIMD3<Float>,
    point: SIMD3<Float>
) -> Float {
    let dir = simd_normalize(rayDirection)
    let toPoint = point - rayOrigin
    let t = max(0, simd_dot(toPoint, dir))
    let closestPoint = rayOrigin + dir * t
    return simd_length(point - closestPoint)
}

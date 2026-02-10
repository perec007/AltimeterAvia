//
//  Track3DView.swift
//  AltimeterAvia
//
//  3D проекция трека с вращением камеры (SceneKit).
//

import SwiftUI
import SceneKit

struct Track3DView: View {
    let points: [TrackPointRecord]
    
    var body: some View {
        Track3DViewRepresentable(points: points)
            .ignoresSafeArea(edges: .all)
    }
}

private func scenePositions(from points: [TrackPointRecord]) -> [SCNVector3] {
    guard !points.isEmpty else { return [] }
    let hasCoords = points.contains { $0.latitude != nil && $0.longitude != nil }
    if hasCoords {
        let valid = points.compactMap { p -> (lat: Double, lon: Double, alt: Double)? in
            guard let lat = p.latitude, let lon = p.longitude else { return nil }
            let alt = p.altitudeBaroDisplay ?? p.altitudeBaroSeaLevel ?? p.altitudeGps ?? 0
            return (lat, lon, alt)
        }
        guard let first = valid.first else { return [] }
        let lat0 = first.lat, lon0 = first.lon
        let scale = 1.0
        return valid.map { p in
            let x = (p.lon - lon0) * 111320 * cos(lat0 * .pi / 180) * scale
            let z = (p.lat - lat0) * 110540 * scale
            return SCNVector3(x: Float(x), y: Float(p.alt), z: Float(z))
        }
    }
    let altScale = 1.0
    return points.enumerated().map { i, p in
        let alt = p.altitudeBaroDisplay ?? p.altitudeBaroSeaLevel ?? p.altitudeGps ?? 0
        return SCNVector3(x: Float(i) * 2, y: Float(alt) * Float(altScale), z: 0)
    }
}

struct Track3DViewRepresentable: UIViewRepresentable {
    let points: [TrackPointRecord]
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        
        let positions = scenePositions(from: points)
        let scene = buildScene(positions: positions)
        scnView.scene = scene
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        let positions = scenePositions(from: points)
        let scene = buildScene(positions: positions)
        scnView.scene = scene
    }
    
    private func buildScene(positions: [SCNVector3]) -> SCNScene {
        let scene = SCNScene()
        
        guard positions.count >= 2 else {
            return scene
        }
        
        var lineVertices: [SCNVector3] = []
        for i in 0..<(positions.count - 1) {
            lineVertices.append(positions[i])
            lineVertices.append(positions[i + 1])
        }
        let data = Data(bytes: lineVertices, count: lineVertices.count * MemoryLayout<SCNVector3>.size)
        let source = SCNGeometrySource(data: data, semantic: .vertex, vectorCount: lineVertices.count, usesFloatComponents: true, componentsPerVector: 3, bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0, dataStride: MemoryLayout<SCNVector3>.size)
        var indices: [Int32] = Array(0..<Int32(lineVertices.count))
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(data: indexData, primitiveType: .line, primitiveCount: indices.count / 2, bytesPerIndex: MemoryLayout<Int32>.size)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = UIColor.systemGreen
        geometry.firstMaterial?.emission.contents = UIColor.systemGreen.withAlphaComponent(0.4)
        let trackNode = SCNNode(geometry: geometry)
        scene.rootNode.addChildNode(trackNode)
        
        let center = positions.reduce(SCNVector3(0, 0, 0)) { r, p in
            SCNVector3(r.x + p.x, r.y + p.y, r.z + p.z)
        }
        let n = Float(positions.count)
        let centroid = SCNVector3(center.x / n, center.y / n, center.z / n)
        
        let centerNode = SCNNode()
        centerNode.position = centroid
        scene.rootNode.addChildNode(centerNode)
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        let extent = positions.reduce(Float(0)) { m, p in
            let dx = p.x - centroid.x, dy = p.y - centroid.y, dz = p.z - centroid.z
            return max(m, sqrt(dx*dx + dy*dy + dz*dz))
        }
        let distance = max(extent * 2.5, 100)
        cameraNode.position = SCNVector3(centroid.x + distance * 0.5, centroid.y + distance * 0.7, centroid.z + distance * 0.5)
        cameraNode.constraints = [SCNLookAtConstraint(target: centerNode)]
        scene.rootNode.addChildNode(cameraNode)
        
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.position = SCNVector3(centroid.x + 200, centroid.y + 500, centroid.z + 200)
        scene.rootNode.addChildNode(light)
        
        return scene
    }
}

//
//  Track3DView.swift
//  AltimeterAvia
//
//  3D проекция трека с картой (SceneKit). Высота трека и карты — по давлению на уровне моря (QNH).
//

import SwiftUI
import SceneKit
import MapKit

struct Track3DView: View {
    let points: [TrackPointRecord]
    var selectedIndex: Int? = nil
    
    var body: some View {
        Track3DViewRepresentable(points: points, selectedIndex: selectedIndex)
            .ignoresSafeArea(edges: .all)
    }
}

private func scenePositions(from points: [TrackPointRecord]) -> [SCNVector3] {
    guard !points.isEmpty else { return [] }
    let hasCoords = points.contains { $0.latitude != nil && $0.longitude != nil }
    if hasCoords {
        let valid = points.compactMap { p -> (lat: Double, lon: Double, alt: Double)? in
            guard let lat = p.latitude, let lon = p.longitude else { return nil }
            let alt = p.altitudeBaroSeaLevel ?? p.altitudeBaroDisplay ?? p.altitudeGps ?? 0
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
        let alt = p.altitudeBaroSeaLevel ?? p.altitudeBaroDisplay ?? p.altitudeGps ?? 0
        return SCNVector3(x: Float(i) * 2, y: Float(alt) * Float(altScale), z: 0)
    }
}

struct Track3DViewRepresentable: UIViewRepresentable {
    let points: [TrackPointRecord]
    var selectedIndex: Int? = nil
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        
        let positions = scenePositions(from: points)
        let scene = buildScene(positions: positions, selectedIndex: selectedIndex)
        scnView.scene = scene
        
        if hasCoordinates, !positions.isEmpty {
            addMapPlaneAsync(context: context, scnView: scnView, points: points, positions: positions)
        }
        
        return scnView
    }
    
    func updateUIView(_ scnView: SCNView, context: Context) {
        let positions = scenePositions(from: points)
        let pointsChanged = context.coordinator.lastPointsCount != points.count
            || context.coordinator.lastFirstTimestamp != points.first?.timestamp
        context.coordinator.lastPointsCount = points.count
        context.coordinator.lastFirstTimestamp = points.first?.timestamp

        if pointsChanged {
            context.coordinator.cancelMapSnapshot()
            let scene = buildScene(positions: positions, selectedIndex: selectedIndex)
            scnView.scene = scene
            if hasCoordinates, !positions.isEmpty {
                addMapPlaneAsync(context: context, scnView: scnView, points: points, positions: positions)
            }
        } else if positions.count >= 2, let idx = selectedIndex, idx >= 0, idx < positions.count {
            updateMarkerOnly(in: scnView.scene, positions: positions, selectedIndex: idx)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var currentSnapshotter: MKMapSnapshotter?
        var lastPointsCount: Int = -1
        var lastFirstTimestamp: Date?

        func cancelMapSnapshot() {
            currentSnapshotter?.cancel()
            currentSnapshotter = nil
        }
    }

    private func updateMarkerOnly(in scene: SCNScene?, positions: [SCNVector3], selectedIndex: Int) {
        guard let scene = scene else { return }
        scene.rootNode.childNode(withName: "selectedMarker", recursively: false)?.removeFromParentNode()
        let centroid = positions.reduce(SCNVector3(0, 0, 0)) { r, p in
            SCNVector3(r.x + p.x, r.y + p.y, r.z + p.z)
        }
        let n = Float(positions.count)
        let center = SCNVector3(centroid.x / n, centroid.y / n, centroid.z / n)
        let extent = positions.reduce(Float(0)) { m, p in
            let dx = p.x - center.x, dy = p.y - center.y, dz = p.z - center.z
            return max(m, sqrt(dx*dx + dy*dy + dz*dz))
        }
        let pos = positions[selectedIndex]
        let sphere = SCNSphere(radius: CGFloat(max(extent * 0.05, 5)))
        sphere.firstMaterial?.diffuse.contents = UIColor.systemOrange
        sphere.firstMaterial?.emission.contents = UIColor.systemOrange
        let markerNode = SCNNode(geometry: sphere)
        markerNode.name = "selectedMarker"
        markerNode.position = pos
        scene.rootNode.addChildNode(markerNode)
    }
    
    private var hasCoordinates: Bool {
        points.contains { $0.latitude != nil && $0.longitude != nil }
    }
    
    private func addMapPlaneAsync(context: Context, scnView: SCNView, points: [TrackPointRecord], positions: [SCNVector3]) {
        context.coordinator.cancelMapSnapshot()
        let valid = points.compactMap { p -> (lat: Double, lon: Double)? in
            guard let lat = p.latitude, let lon = p.longitude else { return nil }
            return (lat, lon)
        }
        guard let minLat = valid.map(\.lat).min(),
              let maxLat = valid.map(\.lat).max(),
              let minLon = valid.map(\.lon).min(),
              let maxLon = valid.map(\.lon).max() else { return }
        
        let padding = 0.0003
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) + padding * 2, 0.001)
        let spanLon = max((maxLon - minLon) + padding * 2, 0.001)
        
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
        
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 1024, height: 1024)
        options.mapType = .standard
        options.showsBuildings = true
        
        let snapshotter = MKMapSnapshotter(options: options)
        let pointsCountWhenStarted = points.count
        context.coordinator.currentSnapshotter = snapshotter
        snapshotter.start { snapshot, error in
            if let err = error {
                #if DEBUG
                print("[Track3D] Map snapshot error: \(err.localizedDescription)")
                #endif
                return
            }
            guard let snapshot = snapshot else { return }
            let image = snapshot.image

            DispatchQueue.main.async {
                guard let scene = scnView.scene else { return }
                if context.coordinator.lastPointsCount >= 0 && context.coordinator.lastPointsCount != pointsCountWhenStarted { return }
                scene.rootNode.childNode(withName: "mapPlanePlaceholder", recursively: false)?.removeFromParentNode()
                scene.rootNode.childNode(withName: "mapPlane", recursively: false)?.removeFromParentNode()

                let minY = positions.map(\.y).min() ?? 0
                let maxX = positions.map(\.x).max() ?? 0
                let minX = positions.map(\.x).min() ?? 0
                let maxZ = positions.map(\.z).max() ?? 0
                let minZ = positions.map(\.z).min() ?? 0
                let centerX = (minX + maxX) / 2
                let centerZ = (minZ + maxZ) / 2
                let widthM = max(maxX - minX, 50)
                let heightM = max(maxZ - minZ, 50)
                
                let plane = SCNPlane(width: CGFloat(widthM), height: CGFloat(heightM))
                plane.firstMaterial?.diffuse.contents = image
                plane.firstMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(1, -1, 1)
                plane.firstMaterial?.isDoubleSided = true  // камера сверху — видна «обратная» сторона плоскости
                plane.firstMaterial?.ambient.contents = UIColor.darkGray
                
                let mapNode = SCNNode(geometry: plane)
                mapNode.name = "mapPlane"
                mapNode.position = SCNVector3(centerX, minY, centerZ)
                mapNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
                mapNode.renderingOrder = -1
                scene.rootNode.insertChildNode(mapNode, at: 0)
            }
        }
    }
    
    private func buildScene(positions: [SCNVector3], selectedIndex: Int?) -> SCNScene {
        let scene = SCNScene()
        
        guard positions.count >= 2 else {
            return scene
        }
        
        let minY = positions.map(\.y).min() ?? 0
        let maxX = positions.map(\.x).max() ?? 0
        let minX = positions.map(\.x).min() ?? 0
        let maxZ = positions.map(\.z).max() ?? 0
        let minZ = positions.map(\.z).min() ?? 0
        let centerX = (minX + maxX) / 2
        let centerZ = (minZ + maxZ) / 2
        let widthM = max(maxX - minX, 50)
        let heightM = max(maxZ - minZ, 50)
        
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
        
        let placeholderPlane = SCNPlane(width: CGFloat(widthM), height: CGFloat(heightM))
        placeholderPlane.firstMaterial?.diffuse.contents = UIColor.darkGray.withAlphaComponent(0.6)
        placeholderPlane.firstMaterial?.isDoubleSided = true
        let placeholderNode = SCNNode(geometry: placeholderPlane)
        placeholderNode.name = "mapPlanePlaceholder"
        placeholderNode.position = SCNVector3(centerX, minY, centerZ)
        placeholderNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        placeholderNode.renderingOrder = -1
        scene.rootNode.insertChildNode(placeholderNode, at: 0)
        
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
        
        if let idx = selectedIndex, idx >= 0, idx < positions.count {
            let pos = positions[idx]
            let sphere = SCNSphere(radius: CGFloat(max(extent * 0.05, 5)))
            sphere.firstMaterial?.diffuse.contents = UIColor.systemOrange
            sphere.firstMaterial?.emission.contents = UIColor.systemOrange
            let markerNode = SCNNode(geometry: sphere)
            markerNode.name = "selectedMarker"
            markerNode.position = pos
            scene.rootNode.addChildNode(markerNode)
        }
        
        return scene
    }
}

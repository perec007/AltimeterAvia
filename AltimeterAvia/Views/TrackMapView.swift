//
//  TrackMapView.swift
//  AltimeterAvia
//
//  Трек на карте (MKMapView + полилиния).
//

import SwiftUI
import MapKit

struct TrackMapView: View {
    let points: [TrackPointRecord]
    var selectedIndex: Int? = nil
    
    private var coordinates: [CLLocationCoordinate2D] {
        points.compactMap { p in
            guard let lat = p.latitude, let lon = p.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
    
    private var selectedCoordinate: CLLocationCoordinate2D? {
        guard let idx = selectedIndex, idx >= 0, idx < points.count,
              let lat = points[idx].latitude, let lon = points[idx].longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var body: some View {
        MapTrackViewRepresentable(coordinates: coordinates, selectedCoordinate: selectedCoordinate)
            .ignoresSafeArea(edges: .all)
    }
}

struct MapTrackViewRepresentable: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    var selectedCoordinate: CLLocationCoordinate2D? = nil
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = false
        map.isRotateEnabled = true
        if !coordinates.isEmpty {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            map.addOverlay(polyline)
            map.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: false)
        }
        return map
    }
    
    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)
        if !coordinates.isEmpty {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            map.addOverlay(polyline)
            var rect = polyline.boundingMapRect
            if let sel = selectedCoordinate {
                let ann = MKPointAnnotation()
                ann.coordinate = sel
                map.addAnnotation(ann)
                let pt = MKMapPoint(sel)
                rect = rect.union(MKMapRect(x: pt.x - 5000, y: pt.y - 5000, width: 10000, height: 10000))
            }
            map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: context.transaction.animation != nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemGreen
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

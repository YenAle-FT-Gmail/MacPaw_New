import SwiftUI
import MapKit

struct LocationsPanel: View {
    @EnvironmentObject var coordinator: StateCoordinator
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
    )
    
    var body: some View {
        VStack(spacing: 0) {
            if coordinator.auditReport.photoLocations.isEmpty {
                emptyState
            } else {
                HSplitView {
                    mapView
                        .frame(minWidth: 400)
                    
                    locationList
                        .frame(minWidth: 250, maxWidth: 350)
                }
            }
        }
        .background(Color(hex: "0D1117"))
        .onAppear { centerMapOnFindings() }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "mappin.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No GPS Data Found")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("No photos with embedded location data were detected.\nRun an audit to scan your photo library.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
    
    // MARK: - Map
    private var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: coordinator.auditReport.photoLocations) { location in
            MapAnnotation(coordinate: location.coordinate) {
                VStack(spacing: 2) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "FF6B35"))
                    
                    Text(location.fileName)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                }
            }
        }
        .overlay(
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("\(coordinator.auditReport.photoLocations.count)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                        Text("LOCATIONS")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3)))
                    )
                    .padding(12)
                }
                Spacer()
            }
        )
    }
    
    // MARK: - Location List
    private var locationList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PHOTOS WITH GPS DATA")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            Divider().background(Color.white.opacity(0.1))
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(coordinator.auditReport.photoLocations) { location in
                        LocationRow(location: location)
                    }
                }
            }
        }
        .background(Color(hex: "0A0E1A"))
    }
    
    private func centerMapOnFindings() {
        guard let first = coordinator.auditReport.photoLocations.first else { return }
        
        if coordinator.auditReport.photoLocations.count == 1 {
            region = MKCoordinateRegion(
                center: first.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        } else {
            let lats = coordinator.auditReport.photoLocations.map { $0.coordinate.latitude }
            let lons = coordinator.auditReport.photoLocations.map { $0.coordinate.longitude }
            let center = CLLocationCoordinate2D(
                latitude: (lats.min()! + lats.max()!) / 2,
                longitude: (lons.min()! + lons.max()!) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: (lats.max()! - lats.min()!) * 1.3 + 0.01,
                longitudeDelta: (lons.max()! - lons.min()!) * 1.3 + 0.01
            )
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

struct LocationRow: View {
    let location: PhotoLocationFinding
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo")
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(location.fileName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
                
                if let date = location.dateTaken {
                    Text(date, style: .date)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
    }
}

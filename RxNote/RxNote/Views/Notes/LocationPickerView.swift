//
//  LocationPickerView.swift
//  RxNote
//
//  Map-based location picker with search and current location support
//

import CoreLocation
import MapKit
import SwiftUI

struct LocationPickerView: View {
    let initialLatitude: Double?
    let initialLongitude: Double?
    let onConfirm: (Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var addressText: String?
    @State private var locationManager = LocationHelper()

    init(
        latitude: Double? = nil,
        longitude: Double? = nil,
        onConfirm: @escaping (Double, Double) -> Void
    ) {
        self.initialLatitude = latitude
        self.initialLongitude = longitude
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapContent

                VStack(spacing: 12) {
                    if let address = addressText {
                        Text(address)
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button {
                        requestCurrentLocation()
                    } label: {
                        Label("Use Current Location", systemImage: "location.fill")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 16)
            }
            .searchable(text: $searchText, prompt: "Search for a place")
            .onSubmit(of: .search) {
                Task { await searchPlace() }
            }
            .navigationTitle("Pick Location")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        if let coord = selectedCoordinate {
                            onConfirm(coord.latitude, coord.longitude)
                        }
                        dismiss()
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
            .onAppear { setupInitialLocation() }
        }
    }

    // MARK: - Map

    @ViewBuilder
    private var mapContent: some View {
        MapReader { proxy in
            Map(position: $position) {
                if let coord = selectedCoordinate {
                    Marker("Selected", coordinate: coord)
                        .tint(.purple)
                }
            }
            .onTapGesture { screenPoint in
                if let coordinate = proxy.convert(screenPoint, from: .local) {
                    selectedCoordinate = coordinate
                    reverseGeocode(coordinate)
                }
            }
            .overlay(alignment: .top) {
                if !searchResults.isEmpty {
                    searchResultsList
                }
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        List(searchResults, id: \.self) { item in
            Button {
                selectMapItem(item)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "Unknown")
                        .font(.subheadline.weight(.medium))
                    if let address = item.placemark.title {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
        .frame(maxHeight: 200)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    // MARK: - Methods

    private func setupInitialLocation() {
        if let lat = initialLatitude, let lon = initialLongitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            selectedCoordinate = coord
            position = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            reverseGeocode(coord)
        } else {
            requestCurrentLocation()
        }
    }

    private func requestCurrentLocation() {
        locationManager.requestLocation { location in
            let coord = location.coordinate
            selectedCoordinate = coord
            position = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            reverseGeocode(coord)
        }
    }

    private func searchPlace() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        selectedCoordinate = coord
        position = .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
        addressText = item.placemark.title
        searchResults = []
        searchText = ""
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            if let placemark = placemarks?.first {
                let parts = [
                    placemark.name,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country,
                ].compactMap { $0 }
                addressText = parts.joined(separator: ", ")
            }
        }
    }
}

// MARK: - Location Helper

private final class LocationHelper: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation(completion: @escaping (CLLocation) -> Void) {
        self.completion = completion
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            completion?(location)
            completion = nil
        }
    }

    func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        completion = nil
    }
}

#Preview {
    LocationPickerView { lat, lon in
        print("Selected: \(lat), \(lon)")
    }
}

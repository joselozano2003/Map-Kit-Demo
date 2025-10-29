//
//  ContentView.swift
//  Map-Kit-Demo
//
//  Created by Jose Lozano on 10/28/25.
//

import SwiftUI
import MapKit
import Combine

import CoreLocation

struct ContentView: View {
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var route: MKRoute?
    @State private var mapStyle: MapStyle = .standard
    @StateObject private var locationManager = LocationManager()
    @State private var trackingMode: MapUserTrackingMode = .follow


    
    @StateObject private var searchCompleter = SearchCompleter()
    @State private var showSuggestions = true


    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.0455, longitude: -114.0729),
            latitudinalMeters: 30000,
            longitudinalMeters: 30000
        )
    )

    @State private var showUserLocation = true

    // Coordinates
    let uCalgary = CLLocationCoordinate2D(latitude: 51.07885784940875, longitude: -114.13220927966469)
    let downtown = CLLocationCoordinate2D(latitude: 51.04554792104228, longitude: -114.07295736885621)

    var body: some View {
        ZStack(alignment: .top) {
            // MARK: - MAP VIEW
            Map(position: $cameraPosition, interactionModes: [.all]) {
                
                // Static annotation
                Annotation("University of Calgary", coordinate: uCalgary) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .font(.title)
                }
                
                // Search result markers
                ForEach(searchResults, id: \.self) { item in
                    Marker(item: item)
                }
                
                // Draw route overlay if available
                if let route = route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 4)
                }
                
                // Example of a circular overlay (around UCalgary)
                MapCircle(center: uCalgary, radius: 50)
                    .stroke(.orange, lineWidth: 2)
                    .foregroundStyle(.orange.opacity(0.2))
            }
            
            .onMapCameraChange { context in
                searchCompleter.region = context.region
            }
            .mapStyle(mapStyle)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapPitchToggle()
            }
            .edgesIgnoringSafeArea(.all)
            .overlay(alignment: .bottomLeading) {
                if let _ = lookAroundScene {
                    LookAroundPreview(scene: $lookAroundScene)
                        .frame(width: 230, height: 140)
                        .cornerRadius(10)
                        .padding(8)
                }
            }
            .onAppear {
                loadLookAroundScene()
            }
            .onChange(of: searchQuery) { newValue in
                searchCompleter.updateQuery(newValue)
                showSuggestions = !newValue.isEmpty
            }
            

            // MARK: - TOP BAR: Search
            VStack(spacing: 0) {
                HStack {
                    TextField("Search", text: $searchQuery)
                        .padding(12)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .onChange(of: searchQuery) { newValue in
                            searchCompleter.updateQuery(newValue)
                            showSuggestions = !newValue.isEmpty
                        }
                        .padding(.horizontal)

                    Button("Go") {
                        performSearch()
                    }
                    .padding(.trailing)
                }

                // Autocomplete suggestion list
                if showSuggestions {
                    List(searchCompleter.results, id: \.self) { completion in
                        Button {
                            selectSuggestion(completion)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(completion.title).bold()
                                Text(completion.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 200)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
            .padding(.top, 50)


            // MARK: - BOTTOM TOOLBAR
            VStack {
                Spacer()
                HStack {
                    Button(action: toggleUserLocation) {
                        Label("User", systemImage: "location.circle.fill")
                    }

                    Spacer()

                    Button(action: drawRoute) {
                        Label("Route", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }

                    Spacer()

                    Menu {
                        Button("Standard") { mapStyle = .standard }
                        Button("Imagery") { mapStyle = .imagery }
                        Button("Hybrid") { mapStyle = .hybrid }
                    } label: {
                        Label("Style", systemImage: "map.fill")
                    }
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(16)
                .padding()
            }
        }
    }

    // MARK: - FUNCTIONS

    func performSearch() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.region = .init(center: downtown, latitudinalMeters: 30000, longitudinalMeters: 30000)
        MKLocalSearch(request: request).start { response, error in
            if let items = response?.mapItems {
                searchResults = items
            }
        }
    }

    func loadLookAroundScene() {
        let request = MKLookAroundSceneRequest(coordinate: uCalgary)
        request.getSceneWithCompletionHandler { scene, error in
            if let scene = scene {
                lookAroundScene = scene
            }
        }
    }

    func toggleUserLocation() {
        showUserLocation.toggle()

        if showUserLocation {
            // Center camera on user
            cameraPosition = .userLocation(fallback: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 51.0455, longitude: -114.0729),
                    latitudinalMeters: 30000,
                    longitudinalMeters: 30000
                )
            ))
        } else {
            // Return to Calgary view
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 51.0455, longitude: -114.0729),
                    latitudinalMeters: 30000,
                    longitudinalMeters: 30000
                )
            )
        }
    }
    
    func selectSuggestion(_ completion: MKLocalSearchCompletion) {
        searchQuery = completion.title + " " + completion.subtitle
        showSuggestions = false

        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            if let items = response?.mapItems {
                self.searchResults = items
                if let first = items.first {
                    self.cameraPosition = .region(
                        MKCoordinateRegion(
                            center: first.placemark.coordinate,
                            latitudinalMeters: 2000,
                            longitudinalMeters: 2000
                        )
                    )
                }
            }
        }
    }

    func drawRoute() {
        guard let destination = searchResults.first else { return }
        guard let userLocation = locationManager.lastLocation else {
            print("No user location yet")
            return
        }

        let sourceItem = MKMapItem(location: userLocation, address: nil)
        let destinationItem = MKMapItem(location: destination.location, address: nil)

        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destinationItem
        request.transportType = .automobile

        MKDirections(request: request).calculate { response, error in
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.route = route
                    self.cameraPosition = .region(route.polyline.boundingMapRect.region)
                }
            } else if let error {
                print("Route error:", error.localizedDescription)
            }
        }
    }

}

class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    @Published var results: [MKLocalSearchCompletion] = []
    
    @Published var region: MKCoordinateRegion? {
        didSet {
            if let region {
                completer.region = region
            }
        }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func updateQuery(_ query: String) {
        completer.queryFragment = query
    }

    func completer(_ completer: MKLocalSearchCompleter, didUpdateResults results: [MKLocalSearchCompletion]) {
        self.results = results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Autocomplete error:", error.localizedDescription)
    }
}

class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}



#Preview {
    ContentView()
}

extension MKMapRect {
    var region: MKCoordinateRegion {
        MKCoordinateRegion(self)
    }
}

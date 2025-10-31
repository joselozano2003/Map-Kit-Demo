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
    @State private var selectedDestination: CLLocationCoordinate2D?

    // Coordinates
    let uCalgary = CLLocationCoordinate2D(latitude: 51.07885784940875, longitude: -114.13220927966469)
    let downtown = CLLocationCoordinate2D(latitude: 51.04554792104228, longitude: -114.07295736885621)

    var body: some View {
        ZStack(alignment: .top) {
            // MARK: - MAP VIEW
            MapReader { proxy in
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
                    
                    // Selected destination marker
                    if let selectedDestination = selectedDestination {
                        Annotation("Selected Location", coordinate: selectedDestination) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.green)
                                .font(.title)
                        }
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
                .onTapGesture { screenCoordinate in
                    print("🔵 Map tapped at screen coordinate: \(screenCoordinate)")
                    if let coordinate = proxy.convert(screenCoordinate, from: .local) {
                        print("✅ Converted to map coordinate: \(coordinate)")
                        selectedDestination = coordinate
                        loadLookAroundScene(for: coordinate)
                        
                        // Add haptic feedback to confirm the action
                        #if os(iOS)
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        #endif
                    } else {
                        print("❌ Failed to convert coordinate")
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .overlay(alignment: .bottomLeading) {
                if let _ = lookAroundScene {
                    LookAroundPreview(scene: $lookAroundScene)
                        .frame(width: 230, height: 140)
                        .cornerRadius(10)
                        .padding(8)
                        .allowsHitTesting(false) // Important: prevent blocking taps
                }
            }
            .onAppear {
                loadLookAroundScene()
            }
            

            // MARK: - TOP BAR: Search
            VStack(spacing: 0) {
                HStack {
                    TextField("Search", text: $searchQuery)
                        .padding(12)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)

                    Button("Go") {
                        performSearch()
                    }
                    .padding(.trailing)
                }

                // Autocomplete suggestion list
                if showSuggestions && !searchCompleter.results.isEmpty {
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
                    .shadow(radius: 5)
                }
            }
            .padding(.top, 50)
            .allowsHitTesting(true) // Only allow hits on the search UI


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
            .allowsHitTesting(true) // Only allow hits on the toolbar
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

    func loadLookAroundScene(for coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 51.07885784940875, longitude: -114.13220927966469)) {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        request.getSceneWithCompletionHandler { scene, error in
            DispatchQueue.main.async {
                if let scene = scene {
                    self.lookAroundScene = scene
                } else if let error = error {
                    print("LookAround error: \(error.localizedDescription)")
                }
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
                DispatchQueue.main.async {
                    self.searchResults = items
                    if let first = items.first {
                        let coordinate = first.placemark.coordinate
                        self.selectedDestination = coordinate
                        self.cameraPosition = .region(
                            MKCoordinateRegion(
                                center: coordinate,
                                latitudinalMeters: 2000,
                                longitudinalMeters: 2000
                            )
                        )
                        self.loadLookAroundScene(for: coordinate)
                    }
                }
            }
        }
    }

    func drawRoute() {
        guard let userLocation = locationManager.lastLocation else {
            print("No user location yet")
            return
        }
        
        // Use selected destination first, then fall back to search results
        let destinationCoordinate: CLLocationCoordinate2D?
        if let selected = selectedDestination {
            destinationCoordinate = selected
        } else if let firstResult = searchResults.first {
            destinationCoordinate = firstResult.placemark.coordinate
        } else {
            print("No destination selected")
            return
        }
        
        guard let destCoord = destinationCoordinate else { return }

        let sourceItem = MKMapItem(location: userLocation, address: nil)
        let destinationItem = MKMapItem(placemark: MKPlacemark(coordinate: destCoord))

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
        print("SearchCompleter init started")
        completer.delegate = self
        completer.resultTypes = .address
        // Set initial region to Calgary
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.0455, longitude: -114.0729),
            latitudinalMeters: 30000,
            longitudinalMeters: 30000
        )
        print("SearchCompleter initialized with delegate: \(completer.delegate != nil)")
        print("SearchCompleter initialized with region: Calgary")
    }

    func updateQuery(_ query: String) {
        print("Updating query to: '\(query)'")
        print("Completer delegate is: \(completer.delegate != nil)")
        completer.queryFragment = query
        
        // Let's also try a manual search as a test
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Manual check - completer has \(self.completer.results.count) results")
            if !self.completer.results.isEmpty {
                print("Manual results found, updating...")
                self.results = self.completer.results
            }
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didUpdateResults results: [MKLocalSearchCompletion]) {
        print("DELEGATE CALLED: Received \(results.count) autocomplete results")
        for result in results.prefix(3) {
            print("  - \(result.title): \(result.subtitle)")
        }
        DispatchQueue.main.async {
            self.results = results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("DELEGATE CALLED: Autocomplete error: \(error.localizedDescription)")
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

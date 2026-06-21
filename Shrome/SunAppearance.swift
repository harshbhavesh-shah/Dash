//
//  SunAppearance.swift
//  Shrome
//
//  Created by Harsh Shah on 06/03/2026.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Sunrise/Sunset Math

enum SunCalculator {
    static func sunriseSunset(for date: Date, latitude: Double, longitude: Double) -> (sunrise: Date, sunset: Date)? {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        guard let dayOfYear = utcCalendar.ordinality(of: .day, in: .year, for: date),
              let startOfDayUTC = utcCalendar.dateInterval(of: .day, for: date)?.start else {
            return nil
        }
        let gamma = 2.0 * Double.pi / 365.0 * (Double(dayOfYear) - 1.0)

        let eqTime = 229.18 * (
            0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma)
            - 0.040849 * sin(2 * gamma)
        )

        let decl = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148  * sin(3 * gamma)

        let latRad = latitude * .pi / 180.0
        let zenith = 90.833 * .pi / 180.0

        let cosHourAngle = (cos(zenith) / (cos(latRad) * cos(decl))) - tan(latRad) * tan(decl)

        guard cosHourAngle >= -1, cosHourAngle <= 1 else { return nil }

        let hourAngleDegrees = acos(cosHourAngle) * 180.0 / .pi

        let sunriseMinutesUTC = 720.0 - 4.0 * (longitude + hourAngleDegrees) - eqTime
        let sunsetMinutesUTC  = 720.0 - 4.0 * (longitude - hourAngleDegrees) - eqTime

        let sunrise = startOfDayUTC.addingTimeInterval(sunriseMinutesUTC * 60.0)
        let sunset  = startOfDayUTC.addingTimeInterval(sunsetMinutesUTC * 60.0)

        return (sunrise, sunset)
    }
}

// MARK: - Live Day/Night Tracking
class SunAppearanceManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = SunAppearanceManager()
    @Published private(set) var isNightTime: Bool = false
    @Published private(set) var locationUnavailable = false

    private let locationManager = CLLocationManager()
    private var boundaryTimer: Timer?
    private var hasRequestedLocation = false

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced
    }
    func activate() {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .denied || status == .restricted {
            locationUnavailable = true
        } else {
            locationUnavailable = false
            requestLocationOnce()
        }
    }

    private func requestLocationOnce() {
        guard !hasRequestedLocation else { return }
        hasRequestedLocation = true
        locationManager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            DispatchQueue.main.async { self.locationUnavailable = true }
        } else if status != .notDetermined {
            DispatchQueue.main.async {
                self.locationUnavailable = false
                self.requestLocationOnce()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        DispatchQueue.main.async {
            self.locationUnavailable = false
            self.recompute(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Sunset appearance: location lookup failed — \(error.localizedDescription)")
        // Allow a retry next time Automatic is activated (e.g. Preferences
        // reopened) instead of getting permanently stuck on one failure.
        DispatchQueue.main.async { self.hasRequestedLocation = false }
    }

    private func recompute(latitude: Double, longitude: Double) {
        let now = Date()
        guard let (sunrise, sunset) = SunCalculator.sunriseSunset(for: now, latitude: latitude, longitude: longitude) else {
            return
        }

        isNightTime = now < sunrise || now >= sunset
        scheduleNextBoundary(sunrise: sunrise, sunset: sunset, latitude: latitude, longitude: longitude)
    }

    private func scheduleNextBoundary(sunrise: Date, sunset: Date, latitude: Double, longitude: Double) {
        boundaryTimer?.invalidate()

        let now = Date()
        let nextBoundary: Date
        if now < sunrise {
            nextBoundary = sunrise
        } else if now < sunset {
            nextBoundary = sunset
        } else {
            // Past tonight's sunset — the next flip is tomorrow's sunrise.
            guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
                  let (tomorrowSunrise, _) = SunCalculator.sunriseSunset(for: tomorrow, latitude: latitude, longitude: longitude) else {
                return
            }
            nextBoundary = tomorrowSunrise
        }

        let interval = max(1, nextBoundary.timeIntervalSinceNow)
        boundaryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.recompute(latitude: latitude, longitude: longitude)
        }
    }
}

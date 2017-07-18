//
//  TrackingManager.swift
//  Pods
//
//  Created by boska on 12/07/2017.
//
//

import Foundation
import CoreLocation
import AdSupport

class TrackingManager: NSObject {
  static let shared = TrackingManager()
  let locationManager = CLLocationManager()
  var currentLocation: CLLocation?
  var currentIp: String?
  var events: [[String: Any]] = []
  var currentAdBreak: Vast?
  private override init() {
    super.init()
    getLocation()
    getIp()
    //currentLocation = CLLocation(latitude: 25.032969, longitude: 121.565418)
    //currentIp = "168.95.1.1"
  }
  func track(event: String, vast: Vast) {
    guard
      let adBreak = currentAdBreak,
      let type: String = try? adBreak.value(ofAttribute: "breakType"),
      let offset: String = try? adBreak.value(ofAttribute: "timeOffset")
    else { return }
    var eventPayload: [String: Any] = [
      "event_type": event,
      "inventory_category": [],
      "inventory_tag": [],
      "ad_pos": offset.toTimeInterval
    ]
    
    if let videoId = AdsManager.current?.currentVideoId {
      eventPayload["video_id"] = videoId
    }
    
    if let videoUrl = AdsManager.current?.videoUrlFromPlayer {
      eventPayload["video_url"] = videoUrl
    }
    if type == "linear" {
      eventPayload["ad_format"] = "instream_linear"
      guard let duration = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"]["Duration"].element?.text else { return }
      eventPayload["ad_ts"] = duration.toTimeInterval
      
      guard let mp4 = try? vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"]["MediaFiles"]["MediaFile"].withAttr("type", "video/mp4").element?.text,
        let unwrap = mp4 else { return }
      eventPayload["creative_url"] = unwrap
      vast.linear.track(event: event)
    } else {
      let nonlinear = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["NonLinearAds"]["NonLinear"]
      guard
        let resourceURL = nonlinear["StaticResource"].element?.text,
        let position = try? adBreak["vmap:Extensions"]["vmap:Extension"].withAttr("type", "position"),
        let placement: String = position["placement"].value(ofAttribute: "type"),
        let hPos: String = try? position["horizontal"].value(ofAttribute: "type"),
        let minDuration: String = nonlinear.element?.value(ofAttribute: "minSuggestedDuration")
      else { return }
      eventPayload["ad_format"] = "\(placement)_nonlinear_\(hPos == "center" ? "banner" : "corner")"
      eventPayload["creative_url"] = resourceURL
      eventPayload["ad_ts"] = minDuration.toTimeInterval
      vast.nonlinear.track(event: event)
    }
    events.append(eventPayload)
  }
  func getLocation() {
    if CLLocationManager.locationServicesEnabled() {
      switch CLLocationManager.authorizationStatus() {
      case .authorizedAlways, .authorizedWhenInUse:
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
      default:
        print("Location services are not enabled")
      }
    } else {
      print("Location services are not enabled")
    }
  }
  func getIp() {
    URL(string: "https://api.ipify.org")?.fetch {
      self.currentIp = String(data: $0, encoding: .utf8)
    }
  }
  func flush() {
    if events.isEmpty { return }
    
    var payload = sharedPayload
    payload["events"] = events
    
    if let location = currentLocation {
      payload["geo"] = ["lat": location.coordinate.latitude, "lng": location.coordinate.longitude]
    }
    if let ip = currentIp {
      payload["ip"] = ip
    }
    if let idfa = IDFA.shared.identifier {
      payload["user_id"] = ["type": "idfa", "id": idfa]
    }
    
    guard
      let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
      let body = String(data: data, encoding: .utf8)
    else { return }
    events.removeAll()
    print(body)
  }
  var sharedPayload: [String: Any] = [
    "sdk_version": Bundle.init(for: AdsManager.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
    "sdk": UIDevice.current.systemName,
    "os": [
      "name": UIDevice.current.systemName,
      "version": UIDevice.current.systemVersion
    ],
    "app": [
      "id": Bundle.main.bundleIdentifier ?? "",
      "name": Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "",
      "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    ],
    "device": [
      "id": UIDevice.current.identifierForVendor?.uuidString ?? "",
      "model": UIDevice.current.model,
      "manufacturer": "apple"
    ],
    "locale": Bundle.main.preferredLocalizations.first ?? ""
  ]
}
extension TrackingManager: CLLocationManagerDelegate {
  func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    currentLocation = locations.first
  }
}

class IDFA {
  static let shared = IDFA()
  var limited: Bool {
    return !ASIdentifierManager.shared().isAdvertisingTrackingEnabled
  }
  var identifier: String? {
    guard !limited else { return nil }
    return ASIdentifierManager.shared().advertisingIdentifier.uuidString
  }
}

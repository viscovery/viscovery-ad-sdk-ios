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
import CryptoSwift

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
      eventPayload["creative_url"] = [unwrap]
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
      eventPayload["creative_url"] = [resourceURL]
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
      payload["user"] = ["type": "idfa", "id": idfa]
    }
    
    guard
      let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
      let body = String(data: data, encoding: .utf8)
    else { return }
    
    print(body)

    guard let key = AdsManager.apiKey else { return }
    let secretString = ["A^HJ))jYpL", ")*&NnVvT#s"].sample()
    let secretNumber = ["44357", "84437", "99989"].sample()
    let message = key.substring(with: 1..<9) + secretNumber
    let bytes = Array(message.utf8)
    
    let hmac = try! HMAC(key: secretString, variant: .sha256).authenticate(bytes).toBase64()!

    let url = URL(string: "http://192.168.7.55:9999/v1/app")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = data
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue(key, forHTTPHeaderField: "X-SDK-Key")
    request.addValue(hmac, forHTTPHeaderField: "X-SDK-Auth")

    let task = URLSession.shared.dataTask(with: request) {
      guard
        let response = $1 as? HTTPURLResponse, response.statusCode == 200,
        let _ = $0, $2 == nil
      else { return }
      self.events.removeAll()
    }
    task.resume()
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
    locationManager.stopUpdatingLocation()
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

extension Array {
  func sample() -> Element {
    let index = Int(arc4random_uniform(UInt32(self.count)))
    return self[index]
  }
}

extension String {
  func index(from: Int) -> Index {
    return self.index(startIndex, offsetBy: from)
  }
  
  func substring(from: Int) -> String {
    let fromIndex = index(from: from)
    return substring(from: fromIndex)
  }
  
  func substring(to: Int) -> String {
    let toIndex = index(from: to)
    return substring(to: toIndex)
  }
  
  func substring(with r: Range<Int>) -> String {
    let startIndex = index(from: r.lowerBound)
    let endIndex = index(from: r.upperBound)
    return substring(with: startIndex..<endIndex)
  }
}

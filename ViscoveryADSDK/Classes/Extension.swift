//
//  Extensions.swift
//  ViscoveryADSDK
//
//  Created by boska on 22/06/2017.
//  Copyright © 2017 Viscovery All rights reserved.
//
import AVFoundation
import SWXMLHash

extension CMTime {
  var durationText: String {
    let totalSeconds = CMTimeGetSeconds(self)
    guard !(totalSeconds.isNaN || totalSeconds.isInfinite) else { return "" }
    let hours: Int = Int(totalSeconds / 3600)
    let minutes: Int = Int(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60)
    let seconds: Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))

    if hours > 0 {
      return String(format: "%i:%02i:%02i", hours, minutes, seconds)
    } else {
      return String(format: "%01i:%02i", minutes, seconds)
    }
  }
  var durationTextOnlySeconds: String {
    let totalSeconds = CMTimeGetSeconds(self)
    guard !(totalSeconds.isNaN || totalSeconds.isInfinite) else { return "" }
    let seconds: Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
    return String(format: "%i", seconds)
  }
}
extension AVPlayer {
  var ready: Bool {
    let timeRange = currentItem?.loadedTimeRanges.first as? CMTimeRange
    guard let duration = timeRange?.duration else { return false }
    let timeLoaded = Int(duration.value) / Int(duration.timescale) // value/timescale = seconds
    let loaded = timeLoaded > 0

    return status == .readyToPlay && loaded
  }
}
extension AdsManager {
  public var videoUrlFromPlayer: String? {
    let asset = contentPlayer.currentItem?.asset
    if asset == nil {
      return nil
    }
    if let urlAsset = asset as? AVURLAsset {
      return urlAsset.url.absoluteString
    }
    return nil
  }
}
extension XMLIndexer {
  public var debugDescription: String {
    guard let offset = element?.attribute(by: "timeOffset")?.text else { return "" }
    guard let breakId = element?.attribute(by: "breakId")?.text else { return "" }
    guard let breakType = element?.attribute(by: "breakType")?.text else { return "" }
    guard let url = self["vmap:AdSource"]["vmap:AdTagURI"].element?.text else { return "" }
    return "\(offset) - \(breakId)(\(breakType)) \n\(url)\n\n"
  }
}

extension UIButton {
  func centerTextAndImage(spacing: CGFloat) {
    let insetAmount = spacing / 2
    imageEdgeInsets = UIEdgeInsets(top: 0, left: insetAmount, bottom: 0, right: -insetAmount)
    titleEdgeInsets = UIEdgeInsets(top: 0, left: -insetAmount, bottom: 0, right: insetAmount)
    contentEdgeInsets = UIEdgeInsets(top: 0, left: insetAmount + 8, bottom: 0, right: insetAmount + 16)
  }
}

extension String {
  var toParameters: [String: String] {
    var parameters: [String: String] = [:]
    for kv in components(separatedBy: ",").map({ $0.components(separatedBy: "=") }) {
      guard
        let key = kv.first,
        let value = kv.last
      else { continue }
      parameters[key] = value
    }
    return parameters
  }
}
extension String {
  var toBase64: String {
    return Data(self.utf8).base64EncodedString()
  }
}

extension String {
  var trimmed: String {
    return String(self.characters.filter { !" \n\t\r".characters.contains($0) })
  }
}
extension String {
  var toTimeInterval: TimeInterval {
    guard !self.isEmpty else {
      return 0
    }

    var interval: Double = 0

    let parts = self.components(separatedBy: ":")
    for (index, part) in parts.reversed().enumerated() {
      interval += (Double(part) ?? 0) * pow(Double(60), Double(index))
    }
    return interval
  }
}
extension UIImageView {
  func setImageWith(url: URL, contentMode mode: UIViewContentMode = .scaleAspectFit, completion: ((UIImage) -> ())? = nil) {
    contentMode = mode
    url.fetch {
      guard
        let image = UIImage(data: $0, scale: UIScreen.main.scale)
      else { return }
      DispatchQueue.main.async {
        self.image = image
        completion?(image)
      }
    }
  }
  func setImageWith(link: String, contentMode mode: UIViewContentMode = .scaleAspectFit, completion: ((UIImage) -> ())? = nil) {
    guard let url = URL(string: link) else { return }
    setImageWith(url: url, contentMode: mode, completion: completion)
  }
}
extension URL {
  func fetch(completionHandler: ((Data) -> ())? = nil) {
    print("Request: \(self)")
    URLSession.shared.dataTask(with: self) {
      guard
        let response = $1 as? HTTPURLResponse, response.statusCode == 200,
        let data = $0, $2 == nil
      else { return }
      completionHandler?(data)
    }.resume()
  }
}
extension ClosedRange {
  func clamp(_ value: Bound) -> Bound {
    return lowerBound > value ? lowerBound
      : upperBound < value ? upperBound
      : value
  }
}
extension Vast {
  func impression() {
    guard let impression = self["VAST"]["Ad"]["InLine"]["Impression"].element?.text,
      let url = URL(string: impression) else { return }
    url.fetch()
  }
  func error() {
    guard let error = self["VAST"]["Ad"]["InLine"]["Error"].element?.text,
      let url = URL(string: error) else { return }
    url.fetch()
  }
}

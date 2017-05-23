//
//  ViscoveryADSDK.swift
//  ViscoveryADSDK
//
//  Created by boska on 18/05/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import GoogleInteractiveMediaAds
import SWXMLHash
import SafariServices

typealias Vast = XMLIndexer
@objc public class AdsManager: NSObject {
  public static var apiKey: String?
  let contentPlayer: AVPlayer
  let contentPlayhead: IMAAVPlayerContentPlayhead
  static var adsLoader: IMAAdsLoader!
  var adsManager: IMAAdsManager!
  let contentVideoView: UIView
  let nonLinearView = NonLinearView(frame: .zero)
  let correlator = Int(Date().timeIntervalSince1970)
  var timeObserver: Any?
  var heightConstrain: NSLayoutConstraint?
  public init(player: AVPlayer, videoView: UIView) {
    
    contentPlayer = player
    contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: contentPlayer)
    contentVideoView = videoView
    super.init()
    for v in contentVideoView.subviews.filter({ $0 is NonLinearView }) {
      v.removeFromSuperview()
    }
    contentVideoView.addSubview(nonLinearView)
    
    constrain(nonLinearView, contentVideoView) {
      $0.0.left == $0.1.left
      $0.0.right == $0.1.right
      $0.0.bottom == $0.1.bottom
      $0.0.height == $0.1.height
    }
    
    AdsManager.adsLoader = IMAAdsLoader()
    AdsManager.adsLoader.delegate = self
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(AdsManager.contentDidFinishPlaying(_:)),
      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: contentPlayer.currentItem
    )
  }
  @objc func contentDidFinishPlaying(_ notification: Notification) {
    if (notification.object as! AVPlayerItem) == contentPlayer.currentItem {
      AdsManager.adsLoader.contentComplete()
    }
  }
  public func requestAds(videoURL: String? = nil) {
    guard let videoURL = videoURL ?? videoUrlFromPlayer else {
      print("video url error")
      contentPlayer.play()
      return
    }
    guard let apiKey = AdsManager.apiKey else {
      print("api key is empty")
      contentPlayer.play()
      return
    }
    let url = URL(string: "https://vsp.viscovery.com/api/vmap?api_key=\(apiKey)&video_url=\(videoURL.toBase64)&platform=mobile&debug=0")!
    // let url = URL(string: "http://www.mocky.io/v2/592266c33700000720fa34a9")!
    
    url.fetch {
      guard
        let json = try? JSONSerialization.jsonObject(with: $0, options: .allowFragments) as! [String: AnyObject],
        let vmap = json["context"] as? String
      else {
        self.contentPlayer.play()
        return
      }
      let xml = SWXMLHash.parse(vmap)
      let nonlinears = xml["vmap:VMAP"]["vmap:AdBreak"].all.filter {
        print($0.debugDescription)
        let type: String = try! $0.value(ofAttribute: "breakType")
        return type == "nonlinear"
      }
      
      self.timeObserver = self.createAdTimeObserver(with: nonlinears)
      
      let request = IMAAdsRequest(adsResponse: vmap, adDisplayContainer: IMAAdDisplayContainer(adContainer: self.contentVideoView, companionSlots: nil), contentPlayhead: self.contentPlayhead, userContext: nil)
      AdsManager.adsLoader.requestAds(with: request)
    }
  }
  func createAdTimeObserver(with nonlinears: [Vast]) -> Any? {
    if nonlinears.count == 0 { return nil }
    var times = [NSValue]()
    var timesAds = [Int: String]()
    
    for ad in nonlinears {
      if let offset: String = try? ad.value(ofAttribute: "timeOffset") {
        let time = CMTime(seconds: offset.toTimeInterval, preferredTimescale: 1)
        timesAds[Int(offset.toTimeInterval)] = ad["vmap:AdSource"]["vmap:AdTagURI"].element?.text?.trimmed
        times.append(NSValue(time: time))
      }
    }
    // .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    return contentPlayer.addBoundaryTimeObserver(forTimes: times, queue: .main) {
      let interval = Int(CMTimeGetSeconds(self.contentPlayer.currentTime()))
      guard let tag = timesAds[interval] else { return }
      guard let url = URL(string: tag.replacingOccurrences(of: "[timestamp]", with: "\(self.correlator)")) else { return }
      url.fetch {
        let vast = SWXMLHash.parse($0)
        switch vast["VAST"]["Ad"] {
        case .Element:
          self.handleAd(vast: vast)
        case .XMLError:
          print("Error: Vast is Empty")
        default:
          print("Error: Vast Error")
        }
      }
    }
  }
  
  func handleAd(vast: Vast) {
    let nonlinear = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["NonLinearAds"]["NonLinear"]
    
    guard let error = vast["VAST"]["Ad"]["InLine"]["Error"].element?.text,
      let errorURL = URL(string: error) else {
      return
    }
    guard let resourceURL = nonlinear["StaticResource"].element?.text else {
      errorURL.fetch()
      return
    }
    if let adParameters = nonlinear["AdParameters"].element?.text?.toParameters {
      self.nonLinearView.adParameters = adParameters
    }
    nonLinearView.clickThroughCallback = {
      if let clickThrough = nonlinear["NonLinearClickThrough"].element?.text,
        let clickThroughURL = URL(string: clickThrough),
        let presenter = UIApplication.shared.keyWindow?.rootViewController,
        let clickTracking = nonlinear["NonLinearClickTracking"].element?.text,
        let clickTrackingURL = URL(string: clickTracking)
        {
        presenter.present(SFSafariViewController(url: clickThroughURL), animated: true)
        clickTrackingURL.fetch()
      }
    }
    nonLinearView.setResourceWithURL(url: resourceURL) {
      if let minDuration: String = nonlinear.element?.value(ofAttribute: "minSuggestedDuration") {
        DispatchQueue.main.asyncAfter(deadline: .now() + (minDuration.toTimeInterval == 0 ? 15 : minDuration.toTimeInterval)) {
          self.nonLinearView.isAdHidden = true
        }
      }
      if let impression = vast["VAST"]["Ad"]["InLine"]["Impression"].element?.text,
        let url = URL(string: impression) {
        url.fetch()
      }
      
      if let start = try! vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["NonLinearAds"]["TrackingEvents"]["Tracking"].withAttr("event", "start").element,
        let text = start.text,
        let url = URL(string: text){
        url.fetch()
      }
    }
  }
}
extension AdsManager: IMAAdsManagerDelegate {
  public func adsManager(_ adsManager: IMAAdsManager!, didReceive event: IMAAdEvent!) {
    if event.type == IMAAdEventType.LOADED {
      // When the SDK notifies us that ads have been loaded, play them.
      adsManager.start()
    }
  }
  
  public func adsManager(_: IMAAdsManager!, didReceive error: IMAAdError!) {
    
    // Something went wrong with the ads manager after ads were loaded. Log the error and play the
    // content.
    print("AdsManager error: \(error.message)")
    contentPlayer.play()
  }
  
  public func adsManagerDidRequestContentPause(_: IMAAdsManager!) {
    // The SDK is going to play ads, so pause the content.
    contentPlayer.pause()
  }
  
  public func adsManagerDidRequestContentResume(_: IMAAdsManager!) {
    // The SDK is done playing ads (at least for now), so resume the content.
    contentPlayer.play()
  }
  
}
extension AdsManager: IMAAdsLoaderDelegate {
  public func adsLoader(_: IMAAdsLoader!, adsLoadedWith adsLoadedData: IMAAdsLoadedData!) {
    adsManager = adsLoadedData.adsManager
    adsManager.delegate = self as! IMAAdsManagerDelegate & NSObjectProtocol
    
    // Create ads rendering settings and tell the SDK to use the in-app browser.
    let adsRenderingSettings = IMAAdsRenderingSettings()
    // adsRenderingSettings.webOpenerPresentingController = self
    
    // Initialize the ads manager.
    adsManager.initialize(with: adsRenderingSettings)
  }
  
  public func adsLoader(_: IMAAdsLoader!, failedWith adErrorData: IMAAdLoadingErrorData!) {
    print("Error loading ads: \(adErrorData.adError.message)")
    contentPlayer.play()
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
class ImageView: UIImageView {
  let imageSize = ConstraintGroup()
  override var bounds: CGRect {
    didSet {
      layoutSize()
    }
  }
  override var image: UIImage? {
    didSet {
      layoutSize()
    }
  }
  func layoutSize() {
    guard let image = self.image else { return }
    constrain(self, replace: imageSize) {
      let size = AVMakeRect(aspectRatio: image.size, insideRect: self.frame).size
      $0.width == size.width
      $0.height == size.height
    }
  }
}
class NonLinearView: UIView {
  var isAdHidden = true {
    didSet {
      image.isHidden = isAdHidden
      close.isHidden = isAdHidden
    }
  }
  let image = ImageView()
  let close = UIButton(type: .system)
  let group = ConstraintGroup()
  var adParameters: [String: String] = [:] {
    didSet {
      configureConstrains(with: adParameters)
    }
  }
  override var bounds: CGRect {
    didSet {
      configureConstrains(with: adParameters)
    }
  }
  var clickThroughCallback: (() -> ())?
  func configureConstrains(with adParameters: [String: String]) {
    DispatchQueue.main.async { [image, group] in
      constrain(image, self, replace: group) {
        guard let positionOffset = adParameters["pos_value"] else { return }
        guard let alignOffset = adParameters["align_value"] else { return }
        
        if adParameters["position"] == "bottom" {
          $0.bottom == $1.bottom - CGFloat(Float(positionOffset) ?? 0)
        } else {
          $0.top == $1.top
        }
        guard let align = adParameters["align"] else { return }
        switch align {
        case "left":
          $0.left == $1.left + CGFloat(Float(alignOffset) ?? 0)
        case "right":
          $0.right == $1.right - CGFloat(Float(alignOffset) ?? 0)
        case "center":
          $0.centerX == $1.centerX
        default: break
        }
      }
      guard let heightPercentage = Float(adParameters["height"] ?? "0") else { return }
      constrain(image, replace: self.image.imageSize) {
        $0.width == self.bounds.width
        $0.height == self.bounds.height * CGFloat(heightPercentage * 0.01)
      }
    }
  }
  override init(frame: CGRect) {
    super.init(frame: frame)
    clipsToBounds = true
    image.clipsToBounds = true
    // backgroundColor = #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1).withAlphaComponent(0.5)
    addSubview(image)
    // image.backgroundColor = #colorLiteral(red: 0.9632971883, green: 0.2329196632, blue: 0.0907504186, alpha: 1).withAlphaComponent(0.5)
    constrain(image, self, replace: group) {
      $0.left == $1.left
      $0.bottom == $1.bottom
    }
    
    addSubview(close)
    constrain(close, image) {
      $0.0.left == $0.1.right
      $0.0.top == $0.1.top
      $0.0.height == 44
      $0.0.width == 44
    }
    close.setTitle(" X ", for: .normal)
    close.setTitleColor(.black, for: .normal)
    close.titleLabel?.backgroundColor = .white
    close.contentVerticalAlignment = .top
    close.contentHorizontalAlignment = .left
    close.isHidden = true
    close.addTarget(self, action: #selector(NonLinearView.dismissAds), for: .touchUpInside)
    
    let tap = UITapGestureRecognizer(target: self, action: #selector(NonLinearView.clickThrough))
    image.isUserInteractionEnabled = true
    image.addGestureRecognizer(tap)
  }
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  func setResourceWithURL(url: String, completion: (() -> ())? = nil) {
    image.setImageWith(link: url, contentMode: .scaleAspectFill) { _ in
      self.configureConstrains(with: self.adParameters)
      self.isAdHidden = false
      completion?()
    }
  }
  func dismissAds() {
    close.isHidden = true
    image.isHidden = true
  }
  func clickThrough() {
    clickThroughCallback?()
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

//
//  ViscoveryADSDK.swift
//  ViscoveryADSDK
//
//  Created by boska on 18/05/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import SWXMLHash
import SafariServices
import AVFoundation

typealias Vast = XMLIndexer
@objc public class AdsManager: NSObject {
  public static var apiKey: String?
  let contentPlayer: AVPlayer
  let contentVideoView: UIView
  var outstreamContainer: UIView?
  let instream = NonLinearView(type: .instream)
  public var instreamOffset: CGFloat = 0 {
    didSet {
      self.instream.offset = (0.0...50.0).clamp(instreamOffset)
    }
  }
  let outstream = NonLinearView(type: .outstream)
  let linearView = LinearView()
  let correlator = Int(Date().timeIntervalSince1970)
  var nonlinearTimingObserver: Any?
  var linearTimingObserver: Any?
  public init(player: AVPlayer, videoView: UIView, outstreamContainerView: UIView? = nil) {
    
    contentPlayer = player
    contentVideoView = videoView
    outstreamContainer = outstreamContainerView
    super.init()
    for v in contentVideoView.subviews.filter({ $0 is NonLinearView }) {
      v.removeFromSuperview()
    }
    contentVideoView.addSubview(instream)
    
    constrain(instream, contentVideoView) {
      $0.0.left == $0.1.left
      $0.0.right == $0.1.right
      $0.0.bottom == $0.1.bottom
      $0.0.height == $0.1.height
    }
    
    if let outstreamContainer = outstreamContainer {
      for v in outstreamContainer.subviews.filter({ $0 is NonLinearView }) {
        v.removeFromSuperview()
      }
      outstreamContainer.addSubview(outstream)
      constrain(outstream, outstreamContainer) {
        $0.0.left == $0.1.left
        $0.0.right == $0.1.right
        $0.0.bottom == $0.1.bottom
        $0.0.height == $0.1.height
      }
    }
    
    contentVideoView.addSubview(linearView)
    constrain(linearView, contentVideoView) {
      $0.0.left == $0.1.left
      $0.0.right == $0.1.right
      $0.0.bottom == $0.1.bottom
      $0.0.height == $0.1.height
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
    //let url = URL(string: "http://www.mocky.io/v2/592e7fd8100000dc24d0dd3b")!
    
    url.fetch {
      guard
        let json = try? JSONSerialization.jsonObject(with: $0, options: .allowFragments) as! [String: AnyObject],
        let vmap = json["context"] as? String
      else {
        self.contentPlayer.play()
        return
      }
      let xml = SWXMLHash.parse(vmap)
      
      let linears = xml["vmap:VMAP"]["vmap:AdBreak"].all.filter {
        print($0.debugDescription)
        let type: String = try! $0.value(ofAttribute: "breakType")
        return type == "linear"
      }
      
      self.linearTimingObserver = self.linearTimingObserver(with: linears)
      
      let nonlinears = xml["vmap:VMAP"]["vmap:AdBreak"].all.filter {
          print($0.debugDescription)
          let type: String = try! $0.value(ofAttribute: "breakType")
          return type == "nonlinear"
      }

      self.nonlinearTimingObserver = self.nonlinearTimingObserver(with: nonlinears)
    }
  }
  func linearTimingObserver(with linears: [Vast]) -> Any? {
    var times = [NSValue]()
    var timesAds = [Int: XMLIndexer]()
    for ad in linears {
      if let offset: String = try? ad.value(ofAttribute: "timeOffset") {
        
        if offset == "00:00:00.000" {
          self.fetchAdTagUri(ad: ad, linearType: .preroll)
        } else {
          let time = CMTime(seconds: offset.toTimeInterval, preferredTimescale: 1)
          timesAds[Int(offset.toTimeInterval)] = ad
          times.append(NSValue(time: time))
        }
      }
    }
    return contentPlayer.addBoundaryTimeObserver(forTimes: times, queue: .main) {
      let interval = Int(CMTimeGetSeconds(self.contentPlayer.currentTime()))
      guard let ad = timesAds[interval] else { return }
      self.fetchAdTagUri(ad: ad, linearType: .midroll)
    }
  }
  func nonlinearTimingObserver(with nonlinears: [Vast]) -> Any? {
    if nonlinears.count == 0 { return nil }
    var times = [NSValue]()
    var timesAds = [Int: XMLIndexer]()
    
    for ad in nonlinears {
      if let offset: String = try? ad.value(ofAttribute: "timeOffset") {
            let time = CMTime(seconds: offset.toTimeInterval, preferredTimescale: 1)
            timesAds[Int(offset.toTimeInterval)] = ad
            times.append(NSValue(time: time))
      }
    }

    return contentPlayer.addBoundaryTimeObserver(forTimes: times, queue: .main) {
      let interval = Int(CMTimeGetSeconds(self.contentPlayer.currentTime()))
      guard let ad = timesAds[interval] else { return }
      self.fetchAdTagUri(ad: ad)
    }
  }
  func fetchAdTagUri(ad: Vast, linearType: AdType? = nil) {
    guard let tag = ad["vmap:AdSource"]["vmap:AdTagURI"].element?.text?.trimmed else { return }
    guard let url = URL(string: tag.replacingOccurrences(of: "[timestamp]", with: "\(self.correlator)")) else { return }
    guard let type: String =  try? ad["vmap:Extensions"]["vmap:Extension"].element!.value(ofAttribute: "type") else { return }
    url.fetch { [type, linearType] in
      let vast = SWXMLHash.parse($0)
      switch vast["VAST"]["Ad"] {
      case .Element:
        if let linearType = linearType {
          self.handleLinearAd(vast: vast, type: linearType)
        } else {
          self.handleNonLinearAd(vast: vast, type: type)
        }
      case .XMLError:
        print("Error: Vast is Empty")
      default:
        print("Error: Vast Error")
      }
    }
  }
  func handleLinearAd(vast: Vast, type: AdType) {
    guard let mp4 = try? vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"]["MediaFiles"]["MediaFile"].withAttr("type", "video/mp4").element?.text,
      let unwrap = mp4,
      let url = URL(string:unwrap) else { return }
    
    let player = AVPlayer(url: url)
    linearView.player = player
    contentPlayer.pause()
    linearView.isHidden = false
    linearView.skip.isHidden = false
    player.play()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(AdsManager.adDidFinishPlaying),
      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: linearView.player?.currentItem
    )
    linearView.skipDidTapHandler = {
      self.linearView.player?.pause()
      self.linearView.isHidden = true
      self.contentPlayer.play()
    }
    linearView.learnMoreDidTapHandler = { [vast] in
      guard
        let clickThrough = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"]["VideoClicks"]["ClickThrough"].element?.text,
        let clickTracking = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"]["VideoClicks"]["ClickTracking"].element?.text,
        let clickThroughURL = URL(string: clickThrough),
        let clickTrackingURL = URL(string: clickTracking),
        let presenter = UIApplication.shared.keyWindow?.rootViewController
      else { return }
      
      presenter.present(SFSafariViewController(url: clickThroughURL), animated: true)
      clickTrackingURL.fetch()
      
      self.linearView.player?.pause()
      self.linearView.isHidden = true
    }
    guard let skipoffset: String = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"].element?.value(ofAttribute: "skipoffset") else { return }
    let skipTime = CMTime(seconds: skipoffset.toTimeInterval, preferredTimescale: 1)

    linearView.player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1) , queue: .main) { _ in
      guard let player = self.linearView.player ,
        let current = player.currentItem
        else { return }
      
      if player.currentTime() > skipTime {
        self.linearView.skip.isEnabled = true
        self.linearView.skip.setImage(UIImage(named: "skip", in:  Bundle(for: LinearView.self), compatibleWith: nil), for: .normal)
        self.linearView.skip.setTitle("Skip Ad", for: .normal)
      } else {
        self.linearView.skip.isEnabled = false
        self.linearView.skip.setImage(nil, for: .normal)
        self.linearView.skip.setTitle("You can skip ad in \((skipTime - player.currentTime()).durationTextOnlySeconds)s", for: .normal)
      }
      self.linearView.duration.text = "Ad · " + (current.duration - player.currentTime()).durationText
    }
    linearView.player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60) , queue: .main) { _ in
      guard let player = self.linearView.player ,
        let current = player.currentItem
        else { return }
      let progress = CGFloat(CMTimeGetSeconds(player.currentTime()) / CMTimeGetSeconds(current.duration))
      guard !(progress.isNaN || progress.isInfinite) else { return }
      self.linearView.updateBar(progress: (0.0...1.0).clamp(progress))
    }
  }
  func adDidFinishPlaying() {
    linearView.isHidden = true;
    contentPlayer.play()
  }
  func handleNonLinearAd(vast: Vast, type: String) {
    let nonlinear = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["NonLinearAds"]["NonLinear"]
    let nonlinearView = type == "instream" ? instream : outstream
    guard let error = vast["VAST"]["Ad"]["InLine"]["Error"].element?.text,
      let errorURL = URL(string: error) else {
      return
    }
    guard let resourceURL = nonlinear["StaticResource"].element?.text else {
      errorURL.fetch()
      return
    }
    if let adParameters = nonlinear["AdParameters"].element?.text?.toParameters {
      nonlinearView.adParameters = adParameters
    }
    nonlinearView.clickThroughCallback = {
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
    nonlinearView.setResourceWithURL(url: resourceURL) {
      if let minDuration: String = nonlinear.element?.value(ofAttribute: "minSuggestedDuration") {
        DispatchQueue.main.asyncAfter(deadline: .now() + (minDuration.toTimeInterval == 0 ? 15 : minDuration.toTimeInterval)) {
          nonlinearView.isAdHidden = true
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
extension CMTime {
  var durationText: String {
    let totalSeconds = CMTimeGetSeconds(self)
    guard !(totalSeconds.isNaN || totalSeconds.isInfinite) else { return "" }
    let hours:Int = Int(totalSeconds / 3600)
    let minutes:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 3600) / 60)
    let seconds:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
    
    if hours > 0 {
      return String(format: "%i:%02i:%02i", hours, minutes, seconds)
    } else {
      return String(format: "%01i:%02i", minutes, seconds)
    }
  }
  var durationTextOnlySeconds: String {
    let totalSeconds = CMTimeGetSeconds(self)
    guard !(totalSeconds.isNaN || totalSeconds.isInfinite) else { return "" }
    let seconds:Int = Int(totalSeconds.truncatingRemainder(dividingBy: 60))
    return String(format: "%i", seconds)
  }
}
extension AVPlayer {
  var ready:Bool {
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
enum AdType {
  case instream
  case outstream
  case preroll
  case midroll
}
class LinearView: UIView {
  let learnMore = UIButton(type: .custom)
  let skip = UIButton(type: .custom)
  let progress = UIView()
  let progressBackground = UIView()
  let progressLayout = ConstraintGroup()
  var skipDidTapHandler: (()->())? = nil
  var learnMoreDidTapHandler: (()->())? = nil

  var duration = UILabel()

  var player: AVPlayer? {
    set {
      (self.layer as! AVPlayerLayer).player = newValue
    }
    get {
      return (self.layer as! AVPlayerLayer).player
    }
  }
  override class var layerClass: AnyClass {
    return AVPlayerLayer.self
  }
  convenience init() {
    self.init(frame: .zero)
    addSubview(skip)
    constrain(skip,self) {
      $0.right == $1.right
      $0.bottom == $1.bottom - 36
      $0.height == 25
    }
    skip.setTitleColor(.white, for: .normal)
    skip.titleLabel?.font = UIFont.systemFont(ofSize: 12)
    skip.setTitle("", for: .normal)
    skip.semanticContentAttribute = .forceRightToLeft
    skip.backgroundColor = #colorLiteral(red: 0.1019607843, green: 0.03921568627, blue: 0.03921568627, alpha: 0.4)
    skip.addTarget(self, action: #selector(LinearView.skipDidTap), for: .touchUpInside)
    skip.isHidden = true
    skip.centerTextAndImage(spacing: 8)
    
    backgroundColor = .black
    
    addSubview(learnMore)
    constrain(learnMore,self) {
      $0.top == $1.top + 10
      $0.right == $1.right
      $0.height == 48
      $0.width == 160
    }
    
    learnMore.setTitleColor(.white, for: .normal)
    let title = NSAttributedString(string: "Learn More", attributes: [NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue, NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: UIFont.systemFont(ofSize: 14)])
    learnMore.setAttributedTitle(title, for: .normal)
    learnMore.setImage(UIImage(named: "more", in:  Bundle(for: LinearView.self), compatibleWith: nil), for: .normal)
    learnMore.semanticContentAttribute = .forceRightToLeft
    learnMore.centerTextAndImage(spacing: 8)
    learnMore.contentVerticalAlignment = .top
    learnMore.contentHorizontalAlignment = .right
    learnMore.addTarget(self, action: #selector(LinearView.learnMoreDidTap), for: .touchUpInside)

    addSubview(duration)
    constrain(duration,self) {
      $0.left == $1.left + 8
      $0.bottom == $1.bottom - 9
    }
    duration.textColor = .white
    duration.text = ""
    duration.font = UIFont.systemFont(ofSize: 12)
    
    progressBackground.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.6)
    addSubview(progressBackground)
    constrain(progressBackground,self) {
      $0.height == 4
      $0.left == $1.left
      $0.right == $1.right
      $0.bottom == $1.bottom
    }
    
    progress.backgroundColor = #colorLiteral(red: 0.998096168, green: 0.7577474117, blue: 0.003219177248, alpha: 1)
    progressBackground.addSubview(progress)
    updateBar(progress: 0.0)
    
    let tap = UITapGestureRecognizer(target: self, action: #selector(LinearView.tap))
    addGestureRecognizer(tap)

  }
  func skipDidTap() {
    skipDidTapHandler?()
  }
  func learnMoreDidTap() {
    learnMoreDidTapHandler?()
  }
  func updateBar(progress: CGFloat) {
    constrain(self.progress,self.progressBackground, replace: progressLayout) {
      $0.left == $1.left
      $0.top == $1.top
      $0.bottom == $1.bottom
      $0.width == $1.width * progress
    }
  }
  func tap() {
    player?.rate == 1.0 ? player?.pause() : player?.play()
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
  var close: UIButton!
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
  var offset: CGFloat = 0.0 {
    didSet {
      configureConstrains(with: adParameters)
    }
  }
  var clickThroughCallback: (() -> ())?
  func configureConstrains(with adParameters: [String: String]) {
    DispatchQueue.main.async { [image, group] in
      constrain(image, self, replace: group) {
        //let offset = self.offset
        guard let positionOffset = adParameters["pos_value"] else { return }
        guard let alignOffset = adParameters["align_value"] else { return }
        
        if adParameters["position"] == "bottom" {
          $0.bottom == $1.bottom - ( CGFloat(Float(positionOffset) ?? 0) + self.offset )
        } else {
          $0.top == $1.top + self.offset
        }
        guard let align = adParameters["align"] else { return }
        switch align {
        case "left":
          $0.left == $1.left + CGFloat(Float(alignOffset) ?? 0)
        case "right":
          $0.right == $1.right - CGFloat(Float(alignOffset) ?? 0)
        case "center", "fullwidth":
          $0.centerX == $1.centerX
        default: break
        }
      }
      guard let heightPercentage = Float(adParameters["height"] ?? "100") else { return }
      constrain(image, replace: self.image.imageSize) {
        $0.width == self.bounds.width
        $0.height == self.bounds.height * CGFloat(heightPercentage * 0.01)
      }
    }
  }
  convenience init(type: AdType) {
    self.init(frame: .zero)
    close = UIButton(type: .custom)
    close.setImage(UIImage(named: "close", in:  Bundle(for: LinearView.self), compatibleWith: nil), for: .normal)
    clipsToBounds = true
    image.clipsToBounds = true
    addSubview(image)
    constrain(image, self, replace: group) {
      $0.left == $1.left
      $0.bottom == $1.bottom
    }
    
    addSubview(close)
    constrain(close, image) {
      $0.0.left == $0.1.left
      $0.0.top == $0.1.top
      $0.0.height == 20
      $0.0.width == 20
    }
    
    close.isHidden = true
    close.addTarget(self, action: #selector(NonLinearView.dismissAds), for: .touchUpInside)
    
    let tap = UITapGestureRecognizer(target: self, action: #selector(NonLinearView.clickThrough))
    image.isUserInteractionEnabled = true
    image.addGestureRecognizer(tap)

  }
  override init(frame: CGRect) {
    super.init(frame: frame)
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
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    for subview in subviews {
      if !subview.isHidden && subview.alpha > 0 && subview.isUserInteractionEnabled && subview.point(inside: convert(point, to: subview), with: event) {
        return true
      }
    }
    return false
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
extension UIButton {
  func centerTextAndImage(spacing: CGFloat) {
    let insetAmount = spacing / 2
    imageEdgeInsets = UIEdgeInsets(top: 0, left: insetAmount, bottom: 0, right: -insetAmount)
    titleEdgeInsets = UIEdgeInsets(top: 0, left: -insetAmount, bottom: 0, right: insetAmount)
    contentEdgeInsets = UIEdgeInsets(top: 0, left: insetAmount + 8, bottom: 0, right: insetAmount + 16)
  }
}
class CloseButton: UIButton {
  override func draw(_ rect: CGRect) {
    //// Oval Drawing
    let dx = (rect.size.width - 20) / 2
    let dy = (rect.size.width - 20) / 2
    let ovalPath = UIBezierPath(ovalIn: CGRect(x: dx + 0.5, y: dy + 0.5, width: 20, height: 20))
    UIColor.black.setFill()
    ovalPath.fill()
    UIColor.white.setStroke()
    ovalPath.lineWidth = 1
    ovalPath.stroke()
    
    
    //// Bezier Drawing
    let bezierPath = UIBezierPath()
    bezierPath.move(to: CGPoint(x: dx + 6.5, y: dy + 6.5))
    bezierPath.addLine(to: CGPoint(x: dx + 14.5, y: dy + 14.5))
    UIColor.white.setStroke()
    bezierPath.lineWidth = 1
    bezierPath.stroke()
    
    
    //// Bezier 2 Drawing
    let bezier2Path = UIBezierPath()
    bezier2Path.move(to: CGPoint(x: dx + 14.5, y: dy + 6.5))
    bezier2Path.addLine(to: CGPoint(x: dx + 6.5, y: dy + 14.5))
    UIColor.white.setStroke()
    bezier2Path.lineWidth = 1
    bezier2Path.stroke()

  }
}
class SquareCloseButton: UIButton {
  override func draw(_ rect: CGRect) {
    let color = UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 1.000)
    
    //// Rectangle Drawing
    let rectanglePath = UIBezierPath(rect: CGRect(x: 1, y: 1, width: rect.width - 1, height: rect.height - 1))
    color.setFill()
    rectanglePath.fill()
    UIColor.white.setStroke()
    rectanglePath.lineWidth = 1
    rectanglePath.stroke()
    
    
    //// Bezier Drawing
    let bezierPath = UIBezierPath()
    bezierPath.move(to: CGPoint(x: 3, y: 11.5))
    bezierPath.addLine(to: CGPoint(x: 11.5, y: 3))
    color.setFill()
    bezierPath.fill()
    UIColor.white.setStroke()
    bezierPath.lineWidth = 1
    bezierPath.stroke()
    
    
    //// Bezier 2 Drawing
    let bezier2Path = UIBezierPath()
    bezier2Path.move(to: CGPoint(x: 3, y: 3))
    bezier2Path.addLine(to: CGPoint(x: 11.5, y: 11.5))
    color.setFill()
    bezier2Path.fill()
    UIColor.white.setStroke()
    bezier2Path.lineWidth = 1
    bezier2Path.stroke()

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
  func clamp(_ value : Bound) -> Bound {
    return self.lowerBound > value ? self.lowerBound
      : self.upperBound < value ? self.upperBound
      : value
  }
}

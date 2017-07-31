//
//  ViscoveryADSDK.swift
//  ViscoveryADSDK
//
//  Created by boska on 18/05/2017.
//  Copyright © 2017 Viscovery All rights reserved.
//

import Foundation
import SWXMLHash
import SafariServices
import AVFoundation

typealias Vast = XMLIndexer

enum AdType {
  case instream
  case outstream
}

@objc public class AdsManager: NSObject {
  public static var apiKey: String?
  public static var debug = false
  public static var current: AdsManager?
  public var instreamOffset: CGFloat = 0 {
    didSet {
      self.instream.offset = (0.0...50.0).clamp(instreamOffset)
    }
  }
  let contentPlayer: AVPlayer
  let contentVideoView: UIView
  var outstreamContainer: UIView?
  let instream = NonLinearView(type: .instream)
  let outstream = NonLinearView(type: .outstream)
  let linearView = LinearView()
  let correlator = Int(Date().timeIntervalSince1970)
  var adBreakTimeObservers: Any?
  var currentVideoId: String?
  let linearAdCountDown = UILabel()
  public init(player: AVPlayer, videoView: UIView, outstreamContainerView: UIView? = nil) {
    contentPlayer = player
    contentVideoView = videoView
    outstreamContainer = outstreamContainerView
    super.init()
    AdsManager.current = self
    
    for v in contentVideoView.subviews.filter({ $0 is NonLinearView }) {
      v.removeFromSuperview()
    }
    contentVideoView.addSubview(instream)
    
    constrain(instream, contentVideoView) {
      $0.edges == $1.edges
    }
    
    contentVideoView.addSubview(linearView)
    constrain(linearView, contentVideoView) {
      $0.edges == $1.edges
    }
    
    contentVideoView.addSubview(linearAdCountDown)
    linearAdCountDown.textColor = .white
    linearAdCountDown.font = UIFont.systemFont(ofSize: 12)
    constrain(linearAdCountDown, contentVideoView) {
      $0.left == $1.left
      $0.bottom == $1.bottom - instreamOffset
    }
    guard let outstreamContainer = outstreamContainer else { return }
    for v in outstreamContainer.subviews.filter({ $0 is NonLinearView }) {
      v.removeFromSuperview()
    }
    outstreamContainer.addSubview(outstream)
    constrain(outstream, outstreamContainer) {
      $0.edges == $1.edges
    }
  }
  public func requestAds(videoURL: String? = nil) {
    guard let videoURL = videoURL ?? videoUrlFromPlayer?.toBase64 else {
      print("video url error")
      self.adDidFinishPlaying()
      return
    }
    guard let apiKey = AdsManager.apiKey else {
      print("api key is empty")
      self.adDidFinishPlaying()
      return
    }
    
    let endpoint = "https://\(AdsManager.debug ? "vsp-test" :  "vsp").viscovery.com/tag2ad/webapi/ads/v1/vmap?video_id=\(videoURL)&platform=mobile&api_key=\(apiKey)&cache=\(AdsManager.debug ? "0" :  "1")"
    // let url = URL(string: "http://www.mocky.io/v2/592e7fd8100000dc24d0dd3b")!
    
    currentVideoId = videoURL
    
    let url = URL(string: endpoint)!
    url.fetch(closeAdWhenError: true) {
      guard
        let json = try? JSONSerialization.jsonObject(with: $0, options: .allowFragments) as! [String: AnyObject],
        let vmap = json["context"] as? String
      else {
        self.adDidFinishPlaying()
        return
      }
      self.requestAdWith(vmap: vmap)
    }
  }
  public func requestAdWith(vmap: String) {
    let xml = SWXMLHash.parse(vmap)
    adBreakTimeObservers = createAdBreakTimeObservers(adBreaks: xml["vmap:VMAP"]["vmap:AdBreak"].all)
  }
  public func requestAdWith(vast: String) {
    let adBreak = SWXMLHash.parse(vast)
    fetchAdTagUri(adBreak: adBreak)
  }
  func createAdBreakTimeObservers(adBreaks: [Vast]) -> Any? {
    var times = [NSValue]()
    var timesAds = [Int: XMLIndexer]()
    var linearTimes = [NSValue]()
    for adBreak in adBreaks {
      guard
        let type: String = try? adBreak.value(ofAttribute: "breakType"),
        let offset: String = try? adBreak.value(ofAttribute: "timeOffset")
      else { continue }
      if type == "linear" && offset.toTimeInterval == 0.0 {
        fetchAdTagUri(adBreak: adBreak)
      } else {
        let time = CMTime(seconds: offset.toTimeInterval, preferredTimescale: 1)
        timesAds[Int(offset.toTimeInterval)] = adBreak
        times.append(NSValue(time: time))
        if type == "linear" {
          linearTimes.append(NSValue(time: time))
        }
      }
    }
    contentPlayer.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1), queue: .main) { _ in
      self.linearAdCountDown.isHidden = true
      guard let nearestLinear = linearTimes.filter({ $0.timeValue > self.contentPlayer.currentTime()}).first else {
        return
      }
      let countDown = CMTimeGetSeconds(nearestLinear.timeValue - self.contentPlayer.currentTime())
      if countDown <= 10 {
        self.linearAdCountDown.isHidden = false
        self.linearAdCountDown.text = "Ad Starts in \(Int(countDown))s"
      }
    }

    return contentPlayer.addBoundaryTimeObserver(forTimes: times, queue: .main) {
      let interval = Int(CMTimeGetSeconds(self.contentPlayer.currentTime()))
      guard
        let adBreak = timesAds[interval]
      else { return }
      self.fetchAdTagUri(adBreak: adBreak)
    }
  }
  func fetchAdTagUri(adBreak: Vast) {
    TrackingManager.shared.currentAdBreak = adBreak
    guard
      let tag = adBreak["vmap:AdSource"]["vmap:AdTagURI"].element?.text?.trimmed,
      let type: String = try? adBreak.value(ofAttribute: "breakType"),
      let url = URL(string: tag.replacingOccurrences(of: "[timestamp]", with: "\(self.correlator)"))
    else {
      self.adDidFinishPlaying()
      return
    }
    url.fetch(closeAdWhenError: true) { [type] in
      let vast = SWXMLHash.parse($0)
      switch vast["VAST"]["Ad"] {
      case .Element:
        type == "nonlinear" ? self.handleNonLinearAd(vast: vast, extensions: adBreak["vmap:Extensions"]) : self.handleLinearAd(vast: vast)
      default:
        print("Error: Vast Error")
        self.adDidFinishPlaying()
      }
    }
  }
  func handleLinearAd(vast: Vast) {
    guard let mp4 = try? vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"]["MediaFiles"]["MediaFile"].withAttr("type", "video/mp4").element?.text,
      let unwrap = mp4,
      let url = URL(string: unwrap) else { return }
    
    contentPlayer.pause()
    
    let item = AVPlayerItem(url: url)
    let player = AVPlayer(playerItem: item)
    linearView.videoView.player = player
    linearView.videoView.player?.play()
    
    delay(15) { [player] in
      if player.currentItem?.status == .failed {
        self.adDidFinishPlaying()
      }
    }
    TrackingManager.shared.track(event: "start", vast: vast)
    
    DispatchQueue.main.async {
      self.linearView.isHidden = false
      vast.tracking.impression()
    }
    linearView.skip.isHidden = false
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(AdsManager.adDidFinishPlaying),
      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: linearView.videoView.player?.currentItem
    )
    linearView.skipDidTapCallback = {
      self.adDidFinishPlaying()
      TrackingManager.shared.track(event: "skip", vast: vast)
    }
    linearView.learnMoreDidTapCallback = { [vast] in
      guard
        let clickThrough = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"]["VideoClicks"]["ClickThrough"].element?.text,
        let clickTracking = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"]["VideoClicks"]["ClickTracking"].element?.text,
        let clickThroughURL = URL(string: clickThrough),
        let clickTrackingURL = URL(string: clickTracking),
        let presenter = UIApplication.shared.keyWindow?.rootViewController
      else { return }
      
      presenter.present(SFSafariViewController(url: clickThroughURL), animated: true)
      clickTrackingURL.fetch()
      
      self.linearView.videoView.player?.pause()
    }
    linearView.didPauseCallback = { [vast] in
      TrackingManager.shared.track(event: "pause", vast: vast)
    }
    linearView.didPlayCallback = { [vast] in
      TrackingManager.shared.track(event: "resume", vast: vast)

    }
    guard let skipoffset: String = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"].element?.value(ofAttribute: "skipoffset") else { return }
    addSkipPointTimeObserver(skipOffset: skipoffset)
    addProgressBarTimeObserver()
    addTrackingTimeObserver(vast: vast)
  }
  func addTrackingTimeObserver(vast: Vast) {
    var currentTime = kCMTimeZero
    guard let asset = linearView.videoView.player?.currentItem?.asset else { return }
    let interval = CMTimeMultiplyByFloat64(asset.duration, 0.25)
    let trackingSequence = ["firstQuartile", "midpoint", "thirdQuartile", "complete"]
    var index = 0
    while currentTime < asset.duration {
      currentTime = currentTime + interval
      linearView.videoView.player?.addBoundaryTimeObserver(forTimes: [NSValue(time:currentTime)], queue: .main) { [index] time in
        if index < trackingSequence.count {
          TrackingManager.shared.track(event: trackingSequence[index], vast: vast)
        }
      }
      index = index + 1
    }
  }
  func addSkipPointTimeObserver(skipOffset: String) {
    let skipTime = CMTime(seconds: skipOffset.toTimeInterval, preferredTimescale: 1)
    
    linearView.videoView.player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1), queue: .main) { _ in
      guard let player = self.linearView.videoView.player,
        let current = player.currentItem
        else { return }
      
      if player.currentTime() > skipTime {
        self.linearView.skip.isEnabled = true
        self.linearView.skip.setImage(UIImage(named: "skip", in: Bundle(for: LinearView.self), compatibleWith: nil), for: .normal)
        self.linearView.skip.setTitle("Skip Ad", for: .normal)
      } else {
        self.linearView.skip.isEnabled = false
        self.linearView.skip.setImage(nil, for: .normal)
        self.linearView.skip.setTitle("You can skip ad in \((skipTime - player.currentTime()).durationTextOnlySeconds)s", for: .normal)
      }
      self.linearView.duration.text = "Ad · " + (current.duration - player.currentTime()).durationText
    }
  }
  func addProgressBarTimeObserver() {
    linearView.videoView.player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { _ in
      guard let player = self.linearView.videoView.player,
        let current = player.currentItem
        else { return }
      let progress = CGFloat(CMTimeGetSeconds(player.currentTime()) / CMTimeGetSeconds(current.duration))
      guard !(progress.isNaN || progress.isInfinite) else { return }
      self.linearView.updateBar(progress: (0.0...1.0).clamp(progress))
    }
  }
  func adDidFinishPlaying() {
    DispatchQueue.main.async {
      self.linearView.isHidden = true
    }
    self.linearView.videoView.player?.pause()
    contentPlayer.play()
    TrackingManager.shared.flush()
  }
  func handleNonLinearAd(vast: Vast, extensions: XMLIndexer) {
    let nonlinear = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["NonLinearAds"]["NonLinear"]
    guard
      let resourceURL = nonlinear["StaticResource"].element?.text,
      let position = try? extensions["vmap:Extension"].withAttr("type", "position"),
      let placement: String = position["placement"].value(ofAttribute: "type")
    else {
      vast.tracking.error()
      return
    }
    
    let nonlinearView = placement == "instream" ? instream : outstream
    nonlinearView.extensions = extensions
    nonlinearView.clickThroughCallback = {
      if let clickThrough = nonlinear["NonLinearClickThrough"].element?.text,
        let clickThroughURL = URL(string: clickThrough),
        let presenter = UIApplication.shared.keyWindow?.rootViewController,
        let clickTracking = nonlinear["NonLinearClickTracking"].element?.text,
        let clickTrackingURL = URL(string: clickTracking) {
        presenter.present(SFSafariViewController(url: clickThroughURL), animated: true)
        clickTrackingURL.fetch()
        self.contentPlayer.pause()
      }
    }
    nonlinearView.closeCallback = {
      TrackingManager.shared.track(event: "close", vast: vast)
      self.adDidFinishPlaying()
    }
    nonlinearView.setResourceWithURL(url: resourceURL) {
      if let minDuration: String = nonlinear.element?.value(ofAttribute: "minSuggestedDuration") {
        DispatchQueue.main.asyncAfter(deadline: .now() + (minDuration.toTimeInterval == 0 ? 15 : minDuration.toTimeInterval)) {
          nonlinearView.isAdHidden = true
          TrackingManager.shared.track(event: "complete", vast: vast)
          self.adDidFinishPlaying()
        }
      }
      vast.tracking.impression()
      TrackingManager.shared.track(event: "start", vast: vast)
      TrackingManager.shared.track(event: "creativeView", vast: vast)
    }
  }
}

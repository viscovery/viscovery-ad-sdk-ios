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
  case preroll
  case midroll
}

@objc public class AdsManager: NSObject {
  public static var apiKey: String?
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
      $0.edges == $1.edges
    }
    
    contentVideoView.addSubview(linearView)
    constrain(linearView, contentVideoView) {
      $0.edges == $1.edges
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
    // let url = URL(string: "http://www.mocky.io/v2/592e7fd8100000dc24d0dd3b")!
    
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
    guard let type: String = try? ad["vmap:Extensions"]["vmap:Extension"].element!.value(ofAttribute: "type") else { return }
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
  func handleLinearAd(vast: Vast, type _: AdType) {
    guard let mp4 = try? vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"]["MediaFiles"]["MediaFile"].withAttr("type", "video/mp4").element?.text,
      let unwrap = mp4,
      let url = URL(string: unwrap) else { return }
    
    contentPlayer.pause()
    
    let player = AVPlayer(url: url)
    linearView.videoView.player = player
    linearView.videoView.player?.play()
    
    DispatchQueue.main.async {
      self.linearView.isHidden = false
    }
    linearView.skip.isHidden = false
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(AdsManager.adDidFinishPlaying),
      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: linearView.videoView.player?.currentItem
    )
    linearView.skipDidTapHandler = {
      self.linearView.videoView.player?.pause()
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
      
      self.linearView.videoView.player?.pause()
    }
    guard let skipoffset: String = vast["VAST"]["Ad"]["InLine"]["Creatives"]["Creative"]["Linear"].element?.value(ofAttribute: "skipoffset") else { return }
    let skipTime = CMTime(seconds: skipoffset.toTimeInterval, preferredTimescale: 1)
    
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
    linearView.isHidden = true
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
        let clickTrackingURL = URL(string: clickTracking) {
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
        let url = URL(string: text) {
        url.fetch()
      }
    }
  }
}

//
//  VideoView.swift
//  ViscoveryADSDK
//
//  Created by boska on 26/04/2017.
//  Copyright © 2017 Viscovery All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class VideoView: UIView {
  @IBOutlet weak var seekbar: UISlider! {
    didSet {
      seekbar.setThumbImage(#imageLiteral(resourceName: "thumb"), for: .normal)
    }
  }
  var player: AVPlayer? {
    set {
      (self.layer as! AVPlayerLayer).player = newValue
      newValue?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60) , queue: .main) { _ in
        guard let player = (self.layer as! AVPlayerLayer).player,
              let current = player.currentItem
          else { return }
        self.seekbar.value = Float(CMTimeGetSeconds(player.currentTime()) / CMTimeGetSeconds(current.duration))
      }
    }
    get {
      return (self.layer as! AVPlayerLayer).player
    }
  }
  override class var layerClass: AnyClass {
    return AVPlayerLayer.self
  }
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    let tap = UITapGestureRecognizer(target: self, action: #selector(VideoView.tap))
    addGestureRecognizer(tap)
  }
  @IBAction func update(sender: UISlider) {
    guard let player = (self.layer as! AVPlayerLayer).player,
      let current = player.currentItem
      else { return }
    let time = CMTimeMakeWithSeconds( Double(sender.value) * current.duration.seconds, player.currentTime().timescale)
    player.seek(to: time)
  }
  func tap() {
    player?.rate == 1.0 ? player?.pause() : player?.play()
    //seekbar.isHidden = player?.rate == 1.0
  }
}

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
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    let tap = UITapGestureRecognizer(target: self, action: #selector(VideoView.tap))
    addGestureRecognizer(tap)
  }
  func tap() {
    player?.rate == 1.0 ? player?.pause() : player?.play()
  }
}

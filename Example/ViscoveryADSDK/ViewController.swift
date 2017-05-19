//
//  ViewController.swift
//  ViscoveryADSDK
//
//  Created by boska on 05/19/2017.
//  Copyright (c) 2017 boska. All rights reserved.
//

import UIKit
import ViscoveryADSDK
import AVFoundation

class ViewController: UIViewController {
  @IBOutlet weak var videoContainer: VideoView!
  var contentPlayer: AVPlayer?
  var adsManager: AdsManager!
  override func viewDidLoad() {
    super.viewDidLoad()
    guard let contentURL = URL(string: "http://viscovery-vsp-dev.s3.amazonaws.com/sdkdemo/Videos/Mobile%20App_Demo%20Video%20(540p).mp4") else { return }
    contentPlayer = AVPlayer(url: contentURL)
    videoContainer.player = contentPlayer
    adsManager = AdsManager(player: contentPlayer!, videoView: videoContainer)
    
    //Specify video url
    adsManager.requestAds(videoURL: "https%3A%2F%2Ftw.yahoo.com%2F")
    //Or from avplayer playitem
    //adsManager.requestAds()
    
  }
}

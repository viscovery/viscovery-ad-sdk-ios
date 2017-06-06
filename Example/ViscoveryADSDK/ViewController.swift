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
  @IBOutlet weak var outstreamContainer: UIView!
  var contentPlayer: AVPlayer?
  var adsManager: AdsManager!
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let contentURL = URL(string: "http://viscovery-vsp-dev.s3.amazonaws.com/sdkdemo/Videos/Mobile%20App_Demo%20Video%20(540p).mp4") else { return }
    
    let url = getFileURLFromDocumentFirst() ?? contentURL
    
    contentPlayer = AVPlayer(url: url)
    videoContainer.player = contentPlayer
    adsManager = AdsManager(player: contentPlayer!, videoView: videoContainer, outstreamContainerView: outstreamContainer)
    
    contentPlayer?.isMuted = true
    
    adsManager.requestAds()
    
    //you can adjust y-pos of the instream ads (0.0~50.0) in points
    //adsManager.instreamOffset = 20.0
    
  }
  func getFileURLFromDocumentFirst() -> URL? {
    let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    do {
      let directoryContents = try FileManager.default.contentsOfDirectory(at: documentsUrl, includingPropertiesForKeys: nil, options: [])
      return directoryContents.first
    } catch _ {
      return nil
    }
  }
}

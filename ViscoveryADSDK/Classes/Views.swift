//
//  Views.swift
//  ViscoveryADSDK
//
//  Created by boska on 22/06/2017.
//  Copyright © 2017 Viscovery All rights reserved.
//
import AVFoundation
import SWXMLHash

class LinearView: UIView {
  let videoView = VideoView()
  let learnMore = UIButton(type: .custom)
  let skip = UIButton(type: .custom)
  let progress = UIView()
  let progressBackground = UIView()
  let progressLayout = ConstraintGroup()
  var skipDidTapHandler: (() -> ())?
  var learnMoreDidTapHandler: (() -> ())?
  
  var duration = UILabel()
  
  convenience init() {
    self.init(frame: .zero)
    addSubview(videoView)
    constrain(videoView, self) {
      $0.edges == $1.edges
    }
    addSubview(skip)
    constrain(skip, self) {
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
    constrain(learnMore, self) {
      $0.top == $1.top + 10
      $0.right == $1.right
      $0.height == 48
      $0.width == 160
    }
    
    learnMore.setTitleColor(.white, for: .normal)
    let title = NSAttributedString(string: "Learn More", attributes: [NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue, NSForegroundColorAttributeName: UIColor.white, NSFontAttributeName: UIFont.systemFont(ofSize: 14)])
    learnMore.setAttributedTitle(title, for: .normal)
    learnMore.setImage(UIImage(named: "more", in: Bundle(for: LinearView.self), compatibleWith: nil), for: .normal)
    learnMore.semanticContentAttribute = .forceRightToLeft
    learnMore.centerTextAndImage(spacing: 8)
    learnMore.contentVerticalAlignment = .top
    learnMore.contentHorizontalAlignment = .right
    learnMore.addTarget(self, action: #selector(LinearView.learnMoreDidTap), for: .touchUpInside)
    
    addSubview(duration)
    constrain(duration, self) {
      $0.left == $1.left + 8
      $0.bottom == $1.bottom - 9
    }
    duration.textColor = .white
    duration.text = ""
    duration.font = UIFont.systemFont(ofSize: 12)
    
    progressBackground.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.6)
    addSubview(progressBackground)
    constrain(progressBackground, self) {
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
    constrain(self.progress, progressBackground, replace: progressLayout) {
      $0.left == $1.left
      $0.top == $1.top
      $0.bottom == $1.bottom
      $0.width == $1.width * progress
    }
  }
  func tap() {
    videoView.player?.rate == 1.0 ? videoView.player?.pause() : videoView.player?.play()
  }
}
class NonLinearView: UIView {
  var isOutstream = false
  var isAdHidden = true {
    didSet {
      image.isHidden = isAdHidden
      close.isHidden = isAdHidden
      isHidden = isAdHidden
    }
  }
  let image = ImageView()
  var close: UIButton!
  let group = ConstraintGroup()
  var extensions: XMLIndexer? {
    didSet {
      configureConstrains(with: extensions)
    }
  }
  override var bounds: CGRect {
    didSet {
      configureConstrains(with: extensions)
    }
  }
  var offset: CGFloat = 0.0 {
    didSet {
      configureConstrains(with: extensions)
    }
  }
  var clickThroughCallback: (() -> ())?
  
  func configureConstrains(with extensions: XMLIndexer?) {
    guard
      let extensions = extensions,
      let position = try? extensions["vmap:Extension"].withAttr("type", "position"),
      let size = try? extensions["vmap:Extension"].withAttr("type", "size"),
      let vPos: String = try? position["vertical"].value(ofAttribute: "type"),
      let hPos: String = try? position["horizontal"].value(ofAttribute: "type"),
      let vValue = position["vertical"].element?.text,
      let hValue = position["horizontal"].element?.text
    else { return }
    DispatchQueue.main.async { [image, group] in
      constrain(image, self, replace: group) {
        switch (vPos, vValue.contains("%"), self.isOutstream) {
        case (_,_, true):
          $0.top == $1.top
        case ("bottom", true, _):
          $0.bottom == $1.bottom - (self.bounds.height * vValue.toPercent) - self.offset
        case ("bottom", false, _):
          $0.bottom == $1.bottom - vValue.toPx - self.offset
        case ("top", true, _):
          $0.top == $1.top + (self.bounds.height * vValue.toPercent) + self.offset
        case ("top", false, _):
          $0.top == $1.top + vValue.toPx + self.offset
        default: break
        }
        switch (hPos, hValue.contains("%")) {
        case ("left", true):
          $0.left == $1.left + (self.bounds.width * hValue.toPercent)
        case ("left", false):
          $0.left == $1.left + hValue.toPx
        case ("right", true):
          $0.right == $1.right - (self.bounds.width * hValue.toPercent)
        case ("right", false):
          $0.right == $1.right - hValue.toPx
        case ("center", _):
          $0.centerX == $1.centerX
        default: break
        }
        constrain(image, replace: self.image.imageSize) {
          if let width = try? size["size"].withAttr("type", "width"),
            let widthPercent = width.element?.text {
            $0.width == self.bounds.width * widthPercent.toPercent
          } else {
            $0.width == self.bounds.width
          }
          if let height = try? size["size"].withAttr("type", "height"),
            let heightPercent = height.element?.text {
            $0.height == self.bounds.height * heightPercent.toPercent
          } else {
            $0.height == self.bounds.height
          }
        }
      }
    }
  }
  convenience init(type: AdType) {
    self.init(frame: .zero)
    isOutstream = type == .outstream
    close = UIButton(type: .custom)
    close.setImage(UIImage(named: "close", in: Bundle(for: LinearView.self), compatibleWith: nil), for: .normal)
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
    
    isHidden = true
    
  }
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  func setResourceWithURL(url: String, completion: (() -> ())? = nil) {
    image.setImageWith(link: url, contentMode: .scaleAspectFill) { _ in
      self.configureConstrains(with: self.extensions)
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

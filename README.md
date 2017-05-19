# iOS ViscoveryADSDK Integration

## Prerequisites

+ ViscoveryADSDK Account
+ Xcode
+ [CocoaPods](https://cocoapods.org/)

```
$ sudo gem install cocoapods
``` 


## Adding libraries to the Xcode project
Podfile Example

```ruby
use_frameworks!

target 'ViscoveryADSDK_Example' do
pod 'ViscoveryADSDK', :git => ':git => 'https://github.com/viscovery/viscovery-ios-ad-sdk.git'  
end
```
then execute
```
pod install
```

Once the command completed, open the .xcworkspace file in Xcode
## SDK Classes and lifecycle

## Step by Step Implemention
[Link to Full Source Code](#full-example-source-code)
## 1. Import SDK
```swift
import ConSense
```
## 2. Set API Key
Put these line before your ad request. 

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
ConSenseManager.apiKey = "873cbd49-738d-406c-b9bc-e15588567b39"
return true
}
```
## 3. Setup ConSenseManager
Before you started you have to setup your AVPlayer and UIView that AVPlayerLayer in it.

```swift
var contentPlayer: AVPlayer?
var consenseManager: ConSenseManager!
```

And initialize ConSenseManger

```swift
consenseManager = ConSenseManager(player: contentPlayer!, videoView: videoContainer)
```

The you can request ads the video will start automatically.

```swift
consenseManager.requestAds()
```

## Full Example Source Code
```swift
import UIKit
import AVFoundation
import ConSense

class ViewController: UIViewController {
@IBOutlet weak var videoContainer: VideoView!
var contentPlayer: AVPlayer?
var consenseManager: ConSenseManager!

override func viewDidLoad() {
super.viewDidLoad()
guard let contentURL = URL(string: "http://viscovery-vsp-dev.s3.amazonaws.com/sdkdemo/Videos/sillicon%20valley%20S1%20trailer.mp4") else { return }
contentPlayer = AVPlayer(url: contentURL)
videoContainer.player = contentPlayer
consenseManager = ConSenseManager(player: contentPlayer!, videoView: videoContainer)
consenseManager.requestAds()
}
}
```

VideoView 
This class only for demo. you should replace it with any view that has videolayer in it.

```swift
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

```

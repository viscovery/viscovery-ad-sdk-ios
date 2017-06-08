# iOS ViscoveryADSDK Integration

## Prerequisites

+ ViscoveryADSDK Account
+ Xcode
+ iOS 9.0
+ [CocoaPods](https://cocoapods.org/)

```
$ sudo gem install cocoapods
``` 


## Adding libraries to the Xcode project
Podfile Example

Add in your Podfile

```ruby
pod 'ViscoveryADSDK'
```

or use latest version


```
pod 'ViscoveryADSDK', :git => 'https://github.com/viscovery/viscovery-ad-sdk-ios.git'

```

then execute
```
pod install
```

Once the command completed, open the .xcworkspace file in Xcode

## Step by Step Implemention
[Link to Full Source Code](#full-example-source-code)
## 1. Import SDK
```swift
import ViscoveryADSDK
```
## 2. Set API Key
Put these line before your ad request. 

```swift
import ViscoveryADSDK
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    AdsManager.apiKey = "873cbd49-738d-406c-b9bc-e15588567b39"
    return true
}
```
## 3. Setup AdsManager
Before you started you have to setup your AVPlayer and UIView that AVPlayerLayer in it.

```swift
var contentPlayer: AVPlayer?
var adsManager: AdsManager!
@IBOutlet weak var outstreamContainer: UIView!
```

And initialize AdsManager

```swift
adsManager = AdsManager(player: contentPlayer!, 
                     videoView: videoContainer, 
        outstreamContainerView: outstreamContainer)
```

The you can request ads the video will start automatically.

```swift
adsManager.requestAds()
```

## Full Example Source Code
[Code](https://github.com/viscovery/viscovery-ad-sdk-ios/blob/master/Example/ViscoveryADSDK/ViewController.swift)
####VideoView
This class only for demo. you should replace it with any view that has `AVPlayerLayer` in it.

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
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    let tap = UITapGestureRecognizer(target: self, action: #selector(VideoView.tap))
    addGestureRecognizer(tap)
  }
  func tap() {
    player?.rate == 1.0 ? player?.pause() : player?.play()
  }
}
```

## Example Source Code Objective-C

```objective-c

@import ViscoveryADSDK;

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  AdsManager.apiKey = @"873cbd49-738d-406c-b9bc-e15588567b39";
  // Override point for customization after application launch.
  return YES;
}

@end
```


```objective-c

@import ViscoveryADSDK;

@interface VideoView : UIView
  @end
@implementation VideoView
+ (Class) layerClass {
  return [AVPlayerLayer class];
}
  @end

@interface ViewController ()
@property(nonatomic,weak) IBOutlet VideoView *videoView;
@property(nonatomic,strong) AVPlayer *contentPlayer;
@property(nonatomic,strong) AdsManager *adsManager;
@end


@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSURL *url = [[NSURL alloc]initWithString:@"http://viscovery-vsp-dev.s3.amazonaws.com/sdkdemo/Videos/Mobile%20App_Demo%20Video%20(540p).mp4"];
  
  self.contentPlayer = [AVPlayer playerWithURL:url];
  ((AVPlayerLayer *)self.videoView.layer).player = self.contentPlayer;
  self.adsManager = [[AdsManager alloc] initWithPlayer:self.contentPlayer videoView:self.videoView];
  
  [self.adsManager requestAdsWithVideoURL:@"https%3A%2F%2Ftw.yahoo.com%2F"];
  
  //[self.adsManager requestAdsWithVideoURL:nil];
}

@end

```

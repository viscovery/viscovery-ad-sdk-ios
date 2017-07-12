//
//  TrackingManager.swift
//  Pods
//
//  Created by boska on 12/07/2017.
//
//

import Foundation

class TrackingManager {
  static let shared = TrackingManager()
  private init() {}
  func payload(event: String) -> [String: Any]{
    return [
      "sdk_version": Bundle.init(for: AdsManager.self).infoDictionary?["CFBundleShortVersionString"] as? String ?? "",   // SDK 版本
      "sdk": UIDevice.current.systemName,                          // 平台 ["web" | "android" | "ios"]
      "os": [                                 // 作業系統資訊:
        "name": UIDevice.current.systemName,                   //      - 名稱. 例如: Windows
        "version": UIDevice.current.systemVersion                 //      - 版本. 例如: 7
      ],                                      //
      "app": [                                // 應用程式資訊, 例如:
        "id": Bundle.main.bundleIdentifier ?? "",                    //      - ID. 例如: com.example.myapp, 或 Chrome
        "name": Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "",                    //      - 名稱. 例如: Instgram
        "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String  ?? ""              //      - 版本. 例如: 1.0.1
      ],
      "device": [                             // 裝置資訊, 例如:
        "id": UIDevice.current.identifierForVendor?.uuidString ?? "",                        //      - ID. 例如: android-20013fea6bcc820c
        "model": UIDevice.current.model,                  //      - 型號. 例如: one
        "manufacturer": "apple"     //      - 製造商. 例如: htc
      ],
      "locale": Bundle.main.preferredLocalizations.first ?? "",                    // 語系/語言, 例如: en_US.utf8
      "events": [                             // AD 事件列表, 例如:
        [                                   //
          "event": "$ad_event",           //      - event 類型
          "moment_id": "$moment_id",      //      - moment 編號
          "video_id": "$video_id",      //      - 影片 ID
          "ts": "$timestamp",             //      - event 發生時間 (Unix timestamp)
          "format": "$ad_format"          //      - 廣告形式
        ]
      ],
      "user_id": [                            // 使用者編號. 例如:
        "type": "$type",                    //      - 類型. 例如: cookie-id, email
        "id": "$id_value"                   //      - ID. 例如 xxxxxx-xxxxxxx
      ],
      "ip": "$ip-addr",
      "geo": [                                // 地點, 例如:
        "lat": "lat",                       //      - 緯度
        "lng": "lng"                        //      - 經度
      ]
    ]
  }
}

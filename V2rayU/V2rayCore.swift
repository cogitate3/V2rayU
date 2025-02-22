//
//  V2rayCore.swift
//  V2rayU
//
//  Created by yanue on 2018/10/12.
//  Copyright © 2018 yanue. All rights reserved.
//

import Alamofire
import SwiftyJSON

// v2ray-core version check, download, unzip
class V2rayCore {
    static let version = "v1.5.4"
    // need replace ${version}
    //  "https://github.com/XTLS/Xray-core/releases/download/v1.4.2/Xray-macos-64.zip"
    var x86_url: String = "https://github.com/XTLS/Xray-core/releases/download/v1.5.5/Xray-macos-64.zip"
    var arm64_url: String = "https://github.com/XTLS/Xray-core/releases/download/v1.5.5/Xray-macos-arm64-v8a.zip"
    // last release version info
    let versionUrl: String = "https://api.github.com/repos/XTLS/Xray-core/releases/latest"

    func checkLocal(hasNewVersion: Bool) {
        // has new verion
        if hasNewVersion {
            // download new version
            self.download()
            return
        }

        let fileMgr = FileManager.default
        if !fileMgr.fileExists(atPath: v2rayCoreFile) {
            self.download();
        }
    }

    func check() {
        // 当前版本检测
        let oldVersion = UserDefaults.get(forKey: .xRayCoreVersion) ?? V2rayCore.version
        NSLog("check version", oldVersion)
        Alamofire.request(versionUrl).responseJSON { response in
            var hasNewVersion = false

            defer {
                // check local file
                self.checkLocal(hasNewVersion: hasNewVersion)
            }

            //to get status code
            if let status = response.response?.statusCode {
                if status != 200 {
                    NSLog("error with response status: ", status)
                    return
                }
            }

            //to get JSON return value
            if let result = response.result.value {
                let JSON = (result as! NSDictionary)
            
                // get tag_name (verion)
                guard let tag_name = JSON["tag_name"] else {
                    NSLog("error: no tag_name")
                    return
                }

                // get prerelease and draft
                guard let prerelease = JSON["prerelease"], let draft = JSON["draft"] else {
                    // get
                    NSLog("error: get prerelease or draft")
                    return
                }

                // not pre release or draft
                if prerelease as! Bool == true || draft as! Bool == true {
                    NSLog("this release is a prerelease or draft")
                    return
                }

                let newVersion = tag_name as! String
                NSLog("version compare  \(oldVersion),\(newVersion)")


                // get old versiion
                let oldVer = oldVersion.replacingOccurrences(of: "v", with: "").versionToInt()
                let curVer = newVersion.replacingOccurrences(of: "v", with: "").versionToInt()

                // compare with [Int]
                if oldVer.lexicographicallyPrecedes(curVer) {
                    // store this version
                    UserDefaults.set(forKey: .xRayCoreVersion, value: newVersion)
                    // has new version
                    hasNewVersion = true
                    NSLog("has new version \(newVersion)")
                    if let assets = JSON["assets"] as? [NSDictionary] {
                        for asset in assets {
                            guard let name=asset["name"] as? String else{
                                return
                            }
                            guard let download_url=asset["browser_download_url"] as? String else{
                                return
                            }
                            // for arm64 must contains "arm64"
                            if name.contains("macos") && name.suffix(3)=="zip" && name.contains("arm64") {
                                NSLog("arm64 download url \(utsname.sMachine),\(download_url)")
                                break
                            }
                            // for x86 not contains "arm64"
                            if name.contains("macos") && name.suffix(3)=="zip" && !name.contains("arm64") {
                                NSLog("x86 download url \(utsname.sMachine),\(download_url)")
                                break
                            }
                        }
                    }
                }
                return
            }
        }
    }

    func download() {
        let version = UserDefaults.get(forKey: .xRayCoreVersion) ?? "v1.5.5"
        var url: String = self.x86_url
        if utsname.isAppleSilicon {
            url = self.arm64_url
        }
        NSLog("start download \(utsname.sMachine),\(version),\(url)")

        // check unzip sh file
        // path: ~/.V2rayU/unzip.sh
        let shFile = AppHomePath+"/unzip.sh"
        NSLog("shFile: \(shFile)")
        // path: ~/.V2rayU/v2ray-macos.zip
        let fileUrl = URL.init(fileURLWithPath: AppHomePath+"/v2ray-macos.zip")
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            return (fileUrl, [.removePreviousFile, .createIntermediateDirectories])
        }
        NSLog("fileUrl: \(fileUrl)")

        let utilityQueue = DispatchQueue.global(qos: .utility)
        Alamofire.download(url, to: destination)
                .downloadProgress(queue: utilityQueue) { progress in
                    NSLog("已下载：\(progress.completedUnitCount / 1024)KB")
                }
                .responseData { response in
                    switch response.result {
                    case .success(_):
                        if let _ = response.result.value {
                            // make unzip.sh execable
                            // chmod 777 unzip.sh
                            let execable = "cd " + AppHomePath + " && /bin/chmod 777 ./unzip.sh"
                            _ = shell(launchPath: "/bin/bash", arguments: ["-c", execable])

                            // unzip v2ray-core
                            // cmd: /bin/bash -c 'cd path && ./unzip.sh '
                            let sh = "cd " + AppHomePath + " && ./unzip.sh && /bin/chmod -R 777 ./v2ray-core"
                            // exec shell
                            let res = shell(launchPath: "/bin/bash", arguments: ["-c", sh])
                            NSLog("res: \(sh),\(res ?? "")")
                            makeToast(message: "xray-core has been updated to "+version,displayDuration: 5)
                        }
                    case .failure(_):
                        NSLog("error with response status:")
                        return
                    }
                }
    }
}

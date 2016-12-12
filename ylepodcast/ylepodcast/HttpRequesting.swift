//
//  HttpRequesting.swift
//  ylepodcast
//
//  Created by Arto Heino on 07/11/16.
//  Copyright © 2016 Metropolia. All rights reserved.
//

import Foundation
import Alamofire
import UIKit
import CoreData
import CryptoSwift

class HttpRequesting {
    
    var message: String
    var apiKey: String
    var alertMessage: String
    var error: Bool
    var done: Bool
    
    init () {
        self.message = ""
        self.alertMessage = ""
        self.error = true
        self.done = false
        self.apiKey = ""
    }
    
    func setMessage(statusMessage: String) {
        self.alertMessage = statusMessage
    }
    
    func setStatus(status: Bool) {
        self.done = status
    }
    
    func setError(error: Bool) {
        self.error = error
    }
    
    func setApiKey(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func getMessage() -> String {
        return self.alertMessage
    }
    
    func getApiKey() -> String {
        return self.apiKey
    }
    
    func getStatus() -> Bool {
        return self.done
    }
    
    func getError() -> Bool {
        return self.error
    }
    
    
    // Gets the apikey from the server
    func httpGetApi () {
        
        let parameters: Parameters = ["username": "podcast", "password": "podcast16"]
    
        Alamofire.request("http://dev.mw.metropolia.fi/aanimaisema/plugins/api_auth/auth.php", method: .post, parameters:parameters, encoding: JSONEncoding.default)
            .responseJSON{response in
                if let json = response.result.value as? [String: String] {
                    // Set the apikey
                    self.setApiKey(apiKey: json["api_key"]!)
                    print(self.getApiKey())
                }else{
                    self.setMessage(statusMessage: "Ei toimi")
                }
        }
    }
    
    // Gets podcast from the server using apikey and category
    func httpGetPodCasts () {
        var podcastArray: [[String : Any?]] = []
        
        let parameters2: Parameters = ["app_id": "9fb5a69d", "app_key": "100c18223e4a9346ee4a7294fb3c8a1f", "availability": "ondemand","mediaobject": "audio", "order": "playcount.6h:desc", "limit":"50", "type": "radiocontent", "contentprotection": "22-0,22-1" ]
        
        Alamofire.request("https://external.api.yle.fi/v1/programs/items.json", method: .get, parameters:parameters2, encoding: URLEncoding.default)
            .responseJSON{response in
                if let json = response.result.value {
                    if let array = json as? [String:Any]{
                        if let details = array["data"] as? [[String:Any]] {
                            for (_, item) in details.enumerated() {
                                //let tags = item["tags"] as? [String:Any]
                                let title = item["title"] as! [String:Any]
                                let duration = item["duration"] as? String ?? ""
                                let description = item["description"] as! [String:Any]
                                //let photo = item["defaultImage"] as? String ?? ""
                                //let pUrl = item["Download link"] as? String ?? ""

                                let pubEv = item["publicationEvent"] as? [[String:Any]]
                                for (_, event) in (pubEv?.enumerated())! {
                                    let status = event["temporalStatus"] as? String ?? ""
                                    let type = event["type"] as? String ?? ""
                                    if status == "currently" && type == "OnDemandPublication" {
                                        let media = event["media"] as? [String:Any]
                                        let media_id = media?["id"] as? String ?? ""
                                        
                                        let tags = item["tags"] as? [String:Any]
                                        let title = item["title"] as! [String:Any]
                                        let duration = item["duration"] as? String ?? ""
                                        let description = item["description"] as! [String:Any]
                                        let photo = item["defaultImage"] as? String ?? ""
                                        //let pUrl = item["Download link"] as? String ?? ""
                                        let program_id = item["id"] as? String ?? ""
                                        let parsedDuration = self.parseDuration(duration: duration)
                                        
                                        var podcastItem = [String : Any?]()
                                        podcastItem["podcastTitle"] = title["fi"] as! String? ?? "Ei nimeä"
                                        podcastItem["podcastMediaID"] = media_id
                                        podcastItem["podcastID"] = program_id
                                        podcastItem["podcastDescription"] = description["fi"] as! String? ?? "Ei kuvausta"
                                        podcastItem["podcastDuration"] = parsedDuration
                                        
                                        let image = item["image"] as? [String:Any]
                                        if image!["id"] != nil {
                                            var imageURL = "http://images.cdn.yle.fi/image/upload/w_240,h_240,c_fit/"
                                            imageURL.append((image?["id"] as? String)!)
                                            imageURL.append(".png")
                                            podcastItem["imageURL"] = imageURL
                                        }
                                        podcastArray.append(podcastItem)
                                        
                                    }
                                }

                            }
                        }
                    }
                    
                    self.checkPodcastAvailability(podcastArray: podcastArray)
                    
                } else{
                    print("Ei mene if lauseen läpi")
                }
        }
    }
    
    func checkPodcastAvailability(podcastArray: Array<[String : Any?]>) {
        for podcastItem in podcastArray {
            let params: Parameters = ["program_id": podcastItem["podcastID"]!!, "media_id": podcastItem["podcastMediaID"]!!, "protocol": "PMD", "app_id": "9fb5a69d", "app_key": "100c18223e4a9346ee4a7294fb3c8a1f"]
            Alamofire.request("https://external.api.yle.fi/v1/media/playouts.json", method: .get, parameters:params, encoding: URLEncoding.default).responseJSON{response in

                if response.result.value != nil {
                    let context = DatabaseController.getContext()
                    let podcast = Podcast(context: context)
                    if podcastItem["imageURL"] != nil {
                        self.getPodcastImage(context: context, podcast: podcast, url: podcastItem["imageURL"] as! String)
                    }
                    podcast.podcastCollection = podcastItem["podcastTitle"]! as! String?
                    podcast.podcastDescription = podcastItem["podcastDescription"]! as! String?
                    podcast.podcastDuration = Int64(podcastItem["podcastDuration"]! as! Int)
                    podcast.podcastMediaID = podcastItem["podcastMediaID"]! as? String
                
                    let modifiedID = (podcastItem["podcastID"] as AnyObject).replacingOccurrences(of: "-", with: "")
                    let podcastID = Int64(modifiedID)
                
                    podcast.podcastID = podcastID!
                
                    DatabaseController.saveContext()
                
                } else {
                    print("Shit happens")
                }

            }
        }
    }
    
    func getPodcastImage(context: NSManagedObjectContext, podcast: Podcast, url: String) {
        
        Alamofire.request(url).response { response in
            if let data = response.data {
                let imageDataArray = [UInt8](data)
                let imageData = NSData(bytes: imageDataArray, length: imageDataArray.count)
                podcast.podcastImage = imageData
                //print("image data: ")
                //print(imageData)
                DatabaseController.saveContext()
            }
        }
        
    }
    
    func getAndDecryptUrl(podcast: Podcast, urlDecryptObserver: UrlDecryptObserver) {
        var dec_url = ""
        var podcastID:String {
            return "\(podcast.podcastID)"
        }
        let substr1 = podcastID.substring(to: podcastID.index(after: podcastID.startIndex)).appending("-")
        let substr2 = podcastID.substring(from: podcastID.index(after: podcastID.startIndex))
        let programID = substr1 + substr2
        let params: Parameters = ["program_id": programID, "media_id": podcast.podcastMediaID!, "protocol": "PMD", "app_id": "9fb5a69d", "app_key": "100c18223e4a9346ee4a7294fb3c8a1f"]
        print(params)
        Alamofire.request("https://external.api.yle.fi/v1/media/playouts.json", method: .get, parameters:params, encoding: URLEncoding.default).responseJSON{response in
            if let json = response.result.value {
                if let array = json as? [String:Any]{
                    if let details = array["data"] as? [[String:Any]] {
                        let item = details[0]
                        let enc_url = item["url"] as? String ?? ""
                        let decodedData = Data(base64Encoded: enc_url, options:NSData.Base64DecodingOptions(rawValue: 0))
                        let decodedArray = [UInt8](decodedData!)
                        
                        let iv = Array(decodedArray[0 ... 15])
                        let message = Array(decodedArray[16 ..< (decodedArray.count)])
                        
                        let key = "defaultKey"
                        let keyData = key.data(using: .utf8)!
                        let decodedKeyArray = [UInt8](keyData)
                        
                        dec_url = self.aesDecrypt(key: decodedKeyArray, iv: iv, message: message)
                    }
                }
                urlDecryptObserver.urlDecrypted(url: dec_url)
            } else {
                print("Shit happens")
            }
        }
    }
    
    func httpGetFromBackend (url:String!, token: String!, completion:@escaping (AnyObject) -> Void) {
        let headers: HTTPHeaders = [
            "x-access-token": token
        ]
        
        Alamofire.request(url, method: .get, headers:headers)
            .responseJSON{response in
                if let httpStatusCode = response.response?.statusCode {
                    switch(httpStatusCode) {
                    case 200:
                        if let data = response.result.value{
                            completion(data as AnyObject)
                            return
                        }
                    default:
                        if let data = response.result.value{
                            completion(data as AnyObject)
                            return
                        }
                    }
                }else{
                    self.setMessage(statusMessage: "Something went wrong.")
                }
        }
    }

    func base64ToByteArray(base64String: String) -> [UInt8]? {
        if let nsdata = NSData(base64Encoded: base64String, options: []) {
            var bytes = [UInt8](repeating: 0, count: nsdata.length)
            nsdata.getBytes(&bytes, length: bytes.count)
            return bytes
        }
        return nil // Invalid input
    }
    
    
    func aesDecrypt(key: Array<UInt8>, iv: Array<UInt8>, message: Array<UInt8>) -> String {
        var result: NSString = ""
        do {
            let decrypted:[UInt8] = try AES(key: key, iv: iv, blockMode: .CBC, padding: PKCS7()).decrypt(message)
            let decData = NSData(bytes: decrypted, length: Int(decrypted.count))
            result = NSString(data: decData as Data, encoding: String.Encoding.utf8.rawValue)!
        } catch {
            print(error)
        }
        return String(result)
    }
    
    func parseDuration(duration: String) -> Int {
        var pSeconds = 0
        var pMinutes = 0
        var pHours = 0
        let secIdx = duration.characters.index(of: "S")
        let minIdx = duration.characters.index(of: "M")
        let hIdx = duration.characters.index(of: "H")
        let tIdx = duration.characters.index(of: "T")
        if hIdx != nil {
            let range = duration.index(after: tIdx!)..<hIdx!
            let hours = duration.substring(with: range)
            pHours = Int(hours)!
        }
        if minIdx != nil {
            if hIdx != nil {
                let range = duration.index(after: hIdx!)..<minIdx!
                let minutes = duration.substring(with: range)
                pMinutes = Int(minutes)!
            } else {
                let range = duration.index(after: tIdx!)..<minIdx!
                let minutes = duration.substring(with: range)
                pMinutes = Int(minutes)!
            }
        }
        if secIdx != nil {
            if minIdx != nil {
                let range = duration.index(after: minIdx!)..<secIdx!
                let seconds = duration.substring(with: range)
                pSeconds = Int(seconds)!
            } else if hIdx != nil {
                let range = duration.index(after: hIdx!)..<secIdx!
                let seconds = duration.substring(with: range)
                pSeconds = Int(seconds)!
            } else {
                let range = duration.index(after: tIdx!)..<secIdx!
                let seconds = duration.substring(with: range)
                pSeconds = Int(seconds)!
            }
        }
        let parsedDuration = pHours*3600 + pMinutes*60 + pSeconds
        return parsedDuration
    }
    
    func secondsToTimeString(seconds: Int64) -> String {
        //let hours = seconds / 3600
        let minutes = "\((seconds) / 60)"
        var secondsString = "\((seconds % 3600) % 60)"
        if secondsString.characters.count < 2 {
            secondsString = "0" + secondsString
        }
        let timeString = minutes + ":" + secondsString
        
        return timeString
    }
}

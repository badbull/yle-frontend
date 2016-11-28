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
    func httpGetPodCasts (parserObserver: DataParserObserver) {
        var podcastArray: [Podcast] = []
        
        let parameters2: Parameters = ["app_id": "9fb5a69d", "app_key": "100c18223e4a9346ee4a7294fb3c8a1f", "availability": "ondemand","mediaobject": "audio", "order": "playcount.6h:desc", "limit":"80", "type": "radiocontent", "contentprotection": "22-0,22-1" ]
        
        Alamofire.request("https://external.api.yle.fi/v1/programs/items.json", method: .get, parameters:parameters2, encoding: URLEncoding.default)
            .responseJSON{response in
                if let json = response.result.value {
                    if let array = json as? [String:Any]{
                        if let details = array["data"] as? [[String:Any]] {
                            for (_, item) in details.enumerated() {
                                let tags = item["tags"] as? [String:Any] 
                                let cName = item["title"] as? [String:Any]
                                let duration = item["duration"] as? String ?? ""
                                let description = item["description"] as? [String:Any]
                                let photo = item["defaultImage"] as? String ?? ""
                                //let pUrl = item["Download link"] as? String ?? ""
                                let pubEv = item["publicationEvent"] as? [[String:Any]]
                                let program_id = item["id"] as? String ?? ""
                                for (_, event) in (pubEv?.enumerated())! {
                                    let status = event["temporalStatus"] as? String ?? ""
                                    let type = event["type"] as? String ?? ""
                                    if status == "currently" && type == "OnDemandPublication" {
                                        let media = event["media"] as? [String:Any]
                                        let media_id = media?["id"] as? String ?? ""
                                        
                                        let podcast = NSEntityDescription.insertNewObject(forEntityName: "Podcast", into:AppDelegate.moc) as! Podcast
                                        
                                        podcast.podcastCollection = cName!
                                        podcast.podcastImageURL = photo
                                        podcast.podcastDescription = description
                                        podcast.podcastDuration = duration
                                        podcast.podcastTags = tags
                                        podcast.podcastID = program_id
                                        podcast.podcastMediaID =  media_id
                                        podcastArray.append(podcast)
                                        
                                    }
                                }
                            }
                        }
                    }
                    self.checkPodcastAvailability(podcastArray: podcastArray, parserObserver: parserObserver)
                //parserObserver.podcastsParsed(podcasts: AppDelegate.fetchPodcastsFromCoreData())
                    
                } else{
                    print("Ei mene if lauseen läpi")
                }
        }
    }
    
    func checkPodcastAvailability(podcastArray: Array<Podcast>, parserObserver: DataParserObserver) {
        for podcast in podcastArray {
            let params: Parameters = ["program_id": podcast.podcastID!, "media_id": podcast.podcastMediaID!, "protocol": "PMD", "app_id": "9fb5a69d", "app_key": "100c18223e4a9346ee4a7294fb3c8a1f"]
            print(params)
            Alamofire.request("https://external.api.yle.fi/v1/media/playouts.json", method: .get, parameters:params, encoding: URLEncoding.default).responseJSON{response in
                print(response.result)
                if response.result.value != nil {
                    AppDelegate.addPodcastToCoreData(podcast: podcast)
                } else {
                    print("Shit happens")
                }
                parserObserver.podcastsParsed(podcasts: AppDelegate.fetchPodcastsFromCoreData())
            }
        }
    }
    
    func getAndDecryptUrl(podcast: Podcast, urlDecryptObserver: UrlDecryptObserver) {
        var dec_url = ""
        let params: Parameters = ["program_id": podcast.podcastID!, "media_id": podcast.podcastMediaID!, "protocol": "PMD", "app_id": "9fb5a69d", "app_key": "100c18223e4a9346ee4a7294fb3c8a1f"]
        print(params)
        Alamofire.request("https://external.api.yle.fi/v1/media/playouts.json", method: .get, parameters:params, encoding: URLEncoding.default).responseJSON{response in
            if let json = response.result.value {
                if let array = json as? [String:Any]{
                    if let details = array["data"] as? [[String:Any]] {
                        let item = details[0]
                        let enc_url = item["url"] as? String ?? ""
                        let decodedData = Data(base64Encoded: enc_url, options:NSData.Base64DecodingOptions(rawValue: 0))
                        let decodedArray = [UInt8](decodedData!)
                        //print("decoded: ")
                        //print(decodedArray)
                        
                        let iv = Array(decodedArray[0 ... 15])
                        let message = Array(decodedArray[16 ..< (decodedArray.count)])
                        //print("IV: ")
                        //print(iv)
                        //print("message: ")
                        //print(message)
                        let key = "podcastDecryptKey"
                        let keyData = key.data(using: .utf8)!
                        let decodedKeyArray = [UInt8](keyData)
                        
                        dec_url = self.aesDecrypt(key: decodedKeyArray, iv: iv, message: message)
                            //print("dec_url: " + dec_url)
                    }
                }
                urlDecryptObserver.urlDecrypted(url: dec_url)
            } else {
                print("Shit happens")
            }
        }
    }
    
    func httpGetFromBackend (url:String!, token: String!, completion:@escaping ([Any]) -> Void) {

        let headers: HTTPHeaders = [
            "x-access-token": token
        ]
        Alamofire.request(url, method: .get, headers:headers)
            .responseJSON{response in
                if let httpStatusCode = response.response?.statusCode {
                    switch(httpStatusCode) {
                    case 200:
                        if let data = response.result.value as? [Any]{
                            completion(data)
                            return
                        }
                    default:
                        if let data = response.result.value as? [Any]{
                            completion(data)
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
}

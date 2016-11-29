//
//  UserLoads.swift
//  ylepodcast
//
//  Created by Arto Heino on 29/11/16.
//  Copyright © 2016 Metropolia. All rights reserved.
//

import Foundation

class UserLoads{
    
    let userRequests = HttpRequesting()
    var preferences = UserDefaults.standard
    
    func getPlaylists(){
        let token: String = preferences.object(forKey: "userKey") as? String ?? ""
        let id: String = preferences.object(forKey: "userID") as? String ?? ""
        let url: String = "http://media.mw.metropolia.fi/arsu/playlists/user/" + id
        
        userRequests.httpGetFromBackend(url: url, token: token) { success in
            for (_, event) in (success.enumerated()) {
                let context = DatabaseController.getContext()
                let playlist = Playlist(context: context)
                
                playlist.playlistID = event["id"] as! Int64
                playlist.playlistName = event["playlist_name"] as! String?
                playlist.playlistUserID = event["user_id"] as! Int64
                playlist.playlistTypeName = "Omat soittolistat"
                DatabaseController.saveContext()
            }
            
        }

    }

}

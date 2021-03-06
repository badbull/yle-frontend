//
//  HistoryTableViewController.swift
//  ylepodcast
//
//  Created by Carla Miettinen on 04/11/2016.
//  Copyright © 2016 Metropolia. All rights reserved.
//

import UIKit
import CoreData

class HistoryTableViewController: UITableViewController, Playable, NSFetchedResultsControllerDelegate, UrlDecryptObserver {
    
    // MARK: VARIABLES
    
    var fetchedResultsController: NSFetchedResultsController<History>!
    var preferences = UserDefaults.standard
    let dataParser = HttpRequesting()
    var tabController: TabBarController?
    var url: String = ""
    var name: String = ""
    var podcast: Podcast?
    
    // MARK: INITIALIZER
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        tabController = self.tabBarController as! TabBarController?
        self.navigationItem.titleView = UIImageView(image: UIImage(named: "logo"))
        self.navigationItem.titleView!.contentMode = UIViewContentMode.scaleAspectFit
        self.navigationItem.titleView!.frame = CGRect(x: 0, y: 0, width: 0, height: 50)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50)))
        initializeFetchedResultsController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabController?.showPlayer(currentView: self)
    }
    
    func initializeFetchedResultsController() {
        
        let request = NSFetchRequest<History>(entityName: "History")
        let titleSort = NSSortDescriptor(key: "historyID", ascending: true)
        request.sortDescriptors = [titleSort]
        
        let moc = DatabaseController.getContext()
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc,sectionNameKeyPath: nil, cacheName: nil)
        
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
            
        } catch {
            fatalError("Failed to initialize FetchedResultsController: \(error)")
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: HELPERS
    
    func urlDecrypted(url: String) {
        self.url = url
        self.tabController?.hidePlayer()
        toPlayerView()
    }
    
    func toPlayerView() {
        performSegue(withIdentifier: "AudioSegue2", sender: Any?.self)
    }
    
    func configureCell(cell: HistoryTableViewCell, indexPath: IndexPath) {
        
        let selectedObject = fetchedResultsController.object(at: indexPath)
        let podcastObj = selectedObject.podcast?.allObjects
        let podcasts = podcastObj as? [Podcast]
        
        var i = 0
        // Get all podcasts from history and show podcast in correct row
        for object in podcasts!{
            cell.collectionLabel.text = object.podcastTitle
            cell.descriptionLabel.text = object.podcastDescription
            cell.durationLabel.text = dataParser.secondsToTimeString(seconds: object.podcastDuration)
            let podcastImageData = object.podcastImage
            if podcastImageData != nil {
                let image = UIImage(data: podcastImageData as! Data)
                cell.podcastImageView.image = image
            }
            
            if indexPath.row == i {
                break
            }
            i = i + 1
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        
        if segue.identifier == "AudioSegue2" {
            let destination = segue.destination as! AudioController
            destination.podcastUrl = url
            destination.podcastName = name
            destination.podcast = podcast
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch(type) {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
            return
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        default:
            return
        }
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cellIdentifier = "HistoryCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! HistoryTableViewCell
        // Set up the cell
        configureCell(cell: cell, indexPath: indexPath)
        
        return cell
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        
        return fetchedResultsController.sections!.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        let sections = fetchedResultsController.sections
        let sectionInfo = sections?[section]
        return sectionInfo!.numberOfObjects
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let selectedObject = fetchedResultsController.object(at: indexPath)
        
        let podcastObj = selectedObject.podcast?.allObjects
        let podcasts = podcastObj as? [Podcast]
        
        var i = 0
        for object in podcasts!{
            name = object.podcastTitle!
            podcast = object
            dataParser.getAndDecryptUrl(podcast: object, urlDecryptObserver: self)
            if indexPath.row == i {
                break
            }
            i = i + 1
        }
        
    }
    
    // Add, add podcast to playlist action to tableview
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let selectedObject = fetchedResultsController.object(at: indexPath)
        let addAction = UITableViewRowAction(style: .normal, title: "Lisää", handler: { (action: UITableViewRowAction, indexPath: IndexPath) -> Void in
            
            let usersPlaylistController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "UsersPlaylist") as! UsersPlaylistTableViewController
            
            let podcastObj = selectedObject.podcast?.allObjects
            let podcasts = podcastObj as? [Podcast]
            
            var i = 0
            for object in podcasts!{
                usersPlaylistController.selectedPodcast = object
                if indexPath.row == i {
                    break
                }
                i = i + 1
            }
            
            
            
            self.show(usersPlaylistController, sender: nil)
        })
        
        addAction.backgroundColor = UIColor.init(red: 20/255.0, green: 188/255.0, blue: 210/255.0, alpha: 0.5)
        return [addAction]
    }
    
    
}

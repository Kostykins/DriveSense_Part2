
//
//  MapRootViewController.swift
//  DriveSense
//
//  Created by Matt Kostelecky on 5/3/15.
//  Copyright (c) 2015 Matt Kostelecky. All rights reserved.
//

import Foundation
import UIKit
import MapKit

class MapRootViewController: UIViewController, MKMapViewDelegate{
  
  
  @IBOutlet weak var playButton: UIButton!
  @IBOutlet weak var mapView: MKMapView!
  
  //container and recording bar
  @IBOutlet weak var container: UIView!
  @IBOutlet var bottomBar: UIView!

  //labels for slide in view
  @IBOutlet weak var tripLabel: UILabel!
  @IBOutlet weak var durationLabel: UILabel!
 
  //flag to indicate controller that is currently recording
  var recording: Bool!
  var showingTrips: Bool!
  
  var locationManager: CLLocationManager!
  var tripRecorder: TripRecorder!
  
  //used to save the final position of the view on the screen so we can animate to here later
  var frameIn: CGRect!
  var frameContainer: CGRect!
  
  //Timer variables
  var secondsCounting: NSInteger!
  var durationTimer: NSTimer!
  var trips: NSArray!
  
  override func viewDidLoad() {
    self.recording = false
    self.showingTrips = false
    self.tripRecorder = TripRecorder.sharedInstance
    self.locationManager = self.tripRecorder.getLocationManager()
    mapView.delegate = self
    self.trips = self.tripRecorder.getTrips() as NSArray
    secondsCounting = 0;
    
  }
  
  override func viewDidAppear(animated: Bool) {
    
    tripLabel.text = "Name PlaceHolder"
    durationLabel.text = NSString(format: "%d seconds", secondsCounting) as String
    
    mapView.setUserTrackingMode(MKUserTrackingMode.Follow, animated: true)
    
    frameIn = self.bottomBar.frame

    animateOut()
  }
  
  // MARK: - Button Methods

  
  @IBAction func togglePlayButton(sender: AnyObject) {
    if (recording == true) {
      
      playButton.setBackgroundImage(UIImage(named: "play"), forState: UIControlState.Normal)
      
      //reset the timer
      self.durationTimer.invalidate()
      //dont follow user around when not tracking
      mapView.setUserTrackingMode(MKUserTrackingMode.None, animated: true)
      
      var bool = self.tripRecorder.stopRecording()
      animateOut()
      
    } else {
      playButton.setBackgroundImage(UIImage(named: "pause"), forState: UIControlState.Normal)
  
      // follow user around when tracking
      mapView.setUserTrackingMode(MKUserTrackingMode.Follow, animated: true)
      
      //set timer
      self.durationTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "incrementTimer", userInfo: nil, repeats: true)
      secondsCounting = 0
      
      var bool = self.tripRecorder.startRecording()
      animateIn()
    }
    recording = !recording
  }
  
  @IBAction func showTrips(sender: AnyObject) {
    if(recording == true){
      return
    }
    if (showingTrips == true) {
      mapView.removeAnnotations(mapView.annotations)
      mapView.removeOverlays(mapView.overlays)
    } else {
      NSNotificationCenter.defaultCenter().postNotificationName("updateTable", object: nil)
      var trips: NSArray = self.tripRecorder.getTrips() as NSArray
      println(trips.count)
      for(var i = 0; i < trips.count; i++) {
        let trip: Trip = trips.objectAtIndex(i) as! Trip
        let coordinates: NSOrderedSet = trip.coordinates
        drawRouteForCoordinates(coordinates)
        dropPinForCoordinate(trip.startCoordinate)
        dropPinForCoordinate(trip.endCoordinate)
      }
    }
     showingTrips = !showingTrips;
  }
  
  // MARK: - Trip Timing
  func incrementTimer(){
    secondsCounting = secondsCounting + 1
    durationLabel.text = NSString(format: "%d seconds", secondsCounting) as String
  }
  
  // MARK: - Animation Methods
    func animateIn(){
    UIView.animateWithDuration(0.25, animations: {
      self.bottomBar.frame = self.frameIn
    })
    if(self.container != nil){
      self.container.alpha = 0
    }
  }
  
  func animateOut(){
    UIView.animateWithDuration(0.25, animations: {
      let y = self.view.frame.size.height
      var newFrame = self.frameIn
      newFrame.origin.y = y
      self.bottomBar.frame = newFrame
    })
    if(self.container != nil){
      self.container.alpha = 1
    }
  }
  
 // MARK: - Map Drawing
  func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
    //check to make sure it is a polyline (this method is called for anything else thats drawn on a map)
    if !overlay.isKindOfClass(MKPolygon) {
      let route: MKPolyline = overlay as! MKPolyline
      let renderer: MKPolylineRenderer = MKPolylineRenderer(polyline: route)
      renderer.strokeColor = UIColor(red: 255/255, green: 0/255, blue: 0/255, alpha: 1)
      renderer.lineWidth = 3.0
      return renderer
    } else {
      return nil
    }
  }
  
  func drawRouteForCoordinates(points: NSOrderedSet) {
    //draw the route for the map based on the coordiantes
    var pointArray: [CLLocationCoordinate2D] = []
    
    for(var i = 0; i < points.count; i++){
      let coordinate: GPSCoordinate = points.objectAtIndex(i) as! GPSCoordinate
      
      let lat = coordinate.lat.doubleValue
      let lon = coordinate.lon.doubleValue
      
      pointArray.append(CLLocationCoordinate2DMake(lat, lon))
    }
    let count = points.count
    let myPolyline = MKPolyline(coordinates: &pointArray, count: count)
    mapView.addOverlay(myPolyline)
  }
  
  func dropPinForCoordinate(coordinate: GPSCoordinate) {

    let lat = coordinate.lat.doubleValue
    let lon = coordinate.lon.doubleValue
    
    let coordinate2D: CLLocationCoordinate2D = CLLocationCoordinate2DMake(lat, lon)
    
    var annotation: MapAnnotation = MapAnnotation(coordinate: coordinate2D, title: "Title", subtitle: "Subtitle")
  
    mapView.addAnnotation(annotation)
  }
  
  func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
    if (annotation is MKUserLocation) {
      //if annotation is not an MKPointAnnotation (eg. MKUserLocation),
      //return nil so map draws default view for it (eg. blue dot)...
      return nil
    }
    
    let reuseId = "MapAnnotation"
    
    var anView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId)
    if anView == nil {
      anView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
      anView.canShowCallout = true
    }
    else {
      //we are re-using a view, update its annotation reference...
      anView.annotation = annotation
    }

    return anView
  }
}

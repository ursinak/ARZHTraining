//
//  ViewController.swift
//  ARZHTraining
//
//  Created by Ursina Boos on 08.05.20.
//  Copyright © 2020 Ursina Boos. All rights reserved.
//

import ArcGIS
import ArcGISToolkit
import ARKit
import CoreLocation
import SceneKit
import UIKit

class ViewController: UIViewController, ARSCNViewDelegate, UIApplicationDelegate, CLLocationManagerDelegate {
    @IBOutlet var sceneView: ARSCNView!
    
    // add AR View to app
    private let arView = ArcGISARView(renderVideoFeed: true)

    // create variables for scene and scene layers
    var scene: AGSScene!
    var mobileScenePackage: AGSMobileScenePackage!
    var sceneBasemap: AGSBasemap!
    var sceneLayer: AGSArcGISSceneLayer!
    var train1Layer: AGSArcGISSceneLayer!
    var train2Layer: AGSArcGISSceneLayer!
    var train3Layer: AGSArcGISSceneLayer!
    var baseLayer: AGSRasterLayer!
    var zhBuildingsLayer: AGSArcGISSceneLayer!
    var orangeCalibLayer: AGSFeatureLayer!
    var sceneElevation: AGSElevationSource!
    let graphicsOverlay = AGSGraphicsOverlay() // create a graphics overlay 2705
    let graphicsOverlay1 = AGSGraphicsOverlay() // create a graphics overlay 2705
    let graphicsOverlay2 = AGSGraphicsOverlay()
    let graphicsOverlay3 = AGSGraphicsOverlay()

    // AGSCamera control variables
    // Manegg 47.340331, 8.519914
    var cameraViewpoint = AGSPoint(x: 8.5198291, y: 47.34000863, spatialReference: AGSSpatialReference.wgs84())
    var cameraElevation: Dynamic<Int> = Dynamic(0)
    var deltaAltitude: Double = 469.0 // store height of camera
    var lastDelta: Double = 0
    var lastDeltaY: Double = 0
    var initialHeading: Double!
    var initialX: CLLocationDegrees!
    var initialY: CLLocationDegrees!

    // set the data for the picker-view to choose a LOD ("Studienbedingung")
    let pickerData = ["-", "1", "2", "3"]
    var selectedLOD: String = "-" // default selected LOD is none. Value changes if a different LOD is chosen (using the "LOD-Picker")

    var appState: AppState = AppState()

    // create location manager to access the user's location
    let locationManager = CLLocationManager()

    // create readwritetext instance to write and read text from files in the native files app (iOS)
    let rwt = ReadWriteText()
    let textFileName = "study_locations_train" // set the name of the file

    // add IBOutlets for all control elements
    @IBOutlet var calibrationToolbar: UIToolbar!
    @IBOutlet var calibrationSlider: UISlider!
    @IBOutlet var basemapSwitch: UISwitch!
    @IBOutlet var calibrateInfo: UILabel!
    @IBOutlet var sunlightButton: UIBarButtonItem!
    @IBOutlet var sunlightDatePicker: UIDatePicker!

    @IBOutlet var showLodPickerButton: UIBarButtonItem!
    @IBOutlet var lodPicker: UIPickerView!
    @IBOutlet var zhBuildingsButton: UIBarButtonItem!
    @IBOutlet var changeOpacityStepper: UIStepper!

//    func initGesutres() {
//        let panRecognizer = UIPanGestureRecognizer(target: self, action:
//            #selector(adjustViewpoint(_:)))
//        panRecognizer.delegate = self as? UIGestureRecognizerDelegate
    ////        view.addGestureRecognizer(panRecognizer)
//        view.addGestureRecognizer(panRecognizer)
//    }

//    public func licenseApp() {
//        do {
//         let result = try AGSArcGISRuntimeEnvironment.setLicenseKey("runtimelite,1000,rud6554828442,none,A3E60RFLTHEYRJE15226")
//         print("License Result : \(result.licenseStatus)")
//        }
//        catch let error as NSError {
//         print("error: \(error)")
//        }
//    }
    
    public func getState() -> AppState {
        return appState
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view's delegate
        sceneView.delegate = self
        arView.arSCNViewDelegate = self

        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        

        // Add the ArcGISARView to our view as a subview and set up constraints
        view.addSubview(arView)
        view.insertSubview(arView, belowSubview: calibrationToolbar)

        // add some layout constraints for the AR view
        arView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        arView.locationDataSource = AGSCLLocationDataSource()

        // call gestures function, which allows changing the camera position (= view of the scene)
//        initGesutres()

        configureUILayout()

        // get current location of user
        setupLocationManager()
        getLocation()

        removeGestures()
        // call function to load layers (mobile scene package), elevation source etc.
        configureOfflineScene()

        // add the graphics overlay to the map view or scene view
//        arView.sceneView.graphicsOverlays.add(graphicsOverlay) // 2705
        

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTracking() // starts tracking plane detections
    }

    func startTracking() {
//        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
//        configuration.planeDetection = [.vertical, .horizontal]
        configuration.worldAlignment = .gravityAndHeading // 1405

        // Run the view's session
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.startTracking(.initial)
//        arView.startTracking(.ignore) // when device camera is not needed, e.g. when setting an origin camera

        // Continuous update mode
//        arView.startTracking(.continuous, completion: nil)

        // One-time update mode
//         arView.startTracking(.initial, completion: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        arView.stopTracking()
    }

    // MARK: - ARSCNViewDelegate

    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
         let node = SCNNode()

         return node
     }
     */

    func session(_ session: ARSession, didFailWithError error: Error) {
    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }

    func configureUILayout() {
        // rotate horizontal slider 90° to make it a vertical slider
        calibrationSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2))

        // configurate pickerView (LOD picker)
        lodPicker.dataSource = self
        lodPicker.delegate = self

        // set colour and transparency of the datepicker UI element
        sunlightDatePicker.backgroundColor = .white
        sunlightDatePicker.isOpaque = true
        sunlightDatePicker.alpha = 0.5

        // set tint colour of zhBuildingsButton (UIBarButtonItem) to clear to hide the button. Button should only be shown when calibrating
        zhBuildingsButton.tintColor = .clear
    }

    func getLocation() {
        initialX = locationManager.location?.coordinate.longitude
        initialY = locationManager.location?.coordinate.latitude
    }
    
    func removeGestures() {
//        print(arView.sceneView.gestureRecognizers?[5]) // 4 has pinch, 5 is pinch
        arView.sceneView.gestureRecognizers?.remove(at: 5)
        arView.sceneView.gestureRecognizers?.remove(at: 4)
//        arView.sceneView.gestureRecognizers?.remove(at: 0)
    }

    private func configureTrainModels() {
//        let modelSymbol = AGSModelSceneSymbol(name: "art.scnassets/Pig", extension: ".obj", scale: 1)

        let lobsterSymbol = AGSModelSceneSymbol(name: "art.scnassets/Lobster/Lobster", extension: ".obj", scale: 7)

        let greatEgretSymbol = AGSModelSceneSymbol(name: "art.scnassets/GreatEgret/GreatEgret", extension: ".obj", scale: 7)

        let skunkSymbol = AGSModelSceneSymbol(name: "art.scnassets/Skunk/Skunk", extension: ".obj", scale: 7)

        //        let modelSymbol = AGSModelSceneSymbol(url: filePathURL, scale: 3000)
//        modelSymbol.load(completion: { [weak self] error in
//            if let error = error {
//                print(error)
//                return
//            }
//            let modelPoint = AGSPointMake3D(8.5201370, 47.3405240, 500, 0, AGSSpatialReference.wgs84())
//            let modelGraphic = AGSGraphic(geometry: modelPoint, symbol: modelSymbol, attributes: nil)
//            self?.graphicsOverlay.graphics.add(modelGraphic)
//            self?.graphicsOverlay.isVisible = false
//        })

        lobsterSymbol.load(completion: { [weak self] error in
            if let error = error {
                print(error)
                return
            }
            greatEgretSymbol.load(completion: { [weak self] error in
                if let error = error {
                    print(error)
                    return
                }
                skunkSymbol.load(completion: { [weak self] error in
                    if let error = error {
                        print(error)
                        return
                    }
                })
                let modelPoint = AGSPointMake3D(8.5201370, 47.3405240, 430, 1, AGSSpatialReference.wgs84())
//                let modelGraphic = AGSGraphic(geometry: modelPoint, symbol: modelSymbol, attributes: nil)
                
                // By default, the symbol will be positioned using the centroid of the model object --> use bottom to place graphics
                lobsterSymbol.anchorPosition = .bottom
                skunkSymbol.anchorPosition = .bottom
                greatEgretSymbol.anchorPosition = .bottom

                let lobsterGraphic = AGSGraphic(geometry: modelPoint, symbol: lobsterSymbol, attributes: nil)
                let greatEgretGraphic = AGSGraphic(geometry: modelPoint, symbol: greatEgretSymbol, attributes: nil)
                let skunkGraphic = AGSGraphic(geometry: modelPoint, symbol: skunkSymbol, attributes: nil)

                self?.graphicsOverlay1.graphics.add(lobsterGraphic)
                self?.graphicsOverlay2.graphics.add(greatEgretGraphic)
                self?.graphicsOverlay3.graphics.add(skunkGraphic)
//                print(self?.graphicsOverlay.graphics)
//                self?.graphicsOverlay.graphics.add(modelGraphic)
            })

        })
    }
    
    private func addGraphics() {
        arView.sceneView.graphicsOverlays.add(graphicsOverlay)
        arView.sceneView.graphicsOverlays.add(graphicsOverlay1)
        arView.sceneView.graphicsOverlays.add(graphicsOverlay2)
        arView.sceneView.graphicsOverlays.add(graphicsOverlay3)
        
        graphicsOverlay.isVisible = false
        graphicsOverlay1.isVisible = false
        graphicsOverlay2.isVisible = false
        graphicsOverlay3.isVisible = false


    }

    // configure offline scene: load mobile scene package etc
    private func configureOfflineScene() {
        scene = AGSScene()
        scene.addElevationSource()

        let fileName = "arzhtraining"
//        let fileName = "arzhtrainingcalibrate"


        let mspkURL = rwt.returnFileURL(fileName: fileName)
        print(mspkURL)

//        cameraViewpoint = AGSPoint(x: initialX, y: initialY, spatialReference: AGSSpatialReference.wgs84())
        // Task Location: 8.5200106°E 47.3402179°N
        cameraViewpoint = AGSPoint(x: 8.5200106, y: 47.3402179, spatialReference: AGSSpatialReference.wgs84())

        //        Construct the mobile scene package object from the (.mspk) file path
        mobileScenePackage = AGSMobileScenePackage(fileURL: mspkURL)

        mobileScenePackage.load { [weak self] (error) -> Void in
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }

            self?.scene?.baseSurface?.elevationSources.first?.load { (error) -> Void in guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            self?.scene?.baseSurface?.elevation(for: self!.cameraViewpoint) { (elevation, error) -> Void in guard error == nil else {
                print(error!.localizedDescription)
                return
            }

            let camera = AGSCamera(latitude: (self?.cameraViewpoint.y)!, longitude: self!.cameraViewpoint.x, altitude: elevation, heading: 0, pitch: 90, roll: 0)

            self?.deltaAltitude = elevation
            self?.arView.originCamera = camera
            self?.arView.translationFactor = 1
            self?.scene = self?.mobileScenePackage.scenes[0]
//            self?.scene.basemap = .imagery()
            self?.scene.addElevationSource()
            self?.scene.baseSurface?.opacity = 1
            self?.mobileScenePackage.scenes[0].baseSurface?.navigationConstraint = .none

            // display the scene
            self?.arView.sceneView.scene = self?.scene

            self?.baseLayer = self?.mobileScenePackage.scenes[0].operationalLayers[0] as? AGSRasterLayer

//            print(self?.mobileScenePackage.scenes[0].operationalLayers)

            // assign operational layers to respective variables for further actions (e.g. add and remove layers from displayed scene)
//            self?.train1Layer = self?.mobileScenePackage.scenes[0].operationalLayers[2] as? AGSArcGISSceneLayer
//            self?.train2Layer = self?.mobileScenePackage.scenes[0].operationalLayers[3] as? AGSArcGISSceneLayer
//            self?.train3Layer = self?.mobileScenePackage.scenes[0].operationalLayers[4] as? AGSArcGISSceneLayer
            self?.zhBuildingsLayer = self?.mobileScenePackage.scenes[0].operationalLayers[1] as? AGSArcGISSceneLayer
                
//            self?.orangeCalibLayer = self?.mobileScenePackage.scenes[0].operationalLayers[2] as? AGSFeatureLayer

//            print("lod1 layer name: \(self?.train1Layer.name) \nlod2 layer name: \(self?.train2Layer.name) \nlod3 layer name: \(self?.train3Layer.name)\nzH buildings layer name: \(self?.zhBuildingsLayer.name)")

//            self?.train1Layer.isVisible = false
//            self?.train2Layer.isVisible = false
//            self?.train3Layer.isVisible = false
            self?.zhBuildingsLayer.isVisible = true
//            self?.orangeCalibLayer.isVisible = true
            self?.zhBuildingsLayer.opacity = 0 // set opacity to 0, i.e. make layer invisible as it is only needed for occlusion
            self?.baseLayer.opacity = 0.5
//            self?.lod1Layer.surfacePlacement = .drapedFlat

//            print("\(self?.lod1Layer.name)\n\(self?.lod2Layer.name)\n\(self?.lod3Layer.name)")
//            self?.lod3Layer.isVisible = false
//            self?.baseLayer.isVisible = true

            self?.configureTrainModels()
            }
            }
        }
        addGraphics()
        // display the scene
        arView.sceneView.scene = scene
    }

    func showBasemap(_ show: Bool) {
        if !show {
            baseLayer.isVisible = false
        } else {
            baseLayer.isVisible = true
            baseLayer.opacity = 0.5
        }
    }

    // function to turn on/ off Basemap
    @IBAction func switchBasemap(_ sender: Any) {
        showBasemap(basemapSwitch.isOn)
    }

    // function to show calibration slider
    @IBAction func calibrateScene(_ sender: Any) {
        if calibrationSlider.isHidden == false {
            calibrationSlider.isHidden = true
            calibrateInfo.text = ""
            calibrateInfo.backgroundColor = .none
            zhBuildingsLayer.opacity = 0
            changeOpacityStepper.isHidden = true
            zhBuildingsButton.tintColor = .clear
            zhBuildingsButton.isEnabled = false
//            orangeCalibLayer.isVisible = false
        } else {
            calibrationSlider.isHidden = false
            zhBuildingsButton.isEnabled = true
            zhBuildingsButton.tintColor = .darkGray
//            orangeCalibLayer.isVisible = true
        }
    }

    @IBAction func setzhBuildingsOpacity(_ sender: Any) {
        // TODO: connect a slider to change opacity of the buildings
        //        changeZHBuildingsTransparency(Int(sender.value))
        if changeOpacityStepper.isHidden == true {
            changeOpacityStepper.isHidden = false // show stepper to increase/ decrease opacity
            zhBuildingsLayer.opacity = 1
        } else {
            changeOpacityStepper.isHidden = true // hide stepper to increase/ decrease opacity
            zhBuildingsLayer.opacity = 0
        }
    }

    func changeZHBuildingsTransparency(_ transp: Double) {
        let opacity = (transp / 100.0)
        zhBuildingsLayer.opacity = Float(opacity)
    }

    @IBAction func changeOpacity(_ sender: UIStepper) {
        changeZHBuildingsTransparency(sender.value)
    }

    func changeCameraElevation(_ elevation: Int) {
        let delta = elevation - cameraElevation.value
        deltaAltitude = Double(delta)
        cameraElevation.value = elevation
        arView.originCamera = arView.originCamera.elevate(withDeltaAltitude: Double(delta))
    }

    // calibrate Scene: change height of scene
    @IBAction func calibrateHeight(_ sender: UISlider) {
        changeCameraElevation(Int(sender.value))
    }

    //    @objc func adjustViewpoint(_ gesture: UIPanGestureRecognizer) {
    //        let translation = gesture.translation(in: gesture.view!)
    //        // horizontal adjustments
    //        let deltaHeadingX = Double(translation.x)
    //        let deltaHeadingY = Double(translation.y)
    //
    //        if abs(deltaHeadingX - lastDelta) < 0.3 || abs(deltaHeadingY - lastDeltaY) < 0.3 { return }
    //
    //        lastDelta = deltaHeadingX
    //        lastDeltaY = deltaHeadingY
    //
    //        let camera = arView.originCamera
    //
    //        let negHX = -deltaHeadingX
    //        let negHY = -deltaHeadingY
    //        //        let newX = camera.location.x + deltaHeadingX
    //        //        let newY = camera.location.y + deltaHeadingY
    //        let newX = camera.location.x + negHX
    //        let newY = camera.location.y + negHY
    //        //        let newZ = arView.originCamera.location.z
    //
    //        //        let newCamera = AGSPoint(x: newX, y: newY, spatialReference: .wgs84())
    //        let newCamera = AGSPoint(x: newX, y: newY, z: deltaAltitude, spatialReference: .wgs84())
    ////        print("\(newCamera), \(newCamera.z)")
    //
    //        //        arView.originCamera = camera.move(toLocation: newCamera)
    //        //        arView.originCamera = camera.moveTowardTargetPoint(newCamera, distance: 1)
    //        arView.originCamera = arView.originCamera.moveTowardTargetPoint(newCamera, distance: 1)
    //
    //        // ALGR: neue kamera mit X, Y und Z erstellen
    //        // gestures: ausschliessen
    //    }

    /**
     if the "sun button" is pressed, a date picker UI element is shown to set the desired date and time for lighting/ shadowing the scene
     */
    @IBAction func setSunlightDate(_ sender: Any) {
        if sunlightDatePicker.isHidden == true {
            sunlightDatePicker.isHidden = false

            // close lodPicker if it is open
            if lodPicker.isHidden == false {
                lodPicker.isHidden = true
            }
        } else {
            sunlightDatePicker.isHidden = true
        }
    }

    /**
     if a date is chosen, the sunlight & shadows are adapted and the scene is lighted accordingly
     */
    @IBAction func changeSunlightDate(_ sender: Any) {
        let selectedDate = sunlightDatePicker.date

        // if the date is changed, the lighting of the scene is updated
        if selectedDate != Date() {
            arView.sceneView.sunTime = .init(timeIntervalSince1970: selectedDate.timeIntervalSince1970)
        } else {
            arView.sceneView.sunTime = .init()
        }
        arView.sceneView.sunLighting = .lightAndShadows
        zhBuildingsLayer.opacity = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // Put your code which should be executed with a delay here
            self.sunlightDatePicker.isHidden = true
        }
    }

    @IBAction func showLodPicker(_ sender: Any) {
        if lodPicker.isHidden == true {
            lodPicker.isHidden = false
            // close sunlightDatePicker if it is open
            if sunlightDatePicker.isHidden == false {
                sunlightDatePicker.isHidden = true
            }
        } else {
            lodPicker.isHidden = true
        }
    }

    private func updateScene() {
        switch selectedLOD {
        case "1": // adds LOD1 layer to scene
//            scene.operationalLayers.add(sceneLODLayer!)
            graphicsOverlay1.isVisible = true
            graphicsOverlay2.isVisible = false
            graphicsOverlay3.isVisible = false
//            train1Layer.isVisible = true
//            train2Layer.isVisible = false
//            train3Layer.isVisible = false
            print("added LOD 1 to scene")

        case "2": // adds LOD2 layer to scene
            //            scene.operationalLayers.add()
            graphicsOverlay2.isVisible = true
            graphicsOverlay1.isVisible = false
            graphicsOverlay3.isVisible = false
//            train2Layer.isVisible = true
//            train1Layer.isVisible = false
//            train3Layer.isVisible = false
            print("added LOD 2 to scene")

        case "3": // adds LOD3 layer to scene
            //            scene.operationalLayers.add()
            graphicsOverlay3.isVisible = true
            graphicsOverlay2.isVisible = false
            graphicsOverlay1.isVisible = false
//            train3Layer.isVisible = true
//            train1Layer.isVisible = false
//            train2Layer.isVisible = false
            print("added LOD 3 to scene")

        default: // adds LOD1 layer to scene
            //            scene.operationalLayers.add()
            graphicsOverlay1.isVisible = false
            graphicsOverlay2.isVisible = false
            graphicsOverlay3.isVisible = false
//            train1Layer.isVisible = false
//            train2Layer.isVisible = false
//            train3Layer.isVisible = false

            print("added no graphic to scene")
        }
    }

    // get location
    func setupLocationManager() {
        locationManager.delegate = self
//        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters //kCLLocationAccuracyBest
        //        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            let tmstp = printTimestamp()

            //            print("longitude =  \(longitude), latitude = \(latitude)")

            let message = "\(latitude), \(longitude), \(tmstp), \(selectedLOD)\n"
//                let message2 = "\(latitude), \(longitude)\n"

            //                rwt.writeFile(writeString: message, fileName: textFileName)
            rwt.appendFile(writeString: message, fileName: textFileName)
            //            print(rwt.readFile(fileName: textFileName))
            //            print(rwt.DocumentDirURL)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
//        print(newHeading.magneticHeading)
        initialHeading = newHeading.magneticHeading
    }

    func printTimestamp() -> String {
        let timestamp = DateFormatter.localizedString(from: NSDate() as Date, dateStyle: .short, timeStyle: .medium)
        //        print(timestamp)
        return timestamp
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed, \(error)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways {
        }
    }
}

// MARK: AGSScene extension.

extension AGSScene {
    /// Adds an elevation source to the given scene.
    func addElevationSource() {
//        let rwt = ReadWriteText()
        let fileName = "GroundElevation"
//        let tpkxURL = rwt.returnFileURL(fileName: fileName)
        let elevationSource = AGSArcGISTiledElevationSource(name: fileName)
        let surface = AGSSurface()
        surface.elevationSources = [elevationSource]
        surface.name = "baseSurface"
        surface.isEnabled = true
        surface.backgroundGrid.isVisible = false
        surface.navigationConstraint = .none
        baseSurface = surface
//        baseSurface?.opacity = 1
    }
}

// MARK: AGSGeoViewTouchDelegate

// extension ViewController: AGSGeoViewTouchDelegate {
//    public func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
//    }
// }

extension Date {
    static var currentTimeStamp: Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}

extension ViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
}

extension ViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        return pickerData[row]
        return pickerData[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let newSelectedLOD = pickerData[row]
        if selectedLOD != newSelectedLOD {
            selectedLOD = newSelectedLOD
            updateScene()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                // Put your code which should be executed with a delay here
                self.lodPicker.isHidden = true
            }
        }
    }
}

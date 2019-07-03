//
//  ViewController.swift
//  FaceDetect
//
//  Created by Simba on 7/2/19.
//  Copyright © 2019 Simba. All rights reserved.
//

import UIKit
// [START import_vision]
import FirebaseMLVision
// [END import_vision]
import FirebaseMLCommon

class ViewController: UIViewController, UINavigationControllerDelegate {
    
    /// Firebase vision instance.
    // [START init_vision]
    lazy var vision = Vision.vision()
    // [END init_vision]
    /// Manager for local and remote models.
    lazy var modelManager = ModelManager.modelManager()
    
    /// Whether the AutoML models are registered.
    var areAutoMLModelsRegistered = false
    
    /// A string holding current results from detection.
    var resultsText = ""
    
    /// An image picker for accessing the photo library or camera.
    var imagePicker = UIImagePickerController()

    /// An overlay view that displays detection annotations.
    private lazy var annotationOverlayView: UIView = {
        precondition(isViewLoaded)
        let annotationOverlayView = UIView(frame: .zero)
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        return annotationOverlayView
    }()
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        imageView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            ])
        
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.navigationBar.isHidden = false
    }

    @IBAction func onClickDetect(_ sender: Any) {
        detectFaces(image: imageView.image)
    }
    
    private func showResults() {
        let resultsAlertController = UIAlertController(
            title: "Detection Results",
            message: nil,
            preferredStyle: .actionSheet
        )
        resultsAlertController.addAction(
            UIAlertAction(title: "OK", style: .destructive) { _ in
                resultsAlertController.dismiss(animated: true, completion: nil)
            }
        )
        resultsAlertController.message = resultsText
        //resultsAlertController.popoverPresentationController?.barButtonItem = detectButton
        resultsAlertController.popoverPresentationController?.sourceView = self.view
        present(resultsAlertController, animated: true, completion: nil)
        print(resultsText)
    }
    
    /// Updates the image view with a scaled version of the given image.
    private func updateImageView(with image: UIImage) {
        let orientation = UIApplication.shared.statusBarOrientation
        var scaledImageWidth: CGFloat = 0.0
        var scaledImageHeight: CGFloat = 0.0
        switch orientation {
        case .portrait, .portraitUpsideDown, .unknown:
            scaledImageWidth = imageView.bounds.size.width
            scaledImageHeight = image.size.height * scaledImageWidth / image.size.width
        case .landscapeLeft, .landscapeRight:
            scaledImageWidth = image.size.width * scaledImageHeight / image.size.height
            scaledImageHeight = imageView.bounds.size.height
        }
        DispatchQueue.global(qos: .userInitiated).async {
            // Scale image while maintaining aspect ratio so it displays better in the UIImageView.
            var scaledImage = image.scaledImage(
                with: CGSize(width: scaledImageWidth, height: scaledImageHeight)
            )
            scaledImage = scaledImage ?? image
            guard let finalImage = scaledImage else { return }
            DispatchQueue.main.async {
                self.imageView.image = finalImage
            }
        }
    }
    
    private func transformMatrix() -> CGAffineTransform {
        guard let image = imageView.image else { return CGAffineTransform() }
        let imageViewWidth = imageView.frame.size.width
        let imageViewHeight = imageView.frame.size.height
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        let imageViewAspectRatio = imageViewWidth / imageViewHeight
        let imageAspectRatio = imageWidth / imageHeight
        let scale = (imageViewAspectRatio > imageAspectRatio) ?
            imageViewHeight / imageHeight :
            imageViewWidth / imageWidth
        
        // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
        // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
        let scaledImageWidth = imageWidth * scale
        let scaledImageHeight = imageHeight * scale
        let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
        let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)
        
        var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
        transform = transform.scaledBy(x: scale, y: scale)
        return transform
    }
    
    private func addContours(forFace face: VisionFace, transform: CGAffineTransform) {
        // Face
        if let faceContour = face.contour(ofType: .face) {
            for point in faceContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        
        // Eyebrows
        if let topLeftEyebrowContour = face.contour(ofType: .leftEyebrowTop) {
            for point in topLeftEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let bottomLeftEyebrowContour = face.contour(ofType: .leftEyebrowBottom) {
            for point in bottomLeftEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let topRightEyebrowContour = face.contour(ofType: .rightEyebrowTop) {
            for point in topRightEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let bottomRightEyebrowContour = face.contour(ofType: .rightEyebrowBottom) {
            for point in bottomRightEyebrowContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        
        // Eyes
        if let leftEyeContour = face.contour(ofType: .leftEye) {
            for point in leftEyeContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius                )
            }
        }
        if let rightEyeContour = face.contour(ofType: .rightEye) {
            for point in rightEyeContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        
        // Lips
        if let topUpperLipContour = face.contour(ofType: .upperLipTop) {
            for point in topUpperLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let bottomUpperLipContour = face.contour(ofType: .upperLipBottom) {
            for point in bottomUpperLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let topLowerLipContour = face.contour(ofType: .lowerLipTop) {
            for point in topLowerLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let bottomLowerLipContour = face.contour(ofType: .lowerLipBottom) {
            for point in bottomLowerLipContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        
        // Nose
        if let noseBridgeContour = face.contour(ofType: .noseBridge) {
            for point in noseBridgeContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
        if let noseBottomContour = face.contour(ofType: .noseBottom) {
            for point in noseBottomContour.points {
                let transformedPoint = pointFrom(point).applying(transform);
                UIUtilities.addCircle(
                    atPoint: transformedPoint,
                    to: annotationOverlayView,
                    color: UIColor.yellow,
                    radius: Constants.smallDotRadius
                )
            }
        }
    }
    
    private func addLandmarks(forFace face: VisionFace, transform: CGAffineTransform) {
        // Mouth
        if let bottomMouthLandmark = face.landmark(ofType: .mouthBottom) {
            let point = pointFrom(bottomMouthLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Constants.largeDotRadius
            )
        }
        if let leftMouthLandmark = face.landmark(ofType: .mouthLeft) {
            let point = pointFrom(leftMouthLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Constants.largeDotRadius
            )
        }
        if let rightMouthLandmark = face.landmark(ofType: .mouthRight) {
            let point = pointFrom(rightMouthLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.red,
                radius: Constants.largeDotRadius
            )
        }
        
        // Nose
        if let noseBaseLandmark = face.landmark(ofType: .noseBase) {
            let point = pointFrom(noseBaseLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.yellow,
                radius: Constants.largeDotRadius
            )
        }
        
        // Eyes
        if let leftEyeLandmark = face.landmark(ofType: .leftEye) {
            let point = pointFrom(leftEyeLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.cyan,
                radius: Constants.largeDotRadius
            )
        }
        if let rightEyeLandmark = face.landmark(ofType: .rightEye) {
            let point = pointFrom(rightEyeLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.cyan,
                radius: Constants.largeDotRadius
            )
        }
        
        // Ears
        if let leftEarLandmark = face.landmark(ofType: .leftEar) {
            let point = pointFrom(leftEarLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.purple,
                radius: Constants.largeDotRadius
            )
        }
        if let rightEarLandmark = face.landmark(ofType: .rightEar) {
            let point = pointFrom(rightEarLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.purple,
                radius: Constants.largeDotRadius
            )
        }
        
        // Cheeks
        if let leftCheekLandmark = face.landmark(ofType: .leftCheek) {
            let point = pointFrom(leftCheekLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.orange,
                radius: Constants.largeDotRadius
            )
        }
        if let rightCheekLandmark = face.landmark(ofType: .rightCheek) {
            let point = pointFrom(rightCheekLandmark.position)
            let transformedPoint = point.applying(transform)
            UIUtilities.addCircle(
                atPoint: transformedPoint,
                to: annotationOverlayView,
                color: UIColor.orange,
                radius: Constants.largeDotRadius
            )
        }
    }
    
    private func pointFrom(_ visionPoint: VisionPoint) -> CGPoint {
        return CGPoint(x: CGFloat(visionPoint.x.floatValue), y: CGFloat(visionPoint.y.floatValue))
    }
    
    private func process(_ visionImage: VisionImage, with textRecognizer: VisionTextRecognizer?) {
        textRecognizer?.process(visionImage) { text, error in
            guard error == nil, let text = text else {
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "Text recognizer failed with error: \(errorString)"
                self.showResults()
                return
            }
            // Blocks.
            for block in text.blocks {
                let transformedRect = block.frame.applying(self.transformMatrix())
                UIUtilities.addRectangle(
                    transformedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.purple
                )
                
                // Lines.
                for line in block.lines {
                    let transformedRect = line.frame.applying(self.transformMatrix())
                    UIUtilities.addRectangle(
                        transformedRect,
                        to: self.annotationOverlayView,
                        color: UIColor.orange
                    )
                    
                    // Elements.
                    for element in line.elements {
                        let transformedRect = element.frame.applying(self.transformMatrix())
                        UIUtilities.addRectangle(
                            transformedRect,
                            to: self.annotationOverlayView,
                            color: UIColor.green
                        )
                        let label = UILabel(frame: transformedRect)
                        label.text = element.text
                        label.adjustsFontSizeToFitWidth = true
                        self.annotationOverlayView.addSubview(label)
                    }
                }
            }
            self.resultsText += "\(text.text)\n"
            self.showResults()
        }
    }
    
    private func process(
        _ visionImage: VisionImage,
        with documentTextRecognizer: VisionDocumentTextRecognizer?
        ) {
        documentTextRecognizer?.process(visionImage) { text, error in
            guard error == nil, let text = text else {
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "Document text recognizer failed with error: \(errorString)"
                self.showResults()
                return
            }
            // Blocks.
            for block in text.blocks {
                let transformedRect = block.frame.applying(self.transformMatrix())
                UIUtilities.addRectangle(
                    transformedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.purple
                )
                
                // Paragraphs.
                for paragraph in block.paragraphs {
                    let transformedRect = paragraph.frame.applying(self.transformMatrix())
                    UIUtilities.addRectangle(
                        transformedRect,
                        to: self.annotationOverlayView,
                        color: UIColor.orange
                    )
                    
                    // Words.
                    for word in paragraph.words {
                        let transformedRect = word.frame.applying(self.transformMatrix())
                        UIUtilities.addRectangle(
                            transformedRect,
                            to: self.annotationOverlayView,
                            color: UIColor.green
                        )
                        
                        // Symbols.
                        for symbol in word.symbols {
                            let transformedRect = symbol.frame.applying(self.transformMatrix())
                            UIUtilities.addRectangle(
                                transformedRect,
                                to: self.annotationOverlayView,
                                color: UIColor.cyan
                            )
                            let label = UILabel(frame: transformedRect)
                            label.text = symbol.text
                            label.adjustsFontSizeToFitWidth = true
                            self.annotationOverlayView.addSubview(label)
                        }
                    }
                }
            }
            self.resultsText += "\(text.text)\n"
            self.showResults()
        }
    }
    
    // MARK: - Private
    /// Removes the detection annotations from the annotation overlay view.
    private func removeDetectionAnnotations() {
        for annotationView in annotationOverlayView.subviews {
            annotationView.removeFromSuperview()
        }
    }
    
    /// Clears the results text view and removes any frames that are visible.
    private func clearResults() {
        removeDetectionAnnotations()
        self.resultsText = ""
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
        clearResults()
        if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            updateImageView(with: pickedImage)
        }
        dismiss(animated: true)
    }
}

/// Extension of ViewController for On-Device and Cloud detection.
extension ViewController {
    
    // MARK: - Vision On-Device Detection
    /// Detects faces on the specified image and draws a frame around the detected faces using
    /// On-Device face API.
    ///
    /// - Parameter image: The image.
    func detectFaces(image: UIImage?) {
        guard let image = image else { return }
        
        // Create a face detector with options.
        // [START config_face]
        let options = VisionFaceDetectorOptions()
        options.landmarkMode = .all
        options.classificationMode = .all
        options.performanceMode = .accurate
        options.contourMode = .all
        // [END config_face]
        // [START init_face]
        let faceDetector = vision.faceDetector(options: options)
        // [END init_face]
        // Define the metadata for the image.
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = UIUtilities.visionImageOrientation(from: image.imageOrientation)
        
        // Initialize a VisionImage object with the given UIImage.
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        
        // [START detect_faces]
        faceDetector.process(visionImage) { faces, error in
            guard error == nil, let faces = faces, !faces.isEmpty else {
                // [START_EXCLUDE]
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "On-Device face detection failed with error: \(errorString)"
                self.showResults()
                // [END_EXCLUDE]
                return
            }
            
            // Faces detected
            // [START_EXCLUDE]
            faces.forEach { face in
                let transform = self.transformMatrix()
                let transformedRect = face.frame.applying(transform)
                UIUtilities.addRectangle(
                    transformedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.green
                )
                self.addLandmarks(forFace: face, transform: transform)
                self.addContours(forFace: face, transform: transform)
            }
            self.resultsText = faces.map { face in
                let headEulerAngleY = face.hasHeadEulerAngleY ? face.headEulerAngleY.description : "NA"
                let headEulerAngleZ = face.hasHeadEulerAngleZ ? face.headEulerAngleZ.description : "NA"
                let leftEyeOpenProbability = face.hasLeftEyeOpenProbability ? face.leftEyeOpenProbability.description : "NA"
                let rightEyeOpenProbability = face.hasRightEyeOpenProbability ? face.rightEyeOpenProbability.description : "NA"
                let smilingProbability = face.hasSmilingProbability ? face.smilingProbability.description : "NA"
                let output = """
                Frame: \(face.frame)
                Head Euler Angle Y: \(headEulerAngleY)
                Head Euler Angle Z: \(headEulerAngleZ)
                Left Eye Open Probability: \(leftEyeOpenProbability)
                Right Eye Open Probability: \(rightEyeOpenProbability)
                Smiling Probability: \(smilingProbability)
                """
                return "\(output)"
                }.joined(separator: "\n")
            self.showResults()
            // [END_EXCLUDE]
        }
        // [END detect_faces]
    }
    
    /// Detects barcodes on the specified image and draws a frame around the detected barcodes using
    /// On-Device barcode API.
    ///
    /// - Parameter image: The image.
    func detectBarcodes(image: UIImage?) {
        guard let image = image else { return }
        
        // Define the options for a barcode detector.
        // [START config_barcode]
        let format = VisionBarcodeFormat.all
        let barcodeOptions = VisionBarcodeDetectorOptions(formats: format)
        // [END config_barcode]
        // Create a barcode detector.
        // [START init_barcode]
        let barcodeDetector = vision.barcodeDetector(options: barcodeOptions)
        // [END init_barcode]
        // Define the metadata for the image.
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = UIUtilities.visionImageOrientation(from: image.imageOrientation)
        
        // Initialize a VisionImage object with the given UIImage.
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        
        // [START detect_barcodes]
        barcodeDetector.detect(in: visionImage) { features, error in
            guard error == nil, let features = features, !features.isEmpty else {
                // [START_EXCLUDE]
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "On-Device barcode detection failed with error: \(errorString)"
                self.showResults()
                // [END_EXCLUDE]
                return
            }
            
            // [START_EXCLUDE]
            features.forEach { feature in
                let transformedRect = feature.frame.applying(self.transformMatrix())
                UIUtilities.addRectangle(
                    transformedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.green
                )
            }
            self.resultsText = features.map { feature in
                return "DisplayValue: \(feature.displayValue ?? ""), RawValue: " +
                "\(feature.rawValue ?? ""), Frame: \(feature.frame)"
                }.joined(separator: "\n")
            self.showResults()
            // [END_EXCLUDE]
        }
        // [END detect_barcodes]
    }
    
    /// Detects labels on the specified image using On-Device label API.
    ///
    /// - Parameter image: The image.
    func detectLabels(image: UIImage?) {
        guard let image = image else { return }
        
        // [START config_label]
        let options = VisionOnDeviceImageLabelerOptions()
        options.confidenceThreshold = Constants.labelConfidenceThreshold
        // [END config_label]
        // [START init_label]
        let onDeviceLabeler = vision.onDeviceImageLabeler(options: options)
        // [END init_label]
        // Define the metadata for the image.
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = UIUtilities.visionImageOrientation(from: image.imageOrientation)
        
        // Initialize a VisionImage object with the given UIImage.
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        
        // [START detect_label]
        onDeviceLabeler.process(visionImage) { labels, error in
            guard error == nil, let labels = labels, !labels.isEmpty else {
                // [START_EXCLUDE]
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "On-Device label detection failed with error: \(errorString)"
                self.showResults()
                // [END_EXCLUDE]
                return
            }
            
            // [START_EXCLUDE]
            self.resultsText = labels.map { label -> String in
                return "Label: \(label.text), " +
                    "Confidence: \(label.confidence ?? 0), " +
                "EntityID: \(label.entityID ?? "")"
                }.joined(separator: "\n")
            self.showResults()
            // [END_EXCLUDE]
        }
        // [END detect_label]
    }
    
    
    /// Detects text on the specified image and draws a frame around the recognized text using the
    /// On-Device text recognizer.
    ///
    /// - Parameter image: The image.
    func detectTextOnDevice(image: UIImage?) {
        guard let image = image else { return }
        
        // [START init_text]
        let onDeviceTextRecognizer = vision.onDeviceTextRecognizer()
        // [END init_text]
        // Define the metadata for the image.
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = UIUtilities.visionImageOrientation(from: image.imageOrientation)
        
        // Initialize a VisionImage object with the given UIImage.
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        
        self.resultsText += "Running On-Device Text Recognition...\n"
        process(visionImage, with: onDeviceTextRecognizer)
    }
    
    // MARK: - Vision Cloud Detection
    /// Detects text on the specified image and draws a frame around the recognized text using the
    /// Cloud text recognizer.
    ///
    /// - Parameter image: The image.
    func detectTextInCloud(image: UIImage?, options: VisionCloudTextRecognizerOptions? = nil) {
        guard let image = image else { return }
        
        // Define the metadata for the image.
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = UIUtilities.visionImageOrientation(from: image.imageOrientation)
        
        // Initialize a VisionImage object with the given UIImage.
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        
        // [START init_text_cloud]
        var cloudTextRecognizer: VisionTextRecognizer?
        var modelTypeString = Constants.sparseTextModelName
        if let options = options {
            modelTypeString = (options.modelType == .dense) ?
                Constants.denseTextModelName :
            modelTypeString
            cloudTextRecognizer = vision.cloudTextRecognizer(options: options)
        } else {
            cloudTextRecognizer = vision.cloudTextRecognizer()
        }
        // [END init_text_cloud]
        self.resultsText += "Running Cloud Text Recognition (\(modelTypeString) model)...\n"
        process(visionImage, with: cloudTextRecognizer)
    }
    
    /// Detects document text on the specified image and draws a frame around the recognized text
    /// using the Cloud document text recognizer.
    ///
    /// - Parameter image: The image.
    func detectDocumentTextInCloud(image: UIImage?) {
        guard let image = image else { return }
        
        // Define the metadata for the image.
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = UIUtilities.visionImageOrientation(from: image.imageOrientation)
        
        // Initialize a VisionImage object with the given UIImage.
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        
        // [START init_document_text_cloud]
        let cloudDocumentTextRecognizer = vision.cloudDocumentTextRecognizer()
        // [END init_document_text_cloud]
        self.resultsText += "Running Cloud Document Text Recognition...\n"
        process(visionImage, with: cloudDocumentTextRecognizer)
    }
    
    /// Detects landmarks on the specified image and draws a frame around the detected landmarks using
    /// cloud landmark API.
    ///
    /// - Parameter image: The image.
    func detectCloudLandmarks(image: UIImage?) {
        guard let image = image else { return }
        
        // Define the metadata for the image.
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = UIUtilities.visionImageOrientation(from: image.imageOrientation)
        
        // Initialize a VisionImage object with the given UIImage.
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        
        // Create a landmark detector.
        // [START config_landmark_cloud]
        let options = VisionCloudDetectorOptions()
        options.modelType = .latest
        options.maxResults = 20
        // [END config_landmark_cloud]
        // [START init_landmark_cloud]
        let cloudDetector = vision.cloudLandmarkDetector(options: options)
        // Or, to use the default settings:
        // let cloudDetector = vision.cloudLandmarkDetector()
        // [END init_landmark_cloud]
        // [START detect_landmarks_cloud]
        cloudDetector.detect(in: visionImage) { landmarks, error in
            guard error == nil, let landmarks = landmarks, !landmarks.isEmpty else {
                // [START_EXCLUDE]
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "Cloud landmark detection failed with error: \(errorString)"
                self.showResults()
                // [END_EXCLUDE]
                return
            }
            
            // Recognized landmarks
            // [START_EXCLUDE]
            landmarks.forEach { landmark in
                let transformedRect = landmark.frame.applying(self.transformMatrix())
                UIUtilities.addRectangle(
                    transformedRect,
                    to: self.annotationOverlayView,
                    color: UIColor.green
                )
            }
            self.resultsText = landmarks.map { landmark -> String in
                return "Landmark: \(String(describing: landmark.landmark ?? "")), " +
                    "Confidence: \(String(describing: landmark.confidence ?? 0) ), " +
                    "EntityID: \(String(describing: landmark.entityId ?? "") ), " +
                "Frame: \(landmark.frame)"
                }.joined(separator: "\n")
            self.showResults()
            // [END_EXCLUDE]
        }
        // [END detect_landmarks_cloud]
    }
    
    /// Detects labels on the specified image using cloud label API.
    ///
    /// - Parameter image: The image.
    func detectCloudLabels(image: UIImage?) {
        guard let image = image else { return }
        
        // [START init_label_cloud]
        let cloudLabeler = vision.cloudImageLabeler()
        // Or, to change the default settings:
        // let cloudLabeler = vision.cloudImageLabeler(options: options)
        // [END init_label_cloud]
        // Define the metadata for the image.
        let imageMetadata = VisionImageMetadata()
        imageMetadata.orientation = UIUtilities.visionImageOrientation(from: image.imageOrientation)
        
        // Initialize a VisionImage object with the given UIImage.
        let visionImage = VisionImage(image: image)
        visionImage.metadata = imageMetadata
        
        // [START detect_label_cloud]
        cloudLabeler.process(visionImage) { labels, error in
            guard error == nil, let labels = labels, !labels.isEmpty else {
                // [START_EXCLUDE]
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                self.resultsText = "Cloud label detection failed with error: \(errorString)"
                self.showResults()
                // [END_EXCLUDE]
                return
            }
            
            // Labeled image
            // START_EXCLUDE
            self.resultsText = labels.map { label -> String in
                "Label: \(label.text), " +
                    "Confidence: \(label.confidence ?? 0), " +
                "EntityID: \(label.entityID ?? "")"
                }.joined(separator: "\n")
            self.showResults()
            // [END_EXCLUDE]
        }
        // [END detect_label_cloud]
    }
    
    
    
}

// MARK: - Enums
private enum DetectorPickerRow: Int {
    case detectFaceOnDevice = 0,
    detectTextOnDevice,
    detectBarcodeOnDevice,
    detectImageLabelsOnDevice,
    detectImageLabelsAutoMLOnDevice,
    detectObjectsProminentNoClassifier,
    detectObjectsProminentWithClassifier,
    detectObjectsMultipleNoClassifier,
    detectObjectsMultipleWithClassifier,
    detectTextInCloudSparse,
    detectTextInCloudDense,
    detectDocumentTextInCloud,
    detectImageLabelsInCloud,
    detectLandmarkInCloud
    
    static let rowsCount = 14
    static let componentsCount = 1
    
    public var description: String {
        switch self {
        case .detectFaceOnDevice:
            return "Face On-Device"
        case .detectTextOnDevice:
            return "Text On-Device"
        case .detectBarcodeOnDevice:
            return "Barcode On-Device"
        case .detectImageLabelsOnDevice:
            return "Image Labeling On-Device"
        case .detectImageLabelsAutoMLOnDevice:
            return "Image Labeling AutoML On-Device"
        case .detectObjectsProminentNoClassifier:
            return "ODT, prominent, only tracking"
        case .detectObjectsProminentWithClassifier:
            return "ODT, prominent, with classification"
        case .detectObjectsMultipleNoClassifier:
            return "ODT, multiple, only tracking"
        case .detectObjectsMultipleWithClassifier:
            return "ODT, multiple, with classification"
        case .detectTextInCloudSparse:
            return "Text in Cloud (Sparse)"
        case .detectTextInCloudDense:
            return "Text in Cloud (Dense)"
        case .detectDocumentTextInCloud:
            return "Document Text in Cloud"
        case .detectImageLabelsInCloud:
            return "Image Labeling in Cloud"
        case .detectLandmarkInCloud:
            return "Landmarks in Cloud"
        }
    }
}

private enum Constants {
    static let images = ["sunshine_edwards.jpg", "barcode_128.png", "qr_code.jpg", "beach.jpg",
                         "image_has_text.jpg", "liberty.jpg"]
    static let modelExtension = "tflite"
    static let localModelName = "mobilenet"
    static let quantizedModelFilename = "mobilenet_quant_v1_224"
    
    static let detectionNoResultsMessage = "No results returned."
    static let failedToDetectObjectsMessage = "Failed to detect objects in image."
    static let sparseTextModelName = "Sparse"
    static let denseTextModelName = "Dense"
    
    static let localAutoMLModelName = "local_automl_model"
    static let remoteAutoMLModelName = "remote_automl_model"
    static let localModelManifestFileName = "automl_labeler_manifest"
    static let autoMLManifestFileType = "json"
    
    static let labelConfidenceThreshold: Float = 0.75
    static let smallDotRadius: CGFloat = 5.0
    static let largeDotRadius: CGFloat = 10.0
    static let lineColor = UIColor.yellow.cgColor
    static let fillColor = UIColor.clear.cgColor
}

//
//  SCDuplicatedPhotosViewModel.swift
//  Cleaner App
//
//  Created by Vusal Nuriyev 2 on 18.09.24.
//

import SwiftUI
import Photos
import Combine

class SCDuplicatedPhotosViewModel: ObservableObject {
    
    @Published var duplicatePhotosCount: Int = 0
    @Published var duplicatePhotos: [SCDuplicatePhoto] = []
    @Published var selectedPhotos: Set<String> = []
    @Published var isDeleting: Bool = false
    
    init() {
        findDuplicatePhotos()
    }
    
    // MARK: - Duplicate Photos Detection
    
    func findDuplicatePhotos() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self else { return }
            
            var photos: [SCPhoto] = []
            
            if status == .authorized {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                
                var duplicates: [SCDuplicatePhoto] = []
                var assetFeatures: [String: [PHAsset]] = [:]
                
                assets.enumerateObjects { asset, _, _ in
                    
                    let options = PHImageRequestOptions()
                    options.isSynchronous = true
                    var image: UIImage?
                    
                    PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: options) { result, _ in
                        image = result
                    }
                    
                    if let image = image {
                        let features = self.extractFeatures(from: image)
                        let featureKey = self.generateFeatureKey(from: features)
                        if assetFeatures[featureKey] != nil {
                            assetFeatures[featureKey]?.append(asset)
                        } else {
                            assetFeatures[featureKey] = [asset]
                        }
                        
                        let photo = SCPhoto(imageName: asset.localIdentifier, imageData: image)
                        photos.append(photo)
                    }
                }
                
                
                for (featureKey, assets) in assetFeatures {
                    if assets.count > 1 {
                        let duplicatePhotos = assets.compactMap { asset -> SCPhoto? in
                            var image: UIImage?
                            let options = PHImageRequestOptions()
                            options.isSynchronous = true
                            
                            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: options) { result, _ in
                                image = result
                            }
                            
                            if let image = image {
                                return SCPhoto(imageName: asset.localIdentifier, imageData: image)
                            }
                            return nil
                        }
                        
                        let groupName = self.generateDuplicateGroupName(from: assets)
                        let totalSizeMB = assets.reduce(0) { (accumulatedSize, asset) -> Double in
                            accumulatedSize + asset.fileSizeInMB()
                        }
                        
                        let duplicatePhotoGroup = SCDuplicatePhoto(
                            name: groupName,
                            photoCount: duplicatePhotos.count,
                            size: totalSizeMB,
                            photos: duplicatePhotos
                        )
                        duplicates.append(duplicatePhotoGroup)
                    }
                }
                
                DispatchQueue.main.async {
                    self.duplicatePhotos = duplicates
                }
            } else {
                print("Access to photos is denied.")
            }
        }
    }

    func extractFeatures(from image: UIImage) -> [CGFloat] {
        guard let cgImage = image.cgImage else { return [] }

        let histogramBins = 256
        var histogramR = [CGFloat](repeating: 0, count: histogramBins)
        var histogramG = [CGFloat](repeating: 0, count: histogramBins)
        var histogramB = [CGFloat](repeating: 0, count: histogramBins)

        let width = cgImage.width
        let height = cgImage.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo)!
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        guard let pixelBuffer = context.data else { return [] }
        let pixelPointer = pixelBuffer.bindMemory(to: UInt8.self, capacity: width * height * 4)

        for x in 0..<width {
            for y in 0..<height {
                let pixelIndex = ((width * y) + x) * 4
                let red = CGFloat(pixelPointer[pixelIndex])
                let green = CGFloat(pixelPointer[pixelIndex + 1])
                let blue = CGFloat(pixelPointer[pixelIndex + 2])

                histogramR[Int(red)] += 1
                histogramG[Int(green)] += 1
                histogramB[Int(blue)] += 1
            }
        }
        
        let pixelCount = CGFloat(width * height)
        let normalizedHistogramR = histogramR.map { $0 / pixelCount }
        let normalizedHistogramG = histogramG.map { $0 / pixelCount }
        let normalizedHistogramB = histogramB.map { $0 / pixelCount }

        return normalizedHistogramR + normalizedHistogramG + normalizedHistogramB
    }

    func generateFeatureKey(from features: [CGFloat]) -> String {
        return features.map { String(format: "%.3f", $0) }.joined(separator: "-")
    }
    
    // Fetch the UIImage from the PHAsset
    func fetchUIImage(from asset: PHAsset) -> UIImage? {
        var image: UIImage?
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFit, options: options) { result, _ in
            image = result
        }
        return image
    }
    
    func imagesAreVisuallyIdentical(_ image1: UIImage, _ image2: UIImage) -> Bool {
        let features1 = extractFeatures(from: image1)
        let features2 = extractFeatures(from: image2)
        
        let similarityThreshold: CGFloat = 0.9
        let similarity = calculateHistogramSimilarity(features1, features2)
        
        return similarity >= similarityThreshold
    }

    func calculateHistogramSimilarity(_ features1: [CGFloat], _ features2: [CGFloat]) -> CGFloat {
        guard features1.count == features2.count else { return 0 }
        
        let dotProduct = zip(features1, features2).reduce(0) { $0 + $1.0 * $1.1 }
        let magnitude1 = sqrt(features1.reduce(0) { $0 + $1 * $1 })
        let magnitude2 = sqrt(features2.reduce(0) { $0 + $1 * $1 })
        
        return dotProduct / (magnitude1 * magnitude2)
    }
    
    
    func deleteOneDuplicatePhotoPerGroup() {
        PHPhotoLibrary.shared().performChanges({ [weak self] in
            guard let self = self else { return }
            
            for photoGroup in self.duplicatePhotos {
                
                if let firstPhotoIdentifier = photoGroup.photos.first?.imageName {
                    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [firstPhotoIdentifier], options: nil)
                    
                    PHAssetChangeRequest.deleteAssets(assets)
                    self.isDeleting = true
                }
            }
        }) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                print("One photo from each duplicate group has been deleted.")
                self.updateAfterDeletion()
            } else if let error = error {
                print("Failed to delete photos: \(error.localizedDescription)")
            }
            self.isDeleting = false
        }
    }
    
    func deleteSelectedPhotos(from photoGroups: [SCDuplicatePhoto]) {
        isDeleting = true
        
        let selectedAssets = photoGroups.flatMap { group in
            group.photos.filter { selectedPhotos.contains($0.imageName) }
        }
        
        let assetIdentifiers = selectedAssets.map { $0.imageName }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("Selected photos deleted.")
                    self?.removeDeletedPhotos(from: selectedAssets)
                } else if let error = error {
                    print("Error deleting photos: \(error.localizedDescription)")
                }
                self?.isDeleting = false
            }
        }
    }
    
    
    private func removeDeletedPhotos(from deletedPhotos: [SCPhoto]) {
        
        selectedPhotos.removeAll()
        
        for i in 0..<duplicatePhotos.count {
            duplicatePhotos[i].photos.removeAll { photo in
                deletedPhotos.contains { $0.imageName == photo.imageName }
            }
        }
        
        duplicatePhotos.removeAll { $0.photos.isEmpty }
        
        self.objectWillChange.send()
    }
    
    func updateAfterDeletion() {
        
        for (index, photoGroup) in duplicatePhotos.enumerated() {
            if !photoGroup.photos.isEmpty {
                duplicatePhotos[index].photos.removeFirst()
            }
        }
        
        duplicatePhotos.removeAll { $0.photos.isEmpty }
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func updateAfterDeletion(newValue: SCDuplicatePhoto) {
        guard let index = duplicatePhotos.firstIndex(where: {$0.name == newValue.name}) else {return}
        duplicatePhotos.remove(at: index)
    }
}

extension SCDuplicatedPhotosViewModel {
    
    func generateDuplicateGroupName(from assets: [PHAsset]) -> String {
        if let firstAsset = assets.first, let creationDate = firstAsset.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Duplicate Group - \(formatter.string(from: creationDate))"
        }
        return "Duplicate Group"
    }

    func averageHash(for image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let grayCgImage = resizedImage?.cgImage else { return nil }
        guard let context = CGContext(data: nil,
                                      width: 8,
                                      height: 8,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 8,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        
        context.draw(grayCgImage, in: CGRect(x: 0, y: 0, width: 8, height: 8))
        guard let pixelData = context.makeImage()?.dataProvider?.data else { return nil }
        
        let data = CFDataGetBytePtr(pixelData)
        
        var totalBrightness: UInt64 = 0
        for i in 0..<64 {
            totalBrightness += UInt64(data![i])
        }
        let averageBrightness = totalBrightness / 64
        
        var hash = ""
        for i in 0..<64 {
            hash += data![i] >= averageBrightness ? "1" : "0"
        }
        
        return hash
    }
}

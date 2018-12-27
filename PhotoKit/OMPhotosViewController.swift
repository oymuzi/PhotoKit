//
//  OMPhotosViewController.swift
//  PhotoKit
//
//  Created by admin on 2018/12/27.
//  Copyright © 2018年 oymuzi. All rights reserved.
//

import UIKit

class PhotoCell: UICollectionViewCell {
    
    public var imageView: UIImageView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView = UIImageView.init(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        imageView?.contentMode = .scaleAspectFill
        imageView?.clipsToBounds = true
        imageView?.image = nil
        addSubview(imageView!)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


class OMPhotosViewController: UIViewController {
    
    /** 相簿*/
    fileprivate var album: OMAlbum?
    
    fileprivate var displayPhotos = [OMAsset]()
    
    private var photoListView: UICollectionView!
    
    private let reuse = "reuse"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        self.title = album?.title ?? "照片"
        self.setupUI()
        self.loadData()
    }
    
    private func setupUI() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        layout.itemSize = itemSize
        
        photoListView = UICollectionView.init(frame: self.view.bounds, collectionViewLayout: layout)
        photoListView.backgroundColor = UIColor.white
        photoListView.delegate = self
        photoListView.dataSource = self
        photoListView.register(PhotoCell().classForCoder, forCellWithReuseIdentifier: reuse)
        self.view.addSubview(photoListView)
    }
    
    private func loadData(){
        guard album != nil else { return }
        let manager = OMPhotoManager.init()
        self.displayPhotos = manager.requestAssets(from: album!, type: OMPhotoManager.OMAssetType.default)
        self.photoListView.reloadData()
    }
    
    /** 用相簿实例化*/
    public class func initWith(album: OMAlbum) -> OMPhotosViewController {
        let vc = OMPhotosViewController()
        vc.album = album
        return vc
    }
    
    private var itemSize: CGSize {
        let itemW = (UIScreen.main.bounds.width-3)/4
        return CGSize(width: itemW, height: itemW)
    }
    
}


extension OMPhotosViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.displayPhotos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuse, for: indexPath) as! PhotoCell
        var asset = displayPhotos[indexPath.item]
        cell.imageView?.om_requestImageFrom(asset: &asset, imageSize: itemSize*UIScreen.main.scale*1.5)
        return cell
    }
}


//
//  PhotoViewController.swift
//  PhotoKit
//
//  Created by admin on 2018/12/19.
//  Copyright © 2018年 oymuzi. All rights reserved.
//

import UIKit
import Photos

class PhotoViewController: UIViewController {

    
    private var defaultAlbum: PHFetchResult<PHAsset>?
    
    private var fetchResult: PHFetchResult<PHAsset>!
    
    private var displayAlbum = [PHAsset]()
    
    private var cacheingManager: PHCachingImageManager!
    
    private var collectionView: UICollectionView!
    
    private let pageCount: Int = 200
    
    private var pageDuration: Double = 0.05
    
    private var sectionCount: Int = 0
    
    private let resue = "reuse"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.gray
        setupUI()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(title: "Cancel", style: .plain, target: self, action: #selector(dismissView))
         self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "Albums", style: .plain, target: self, action: #selector(goToAlbums))
    }
    
    @objc private func dismissView() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func goToAlbums() {
        self.navigationController?.pushViewController(AlbumViewController.init(), animated: true)
    }
    
    private func initSetting(){
        self.cacheingManager = PHCachingImageManager()
        /** 请求用户访问相册的权限*/
        PHPhotoLibrary.requestAuthorization { (status) in
            
        }
        
        /** 判断用户授权的权限*/
        guard PHPhotoLibrary.authorizationStatus() == .authorized else { return }
        
        /** 更改图片时的操作，下面将会把指定的图片标记成喜欢/不喜欢的状态根据此图片之前的状态*/
        //        let needChangeFavriteAsset = PHAsset()
        //        library.performChanges({
        //            let changeReq = PHAssetChangeRequest.init(for: needChangeFavriteAsset)
        //            changeReq.isFavorite = !needChangeFavriteAsset.isFavorite
        //        }) { (isSuccess, error) in
        //            print("是否成功： \(isSuccess), 错误： \(error?.localizedDescription ?? "")")
        //        }
        
        //        library.performChanges({
        //            let changeReq = PHAssetCollectionChangeRequest.init(for: <#T##PHAssetCollection#>)
        //        }, completionHandler: <#T##((Bool, Error?) -> Void)?##((Bool, Error?) -> Void)?##(Bool, Error?) -> Void#>)
        
        
        /** 注册通知监听用户相册变化，且需获得访问用户相册的权限,无权限时将不能收到消息，将会在代理回调里进行回调，并且只有你app处于前台的时候你才能收到这个代理回调*/
//        library.register(self)
        
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAllBurstAssets = true
        if #available(iOS 9.0, *) {
            fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeiTunesSynced]
//            fetchOptions.fetchLimit = 100
        } else {
            // Fallback on earlier versions
        }
        
//        let albums = PHAssetCollection.fetchTopLevelUserCollections(with: fetchOptions)
        
        
        
        fetchOptions.sortDescriptors = [NSSortDescriptor.init(key: "creationDate", ascending: false)]
        self.fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        print("共获取数量： \(fetchResult.count)")
        
        self.title = fetchResult.count.description
        var tempData = [PHAsset]()
        fetchResult.enumerateObjects { (asset, index, stop) in
            tempData.append(asset)
        }
        self.displayAlbum = tempData
        self.changeLike(for: tempData[0]) { (status, error) in
            
        }
        print("结束时间：\(CFAbsoluteTimeGetCurrent())")
    }
  
    typealias editOprationBlock = (_ status: Bool, _ error: Error?) -> Void
    
    private func changeLike(for asset: PHAsset, completion: editOprationBlock?=nil) {
        PHPhotoLibrary.shared().performChanges({
            let changeLikeRequest = PHAssetChangeRequest.init(for: asset)
            changeLikeRequest.isFavorite = !asset.isFavorite
        }) { (status, error) in
            if completion != nil {
                completion?(status, error)
            }
        }
    }
   
    
    private func setupUI() {
        
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        
        layout.itemSize = itemSize
        
        collectionView = UICollectionView.init(frame: self.view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor.white
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PhotoCell().classForCoder, forCellWithReuseIdentifier: resue)
        self.view.addSubview(collectionView)
        
    }
    
    deinit {
        self.cacheingManager.stopCachingImagesForAllAssets()
        self.displayAlbum = []
        print("已经s背时angle")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("开始时间：\(CFAbsoluteTimeGetCurrent())")
        self.initSetting()
    }
    
    private var itemSize: CGSize {
        let itemW = (UIScreen.main.bounds.width-3)/4
        return CGSize(width: itemW, height: itemW)
    }

}


extension PhotoViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.displayAlbum.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: resue, for: indexPath) as! PhotoCell
        let asset = displayAlbum[indexPath.item]
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.progressHandler = { (progress, error, stop, info) in
            print("正在下载数据：\(progress*100)%")
        }
        self.cacheingManager.requestImage(for: asset, targetSize: CGSize(width: self.itemSize.width*2.5, height: self.itemSize.width*2.5), contentMode: PHImageContentMode.aspectFill, options: options) { [weak self] (image, info) in
            guard let _ = self else { return }
            if let source = image {
                cell.imageView?.image = source
            }
        }
        
        
        return cell
    }
}

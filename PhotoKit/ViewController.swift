//
//  ViewController.swift
//  PhotoKit
//
//  Created by admin on 2018/12/19.
//  Copyright © 2018年 oymuzi. All rights reserved.
//

import UIKit
import Photos

class ViewController: UIViewController {

    private var defaultAlbum: PHFetchResult<PHAsset>?
    
    private var displayAlbum = [PHAsset]()
    
    private var cacheingManager = PHCachingImageManager()
    
    private var library: PHPhotoLibrary = PHPhotoLibrary.shared()
    
    private var collectionView: UICollectionView!
    
    private let resue = "reuse"
    
    private var currentPage = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
////        initSetting()
//        setupUI()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "照片", style: .plain, target: self, action: #selector(presentPhoto))
    }
    
    @objc private func presentPhoto(){
        OMPhotoManager.presentAlbumsViewController(isPushToAllPhoto: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        self.initSetting()
    }
    
    private var itemSize: CGSize {
        let itemW = (UIScreen.main.bounds.width-3)/4
        return CGSize(width: itemW, height: itemW)
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
//        collectionView.mj_footer = MJRefreshAutoNormalFooter.init(refreshingBlock: {
//            self.startLoading()
//        })
        self.view.addSubview(collectionView)
        
    }
    
    private func initSetting(){
        print("开始时间：\(CFAbsoluteTimeGetCurrent())")
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
        library.register(self)
        
        
        let fetchOptions = PHFetchOptions()
        if #available(iOS 9.0, *) {
            fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeiTunesSynced]
        } else {
            // Fallback on earlier versions
        }
        fetchOptions.sortDescriptors = [NSSortDescriptor.init(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        
        
        fetchResult.enumerateObjects { (asset, index, stop) in
            self.displayAlbum.append(asset)
        }
        let requestOptions = PHImageRequestOptions()
        requestOptions.resizeMode = .exact
        requestOptions.deliveryMode = .highQualityFormat
//        DispatchQueue.global().sync {
            self.cacheingManager.startCachingImages(for: self.displayAlbum, targetSize: CGSize(width: self.itemSize.width*2.5, height: self.itemSize.width*2.5), contentMode: .default, options: requestOptions)
//        }
        print("结束时间：\(CFAbsoluteTimeGetCurrent())")
    }
    
    
//    private func startLoading(){
//
//        fetchResult.enumerateObjects { (asset, index, stop) in
//            self.displayAlbum.append(asset)
//        }
//        let requestOptions = PHImageRequestOptions()
//        requestOptions.resizeMode = .exact
//        requestOptions.deliveryMode = .fastFormat
//        cacheingManager.startCachingImages(for: displayAlbum, targetSize: itemSize, contentMode: .aspectFill, options: requestOptions)
//    }
    
//    private var fetchResult: PHFetchResult<PHAsset> {
//        let fetchOptions = PHFetchOptions()
//        if #available(iOS 9.0, *) {
//            fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeiTunesSynced]
//            fetchOptions.fetchLimit = 99
//        } else {
//            // Fallback on earlier versions
//        }
//        fetchOptions.sortDescriptors = [NSSortDescriptor.init(key: "creationDate", ascending: true)]
//        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
//        return fetchResult
//    }
    
    deinit {
        /** 取消监听相册变化*/
        self.library.unregisterChangeObserver(self)
    }


}

extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return displayAlbum.count
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
        self.cacheingManager.requestImage(for: asset, targetSize: CGSize(width: self.itemSize.width*2.5, height: self.itemSize.width*2.5), contentMode: PHImageContentMode.aspectFill, options: options) { (image, info) in
            if let source = image {
                cell.imageView?.image = source
            }
        }
        
        
        return cell
    }
}


extension ViewController: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        
    }
}


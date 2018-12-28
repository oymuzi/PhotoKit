//
//  OMPhotoManager.swift
//  PhotoKit
//
//  Created by admin on 2018/12/26.
//  Copyright © 2018年 oymuzi. All rights reserved.
//

import Foundation
import UIKit
import Photos

//MARK: - 拓展常用方法

extension Array{
    static func +(_ lhs: Array<Element>, _ rhs: Array<Element>) -> Array<Element> {
        var baseArray = lhs
        for element in rhs{
            baseArray.append(element)
        }
        return baseArray
    }
}

extension CGSize{
    
    static func * (_ lhs: CGSize, _ rhs: CGFloat) -> CGSize {
        return CGSize.init(width: lhs.width * rhs, height: lhs.height * rhs)
    }
    
    static func * (_ lhs: CGFloat, _ rhs: CGSize) -> CGSize {
        return CGSize.init(width: lhs * rhs.width, height: lhs * rhs.height)
    }
}

extension UIImageView{
    
    /** 请求相簿封面的图标*/
    func om_requestAlbumIcon(album: inout OMAlbum) {
        let manager = OMPhotoManager.init()
        manager.requestImageFrom(album: &album) { (image, info) in
            DispatchQueue.main.async {
                self.image = image
                self.setNeedsLayout()
            }
        }
    }
    
    /** 请求来自相簿的图片*/
    func om_requestImageFrom(asset: inout OMAsset, imageSize: CGSize) {
        let manager = OMPhotoManager.init()
        manager.requestImageFrom(asset: &asset, imageSize: imageSize) { (image, info) in
            DispatchQueue.main.async {
                self.image = image
                self.setNeedsLayout()
            }
        }
    }
    
}


func currentWindow() -> UIWindow? {
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    return appDelegate.window
}


func currentViewController() -> UIViewController?{
    guard let window = currentWindow() else { return nil }
    guard let rootVC = window.rootViewController else { return nil }
    if rootVC.isKind(of: UINavigationController.self) {
        let navgationController = rootVC as? UINavigationController
        return navgationController?.children.first
    }
    if rootVC.isKind(of: UITabBarController.self) {
        let tabbarController = rootVC as? UITabBarController
        let selectVC = tabbarController?.selectedViewController
        guard (selectVC?.isKind(of: UINavigationController.self) ?? false) else {
            return selectVC
        }
        return (selectVC as? UINavigationController)?.children.first
    }
    return rootVC
}

/** 缓存相簿列表数据的key */
fileprivate let cacheData: String = "OMAlbumsFromCache"

//MARK: - 图库管理者
class OMPhotoManager{
    
    /** 缓存相簿列表*/
    private var cacheAlbums: [OMCacheAlbum] = []
    
    /** 抓取的结果*/
    private var fetchResults: PHFetchResult<PHAsset>?
    
    /** 相簿管理器的配置*/
    public var config: OMAlbumConfig = OMAlbumConfig.init()
    
    /** 缓存管理器*/
    public var cacheImageManager: PHCachingImageManager = {
        let cacheImageManager = PHCachingImageManager.init()
        return cacheImageManager
    }()
    
    /** 请求获取图片的回调*/
    typealias OMAlbumRequestHandler = ((_ image: UIImage?, _ info: [AnyHashable: Any]?) -> Void)
    
    /** 请求获取相册图片的ID*/
    typealias OMImageRequestID = PHImageRequestID
    
    /** 操作回调*/
    typealias OMEditOprationHandler = ((_ status: Bool, _ error: Error?) -> Void)
    
    /** 获取相簿类型*/
    enum OMAlbumFetchType{
        /** 包含了系统相相簿和用户相簿*/
        case `default`
        /** 系统相簿*/
        case system
        /** 用户相簿*/
        case user
        /** 仅获取是图片的相簿*/
        case onlyImage
        /** 仅获取是视频的相簿*/
        case onlyVideo
        /** 仅获取是动态图的相簿集合*/
        @available(iOS 11.0, *)
        case onlyGIF
    }
    
    /** 资源类型*/
    enum OMAssetType {
        /** 默认为全获取*/
        case `default`
        /** 仅图片*/
        case onlyImage
        /** 仅GIF图片*/
        case onlyGIF
        /** 仅视频*/
        case onlyVideo
    }
    
    /** 错误类型*/
    enum OMError: Error{
        case notFoundAlbum          /// 未找到指定相簿
        case invalidAsset           /// 不合法的资源
        case deleteAssetFailured    /// 删除资源失败
        case deleteAlbumFailured    /// 删除相簿失败
        case initRequestFailured    /// 初始化操作失败
        case createAlbumFailured    /// 创建相簿失败
        case createAssetFailured    /// 创建资源失败
    }
    
    
    init() {
        self.cacheAlbums = readAlbumsFromCache()
    }
    
    //MARK: - public method
    
    //MARK: - open method
    /** 跳转到相簿页面，若isPushToAllPhoto为true，则直接跳转到所有图片的页面*/
    open class func presentAlbumsViewController(isPushToAllPhoto: Bool = false){
        let vc = OMAlbumsViewController()
        vc.title = "照片"
        let manager = OMPhotoManager.init()
        let navi = UINavigationController.init(rootViewController: vc)
        configureNavigationbar(navi.navigationBar)
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "取消", style: .plain, target: self, action: #selector(dismiss))
        DispatchQueue.main.async {
            if isPushToAllPhoto{
                let photos = manager.requestAssets(from: OMAsset.fetchAssets(with: OMAlbumConfig.fetchOptions))
                let photoViewController = OMPhotosViewController.initWith(assets: photos)
                photoViewController.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "取消", style: .plain, target: self, action: #selector(dismiss))
                vc.navigationController?.pushViewController(photoViewController, animated: false)
            }
            currentViewController()?.navigationController?.present(navi, animated: true, completion: nil)
        }
    }
    
    /** 设置导航栏*/
    private class func configureNavigationbar(_ bar: UINavigationBar){
        bar.tintColor = UIColor.black
        bar.barTintColor = UIColor.white
        bar.shadowImage = UIImage.init()
    }
    
    /** 关闭图片管理器*/
    @objc private class func dismiss(){
        DispatchQueue.main.async {
            currentViewController()?.dismiss(animated: true, completion: nil)
        }
    }
    
    //MARK: - add method
    
    /** 添加图片到指定相簿中*/
    public func addImage(_ image: UIImage, to album: OMAlbum, completion: OMEditOprationHandler?){
        performChange({ [weak self] () in
            guard let _ = self else { return }
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            request.creationDate = Date()
            guard let asset = request.placeholderForCreatedAsset else {
                completion?(false, OMError.initRequestFailured)
                return
            }
            PHAssetCollectionChangeRequest.init(for: album.collection)?.addAssets([asset] as NSArray)
            }, completionHandler: completion)
    }
    
    /** 添加一组图片到指定相簿中*/
    public func addImages(_ images: [UIImage], to album: OMAlbum, completion: OMEditOprationHandler?){
        performChange({ [weak self] () in
            guard let _ = self else { return }
            var assets = [PHObjectPlaceholder]()
            for image in images{
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                request.creationDate = Date()
                guard let asset = request.placeholderForCreatedAsset else {
                    completion?(false, OMError.initRequestFailured)
                    return
                }
                assets.append(asset)
            }
            PHAssetCollectionChangeRequest.init(for: album.collection)?.addAssets(assets as NSArray)
            }, completionHandler: completion)
    }
    
    /** 添加单个资源到指定相簿中*/
    public func addAsset(_ asset: OMAsset, to album: OMAlbum, completion: OMEditOprationHandler?){
        addAssets([asset], to: album, completion: completion)
    }
    
    /** 添加图片到指定相簿中， automaticCreateAlbum设置为true的时候将会在没有找到该相簿时自动创建*/
    public func addImage(_ image: UIImage, to albumName: String, automaticCreateAlbum: Bool = false, completion: OMEditOprationHandler?){
        lookupAlbums(names: [albumName], useCache: false) { (albums) in
            if albums.isEmpty {
                guard automaticCreateAlbum else {
                    completion?(false, OMError.invalidAsset)
                    return
                }
                self.createAlbum(name: albumName, completion: { (status, error) in
                    guard status else {
                        completion?(false, OMError.createAlbumFailured)
                        return
                    }
                    self.lookupAlbums(names: [albumName], useCache: false, completion: { (newAlbums) in
                        self.addImage(image, to: newAlbums[0], completion: completion)
                    })
                })
                return
            }
            self.addImage(image, to: albums[0], completion: completion)
        }
    }
    
    /** 添加图片到指定相簿中， automaticCreateAlbum设置为true的时候将会在没有找到该相簿时自动创建*/
    public func addImages(_ images: [UIImage], to albumName: String, automaticCreateAlbum: Bool = false, completion: OMEditOprationHandler?){
        lookupAlbums(names: [albumName], useCache: false) { (albums) in
            if albums.isEmpty {
                guard automaticCreateAlbum else {
                    completion?(false, OMError.invalidAsset)
                    return
                }
                self.createAlbum(name: albumName, completion: { (status, error) in
                    guard status else {
                        completion?(false, OMError.createAlbumFailured)
                        return
                    }
                    self.lookupAlbums(names: [albumName], useCache: false, completion: { (newAlbums) in
                        self.addImages(images, to: newAlbums[0], completion: completion)
                    })
                })
                return
            }
            self.addImages(images, to: albums[0], completion: completion)
        }
    }
    
    /** 添加单个资源到指定相簿中, automaticCreateAlbum设置为true的时候将会在没有找到该相簿时自动创建*/
    public func addAsset(_ asset: OMAsset, to albumName: String, automaticCreateAlbum: Bool = false, completion: OMEditOprationHandler?){
        self.addAssets([asset], to: albumName, automaticCreateAlbum: automaticCreateAlbum, completion: completion)
    }
    
    /** 添加多个资源到指定的相簿中*/
    public func addAssets(_ assets: [OMAsset], to album: OMAlbum, completion: OMEditOprationHandler?){
        performChange({ [weak self] () in
            guard let _ = self else { return }
            guard let request = PHAssetCollectionChangeRequest.init(for: album.collection) else {
                completion?(false, OMError.initRequestFailured)
                return
            }
            request.addAssets(assets as NSArray)
            }, completionHandler: completion)
    }
    
    /** 添加多个资源到指定的相簿中, automaticCreateAlbum设置为true的时候将会在没有找到该相簿时自动创建*/
    public func addAssets(_ assets: [OMAsset], to albumName: String, automaticCreateAlbum: Bool = false, completion: OMEditOprationHandler?){
        guard !assets.isEmpty else {
            completion?(false, OMError.invalidAsset)
            return
        }
        self.lookupAlbums(names: [albumName], useCache: false) { (albums) in
            if albums.isEmpty {
                guard automaticCreateAlbum else {
                    completion?(false, OMError.notFoundAlbum)
                    return
                }
                self.createAlbum(name: albumName, completion: { (status, error) in
                    guard status else {
                        completion?(false, OMError.createAlbumFailured)
                        return
                    }
                    self.lookupAlbums(names: [albumName], useCache: false, completion: { (newAlbums) in
                        self.addAssets(assets, to: newAlbums[0], completion: completion)
                    })
                })
                return
            }
            self.addAssets(assets, to: albums[0], completion: completion)
        }
    }
    
    /** 创建相簿*/
    public func createAlbum(name: String, completion: OMEditOprationHandler?){
        performChange({ [weak self] () in
            guard let _ = self else { return }
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            }, completionHandler: completion)
    }
    
    /** 创建相簿列表*/
    public func createAlbumList(name: String, completionHandler: OMEditOprationHandler?) {
        performChange({ [weak self] () in
            guard let _ = self else { return }
            PHCollectionListChangeRequest.creationRequestForCollectionList(withTitle: name)
            }, completionHandler: completionHandler)
    }
    
    //MARK: - remove method
    /** 根据相簿名称移除单个相簿*/
    public func removeAlbum(name: String, completion: OMEditOprationHandler?){
        removeAlbum(names: [name], completion: completion)
    }
    
    /** 根据相簿名称数组移除多个相簿, 默认删除相簿里的照片或视频等资源*/
    public func removeAlbum(names: [String], removeAllAssets: Bool = true, completion: OMEditOprationHandler?){
        self.lookupAlbums(names: names, useCache: false) { (albums) in
            self.removeAlbums(albums, completion: completion)
        }
    }
    
    /** 删除单个相簿, 默认删除相簿里的照片或视频等资源*/
    public func removeAlbum(_ album: OMAlbum, removeAllAssets: Bool = true, completion: OMEditOprationHandler?){
        removeAlbums([album], completion: completion)
    }
    
    /** 删除多个相簿, 默认删除相簿里的照片或视频等资源*/
    public func removeAlbums(_ albums: [OMAlbum], removeAllAssets: Bool = true, completion: OMEditOprationHandler?){
        performChange({ [weak self] () in
            guard let _ = self else { return }
            let collections = albums.map({ (album) -> PHAssetCollection in
                PHAssetChangeRequest.deleteAssets(album.results)
                return album.collection
            })
            PHAssetCollectionChangeRequest.deleteAssetCollections(collections as NSArray)
            }, completionHandler: completion)
    }
    
    /** 移除单个资源从指定相簿中*/
    public func removeAsset(_ asset: OMAsset, in album: OMAlbum, completion: OMEditOprationHandler?){
        removeAssets([asset], in: album, completion: completion)
    }
    
    /** 移除多个资源从指定相簿中*/
    public func removeAssets(_ asset: [OMAsset], in album: OMAlbum, completion:
        OMEditOprationHandler?){
        performChange({ [weak self] () in
            guard let _ = self else { return }
            guard let request = PHAssetCollectionChangeRequest.init(for: album.collection) else {
                completion?(false, OMError.deleteAssetFailured)
                return
            }
            request.removeAssets(asset as NSArray)
            }, completionHandler: completion)
    }
    
    
    /** 清除缓存相簿列表，其实这个占用的空间非常小，一般情况下不调用此方法*/
    public func removeCache(){
        UserDefaults.standard.setNilValueForKey(cacheData)
    }
    
    //MARK: - request method
    /** 在指定相册里获取资源结果*/
    public func requestAssetsResults(from album: OMAlbum, options: PHFetchOptions? = OMAlbumConfig.fetchOptions) -> PHFetchResult<PHAsset> {
        return PHAsset.fetchAssets(in: album.collection, options: options)
    }
    
    /** 从结果里获取资源*/
    public func requestAssets(from results: PHFetchResult<PHAsset>) -> [OMAsset] {
        var assets = [OMAsset]()
        results.enumerateObjects { (asset, index, stop) in
            let omAsset: OMAsset = self.initExtraInfo(with: asset)
            assets.append(omAsset)
        }
        return assets
    }
    
    /** 在指定相簿里获取指定类型的资源*/
    public func requestAssets(from album: OMAlbum, type: OMAssetType = .default, options: PHFetchOptions? = OMAlbumConfig.fetchOptions) -> Array<OMAsset> {
        var assets = [PHAsset]()
        requestAssetsResults(from: album, options: options).enumerateObjects { (asset, index, stop) in
            let temp = self.initExtraInfo(with: asset)
            switch type{
            case .default:
                assets.append(temp)
                break
            case .onlyGIF:
                if asset.isGIF{
                    assets.append(temp)
                }
                break
            case .onlyImage:
                if asset.isImage{
                    assets.append(asset)
                }
                break
            case .onlyVideo:
                if asset.isVideo{
                    assets.append(asset)
                }
                break
            }
        }
        return assets
    }
    
    /** 同步方式获取相簿列表，不会使用缓存*/
    public func requestAlbumsSync(type: OMAlbumFetchType = .default) -> Array<OMAlbum>{
        switch type {
        case .default:
            let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
            let userAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
            let albums = requestAlbumsFor(albumResult: systemAlbum) + requestAlbumsFor(albumResult: userAlbum)
            return albums
        case .system:
            let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
            let albums = requestAlbumsFor(albumResult: systemAlbum)
            return albums
        case .user:
            let userAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
            let albums = requestAlbumsFor(albumResult: userAlbum)
            return albums
        case .onlyImage:
            let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .smartAlbumGeneric, options: nil)
            let userAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumGeneric, options: nil)
            let albums = requestAlbumsFor(albumResult: systemAlbum) + requestAlbumsFor(albumResult: userAlbum)
            return albums
        case .onlyGIF:
            if #available(iOS 11.0, *) {
                let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .smartAlbumAnimated, options: nil)
                let userAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumAnimated, options: nil)
                let albums = requestAlbumsFor(albumResult: systemAlbum) + requestAlbumsFor(albumResult: userAlbum)
                return albums
            } else {
                return []
            }
        case .onlyVideo:
            let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .smartAlbumVideos, options: nil)
            let userAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumVideos, options: nil)
            let albums = requestAlbumsFor(albumResult: systemAlbum) + requestAlbumsFor(albumResult: userAlbum)
            return albums
        }
    }
    
    /** 异步方式获取相簿*/
    public func requestAlbumsAsync(type: OMAlbumFetchType = .default, useCache: Bool = true, completion: @escaping (([OMAlbum]) -> Void)){
        DispatchQueue.global().async {
            if useCache {
                if !self.cacheAlbums.isEmpty {
                    let albums = self.cacheAlbums.map({ (cache) -> OMAlbum in
                        var album = OMAlbum.init()
                        album.title = cache.title
                        album.originTitle = cache.originTitle
                        album.count = cache.count
                        return album
                    })
                    completion(albums)
                }
            }
            var albumLists = [OMAlbum]()
            switch type {
            case .default:
                let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
                let userAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
                let albums = self.requestAlbumsFor(albumResult: systemAlbum) + self.requestAlbumsFor(albumResult: userAlbum)
                albumLists = albums
            case .system:
                let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
                let albums = self.requestAlbumsFor(albumResult: systemAlbum)
                albumLists = albums
            case .user:
                let userAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumRegular, options: nil)
                let albums = self.requestAlbumsFor(albumResult: userAlbum)
                albumLists = albums
            case .onlyImage:
                let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumGeneric, options: nil)
                let userAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .smartAlbumGeneric, options: nil)
                let albums = self.requestAlbumsFor(albumResult: systemAlbum) + self.requestAlbumsFor(albumResult: userAlbum)
                albumLists = albums
            case .onlyGIF:
                if #available(iOS 11.0, *) {
                    let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumAnimated, options: nil)
                    let userAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .smartAlbumAnimated, options: nil)
                    let albums = self.requestAlbumsFor(albumResult: systemAlbum) + self.requestAlbumsFor(albumResult: userAlbum)
                    albumLists = albums
                } else {
                    albumLists = []
                }
            case .onlyVideo:
                let systemAlbum = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumVideos, options: nil)
                let userAlbum = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .smartAlbumVideos, options: nil)
                let albums = self.requestAlbumsFor(albumResult: systemAlbum) + self.requestAlbumsFor(albumResult: userAlbum)
                albumLists = albums
            }
            completion(albumLists)
            guard self.config.isCacheAlbumList else { return }
            let cache = albumLists.map({ (album) -> OMCacheAlbum in
                return OMCacheAlbum.init(title: album.title, originTitle: album.originTitle, count: album.count)
            })
            let datas = cache.map({ (cache) -> Data in
                return NSKeyedArchiver.archivedData(withRootObject: cache)
            })
            UserDefaults.standard.set(datas, forKey: cacheData)
            UserDefaults.standard.synchronize()
        }
    }
    
    
    
    /** 请求获取相册图片*/
    public func requestImageFrom(asset: inout OMAsset, imageSize: CGSize, completion: @escaping OMAlbumRequestHandler) {
        guard asset.isImage || asset.isVideo else {
            completion(config.placeholderImage, nil)
            return
        }
        
        cancelRequestImageFor(requestID: asset.identifer)
        let requestID = self.cacheImageManager.requestImage(for: asset, targetSize: imageSize, contentMode: config.requestContentMode, options: config.requestIconOptions, resultHandler: completion)
        asset.identifer = requestID
    }
    
    /** 请求获取相簿的占位图*/
    public func requestImageFrom(album: inout OMAlbum, completion: @escaping OMAlbumRequestHandler) {
        guard album.iconAsset != nil else {
            completion(config.iconPlaceholder, nil)
            return
        }
        requestImageFrom(asset: &album.iconAsset!, imageSize: config.iconSize*config.scale, completion: completion)
    }
    
    
    /** 取消正在获取相册图片的请求*/
    public func cancelRequestImageFor(requestID: OMImageRequestID) {
        self.cacheImageManager.cancelImageRequest(requestID)
    }
    
    //MARK: - private method
    
    /** 执行增删改查操作*/
    private func performChange(_ changeBlock: @escaping () -> Void, completionHandler: ((Bool, Error?) -> Void)? = nil){
        PHPhotoLibrary.shared().performChanges(changeBlock, completionHandler: completionHandler)
    }
    
    /** 查找指定的相簿*/
    private func lookupAlbums(names: [String], useCache: Bool = true, completion: @escaping (([OMAlbum]) -> Void)){
        guard !names.isEmpty else {
            completion([])
            return
        }
        requestAlbumsAsync(type: .default, useCache: useCache) {  [weak self] (albums) in
            guard let _ = self else { return }
            let handlerAlbums = albums.filter({ (album) -> Bool in
                return names.contains(album.title ?? "")
            })
            completion(handlerAlbums)
        }
    }
    
    /** 从缓存中取出相簿*/
    private func readAlbumsFromCache() -> [OMCacheAlbum] {
        guard let values = UserDefaults.standard.value(forKey: cacheData) as? Array<Data> else { return [] }
        let albums = values.map({ (data) -> OMCacheAlbum in
            return NSKeyedUnarchiver.unarchiveObject(with: data) as! OMCacheAlbum
        })
        return albums
    }
    
    /** 初始化一些额外属性*/
    private func initExtraInfo(with: PHAsset) -> OMAsset {
        let asset: OMAsset = with
        asset.isImage = with.mediaType == .image
        asset.isVideo = with.mediaType == .video
        if #available(iOS 11.0, *) {
            asset.isGIF = with.playbackStyle == .imageAnimated
        }
        return asset
    }
    
    /** 通过指定的相簿列表结果获取相簿*/
    private func requestAlbumsFor(albumResult: PHFetchResult<PHAssetCollection>) -> [OMAlbum] {
        var albums = [OMAlbum]()
        var assetCollection = OMAlbum.init()
        albumResult.enumerateObjects { (asset, index, stop) in
            let results = OMAsset.fetchAssets(in: asset, options: nil)
            let title = OMAlbumTitle(rawValue: asset.localizedTitle ?? "") ?? .none
            if self.config.ignoreAlbums.contains(title) && title != .none { return }
            if self.config.isHiddenWhereAlbumCountZero && results.count == 0 { return }
            assetCollection.collection = asset
            assetCollection.config = self.config
            assetCollection.originTitle = asset.localizedTitle
            assetCollection.title = asset.localizedTitle
            assetCollection.results = results
            assetCollection.count = results.count
            assetCollection.location = asset.localizedLocationNames
            if let iconAsset: PHAsset = results.lastObject, results.count > 0 {
                assetCollection.iconAsset = self.initExtraInfo(with: iconAsset)
            } else {
                assetCollection.iconAsset = nil
            }
            albums.append(assetCollection)
        }
        return albums
    }
    
}

//MARK: - 资源

/** 缓存相簿基本信息*/
@objc(OMCacheAlbum_oymuzi) fileprivate class OMCacheAlbum: NSObject, NSCoding{
    
    private let propertyTitle = "OMCacheAlbum_title"
    private let propertyOriginTitle = "OMCacheAlbum_originTitle"
    private let propertyCount = "OMCacheAlbum_count"
    
    var title: String?
    var originTitle: String?
    var count: Int
    
    override init() {
        title = nil
        originTitle = nil
        count = 0
    }
    
    convenience init(title: String?, originTitle: String?, count: Int){
        self.init()
        self.title = title
        self.originTitle = originTitle
        self.count = count
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(title, forKey: propertyTitle)
        aCoder.encode(originTitle, forKey: propertyOriginTitle)
        aCoder.encode(count, forKey: propertyCount)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.title = aDecoder.decodeObject(forKey: propertyTitle) as? String
        self.originTitle = aDecoder.decodeObject(forKey: propertyOriginTitle) as? String
        self.count = aDecoder.decodeInteger(forKey: propertyCount)
    }
}

/** 资源类型*/
typealias OMAsset = PHAsset
/** 请求图片和取消时的identifer*/
typealias OMRequestID = PHImageRequestID

/** 拓展资源类型方法*/
extension OMAsset{
    
    /** 增加属性的key*/
    fileprivate struct AssociationKeys {
        static var identifer: OMRequestID = 0
        static var isImage: Bool = false
        static var isVideo: Bool = false
        static var isGIF: Bool = false
        static var isLivePhoto: Bool = false
        static var isIniCloud: Bool = false
        static var videoDuration: TimeInterval = 0.00
    }
    
    /** 标识符*/
    fileprivate var identifer: OMRequestID{
        set{
            objc_setAssociatedObject(self, &AssociationKeys.identifer, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
        get{
            guard let value = objc_getAssociatedObject(self, &AssociationKeys.identifer) else { return 0 }
            return value as! OMRequestID
        }
    }
    
    /** 是否为图片*/
    public var isImage: Bool {
        set{
            objc_setAssociatedObject(self, &AssociationKeys.isImage, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
        get{
            guard let value = objc_getAssociatedObject(self, &AssociationKeys.isImage) else { return false }
            return value as! Bool
        }
    }
    
    /** 是否为视频*/
    public var isVideo: Bool {
        set{
            objc_setAssociatedObject(self, &AssociationKeys.isVideo, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
        get{
            guard let value = objc_getAssociatedObject(self, &AssociationKeys.isVideo) else { return false }
            return value as! Bool
        }
    }
    
    /** 是否为图片*/
    public var isGIF: Bool {
        set{
            objc_setAssociatedObject(self, &AssociationKeys.isGIF, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
        get{
            guard let value = objc_getAssociatedObject(self, &AssociationKeys.isGIF) else { return false }
            return value as! Bool
        }
    }
    
    /** 是否为live photo*/
    public var isLivePhoto: Bool {
        set{
            objc_setAssociatedObject(self, &AssociationKeys.isLivePhoto, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
        get{
            guard let value = objc_getAssociatedObject(self, &AssociationKeys.isLivePhoto) else { return false }
            return value as! Bool
        }
    }
    
    /** 是否为图片*/
    public var isIniCloud: Bool {
        set{
            objc_setAssociatedObject(self, &AssociationKeys.isIniCloud, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
        get{
            guard let value = objc_getAssociatedObject(self, &AssociationKeys.isIniCloud) else { return false }
            return value as! Bool
        }
    }
    
    /** 是否为图片*/
    public var veideoDuration: TimeInterval {
        set{
            objc_setAssociatedObject(self, &AssociationKeys.videoDuration, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_ASSIGN)
        }
        get{
            guard let value = objc_getAssociatedObject(self, &AssociationKeys.videoDuration) else { return 0.00 }
            return value as! TimeInterval
        }
    }
}

struct OMAlbum{
    /** 配置*/
    public var config: OMAlbumConfig!
    
    /** 相簿的数据*/
    public var collection: PHAssetCollection!
    
    /** 结果*/
    public var results: PHFetchResult<PHAsset>
    
    /** 相簿封面资源*/
    public var iconAsset: OMAsset?
    
    /** 原始标题*/
    public var originTitle: String?
    
    private var _title: String?
    
    /** 资源标识符*/
    fileprivate var identifer: PHImageRequestID = 0
    
    /** 处理后的标题*/
    public var title: String? {
        set{
            _title = newValue
        }
        get{
            switch _title {
            case OMAlbumTitle.hidden.rawValue:             return config.titleConfig.hidden
            case OMAlbumTitle.slomo.rawValue:              return config.titleConfig.solomo
            case OMAlbumTitle.bursts.rawValue:             return config.titleConfig.bursts
            case OMAlbumTitle.videos.rawValue:             return config.titleConfig.videos
            case OMAlbumTitle.portrait.rawValue:           return config.titleConfig.portait
            case OMAlbumTitle.selfies.rawValue:            return config.titleConfig.selfies
            case OMAlbumTitle.animated.rawValue:           return config.titleConfig.animated
            case OMAlbumTitle.allPhotos.rawValue:          return config.titleConfig.allPhotos
            case OMAlbumTitle.favorites.rawValue:          return config.titleConfig.favorites
            case OMAlbumTitle.panoramas.rawValue:          return config.titleConfig.panoramas
            case OMAlbumTitle.timeLapse.rawValue:          return config.titleConfig.timeLapse
            case OMAlbumTitle.livePhotos.rawValue:         return config.titleConfig.livePhotos
            case OMAlbumTitle.screenshots.rawValue:        return config.titleConfig.screenshots
            case OMAlbumTitle.longExposure.rawValue:       return config.titleConfig.longExposure
            case OMAlbumTitle.recentlyAdded.rawValue:      return config.titleConfig.recentlyAdded
            case OMAlbumTitle.recentlyDeleted.rawValue:    return config.titleConfig.recentlyDeleted
            default: return _title
            }
        }
    }
    /** 相簿的资源数量*/
    public var count: Int
    
    /** 相簿存储的地理位置信息*/
    public var location: [String]
    
    init() {
        self.config = OMAlbumConfig.init()
        self.collection = PHAssetCollection.init()
        self.results = PHFetchResult.init()
        self.iconAsset = nil
        self.originTitle = ""
        self.count = 0
        self.location = []
    }
}

//MARK: - 配置

/** 系统相簿名称*/
enum OMAlbumTitle: String{
    case none               = "_None"
    case hidden             = "Hidden"
    case recentlyDeleted    = "Recently Deleted"
    case allPhotos          = "All Photos"
    case slomo              = "Slo-mo"
    case selfies            = "Selfies"
    case recentlyAdded      = "Recently Added"
    case favorites          = "Favorites"
    case panoramas          = "Panoramas"
    case videos             = "Videos"
    case timeLapse          = "Time-lapse"
    case portrait           = "Portrait"
    case livePhotos         = "Live Photos"
    case bursts             = "Bursts"
    case screenshots        = "Screenshots"
    case longExposure       = "Long Exposure"
    case animated           = "Animated"
}

/** 系统自带相簿的名称*/
struct OMAlbumTitleConfig{
    public var hidden: String              = "隐藏"
    public var recentlyDeleted: String     = "最近删除"
    public var allPhotos: String           = "所有照片"
    public var solomo: String              = "慢动作"
    public var selfies: String             = "自拍"
    public var recentlyAdded: String       = "最近添加"
    public var favorites: String           = "个人收藏"
    public var panoramas: String           = "全景照片"
    public var videos: String              = "视频"
    public var timeLapse: String           = "延时摄影"
    public var portait: String             = "人像"
    public var livePhotos: String          = "实况照片"
    public var bursts: String              = "连拍快照"
    public var screenshots: String         = "屏幕快照"
    public var longExposure: String        = "长曝光"
    public var animated: String            = "动图"
    
    init() { }
}

/** 相簿配置*/
struct OMAlbumConfig{
    
    /** 是否开启缓存相簿列表，默认值：true，只缓存标题，原始相簿标题，资源数量，将会存储在UerDefaults里，若需清除缓存，可调用OMAlbumManager的removeCache方法*/
    public var isCacheAlbumList = true
    
    /** 是否指向顶部*/
    public var isRefecnceTop: Bool = true
    
    /** 是否按时间的升序排序*/
    public var isSortByDateAscend: Bool = false
    
    /** 是否需要相簿占位图*/
    public var isNeedIcon: Bool = true
    
    /** 默认相簿的占位图大小*/
    public var iconSize: CGSize = CGSize.init(width: 60, height: 60)
    
    /** 请求图片的比例设置，在请求图标时将会用到此比例*/
    public var scale: CGFloat = UIScreen.main.scale * 1.25
    
    /** 请求图片时的图片u缩放模式*/
    public var requestContentMode: PHImageContentMode = .default
    
    /** 配置相簿标题，若需使用原有标题，可通过originTitle属性获取 */
    public var titleConfig: OMAlbumTitleConfig = OMAlbumTitleConfig()
    
    /** 是否隐藏相册当相簿里资源数量为0时*/
    public var isHiddenWhereAlbumCountZero: Bool = false
    
    /** 不想展示的相簿名称 */
    public var ignoreAlbums: [OMAlbumTitle] = []
    
    /** 相簿的封面占位图*/
    public var iconPlaceholder: UIImage? = nil
    
    /** 默认图*/
    public var placeholderImage: UIImage? = nil
    
    /** 请求相簿的封面时的可选项*/
    public var requestIconOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions.init()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.version = .current
        return options
    }()
    
    /** 获取相片或者视频时的可选项*/
    static var fetchOptions: PHFetchOptions = {
        let options = PHFetchOptions.init()
        if #available(iOS 9.0, *) {
            options.includeAssetSourceTypes = [PHAssetSourceType.typeUserLibrary, PHAssetSourceType.typeCloudShared, PHAssetSourceType.typeiTunesSynced]
        }
        options.sortDescriptors = [NSSortDescriptor.init(key: "creationDate", ascending: false)]
        return options
    }()
    
    init() { }
}

//
//  AlbumViewController.swift
//  PhotoKit
//
//  Created by admin on 2018/12/20.
//  Copyright © 2018年 oymuzi. All rights reserved.
//

import UIKit
import Photos

class AlbumViewController: UIViewController {

    
    static func initWith(albumID: String) -> AlbumViewController {
        return self.init()
    }
  
    
    private var tableView: UITableView!
    
//    typealias OMAlbum = (album: PHCollection, count: Int)
//
    private var albums = [OMAlbum]()
    
    private let reuse = "reuse"
    
    let albumManager = OMPhotoManager.init()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.white
        print("开始：", CFAbsoluteTimeGetCurrent())
//        self.albums = OMAlbumManager.cacheAlbums
        self.albumManager.config.ignoreAlbums = [.hidden, .recentlyDeleted]
        self.albumManager.requestAlbumsAsync(type: .default) { (albums) in
            self.albums = albums
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
            guard var asset = self.albums[0].iconAsset else { return }
            self.albumManager.requestImageFrom(asset: &asset, imageSize: CGSize.init(width: 100, height: 100), completion: { (image, info) in
                guard let icon = image else { return }
                self.albumManager.addImage(icon, to: "TRR", automaticCreateAlbum: false, completion: { (status, error) in
                    print("是否成功：\(status) \(error)")
                })
            
            })
            
            
            print("结束：", CFAbsoluteTimeGetCurrent(), albums.count)
        }
        
        self.albumManager.removeAlbum(names: ["没想到吧"]) { (status, error) in
            print("是否成功删除：\(status)")
        }
        
        
        tableView = UITableView.init(frame: self.view.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(OMImageViewCell().classForCoder, forCellReuseIdentifier: reuse)
        self.view.addSubview(tableView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
       
        
        
    }
    

}

class OMImageViewCell: UITableViewCell {

    public var iconView: UIImageView!
    
    public var titleLabel: UILabel!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        iconView = UIImageView.init()
        iconView?.frame = CGRect.init(x: 15, y: 5, width: 40, height: 40)
        iconView?.contentMode = .center
        iconView?.clipsToBounds = true
        self.contentView.addSubview(iconView)
        
        titleLabel = UILabel.init()
        titleLabel.frame = CGRect.init(x: 60, y: 0, width: UIScreen.main.bounds.width-75, height: self.contentView.frame.height)
        self.contentView.addSubview(titleLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension AlbumViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return albums.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = OMImageViewCell.init(style: .default, reuseIdentifier: reuse)
        cell.titleLabel.text = "(\(albums[indexPath.row].count.description))  "+(albums[indexPath.row].title ?? "")
        cell.iconView.om_requestAlbumIcon(album: &albums[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let index = indexPath.row
        let assets = OMPhotoManager.init().requestAssets(from: albums[index])
        let va = PhotoViewController()
        va.displayAlbum = assets
        self.navigationController?.pushViewController(va, animated: true)
    }
}

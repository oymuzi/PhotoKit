//
//  OMAlbumsViewController.swift
//  PhotoKit
//
//  Created by admin on 2018/12/26.
//  Copyright © 2018年 oymuzi. All rights reserved.
//

import UIKit

class OMAlbumCell: UITableViewCell {
    
    public var iconView: UIImageView!
    
    public var titleLabel: UILabel!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        imageView?.frame = CGRect.init(x: 15, y: 5, width: 40, height: 40)
        imageView?.contentMode = .scaleAspectFit
        imageView?.clipsToBounds = true
        imageView?.image = nil
        
        textLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        textLabel?.frame = CGRect.init(x: 60, y: 0, width: UIScreen.main.bounds.width-110, height: self.contentView.frame.height)
//
        
//        iconView = UIImageView.init()
//        iconView?.frame = CGRect.init(x: 15, y: 5, width: 40, height: 40)
//        iconView?.contentMode = .center
//        iconView?.clipsToBounds = true
//        self.contentView.addSubview(iconView)
        
        
//        titleLabel = UILabel.init()
//        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
//        titleLabel.frame = CGRect.init(x: 60, y: 0, width: UIScreen.main.bounds.width-75, height: self.contentView.frame.height)
//        self.contentView.addSubview(titleLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


class OMAlbumsViewController: UIViewController {
    
    public var displayAlbums = [OMAlbum]()
    
    private var albumsListView: UITableView!
    
//    private let manager = OMPhotoManager.init()
    
    private let reuse = "reuseIdenfier"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "照片"
        self.view.backgroundColor = UIColor.white
        self.setupUI()
        self.loadData()
    }
    
    private func setupUI() {
        albumsListView = UITableView.init()
        albumsListView.frame = view.bounds
        albumsListView.delegate = self
        albumsListView.dataSource = self
        albumsListView.tableFooterView = UIView()
        albumsListView.tableHeaderView = UIView()
        albumsListView.register(OMAlbumCell().classForCoder, forCellReuseIdentifier: reuse)
        self.view.addSubview(albumsListView)
    }
    
    private func loadData() {
        let manager = OMPhotoManager.init()
        manager.requestAlbumsAsync { [weak self] (albums) in
            guard let strongSelf = self else { return }
            strongSelf.displayAlbums = albums
            DispatchQueue.main.async {
                strongSelf.albumsListView.reloadData()
                print("数量：\(albums.count)")
            }
        }
    }

}

extension OMAlbumsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayAlbums.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = OMAlbumCell.init(style: .value1, reuseIdentifier: reuse)
        cell.accessoryType = .disclosureIndicator
        cell.imageView?.om_requestAlbumIcon(album: &displayAlbums[indexPath.row])
        cell.textLabel?.text = displayAlbums[indexPath.row].title
        cell.detailTextLabel?.text = displayAlbums[indexPath.row].count.description
        return cell
    }
}

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
        imageView?.image = nil
        self.accessoryType = .disclosureIndicator
        iconView = UIImageView.init()
        iconView.image = nil
        iconView?.frame = CGRect.init(x: 0, y: 0, width: 60, height: 60)
        iconView?.contentMode = .scaleAspectFill
        iconView?.clipsToBounds = true
        self.contentView.addSubview(iconView)


        titleLabel = UILabel.init()
        titleLabel.frame = CGRect.init(x: 70, y: 0, width: UIScreen.main.bounds.width-120, height: 60)
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        titleLabel.text = ""
        self.contentView.addSubview(titleLabel)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


class OMAlbumsViewController: UIViewController {
    
    public var displayAlbums = [OMAlbum]()
    
    private var albumsListView: UITableView!
    
    private var isLoadedData: Bool = false
    
    private var isRefreshed: Bool = false
    
//    private let manager = OMPhotoManager.init()
    
    private let reuse = "reuseIdenfier"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "照片"
        self.view.backgroundColor = UIColor.white
        self.setupUI()
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
        guard !isLoadedData else { return }
        let manager = OMPhotoManager.init()
        manager.requestAlbumsAsync { [weak self] (albums) in
            guard let strongSelf = self else { return }
            strongSelf.displayAlbums = albums
            strongSelf.isLoadedData = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.loadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !isRefreshed else { return }
        self.albumsListView.reloadData()
        self.isRefreshed = true
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
        cell.selectionStyle = .gray
        cell.iconView?.om_requestAlbumIcon(album: &displayAlbums[indexPath.row])
        cell.titleLabel?.text = displayAlbums[indexPath.row].title
        cell.detailTextLabel?.text = displayAlbums[indexPath.row].count.description
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let albumVC = OMPhotosViewController.initWith(album: displayAlbums[indexPath.row])
        self.navigationController?.pushViewController(albumVC, animated: true)
    }
    
    
}

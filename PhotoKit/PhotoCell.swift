//
//  PhotoCell.swift
//  PhotoKit
//
//  Created by admin on 2018/12/19.
//  Copyright © 2018年 oymuzi. All rights reserved.
//

import UIKit

class PhotoCell: UICollectionViewCell {
    
    public var imageView: UIImageView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView = UIImageView.init(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        imageView?.contentMode = .scaleAspectFit
        imageView?.clipsToBounds = true
        addSubview(imageView!)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

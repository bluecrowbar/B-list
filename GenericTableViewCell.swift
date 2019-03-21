//
//  GenericTableViewCell.swift
//  B-list
//
//  Created by Steven Vandeweghe on 18/10/14.
//  Copyright (c) 2014 Blue Crowbar. All rights reserved.
//

import UIKit

class GenericTableViewCell: UITableViewCell {
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var subtitleLabel: UILabel!
	@IBOutlet weak var titleTextField: UITextField!
	@IBOutlet weak var sideMarkerView: UIView!
	
	override var layoutMargins: UIEdgeInsets {
		get { return .zero }
		set(value) {}
	}
}

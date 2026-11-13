//
//  Assets.swift
//  Hidden Bar
//
//  Created by Peter Luo on 2021/5/28.
//  Copyright © 2021 Dwarves Foundation. All rights reserved.
//

import AppKit

struct Assets {
    private static let icExpand = NSImage(named: NSImage.Name("ic_expand"))
    private static let icCollapse = NSImage(named: NSImage.Name("ic_collapse"))

    static var expandImage: NSImage? {
        return Constant.isUsingLTRLanguage ? icExpand : icCollapse
    }

    static var collapseImage: NSImage? {
        return Constant.isUsingLTRLanguage ? icCollapse : icExpand
    }
}

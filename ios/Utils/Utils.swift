//
//  Utils.swift
//  flutter_opentok
//
//  Created by Genert Org on 23/08/2019.
//

import Foundation

class Utils {
    static func sanitizeBooleanProperty(_ property: Any) -> Bool {
        guard let prop = property as? Bool else { return true; }
        return prop;
    }
}

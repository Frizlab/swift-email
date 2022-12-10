/*
Copyright 2021-2022 François Lamboley

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation



public struct Email : Hashable, Equatable, Sendable {
	
	public var localPart: String
	public var domainPart: String
	
}


extension Email : RawRepresentable {
	
	public typealias RawValue = String
	
	public init?(rawValue: String) {
		let v = EmailValidator(string: rawValue)
		let (validationResult, localPart, domainPart) = v.evaluateEmail()
		guard validationResult.category.value < EmailValidator.ValidationCategory.err.value else {
			return nil
		}
		self.localPart = localPart
		self.domainPart = domainPart
	}
	
	public var rawValue: String {
		return localPart + "@" + domainPart
	}
	
}


extension Email : LosslessStringConvertible {
	
	public init?(_ description: String) {
		self.init(rawValue: description)
	}
	
	public var description: String {
		return rawValue
	}
	
}


extension Email : Codable {
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let stringValue = try container.decode(String.self)
		
		let v = EmailValidator(string: stringValue)
		let (validationResult, localPart, domainPart) = v.evaluateEmail()
		guard validationResult.category.value < EmailValidator.ValidationCategory.err.value else {
			throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid email", underlyingError: nil))
		}
		self.localPart = localPart
		self.domainPart = domainPart
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
	
}

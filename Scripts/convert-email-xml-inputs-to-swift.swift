#!/usr/bin/swift
/* Swift 5 */

import Foundation



let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0], isDirectory: false)
let projectDirURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
/* INPUTS */
let xmlEmailMetaURL = URL(fileURLWithPath: "Docs/dominicsayers-isemail/test/meta.xml", isDirectory: false, relativeTo: projectDirURL)
let xmlEmailTests1URL = URL(fileURLWithPath: "Docs/dominicsayers-isemail/test/tests.xml", isDirectory: false, relativeTo: projectDirURL)
let xmlEmailTests2URL = URL(fileURLWithPath: "Docs/dominicsayers-isemail/test/tests-original.xml", isDirectory: false, relativeTo: projectDirURL)
/* OUTPUTS */
let swiftEmailTestsURL = URL(fileURLWithPath: "Tests/EmailTests/DominicSayersTests.swift", isDirectory: false, relativeTo: projectDirURL)
let swiftEmailMetaURL = URL(fileURLWithPath: "Sources/Email/EmailValidator+ValidationCodes.swift", isDirectory: false, relativeTo: projectDirURL)


/* USER CONSTANTS */
let isEmailPrefix = "ISEMAIL_"

/* ABSOLUTE CONSTANTS */
let dateFormatter = ISO8601DateFormatter()
dateFormatter.formatOptions = [.withInternetDateTime]

/* Needed later when converting the tests. */
var transforms = (
	[(#"\u240d\u240a"#, #"\015\012"#)] + (0..<32).map{ i in (#"\u\#(String(format: "%04x", 0x2400 + i))"#, #"\0\#(String(format: "%02o", i))"#) }
).map{ t in
	(String(data: Data(t.0.utf8), encoding: .nonLossyASCII)!, String(data: Data(t.1.utf8), encoding: .nonLossyASCII)!)
}



class StandardErrorOutputStream: TextOutputStream {
	
	func write(_ string: String) {
		let stderr = FileHandle.standardError
		stderr.write(string.data(using: String.Encoding.utf8)!)
	}
	
}

var mx_stderr = StandardErrorOutputStream()


extension Array {
	
	var singleElement: Element? {
		guard let r = first, count == 1 else {return nil}
		return r
	}
	
}

extension String {
	
	func snailCaseToCamelCase(xmlPrefix: String, swiftPrefix: String) -> String? {
		guard hasPrefix(xmlPrefix), count > xmlPrefix.count else {
			return nil
		}
		let withoutPrefix = self[index(startIndex, offsetBy: xmlPrefix.count)...]
		return withoutPrefix.split(separator: "_").map(String.init).reduce(swiftPrefix, { $0 + ($0.isEmpty ? $1.lowercased() : $1.capitalized) })
	}
	
	func dashCaseToCamelCase(xmlPrefix: String, swiftPrefix: String) -> String? {
		guard hasPrefix(xmlPrefix), count > xmlPrefix.count else {
			return nil
		}
		let withoutPrefix = self[index(startIndex, offsetBy: xmlPrefix.count)...]
		return withoutPrefix.split(separator: "-").map(String.init).reduce(swiftPrefix, { $0 + ($0.isEmpty ? $1.lowercased() : $1.capitalized) })
	}
	
	func stringInGeneratedSwift() -> String {
		return #""\#(unicodeScalars.lazy.map{ $0.escaped(asASCII: false) }.joined(separator: ""))""#
	}
	
}


/* Validation codes file header. */
var swiftEmailValidationCodesFileContent = """
/*
 * !!! File autogenerated by \(scriptURL.lastPathComponent)
 * !!! Don’t change manually.
 *
 * \(swiftEmailMetaURL.lastPathComponent)
 * Email
 *
 * Created by \(scriptURL.lastPathComponent) on \(dateFormatter.string(from: Date())).
 */

import Foundation




"""

/* Validation codes file content, from XML. */
guard let validationCodesDocRoot = try? XMLDocument(contentsOf: xmlEmailMetaURL, options: []).rootElement() else {
	print("error: cannot read XML input at \(xmlEmailMetaURL)", to: &mx_stderr)
	exit(1)
}

guard let categories = validationCodesDocRoot.elements(forName: "Categories").singleElement else {
	print("error: no or multiple Categories elements in the meta XML input; expecting exactly 1", to: &mx_stderr)
	exit(1)
}
swiftEmailValidationCodesFileContent += """
extension EmailValidator {
	
	public struct ValidationCategory : Hashable, Sendable {
		

"""
var cateogoryValues = Set<Int>()
var cateogoryXMLIds = Set<String>()
for category in categories.elements(forName: "item") {
	guard let categoryIdXML = category.attribute(forName: "id")?.stringValue, let categoryId = categoryIdXML.snailCaseToCamelCase(xmlPrefix: isEmailPrefix, swiftPrefix: "") else {
		print("error: found a category which does not have an id, or has an id which does not have the “\(isEmailPrefix)” prefix; here is it’s string representation: \(category)", to: &mx_stderr)
		exit(1)
	}
	guard let value = category.elements(forName: "value").singleElement?.stringValue.flatMap(Int.init) else {
		print("error: found category \(categoryIdXML) which does not have or have multiple values (expected exactly one), or whose value is not an Int", to: &mx_stderr)
		exit(1)
	}
	guard let description = category.elements(forName: "description").singleElement?.stringValue else {
		print("error: found category \(categoryIdXML) which does not have or have multiple descriptions (expected exactly one)", to: &mx_stderr)
		exit(1)
	}
	
	guard cateogoryXMLIds.insert(categoryIdXML).inserted else {
		print("error: found a second category with the same id as another one: \(category)", to: &mx_stderr)
		exit(1)
	}
	guard cateogoryValues.insert(value).inserted else {
		print("error: found a second category with the same value as another one: \(category)", to: &mx_stderr)
		exit(1)
	}
	
	/* Note: We don’t check the id to be a valid string for a Swift variable. */
	swiftEmailValidationCodesFileContent += #"\#t\#tpublic static let \#(categoryId) = ValidationCategory("#
	swiftEmailValidationCodesFileContent +=    #"value: \#(value), "#
	swiftEmailValidationCodesFileContent +=    #"xmlId: \#(categoryIdXML.stringInGeneratedSwift()), "#
	swiftEmailValidationCodesFileContent +=    #"description: \#(description.stringInGeneratedSwift())"#
	swiftEmailValidationCodesFileContent += ")\n"
}
swiftEmailValidationCodesFileContent += """
		
		public let value: Int
		public let xmlId: String
		public let description: String
		
		private init(value v: Int, xmlId pi: String, description d: String) {
			value = v
			xmlId = pi
			description = d
		}
		
	}
	
}

"""


guard let allSMTP = validationCodesDocRoot.elements(forName: "SMTP").singleElement else {
	print("error: no or multiple SMTP elements in the meta XML input; expecting exactly 1", to: &mx_stderr)
	exit(1)
}
swiftEmailValidationCodesFileContent += """


extension EmailValidator {
	
	public struct ValidationSMTPInfo : Hashable, Sendable {
		

"""
var smtpValues = Set<String>()
var smtpXMLIds = Set<String>()
for smtp in allSMTP.elements(forName: "item") {
	guard let xmlId = smtp.attribute(forName: "id")?.stringValue, let id = xmlId.snailCaseToCamelCase(xmlPrefix: isEmailPrefix + "META_SMTP_", swiftPrefix: "code") else {
		print("error: found an SMTP info which does not have an id, or has an id which does not have the “\(isEmailPrefix + "META_SMTP_")” prefix; here is it’s string representation: \(smtp)", to: &mx_stderr)
		exit(1)
	}
	guard let value = smtp.elements(forName: "value").singleElement?.stringValue else {
		print("error: found an SMTP info \(xmlId) which does not have or have multiple values (expected exactly one)", to: &mx_stderr)
		exit(1)
	}
	guard let text = smtp.elements(forName: "text").singleElement?.stringValue else {
		print("error: found an SMTP info \(xmlId) which does not have or have multiple text element (expected exactly one)", to: &mx_stderr)
		exit(1)
	}
	
	guard smtpXMLIds.insert(xmlId).inserted else {
		print("error: found a second SMTP info with the same id as another one: \(smtp)", to: &mx_stderr)
		exit(1)
	}
	guard smtpValues.insert(value).inserted else {
		print("error: found a second SMTP info with the same value as another one: \(smtp)", to: &mx_stderr)
		exit(1)
	}
	
	/* Note: We don’t check the id to be a valid string for a Swift variable. */
	swiftEmailValidationCodesFileContent += #"\#t\#tpublic static let \#(id) = ValidationSMTPInfo("#
	swiftEmailValidationCodesFileContent +=    #"value: \#(value.stringInGeneratedSwift()), "#
	swiftEmailValidationCodesFileContent +=    #"xmlId: \#(xmlId.stringInGeneratedSwift()), "#
	swiftEmailValidationCodesFileContent +=    #"text: \#(text.stringInGeneratedSwift())"#
	swiftEmailValidationCodesFileContent += ")\n"
}
swiftEmailValidationCodesFileContent += """
		
		public let value: String
		public let xmlId: String
		public let text: String
		
		private init(value v: String, xmlId pi: String, text t: String) {
			value = v
			xmlId = pi
			text = t
		}
		
	}
	
}

"""


guard let references = validationCodesDocRoot.elements(forName: "References").singleElement else {
	print("error: no or multiple References elements in the meta XML input; expecting exactly 1", to: &mx_stderr)
	exit(1)
}
swiftEmailValidationCodesFileContent += """


extension EmailValidator {
	
	public struct ValidationReference : Hashable, Sendable {
		

"""
var referenceXMLIds = Set<String>()
for reference in references.elements(forName: "item") {
	guard let xmlId = reference.attribute(forName: "id")?.stringValue, let id = xmlId.dashCaseToCamelCase(xmlPrefix: "", swiftPrefix: "") else {
		print("error: found a reference which does not have an id; here is it’s string representation: \(reference)", to: &mx_stderr)
		exit(1)
	}
	guard let blockQuoteElement = reference.elements(forName: "blockquote").singleElement else {
		print("error: found a reference \(xmlId) which does not have or have multiple blockquotes (expected exactly one)", to: &mx_stderr)
		exit(1)
	}
	guard let blockQuote = blockQuoteElement.stringValue else {
		print("error: found a reference \(xmlId) which does not have a string value for its block quote", to: &mx_stderr)
		exit(1)
	}
	guard let blockQuoteURL = blockQuoteElement.attribute(forName: "cite")?.stringValue.flatMap(URL.init) else {
		print("error: found a reference \(xmlId) which does not have an url value for its block quote", to: &mx_stderr)
		exit(1)
	}
	guard let blockQuoteName = reference.elements(forName: "cite").singleElement?.stringValue else {
		print("error: found a reference \(xmlId) which does not have or have multiple cite elements (expected exactly one)", to: &mx_stderr)
		exit(1)
	}
	
	guard referenceXMLIds.insert(xmlId).inserted else {
		print("error: found a reference with the same id as another one: \(reference)", to: &mx_stderr)
		exit(1)
	}
	
	/* Note: We don’t check the id to be a valid string for a Swift variable. */
	swiftEmailValidationCodesFileContent += #"\#t\#tpublic static let \#(id) = ValidationReference("#
	swiftEmailValidationCodesFileContent +=    #"xmlId: \#(xmlId.stringInGeneratedSwift()), "#
	swiftEmailValidationCodesFileContent +=    #"blockQuoteName: \#(blockQuoteName.stringInGeneratedSwift()), "#
	swiftEmailValidationCodesFileContent +=    #"blockQuoteURL: URL(string: \#(blockQuoteURL.absoluteString.stringInGeneratedSwift()))!, "#
	swiftEmailValidationCodesFileContent +=    #"blockQuote: \#(blockQuote.stringInGeneratedSwift())"#
	swiftEmailValidationCodesFileContent += ")\n"
}
swiftEmailValidationCodesFileContent += """
		
		public let xmlId: String
		
		public let blockQuoteName: String
		public let blockQuoteURL: URL
		public let blockQuote: String
		
		private init(xmlId pi: String, blockQuoteName bqn: String, blockQuoteURL bqu: URL, blockQuote bq: String) {
			xmlId = pi
			blockQuoteName = bqn
			blockQuoteURL = bqu
			blockQuote = bq
		}
		
	}
	
}

"""


guard let diagnoses = validationCodesDocRoot.elements(forName: "Diagnoses").singleElement else {
	print("error: no or multiple Diagnoses elements in the meta XML input; expecting exactly 1", to: &mx_stderr)
	exit(1)
}
swiftEmailValidationCodesFileContent += """


extension EmailValidator {
	
	public struct ValidationDiagnosis : Hashable, Sendable {
		

"""
var diagnosisValues = Set<Int>()
var diagnosisXMLIds = Set<String>()
for diagnosis in diagnoses.elements(forName: "item") {
	guard let xmlId = diagnosis.attribute(forName: "id")?.stringValue, let id = xmlId.snailCaseToCamelCase(xmlPrefix: isEmailPrefix, swiftPrefix: "") else {
		print("error: found a diagnosis which does not have an id, or has an id which does not have the “\(isEmailPrefix)” prefix; here is it’s string representation: \(diagnosis)", to: &mx_stderr)
		exit(1)
	}
	guard let value = diagnosis.elements(forName: "value").singleElement?.stringValue.flatMap(Int.init) else {
		print("error: found diagnosis \(xmlId) which does not have or have multiple values (expected exactly one), or whose value is not an Int", to: &mx_stderr)
		exit(1)
	}
	guard let xmlCategory = diagnosis.elements(forName: "category").singleElement?.stringValue, let category = xmlCategory.snailCaseToCamelCase(xmlPrefix: isEmailPrefix, swiftPrefix: "") else {
		print("error: found diagnosis \(xmlId) which does not have or have multiple category elements (expected exactly one)", to: &mx_stderr)
		exit(1)
	}
	guard cateogoryXMLIds.contains(xmlCategory) else {
		print("error: found diagnosis \(xmlId) whose category \(xmlCategory) does not exist", to: &mx_stderr)
		exit(1)
	}
	guard let description = diagnosis.elements(forName: "description").singleElement?.stringValue else {
		print("error: found diagnosis \(xmlId) which does not have or have multiple description elements (expected exactly one)", to: &mx_stderr)
		exit(1)
	}
	guard let smtpReferenceXML = diagnosis.elements(forName: "smtp").singleElement?.stringValue, let smtpReference = smtpReferenceXML.snailCaseToCamelCase(xmlPrefix: isEmailPrefix + "META_SMTP_", swiftPrefix: "code") else {
		print("error: found diagnosis \(xmlId) which does not have or have multiple smtp elements (expected exactly one)", to: &mx_stderr)
		exit(1)
	}
	guard smtpXMLIds.contains(smtpReferenceXML) else {
		print("error: found diagnosis \(xmlId) whose SMTP reference \(smtpReferenceXML) does not exist", to: &mx_stderr)
		exit(1)
	}
	
	let references = diagnosis.elements(forName: "reference").map{ (element: XMLElement) -> String in
		guard let xmlRef = element.stringValue, let ref = xmlRef.dashCaseToCamelCase(xmlPrefix: "", swiftPrefix: "") else {
			print("error: found diagnosis \(xmlId) which have an invalid reference \(element)", to: &mx_stderr)
			exit(1)
		}
		guard referenceXMLIds.contains(xmlRef) else {
			print("error: found diagnosis \(xmlId) whose reference \(xmlRef) does not exist", to: &mx_stderr)
			exit(1)
		}
		return ref
	}
	
	guard diagnosisXMLIds.insert(xmlId).inserted else {
		print("error: found a diagnosis with the same id as another one: \(diagnosis)", to: &mx_stderr)
		exit(1)
	}
	guard diagnosisValues.insert(value).inserted else {
		print("error: found a diagnosis with the same value as another one: \(diagnosis)", to: &mx_stderr)
		exit(1)
	}
	
	/* Note: We don’t check the id to be a valid string for a Swift variable. */
	swiftEmailValidationCodesFileContent += #"\#t\#tpublic static let \#(id) = ValidationDiagnosis("#
	swiftEmailValidationCodesFileContent +=    #"xmlId: \#(xmlId.stringInGeneratedSwift()), "#
	swiftEmailValidationCodesFileContent +=    #"value: \#(value), "#
	swiftEmailValidationCodesFileContent +=    #"category: .\#(category), "#
	swiftEmailValidationCodesFileContent +=    #"smtpInfo: .\#(smtpReference), "#
	swiftEmailValidationCodesFileContent +=    #"references: [\#(references.map{ "." + $0 }.joined(separator: ", "))], "#
	swiftEmailValidationCodesFileContent +=    #"description: \#(description.stringInGeneratedSwift())"#
	swiftEmailValidationCodesFileContent += ")\n"
}
swiftEmailValidationCodesFileContent += """
		
		public let xmlId: String
		
		public let value: Int
		public let category: ValidationCategory
		public let smtpInfo: ValidationSMTPInfo
		public let references: [ValidationReference]
		public let description: String
		
		private init(xmlId pi: String, value v: Int, category c: ValidationCategory, smtpInfo si: ValidationSMTPInfo, references r: [ValidationReference], description d: String) {
			xmlId = pi
			value = v
			category = c
			smtpInfo = si
			references = r
			description = d
		}
		
	}
	
}

"""





/* Test file header. */
var swiftEmailTestsFileContent = """
/*
 * !!! File autogenerated by \(scriptURL.lastPathComponent)
 * !!! Don’t change manually.
 *
 * \(swiftEmailTestsURL.lastPathComponent)
 * EmailTests
 *
 * Created by \(scriptURL.lastPathComponent) on \(dateFormatter.string(from: Date())).
 */

import XCTest

@testable import Email



class \(swiftEmailTestsURL.deletingPathExtension().lastPathComponent) : XCTestCase {

"""

/* Test file content, from XML. */
guard let tests1DocRoot = try? XMLDocument(contentsOf: xmlEmailTests1URL, options: []).rootElement() else {
	print("error: cannot read XML input at \(xmlEmailTests1URL)", to: &mx_stderr)
	exit(1)
}
guard let tests2DocRoot = try? XMLDocument(contentsOf: xmlEmailTests2URL, options: []).rootElement() else {
	print("error: cannot read XML input at \(xmlEmailTests2URL)", to: &mx_stderr)
	exit(1)
}
for (id, test) in (tests1DocRoot.elements(forName: "test").map({ ("", $0) }) + tests2DocRoot.elements(forName: "test").map({ ("Original", $0) })) {
	guard let testId = test.attribute(forName: "id")?.stringValue else {
		print("warning: skipping a test which does not have an id; here is it’s string representation: \(test)", to: &mx_stderr)
		continue
	}
	guard let addressTransformed = test.elements(forName: "address").singleElement?.stringValue else {
		print("warning: skipping test \(testId) which does not have or have multiple addresses (expected exactly one)", to: &mx_stderr)
		continue
	}
	guard let xmlCategory = test.elements(forName: "category").singleElement?.stringValue, let category = xmlCategory.snailCaseToCamelCase(xmlPrefix: isEmailPrefix, swiftPrefix: "") else {
		print("warning: skipping test \(testId) which does not have, have an invalid or have multiple categories (expected exactly one)", to: &mx_stderr)
		continue
	}
	guard cateogoryXMLIds.contains(xmlCategory) else {
		print("warning: skipping test \(testId) whose category \(xmlCategory) does not exist", to: &mx_stderr)
		continue
	}
	guard let xmlDiagnosis = test.elements(forName: "diagnosis").singleElement?.stringValue, let diagnosis = xmlDiagnosis.snailCaseToCamelCase(xmlPrefix: isEmailPrefix, swiftPrefix: "") else {
		print("warning: skipping test \(testId) which does not have, have an invalid or have multiple diagnoses (expected exactly one)", to: &mx_stderr)
		continue
	}
	guard diagnosisXMLIds.contains(xmlDiagnosis) else {
		print("warning: skipping test \(testId) whose diagnosis \(xmlDiagnosis) does not exist", to: &mx_stderr)
		continue
	}
	let source = test.elements(forName: "source").singleElement?.stringValue
	if source == nil {
		print("warning: test \(testId) have no or multiple sources (expected exactly one); test won’t have its source in the generated file", to: &mx_stderr)
	}
	let sourcelink = test.elements(forName: "sourcelink").singleElement?.stringValue
	if sourcelink == nil {
		print("warning: test \(testId) have no or multiple source links (expected exactly one); test won’t have its source link in the generated file", to: &mx_stderr)
	}
	
	/* We must transform the address a bit per tests.php source code */
	let address = transforms.reduce(addressTransformed, { $0.replacingOccurrences(of: $1.0, with: $1.1) })
	
	let fullSource: String
	switch (source, sourcelink) {
	case (.some(let source), .some(let sourcelink)): fullSource = "From " + source + " (" + sourcelink + ")"
	case (.some(let source), nil):                   fullSource = "From " + source
	case (nil, .some(let sourcelink)):               fullSource = "Source: " + sourcelink
	case (nil, nil):                                 fullSource = "Unknown source"
	}
	
	let actualCategory: String
	let actualDiagnosis: String
	if xmlCategory == "ISEMAIL_DNSWARN" {
		/* For the time being we do not do DNS lookups, so let’s just ignore these
		 * errors.*/
		actualCategory = "validCategory"
		actualDiagnosis = "valid"
	} else {
		actualCategory = category
		actualDiagnosis = diagnosis
	}
	
	/* Note: We assume that 1/ there won’t be two tests with the same id 2/ the
	 *       ids will never contain an invalid char in a function name. */
	swiftEmailTestsFileContent += #"""
		
		/* \#(fullSource.replacingOccurrences(of: "/*", with: "/​*").replacingOccurrences(of: "*/", with: "*​/")) */
		func testXMLTest\#(id)\#(testId)() {
			let email = \#(address.stringInGeneratedSwift())
			let (validationResult, _, _) = EmailValidator(string: email).evaluateEmail()
	//		XCTAssertEqual(validationResult.category, .\#(actualCategory)) /* On the original test set, the category is sometimes not correct. We _cannot_ fail the category (linked with diagnosis by autogeneration), so we don’t test that. */
			XCTAssertEqual(validationResult, .\#(actualDiagnosis))
		}
	
	"""#
}

/* Test file footer. */
swiftEmailTestsFileContent += """
	
}

"""

guard let _ = try? Data(swiftEmailValidationCodesFileContent.utf8).write(to: swiftEmailMetaURL) else {
	print("error: cannot write validation codes file to \(swiftEmailTestsURL)", to: &mx_stderr)
	exit(1)
}

guard let _ = try? Data(swiftEmailTestsFileContent.utf8).write(to: swiftEmailTestsURL) else {
	print("error: cannot write test file to \(swiftEmailTestsURL)", to: &mx_stderr)
	exit(1)
}

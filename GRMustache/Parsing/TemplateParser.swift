//
//  TemplateParser.swift
//  GRMustache
//
//  Created by Gwendal Roué on 25/10/2014.
//  Copyright (c) 2014 Gwendal Roué. All rights reserved.
//

import Foundation

protocol TemplateTokenConsumer {
    func parser(parser:TemplateParser, shouldContinueAfterParsingToken token:TemplateToken) -> Bool
    func parser(parser:TemplateParser, didFailWithError error:NSError)
}

class TemplateParser {
    let tokenConsumer: TemplateTokenConsumer
    let tagStartDelimiter: String
    let tagEndDelimiter: String
    
    init(tokenConsumer: TemplateTokenConsumer, configuration: Configuration) {
        self.tokenConsumer = tokenConsumer
        self.tagStartDelimiter = configuration.tagStartDelimiter
        self.tagEndDelimiter = configuration.tagEndDelimiter
    }
    
    func parse(templateString:String) {
        var delimiters = Delimiters(tagStart: tagStartDelimiter, tagEnd: tagEndDelimiter)
        
        var i = templateString.startIndex
        let end = templateString.endIndex
        
        var state: State = .Start
        var stateStart = i
        
        var lineNumber = 1
        var startLineNumber = lineNumber
        
        var atString = { (string: String?) -> Bool in
            return string != nil && templateString.substringFromIndex(i).hasPrefix(string!)
        }
        
        while i < end {
            let c = templateString[i]
            
            switch state {
            case .Start:
                if c == "\n" {
                    startLineNumber = lineNumber
                    stateStart = i
                    state = .Text
                    
                    ++lineNumber
                } else if atString(delimiters.unescapedTagStart) {
                    startLineNumber = lineNumber
                    stateStart = i
                    state = .UnescapedTag
                    i = advance(i, delimiters.unescapedTagStartLength).predecessor()
                } else if atString(delimiters.setDelimitersStart) {
                    startLineNumber = lineNumber
                    stateStart = i
                    state = .SetDelimitersTag
                    i = advance(i, delimiters.setDelimitersStartLength).predecessor()
                } else if atString(delimiters.tagStart) {
                    startLineNumber = lineNumber
                    stateStart = i
                    state = .Tag
                    i = advance(i, delimiters.tagStartLength).predecessor()
                } else {
                    startLineNumber = lineNumber
                    stateStart = i
                    state = .Text
                }
            case .Text:
                if c == "\n" {
                    ++lineNumber
                } else if atString(delimiters.unescapedTagStart) {
                    if stateStart != i {
                        let templateSubstring = templateString.substringWithRange(stateStart..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .Text(text: templateSubstring))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    }
                    startLineNumber = lineNumber
                    stateStart = i
                    state = .UnescapedTag
                    i = advance(i, delimiters.unescapedTagStartLength).predecessor()
                } else if atString(delimiters.setDelimitersStart) {
                    if stateStart != i {
                        let templateSubstring = templateString.substringWithRange(stateStart..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .Text(text: templateSubstring))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    }
                    startLineNumber = lineNumber
                    stateStart = i
                    state = .SetDelimitersTag
                    i = advance(i, delimiters.setDelimitersStartLength).predecessor()
                } else if atString(delimiters.tagStart) {
                    if stateStart != i {
                        let templateSubstring = templateString.substringWithRange(stateStart..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .Text(text: templateSubstring))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    }
                    startLineNumber = lineNumber
                    stateStart = i
                    state = .Tag
                    i = advance(i, delimiters.tagStartLength).predecessor()
                }
            case .Tag:
                if c == "\n" {
                    ++lineNumber
                } else if atString(tagEndDelimiter) {
                    let tagInitialIndex = advance(stateStart, delimiters.tagStartLength)
                    let tagInitial = templateString[tagInitialIndex]
                    let templateSubstring = templateString.substringWithRange(stateStart..<advance(i, delimiters.tagEndLength))
                    switch tagInitial {
                    case "!":
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .Comment)
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    case "#":
                        let content = templateString.substringWithRange(tagInitialIndex.successor()..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .Section(content: content))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    case "^":
                        let content = templateString.substringWithRange(tagInitialIndex.successor()..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .InvertedSection(content: content))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    case "$":
                        let content = templateString.substringWithRange(tagInitialIndex.successor()..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .InheritableSection(content: content))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    case "/":
                        let content = templateString.substringWithRange(tagInitialIndex.successor()..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .Close(content: content))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    case ">":
                        let content = templateString.substringWithRange(tagInitialIndex.successor()..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .Partial(content: content))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    case "<":
                        let content = templateString.substringWithRange(tagInitialIndex.successor()..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .InheritablePartial(content: content))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    case "&":
                        let content = templateString.substringWithRange(tagInitialIndex.successor()..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .UnescapedVariable(content: content))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    case "%":
                        let content = templateString.substringWithRange(tagInitialIndex.successor()..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .Pragma(content: content))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    default:
                        let content = templateString.substringWithRange(tagInitialIndex..<i)
                        let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .EscapedVariable(content: content))
                        if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                            return
                        }
                    }
                    stateStart = advance(i, delimiters.tagEndLength)
                    state = .Start
                    i = advance(i, delimiters.tagEndLength).predecessor()
                }
                break
            case .UnescapedTag:
                if c == "\n" {
                    ++lineNumber
                } else if atString(delimiters.unescapedTagEnd) {
                    let tagInitialIndex = advance(stateStart, delimiters.unescapedTagStartLength)
                    let templateSubstring = templateString.substringWithRange(stateStart..<advance(i, delimiters.unescapedTagEndLength))
                    let content = templateString.substringWithRange(tagInitialIndex..<i)
                    let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .UnescapedVariable(content: content))
                    if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                        return
                    }
                    stateStart = advance(i, delimiters.unescapedTagEndLength)
                    state = .Start
                    i = advance(i, delimiters.unescapedTagEndLength).predecessor()
                }
            case .SetDelimitersTag:
                if c == "\n" {
                    ++lineNumber
                } else if atString(delimiters.setDelimitersEnd) {
                    let tagInitialIndex = advance(stateStart, delimiters.setDelimitersStartLength)
                    let content = templateString.substringWithRange(tagInitialIndex.successor()..<i)
                    let newDelimiters = content.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).filter { countElements($0) > 0 }
                    if (newDelimiters.count != 2) {
                        failWithParseError(lineNumber: lineNumber, description: "Invalid set delimiters tag")
                        return;
                    }
                    
                    let templateSubstring = templateString.substringWithRange(stateStart..<advance(i, delimiters.setDelimitersEndLength))
                    let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .SetDelimiters)
                    if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                        return
                    }
                    
                    stateStart = advance(i, delimiters.setDelimitersEndLength)
                    state = .Start;
                    i = advance(i, delimiters.setDelimitersEndLength).predecessor()
                    
                    delimiters = Delimiters(tagStart: newDelimiters[0], tagEnd: newDelimiters[1])
                }
            }
            
            i = i.successor()
        }
        
        
        // EOF
        
        switch state {
        case .Start:
            break
        case .Text:
            let templateSubstring = templateString.substringWithRange(stateStart..<end)
            let token = TemplateToken(lineNumber: startLineNumber, templateSubstring: templateSubstring, type: .Text(text: templateSubstring))
            if !tokenConsumer.parser(self, shouldContinueAfterParsingToken: token) {
                return
            }
        case .Tag, .UnescapedTag, .SetDelimitersTag:
            failWithParseError(lineNumber: startLineNumber, description: "Unclosed Mustache tag")
            return
        }
    }
    
    
    // MARK: - Private
    
    enum State {
        case Start
        case Text
        case Tag
        case UnescapedTag
        case SetDelimitersTag
    }
    
    struct Delimiters {
        let tagStart: String
        let tagStartLength: Int
        let tagEnd: String
        let tagEndLength: Int
        let unescapedTagStart: String?
        let unescapedTagStartLength: Int
        let unescapedTagEnd: String?
        let unescapedTagEndLength: Int
        let setDelimitersStart: String
        let setDelimitersStartLength: Int
        let setDelimitersEnd: String
        let setDelimitersEndLength: Int
        
        init(tagStart: String, tagEnd: String) {
            self.tagStart = tagStart
            self.tagEnd = tagEnd
            
            tagStartLength = distance(tagStart.startIndex, tagStart.endIndex)
            tagEndLength = distance(tagEnd.startIndex, tagEnd.endIndex)
            
            let usesStandardDelimiters = (tagStart == "{{") && (tagEnd == "}}")
            unescapedTagStart = usesStandardDelimiters ? "{{{" : nil
            unescapedTagStartLength = unescapedTagStart != nil ? distance(unescapedTagStart!.startIndex, unescapedTagStart!.endIndex) : 0
            unescapedTagEnd = usesStandardDelimiters ? "}}}" : nil
            unescapedTagEndLength = unescapedTagEnd != nil ? distance(unescapedTagEnd!.startIndex, unescapedTagEnd!.endIndex) : 0
            
            setDelimitersStart = "\(tagStart)="
            setDelimitersStartLength = distance(setDelimitersStart.startIndex, setDelimitersStart.endIndex)
            setDelimitersEnd = "=\(tagEnd)"
            setDelimitersEndLength = distance(setDelimitersEnd.startIndex, setDelimitersEnd.endIndex)
        }
    }
    
    func failWithParseError(#lineNumber: Int, description: String) {
        let userInfo = [NSLocalizedDescriptionKey: "Parse error at line \(lineNumber): \(description)"]
        var error = NSError(domain: GRMustacheErrorDomain, code: GRMustacheErrorCodeParseError, userInfo: userInfo)
        tokenConsumer.parser(self, didFailWithError: error)
    }
}

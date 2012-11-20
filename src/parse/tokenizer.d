module parse.tokenizer;

import std.array, std.algorithm, std.conv;
import common, ast;


@safe nothrow:


enum ParseContext { any, text, character, comment }


immutable struct TokenResult
{
    TokenType type;
    size_t length;
    ParseContext contextAfter;
    bool isError;
}


private enum TokenResult empty = TokenResult();


private pure TokenResult ok (immutable TokenType tokenType, 
                             immutable size_t length, 
                             immutable ParseContext contextAfter = ParseContext.any)
{
    return TokenResult(tokenType, length, contextAfter);
}


private pure TokenResult error (immutable TokenType tokenType, 
                                immutable size_t length, 
                                immutable ParseContext contextAfter = ParseContext.any)
{
    return TokenResult(tokenType, length, contextAfter, true);
}


final class Tokenizer
{
    nothrow:

    private dstring src;
    private ParseContext context;

    Token front;
    bool empty;
    uint index;


    this (const dstring src)
    {
        this.src = src;
        popFront();
    }


    void popFront ()
    {
        if (!src.length)
        {
            empty = true;
            return;
        }

        auto tr = parseNext();

        front = Token(
            index++,
            tr.type,
            front.type == TokenType.newLine
                ? Position (front.start.line + 1, 0)
                : Position (front.start.line, front.start.column + cast(uint)front.text.length),
            src[0 .. tr.length],
            front.pos + cast(uint)front.text.length,
            tr.isError);

        src = src[tr.length .. $];
        context = tr.contextAfter;
    }


    private TokenResult parseNext ()
    {
        auto errorLength = 0;
        enum parsers = [
            ParseContext.any : [&parseCommentEnd, &parseCommentLine, &parseCommentStart, &parseWhite,
                                &parseNewLine, &parseBraceStart, &parseBraceEnd, &parseIdent, &parseNum,
                                &parseTextStart, &parseCharStart, &parseOp],
            ParseContext.text : [&parseTextEnd, &parseText, &parseTextEscape, &parseTextNewLine],
            ParseContext.character : [&parseChar, &parseCharEscape, &parseCharEnd, &parseCharNewLine],
            ParseContext.comment : [&parseCommentEnd, &parseComment, &parseCommentNewLine],
        ];
        auto src2 = src;
        tryAgain:
        foreach (p; parsers[context])
        {
            assert (src.length);
            auto tr = p(src2);
            if (tr.length)
                return errorLength == 0 ? tr : error(TokenType.unknown, errorLength);
        }

        src2 = src2[1 .. $];
        ++errorLength;

        if (!src2.length)
            return error(TokenType.unknown, errorLength);

        goto tryAgain;
    }
}


pure:


TokenResult parseCharStart (const dstring src)
{
    return ok(TokenType.textStart, src[0] == '\'', ParseContext.character);
}


TokenResult parseCharEnd (const dstring src)
{
    return ok(TokenType.textEnd, src[0] == '\'', ParseContext.any);
}


TokenResult parseChar (const dstring src)
{
    auto l = src.lengthUntilIncluding!(ch => ch =='\\' || ch == '\'');
    if (!l)
    {
        l = src.lengthUntilIncluding!isNewLine;
        return error(TokenType.text, l ? l - 1 : src.length, ParseContext.any);
    }
    return ok(TokenType.text, l - 1, ParseContext.character);
}


TokenResult parseCharNewLine (const dstring src)
{
    return ok(TokenType.newLine, src.lengthWhile!isNewLine, ParseContext.character);
}


TokenResult parseCharEscape (const dstring src)
{
    return parseTextEscapeImpl (src, ParseContext.character);
}


TokenResult parseTextStart (const dstring src)
{
    return ok(TokenType.textStart, src[0] == '"', ParseContext.text);
}


TokenResult parseTextEnd (const dstring src)
{
    return ok(TokenType.textEnd, src[0] == '"', ParseContext.any);
}


TokenResult parseText (const dstring src)
{
    auto l = src.lengthUntilIncluding!(ch => ch == '\\' || ch == '"' || ch.isNewLine);
    if (!l)
        return error(TokenType.text, src.length, ParseContext.any);
    else if (src[l - 1] == '"')
        return ok(TokenType.text, l - 1, ParseContext.text);
    else if (src[l - 1] == '\\')
        return src[l + 1 .. $ - l + 2].lengthUntilIncluding!(ch => ch == '"')
            ? ok(TokenType.text, l - 1, ParseContext.text)
            : error(TokenType.text, l - 1, ParseContext.any);
    else
        return src.lengthUntilIncluding!(ch => ch == '"')
            ? ok(TokenType.text, l - 1, ParseContext.text)
            : error(TokenType.text, l - 1, ParseContext.any);
}


TokenResult parseTextNewLine (const dstring src)
{
    return ok(TokenType.newLine, src.lengthWhile!isNewLine, ParseContext.text);
}


TokenResult parseTextEscape (const dstring src)
{
    return parseTextEscapeImpl(src, ParseContext.text);
}


TokenResult parseTextEscapeImpl (const dstring src, ParseContext pc)
{
    if (src[0] == '\\')
    {
        if (src.length < 2)
            return error(TokenType.textEscape, 1, pc);

        immutable ch = src[1];
        if (ch == 'n' || ch == 'r' || ch == 't' || ch == '"' || ch == '\'' || ch == '\\')
            return ok(TokenType.textEscape, 2, pc);
        return error(TokenType.textEscape, 2, pc);
    }
    return empty;
}


TokenResult parseOp (const dstring src)
{
    switch (src[0])
    {
        case '.': return ok(TokenType.dot, 1);
        case '=': return ok(TokenType.assign, 1);
        case ',': return ok(TokenType.coma, 1);
        case ':': return ok(TokenType.asType, 1);
        default:  return ok(TokenType.op, src.lengthWhile!isOp);
    }
}


TokenResult parseNum (const dstring src)
{
    if (src[0] == '#')
    {
        auto tr = parseIdentOrNum!(isHexNum, ch => ch.isHexNum || ch == '_')(
            src[1 .. $], TokenType.num);
        return TokenResult(tr.type, tr.length + 1);
    }

    return parseIdentOrNum!(isNum, ch => ch.isNum || ch == '_')(src, TokenType.num);
}


TokenResult parseIdent (const dstring src)
{
    immutable tr = parseIdentOrNum!(isIdent, ch => ch.isIdent || ch.isNum || ch == '_')
        (src, TokenType.ident);

    if (!tr.length)
        return tr;

    switch (src[0 .. tr.length])
    {
        case "if":     return ok(TokenType.keyIf,     tr.length);
        case "then":   return ok(TokenType.keyThen,   tr.length);
        case "else":   return ok(TokenType.keyElse,   tr.length);
        case "end":    return ok(TokenType.keyEnd,    tr.length);
        case "fn":     return ok(TokenType.keyFn,     tr.length);
        case "return": return ok(TokenType.keyReturn, tr.length);
        case "goto":   return ok(TokenType.keyGoto,   tr.length);
        case "label":  return ok(TokenType.keyLabel,  tr.length);
        case "struct": return ok(TokenType.keyStruct, tr.length);
        case "throw":  return ok(TokenType.keyThrow,  tr.length);
        case "var":    return ok(TokenType.keyVar,    tr.length);
        case "import": return ok(TokenType.keyImport, tr.length);

        case "Type":   return ok(TokenType.typeType,  tr.length);
        case "Void":   return ok(TokenType.typeVoid,  tr.length);
        case "Any":    return ok(TokenType.typeAny,   tr.length);
        case "AnyOf":  return ok(TokenType.typeOr,    tr.length);
        case "Fn":     return ok(TokenType.typeFn,    tr.length);
        case "Num":    return ok(TokenType.typeNum,   tr.length);
        case "Text":   return ok(TokenType.typeText,  tr.length);
        case "Char":   return ok(TokenType.typeChar,  tr.length);

        default:       return tr;
    }
}


TokenResult parseIdentOrNum (alias start, alias rest) (const dstring src, TokenType tokType)
{
    //auto l = src.lengthWhile!(ch => ch == '_'); // BUG: Internal error: toir.c 178
    auto l = src.lengthWhile!isUnderscore;
    immutable nl = src[l .. $].lengthWhile!start;
    if (!nl)
        return empty;
    l = l + nl;
    if (l)
        l = l + src[l .. $].lengthWhile!rest;
    return ok(tokType, l);
}


TokenResult parseBraceStart (const dstring src)
{
    return ok(TokenType.braceStart, src[0].isBraceStart);
}


TokenResult parseBraceEnd (const dstring src)
{
    return ok(TokenType.braceEnd, src[0].isBraceEnd);
}


TokenResult parseCommentLine (const dstring src)
{
    if (!(src.length >= 2 && src[0] == '-' && src[1] == '-'))
        return empty;
    immutable l = src.lengthUntilIncluding!isNewLine;
    return ok(TokenType.commentLine, l ? l - 1 : src.length);
}


TokenResult parseCommentStart (const dstring src)
{
    if (src.length >= 2 && src[0] == '/' && src[1]== '-')
        return ok(TokenType.commentMultiStart, 2, ParseContext.comment);
    return empty;
}


TokenResult parseComment (const dstring src)
{
    size_t l;
    while (true)
    {
        if (!src.myCanFind("-/"))
        {
            auto lineLength = src.lengthWhile!(ch => !ch.isNewLine);
            return error(TokenType.commentMulti, lineLength, ParseContext.any);
        }

        if (l == src.length || isNewLine(src[l]) || (src[l] == '-' && l + 1 < src.length && src[l + 1] == '/'))
        {
            if (l == 0)
                return empty;
            else
                return ok(TokenType.commentMulti, l, ParseContext.comment);
        }
        ++l;
    }
}


TokenResult parseCommentEnd (const dstring src)
{
    if (src.length >= 2 && src[0] == '-' && src[1]== '/')
        return ok(TokenType.commentMultiEnd, 2, ParseContext.any);
    return empty;
}


TokenResult parseCommentNewLine (const dstring src)
{
    return ok(TokenType.newLine, src.lengthWhile!isNewLine, ParseContext.comment);
}


TokenResult parseNewLine (const dstring src)
{
    return ok(TokenType.newLine, src.lengthWhile!isNewLine);
}


TokenResult parseWhite (const dstring src)
{
    return ok(TokenType.white, src.lengthWhile!isWhite);
}


@property:


size_t lengthWhile (alias isMatch) (immutable dstring src)
{
    size_t i = 0;
    while (i < src.length)
    {
        if (!isMatch(src[i]))
            return i;
        i++;
    }
    return src.length;
}


size_t lengthUntilIncluding (alias isMatch) (immutable dstring src)
{
    size_t i = 0;
    while (i < src.length)
    {
        if (isMatch(src[i]))
            return i + 1;
        i++;
    }
    return 0;
}


bool isUnderscore (dchar ch) { return ch == '_'; }

bool isWhite (dchar ch) { return ch == ' ' || ch == '\t'; }

bool isNewLine (dchar ch) { return ch == '\r' || ch == '\n'; }

bool isIdent (dchar ch) { return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z'); }

bool isBraceStart (dchar ch) { return ch == '(' || ch == '{' || ch == '['; }

bool isBraceEnd (dchar ch) { return ch == ')' || ch == '}' || ch == ']'; }

bool isNum (dchar ch) { return ch >= '0' && ch <= '9'; }

bool isHexNum (dchar ch) { return ch.isNum || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F'); }

bool isOp (dchar ch)
{
    return ch == '!' ||  ch == '\\' ||  ch == '^' ||  ch == '`' ||  ch == '|' ||  ch == '~'
        || (ch >= '#' && ch <= '\'')
        || (ch >= '*' && ch <= '-') ||  ch == '/'
        || (ch >= ':' && ch <= '@');
}

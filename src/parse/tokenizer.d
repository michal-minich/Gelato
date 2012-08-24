module parse.tokenizer;

import std.array, std.algorithm, std.conv;
import common, parse.ast;


@safe:
enum Geany { Bug }


enum ParseContext { any, text, character, comment }


immutable struct TokenResult
{
    nothrow:

    TokenType type;
    size_t length;
    ParseContext contextAfter;
    bool isError;

    static enum TokenResult empty = TokenResult();

    pure static TokenResult ok (TokenType tokenType,
        size_t length,
        ParseContext contextAfter = ParseContext.any)
    {
        return TokenResult(tokenType, length, contextAfter);
    }

    pure static TokenResult error (TokenType tokenType,
        size_t length,
        ParseContext contextAfter = ParseContext.any)
    {
        return TokenResult(tokenType, length, contextAfter, true);
    }
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


    @trusted void popFront ()
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
            ParseContext.any : [&parseCommentLine, &parseCommentStart, &parseWhite, &parseNewLine,
                                &parseBraceStart, &parseBraceEnd, &parseIdent, &parseNum,
                                &parseTextStart, &parseCharStart, &parseOp],
            ParseContext.text : [&parseText, &parseTextEscape, &parseTextEnd, &parseTextNewLine],
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
                return errorLength == 0 ? tr : TokenResult.error(TokenType.unknown, errorLength);
        }

        src2 = src2[1 .. $];
        ++errorLength;

        if (!src2.length)
            return TokenResult.error(TokenType.unknown, errorLength);

        goto tryAgain;
    }
}


@safe pure nothrow:


TokenResult parseCharStart (const dstring src)
{
    return TokenResult.ok(TokenType.textStart, src[0] == '\'', ParseContext.character);
}


TokenResult parseCharEnd (const dstring src)
{
    return TokenResult.ok(TokenType.textEnd, src[0] == '\'', ParseContext.any);
}


TokenResult parseChar (const dstring src)
{
    auto l = lengthUntilIncluding!(ch => ch =='\\' || ch == '\'')(src);
    if (!l)
    {
        l = lengthUntilIncluding!isNewLine(src);
        return TokenResult.error(TokenType.text, l ? l - 1 : src.length, ParseContext.any);
    }
    return TokenResult.ok(TokenType.text, l - 1, ParseContext.character);
}


TokenResult parseCharNewLine (const dstring src)
{
    return TokenResult.ok(TokenType.newLine, lengthWhile!isNewLine(src), ParseContext.character);
}


TokenResult parseCharEscape (const dstring src)
{
    return parseTextEscapeImpl (src, ParseContext.character);
}


TokenResult parseTextStart (const dstring src)
{
    return TokenResult.ok(TokenType.textStart, src[0] == '"', ParseContext.text);
}


TokenResult parseTextEnd (const dstring src)
{
    return TokenResult.ok(TokenType.textEnd, src[0] == '"', ParseContext.any);
}


TokenResult parseText (const dstring src)
{
    auto l = lengthUntilIncluding!(ch => ch =='\\' || ch == '"')(src);
    if (!l)
    {
        l = lengthUntilIncluding!isNewLine(src);
        return TokenResult.error(TokenType.text, l ? l - 1 : src.length, ParseContext.any);
    }
    return TokenResult.ok(TokenType.text, l - 1, ParseContext.text);
}


TokenResult parseTextNewLine (const dstring src)
{
    return TokenResult.ok(TokenType.newLine, lengthWhile!isNewLine(src), ParseContext.text);
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
            return TokenResult.error(TokenType.textEscape, 1, pc);

        immutable ch = src[1];
        if (ch == 'n' || ch == 'r' || ch == 't')
            return TokenResult.ok(TokenType.textEscape, 2, pc);
        return TokenResult.error(TokenType.textEscape, 2, pc);
    }
    return TokenResult.empty;
}


TokenResult parseOp (const dstring src)
{
    switch (src[0])
    {
        case '.': return TokenResult.ok(TokenType.dot, 1);
        case ',': return TokenResult.ok(TokenType.coma, 1);
        default:  return TokenResult.ok(TokenType.op, lengthWhile!isOp(src));
    }
}


TokenResult parseNum (const dstring src)
{
    return parseIdentOrNum!(isNum, ch => isNum(ch) || isUnderscore(ch))(src, TokenType.num);
}


TokenResult parseIdent (const dstring src)
{
    immutable tr = parseIdentOrNum!(isIdent, ch => isIdent(ch) || isNum(ch) || isUnderscore(ch))
        (src, TokenType.ident);

    if (!tr.length)
        return tr;

    switch (src[0 .. tr.length])
    {
        case "if":     return TokenResult.ok(TokenType.keyIf,     tr.length);
        case "then":   return TokenResult.ok(TokenType.keyThen,   tr.length);
        case "else":   return TokenResult.ok(TokenType.keyElse,   tr.length);
        case "end":    return TokenResult.ok(TokenType.keyEnd,    tr.length);
        case "fn":     return TokenResult.ok(TokenType.keyFn,     tr.length);
        case "return": return TokenResult.ok(TokenType.keyReturn, tr.length);
        case "goto":   return TokenResult.ok(TokenType.keyGoto,   tr.length);
        case "label":  return TokenResult.ok(TokenType.keyLabel,  tr.length);
        case "struct": return TokenResult.ok(TokenType.keyStruct, tr.length);
        case "throw":  return TokenResult.ok(TokenType.keyThrow,  tr.length);
        case "var":    return TokenResult.ok(TokenType.keyVar,    tr.length);

        case "Type":   return TokenResult.ok(TokenType.typeType,  tr.length);
        case "Any":    return TokenResult.ok(TokenType.typeAny,   tr.length);
        case "Void":   return TokenResult.ok(TokenType.typeVoid,  tr.length);
        case "Or":     return TokenResult.ok(TokenType.typeOr,    tr.length);
        case "Fn":     return TokenResult.ok(TokenType.typeFn,    tr.length);
        case "Num":    return TokenResult.ok(TokenType.typeNum,   tr.length);
        case "Text":   return TokenResult.ok(TokenType.typeText,  tr.length);
        case "Char":   return TokenResult.ok(TokenType.typeChar,  tr.length);
        default:       return tr;
    }
}


TokenResult parseIdentOrNum (alias start, alias rest) (const dstring src, TokenType tokType)
{
    auto l = lengthWhile!isUnderscore(src);
    immutable nl = lengthWhile!start(src[l .. $]);
    if (!nl)
        return TokenResult.empty;
    l = l + nl;
    if (l)
        l = l + lengthWhile!rest(src[l .. $]);
    return TokenResult.ok(tokType, l);
}


TokenResult parseBraceStart (const dstring src)
{
    return TokenResult.ok(TokenType.braceStart, isBraceStart(src[0]));
}


TokenResult parseBraceEnd (const dstring src)
{
    return TokenResult.ok(TokenType.braceEnd, isBraceEnd(src[0]));
}


TokenResult parseCommentLine (const dstring src)
{
    if (!(src.length >= 2 && src[0] == '-' && src[1] == '-'))
        return TokenResult.empty;
    immutable l = lengthUntilIncluding!isNewLine(src);
    return TokenResult.ok(TokenType.commentLine, l ? l - 1 : src.length);
}


TokenResult parseCommentStart (const dstring src)
{
    if (src.length >= 2 && src[0] == '/' && src[1]== '-')
        return TokenResult.ok(TokenType.commentMultiStart, 2, ParseContext.comment);
    return TokenResult.empty;
}


TokenResult parseComment (const dstring src)
{
    size_t l;
    while (true)
    {
        auto l1 = lengthUntilIncluding!(ch => isNewLine(ch) || ch == '-')(src[l .. $]);
        if (!l1)
            return TokenResult.error(TokenType.commentMulti, src.length, ParseContext.comment);
        l = l + l1;
        if (l == src.length || isNewLine(src[l]) || (l + 1 < src.length && src[l + 1] == '/'))
            return TokenResult.ok(TokenType.commentMulti, l, ParseContext.comment);
    }
}


TokenResult parseCommentEnd (const dstring src)
{
    if (src.length >= 2 && src[0] == '-' && src[1]== '/')
        return TokenResult.ok(TokenType.commentMultiEnd, 2, ParseContext.any);
    return TokenResult.empty;
}


TokenResult parseCommentNewLine (const dstring src)
{
    return TokenResult.ok(TokenType.newLine, lengthWhile!isNewLine(src), ParseContext.comment);
}


TokenResult parseNewLine (const dstring src)
{
    return TokenResult.ok(TokenType.newLine, lengthWhile!isNewLine(src));
}


TokenResult parseWhite (const dstring src)
{
    return TokenResult.ok(TokenType.white, lengthWhile!isWhite(src));
}



size_t lengthWhile (alias isMatch) (const dstring src)
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


size_t lengthUntilIncluding (alias isMatch) (const dstring src)
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


bool isWhite (const dchar ch)
{
    return ch == ' ' || ch == '\t';
}


bool isNewLine (const dchar ch)
{
    return ch == '\r' || ch == '\n';
}


bool isIdent (const dchar ch)
{
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
}


bool isNum (const dchar ch)
{
    return ch >= '0' && ch <= '9';
}


bool isUnderscore (const dchar ch)
{
    return ch == '_';
}


bool isMinus (const dchar ch)
{
    return ch == '-';
}


bool isSingleQoute (const dchar ch)
{
    return ch == '\'';
}


bool isDoubleQoute (const dchar ch)
{
    return ch == '"';
}


bool isSingleQouteOrBackSlash (const dchar ch)
{
    return ch == '\'' || ch == '\\';
}


bool isDoubleQouteOrBackSlash (const dchar ch)
{
    return ch == '"' || ch == '\\';
}


bool isOp (const dchar ch)
{
    return ch == '!' ||  ch == '\\' ||  ch == '^' ||  ch == '`' ||  ch == '|' ||  ch == '~'
        || (ch >= '#' && ch <= '\'')
        || (ch >= '*' && ch <= '-') ||  ch == '/'
        || (ch >= ':' && ch <= '@');
}


bool isBraceStart (const dchar ch)
{
    return ch == '(' || ch == '{' || ch == '[';
}


bool isBraceEnd (const dchar ch)
{
    return ch == ')' || ch == '}' || ch == ']';
}
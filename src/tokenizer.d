module tokenizer;

import std.array, std.algorithm, std.conv;
import common;



struct Token
{
    uint index;
    TokenType type;
    Position start;
    dstring text;
    uint pos;
    bool isError;

    const @safe @property size_t endColumn ()
    {
        return start.column + text.length - 1;
    }

    const dstring toDebugString ()
    {
        return dtext(index, "\t", type, "\t\t", start.line, ":", start.column, "-", endColumn,
               "(", text.length, ")", pos, "\t", isError ? "Error" : "",
               "\t\"", text.toVisibleCharsText(), "\"");
    }
}


enum TokenType
{
    empty, unknown,
    white, newLine,
    num, ident, op,
    textStart, text, textEscape, textEnd,
    braceStart, braceEnd,
    commentLine, commentMultiStart, commentMulti, commentMultiEnd,
    keyIf, keyThen, keyElse, keyEnd,
    keyFn, keyReturn,
    keyGoto, keyLabel,
    keyStruct,
    keyThrow,
    keyVar,
}


enum ParseContext { any, text, character, comment }


immutable struct ParseResult
{
    TokenType type;
    size_t length;
    ParseContext contextAfter;
    bool isError;

    static enum ParseResult empty = ParseResult();

    @safe pure static ParseResult ok (TokenType tokenType,
        size_t length,
        ParseContext contextAfter = ParseContext.any)
    {
        return ParseResult(tokenType, length, contextAfter);
    }

    @safe pure static ParseResult error (TokenType tokenType,
        size_t length,
        ParseContext contextAfter = ParseContext.any)
    {
        return ParseResult(tokenType, length, contextAfter, true);
    }
}


@safe final class Tokenizer
{
    private dstring src;
    private ParseContext context;
    Token front;
    bool empty;
    uint index;


    this (const dstring src)
    {
        this.src = src;
        popFront2();
    }


    @trusted void popFront ()
    {
        assert (!empty, "Cannot popFront from empty Tokenizer");
        return popFront2();
    }


    @trusted void popFront2 ()
    {
        if (!src.length)
        {
            empty = true;
            return;
        }

        auto pr = parseNext();

        front = Token(
            index++,
            pr.type,
            front.type == TokenType.newLine
                ? Position (front.start.line + 1, 0)
                : Position (front.start.line, front.start.column + to!uint(front.text.length)),
            src[0 .. pr.length],
            front.pos + to!uint(front.text.length),
            pr.isError);

        //std.stdio.writeln(front.toDebugString());

        src = src[pr.length .. $];
        context = pr.contextAfter;
    }


    private ParseResult parseNext ()
    {
        auto errorLength = 0;
        enum parsers = [
            ParseContext.any : [&parseCommentLine, &parseCommentStart, &parseWhite, &parseNewLine,
                                &parseBraceStart, &parseBraceEnd, &parseIdent, &parseNum,
                                &parseTextStart/*, &parseChar*/, &parseOp],
            ParseContext.text : [&parseText, &parseTextEscape, &parseTextEnd, &parseTextNewLine],
            //ParseContext.character : [],
            ParseContext.comment : [&parseCommentEnd, &parseComment, &parseCommentNewLine],
        ];
        auto src2 = src;
        tryAgain:
        foreach (p; parsers[context])
        {
            assert (src.length);
            auto pr = p(src2);
            if (pr.length)
                return errorLength == 0 ? pr : ParseResult.error(TokenType.unknown, errorLength);
        }

        src2 = src2[1 .. $];
        ++errorLength;

        if (!src2.length)
            return ParseResult.error(TokenType.unknown, errorLength);

        goto tryAgain;
    }
}


@safe pure:


ParseResult parseTextStart (const dstring src)
{
    return ParseResult.ok(TokenType.textStart, src[0] == '"', ParseContext.text);
}


ParseResult parseTextEnd (const dstring src)
{
    return ParseResult.ok(TokenType.textEnd, src[0] == '"', ParseContext.any);
}


ParseResult parseText (const dstring src)
{
    auto l = lengthUntilIncluding!(ch => ch =='\\' || ch == '"')(src);
    if (!l)
    {
        l = lengthUntilIncluding!isNewLine(src);
        return ParseResult.error(TokenType.text, l ? l - 1 : src.length, ParseContext.any);
    }
    return ParseResult.ok(TokenType.text, l - 1, ParseContext.text);
}


ParseResult parseTextNewLine (const dstring src)
{
    return ParseResult.ok(TokenType.newLine, lengthWhile!isNewLine(src), ParseContext.text);
}


ParseResult parseTextEscape (const dstring src)
{
    if (src[0] == '\\')
    {
        if (src.length < 2)
            return ParseResult.error(TokenType.textEscape, 1, ParseContext.text);

        immutable ch = src[1];
        if (ch == 'n' || ch == 'r' || ch == 't')
            return ParseResult.ok(TokenType.textEscape, 2, ParseContext.text);
        return ParseResult.error(TokenType.textEscape, 2, ParseContext.text);
    }
    return ParseResult.empty;
}


ParseResult parseOp (const dstring src)
{
    return ParseResult.ok(TokenType.op, lengthWhile!isOp(src));
}


ParseResult parseNum (const dstring src)
{
    return parseIdentOrNum!(isNum, ch => isNum(ch) || isUnderscore(ch))(src, TokenType.num);
}


ParseResult parseIdent (const dstring src)
{
    immutable pr = parseIdentOrNum!(isIdent, ch => isIdent(ch) || isNum(ch) || isUnderscore(ch))
        (src, TokenType.ident);

    if (!pr.length)
        return pr;

    switch (src[0 .. pr.length])
    {
        case "if":     return ParseResult.ok(TokenType.keyIf,     pr.length);
        case "then":   return ParseResult.ok(TokenType.keyThen,   pr.length);
        case "else":   return ParseResult.ok(TokenType.keyElse,   pr.length);
        case "end":    return ParseResult.ok(TokenType.keyEnd,    pr.length);
        case "fn":     return ParseResult.ok(TokenType.keyFn,     pr.length);
        case "return": return ParseResult.ok(TokenType.keyReturn, pr.length);
        case "goto":   return ParseResult.ok(TokenType.keyGoto,   pr.length);
        case "label":  return ParseResult.ok(TokenType.keyLabel,  pr.length);
        case "struct": return ParseResult.ok(TokenType.keyStruct, pr.length);
        case "throw":  return ParseResult.ok(TokenType.keyThrow,  pr.length);
        case "var":    return ParseResult.ok(TokenType.keyVar,    pr.length);
        default:       return pr;
    }
}


ParseResult parseIdentOrNum (alias start, alias rest) (const dstring src, TokenType tokType)
{
    auto l = lengthWhile!isUnderscore(src);
    immutable nl = lengthWhile!start(src[l .. $]);
    if (!nl)
        return ParseResult.empty;
    l = l + nl;
    if (l)
        l = l + lengthWhile!rest(src[l .. $]);
    return ParseResult.ok(tokType, l);
}


ParseResult parseBraceStart (const dstring src)
{
    return ParseResult.ok(TokenType.braceStart, isBraceStart(src[0]));
}


ParseResult parseBraceEnd (const dstring src)
{
    return ParseResult.ok(TokenType.braceEnd, isBraceEnd(src[0]));
}


ParseResult parseCommentLine (const dstring src)
{
    if (!(src.length >= 2 && src[0] == '-' && src[1] == '-'))
        return ParseResult.empty;
    immutable l = lengthUntilIncluding!isNewLine(src);
    return ParseResult.ok(TokenType.commentLine, l ? l - 1 : src.length);
}


ParseResult parseCommentStart (const dstring src)
{
    if (src.length >= 2 && src[0] == '/' && src[1]== '-')
        return ParseResult.ok(TokenType.commentMultiStart, 2, ParseContext.comment);
    return ParseResult.empty;
}


ParseResult parseComment (const dstring src)
{
    size_t l;
    while (true)
    {
        auto l1 = lengthUntilIncluding!(ch => isNewLine(ch) || ch == '-')(src[l .. $]);
        if (!l1)
            return ParseResult.error(TokenType.commentMulti, src.length, ParseContext.comment);
        l = l + l1;
        if (l == src.length || isNewLine(src[l]) || (l + 1 < src.length && src[l + 1] == '/'))
            return ParseResult.ok(TokenType.commentMulti, l, ParseContext.comment);
    }
}


ParseResult parseCommentEnd (const dstring src)
{
    if (src.length >= 2 && src[0] == '-' && src[1]== '/')
        return ParseResult.ok(TokenType.commentMultiEnd, 2, ParseContext.any);
    return ParseResult.empty;
}


ParseResult parseCommentNewLine (const dstring src)
{
    return ParseResult.ok(TokenType.newLine, lengthWhile!isNewLine(src), ParseContext.comment);
}


ParseResult parseNewLine (const dstring src)
{
    return ParseResult.ok(TokenType.newLine, lengthWhile!isNewLine(src));
}


ParseResult parseWhite (const dstring src)
{
    return ParseResult.ok(TokenType.white, lengthWhile!isWhite(src));
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

module tokenizer;

import common, std.array, std.algorithm;



immutable struct Position
{
    size_t line;
    size_t column;
}


const struct Token
{
    TokenType type;
    Position start;
    dstring text;
    bool isError;

    size_t endColumn () @safe @property const
    {
        return start.column + text.length;
    }

    dstring toDebugString () const
    {
        return txt(type, "\t", start.line, ":", start.column, "-", endColumn,
               "(", text.length, ")", "\t", isError ? "Error" : "",
               "\t\"", toVisibleCharsText(text), "\"");
    }

    static dstring toVisibleCharsText (const dstring str) @trusted
    {
        return str
            .replace("\\", "\\\\")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t");
    }
}


    static dstring toInvisibleCharsText (const dstring str) @trusted
    {
        return str
            .replace("\\n", "\n")
            .replace("\\r", "\r")
            .replace("\\t", "\t")
            .replace("\\\\", "\\");
    }


dchar toInvisibleChar (const dchar escape) @safe pure
{
    switch (escape)
    {
        case 'n': return '\n';
        case 'r': return '\r';
        case 't': return '\t';
        default:  return 0;
    }
}


enum TokenType
{
    empty,
    unknown,

    white,
    newLine,

    num,
    text,
    ident,
    op,
    braceStart,
    braceEnd,

    commentLine,
    commentMulti,

    keyIf,
    keyThen,
    keyElse,
    keyFn,
    keyReturn,
    keyGoto,
    keyLabel,
    keyStruct,
}


immutable struct ParseResult
{
    TokenType type;
    size_t length;
    bool isError;

    //@disable this();

    static ParseResult empty () @property @safe pure { return ParseResult(); }

    static ParseResult ok (TokenType tokenType, size_t length) @safe pure
    {
        return ParseResult(tokenType, length);
    }

    static ParseResult error (TokenType tokenType, size_t length) @safe pure
    {
        return ParseResult(tokenType, length, true);
    }
}


final class Tokenizer
{
    size_t pos;
    size_t line;
    size_t column;

    Token[] tokenize (const dstring src) @safe
    {
        Token[] toks;

        if (!src.length)
            return toks;

        next:

        toks ~= parseNextToken (src[pos..$]);

        if (pos < src.length)
            goto next;

        return toks;
    }


    Token parseNextToken (const dstring src) @safe
    in
    {
        assert (src.length);
    }
    body
    {
        auto pr = parseNext(src);
        auto t = Token(pr.type, Position(line, column), src[0 .. pr.length], pr.isError);
        column += pr.length;
        pos += pr.length;
        return t;
    }


    ParseResult parseNext (dstring src) const @safe
    in
    {
        assert (src.length);
    }
    body
    {
        auto errorLength = 0;

        tryAgain:

        foreach (f; [&parseCommentLine, &parseCommentMulti, &parseWhite, &parseNewLine,
                     &parseBraceStart, &parseBraceEnd,
                     &parseIdent, &parseNum, &parseText, &parseChar, &parseOp,
                     ])
        {
            assert (src.length);
            auto pr = f(src);
            if (pr.length)
                return errorLength == 0 ? pr : ParseResult.error(TokenType.unknown, errorLength);
        }

        src = src[1 .. $];
        ++errorLength;

        if (!src.length)
            return ParseResult.error(TokenType.unknown, errorLength);


        goto tryAgain;
    }
}


@safe pure:


ParseResult parseWhite (const dstring src)
{
    return ParseResult.ok(TokenType.white, lengthWhile!isWhite(src));
}


ParseResult parseNewLine (const dstring src)
{
    return ParseResult.ok(TokenType.newLine, lengthWhile!isNewLine(src));
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
    auto pr = parseIdentOrNum!(isIdent, ch => isIdent(ch) || isNum(ch) || isUnderscore(ch))
        (src, TokenType.ident);

    switch (src[0 .. pr.length])
    {
        case "if":     return ParseResult.ok(TokenType.keyIf,     pr.length);
        case "then":   return ParseResult.ok(TokenType.keyThen,   pr.length);
        case "else":   return ParseResult.ok(TokenType.keyElse,   pr.length);
        case "fn":     return ParseResult.ok(TokenType.keyFn,     pr.length);
        case "return": return ParseResult.ok(TokenType.keyReturn, pr.length);
        case "goto":   return ParseResult.ok(TokenType.keyGoto,   pr.length);
        case "label":  return ParseResult.ok(TokenType.keyLabel,  pr.length);
        case "struct": return ParseResult.ok(TokenType.keyStruct, pr.length);
        default:       return pr;
    }
}


ParseResult parseIdentOrNum (alias start, alias rest) (const dstring src, TokenType tokType)
{
    auto l = lengthWhile!isUnderscore(src);
    auto nl = lengthWhile!start(src[l .. $]);
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

    auto l = lengthUntilExcluding!isNewLine(src);
    if (l)
        return ParseResult.ok(TokenType.commentLine, l);
    return ParseResult.ok(TokenType.commentLine, src.length);
}


ParseResult parseCommentMulti (const dstring src) @trusted
{
    if (!(src.length >= 2 && src[0] == '/' && src[1] == '-'))
        return ParseResult.empty;

    if (src.length == 2)
        return ParseResult.error(TokenType.commentMulti, 2);

    size_t l = 2;
    while (true)
    {
        auto lm = lengthUntilIncluding!isMinus(src[l .. $]);
        if (!lm)
            break;
        l = l + lm;
        if (l == src.length)
            break;
        else if (src[l - 1] == '-' && src[l] == '/' && l > 2)
            return ParseResult.ok(TokenType.commentMulti, l + 1);
    }

    auto ln = lengthUntilExcluding!isNewLine(src[l .. $]);
    if (ln)
        return ParseResult.error(TokenType.commentMulti, l + ln);
    return ParseResult.error(TokenType.commentMulti, src.length);
}


ParseResult parseChar (const dstring src)
{
    auto pr = parseTextOrChar!(isSingleQoute, isSingleQouteOrBackSlash)(src);
    if (pr.length > 3)
        return ParseResult.error(TokenType.text, pr.length);
    return pr;
}


ParseResult parseText (const dstring src)
{
    return parseTextOrChar!(isDoubleQoute, isDoubleQouteOrBackSlash)(src);
}


ParseResult parseTextOrChar (alias qoute, alias inQoute) (const dstring src) @trusted
in
{
    assert (src.length);
}
body
{
    if (!qoute(src[0]))
        return ParseResult.empty;
    else if (src.length == 1)
        return ParseResult.error(TokenType.text, 1);

    auto l = lengthUntilIncluding!qoute(src[1 .. $]);
    if (l)
        return ParseResult.ok(TokenType.text, l + 1);

    l = lengthUntilIncluding!isNewLine(src[1 .. $]);
    if (l)
        return ParseResult.error(TokenType.text, l);

    return ParseResult.error(TokenType.text, src.length);
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


size_t lengthUntilExcluding (alias isMatch) (const dstring src)
{
    size_t i = 0;
    while (i < src.length)
    {
        if (isMatch(src[i]))
            return i;
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


bool isStar (const dchar ch)
{
    return ch == '*';
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

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

    static dstring toVisibleCharsText (const dstring str)
    {
        return str
            .replace("\\", "\\\\")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t");
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

        foreach (f; [&parseWhite, &parseNewLine, &parseBraceStart, &parseBraceEnd,
                     &parseIdent, &parseNum, &parseText, &parseChar, &parseOp
                     ])
        {
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
    auto l = goWhileCanFind!isWhite(src);
    return ParseResult.ok(TokenType.white, l);
}


ParseResult parseNewLine (const dstring src)
{
    auto l = goWhileCanFind!isNewLine(src);
    return ParseResult.ok(TokenType.newLine, l);
}


ParseResult parseOp (const dstring src)
{
    auto l = goWhileCanFind!isOp(src);
    return ParseResult.ok(TokenType.op, l);
}


ParseResult parseNum (const dstring src)
{
    return parseIdentOrNum!(isNum, ch => isNum(ch) || isUnderscore(ch))
        (src, TokenType.num);
}


ParseResult parseIdent (const dstring src)
{
    auto pr = parseIdentOrNum!(isIdent, ch => isIdent(ch) || isNum(ch) || isUnderscore(ch))
        (src, TokenType.ident);

    if (pr.length)
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
    return pr;
}


ParseResult parseIdentOrNum (alias start, alias rest) (const dstring src, TokenType tokType)
{
    auto l = goWhileCanFind!isUnderscore(src);
    auto nl = goWhileCanFind!start(src[l .. $]);
    if (!nl)
        return ParseResult.empty;
    l = l + nl;
    if (l)
        l = l + goWhileCanFind!rest(src[l .. $]);
    return ParseResult.ok(tokType, l);
}


ParseResult parseBraceStart (const dstring src)
{
    return isBraceStart(src[0])
        ? ParseResult.ok(TokenType.braceStart, 1)
        : ParseResult.empty;
}


ParseResult parseBraceEnd (const dstring src)
{
    return isBraceEnd(src[0])
        ? ParseResult.ok(TokenType.braceEnd, 1)
        : ParseResult.empty;
}


ParseResult parseChar (const dstring src)
{
    auto pr = parseTextOrChar!(ch => ch == '\'')(src);
    if (pr.length > 3)
        return ParseResult.error(TokenType.text, pr.length);
    return pr;
}


ParseResult parseText (const dstring src)
{
    if ('"' != (src[0]))
        return ParseResult.empty;
    else if (src.length == 1)
        return ParseResult.error(TokenType.text, 1);

    auto l = goUntilIncluding!(ch => '"' == ch || ch == '\\')(src[1 .. $]);
    if (l)
        return ParseResult.ok(TokenType.text, l + 1);

    l = goUntilIncluding!isNewLine(src[1 .. $]);
    if (l)
        return ParseResult.error(TokenType.text, l);

    return ParseResult.error(TokenType.text, src.length);
}


ParseResult parseTextOrChar (alias qoute) (const dstring src)
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

    auto l = goUntilIncluding!(ch => qoute(ch))(src[1 .. $]);
    if (l)
        return ParseResult.ok(TokenType.text, l + 1);

    l = goUntilIncluding!isNewLine(src[1 .. $]);
    if (l)
        return ParseResult.error(TokenType.text, l);

    return ParseResult.error(TokenType.text, src.length);
}


size_t goWhileCanFind (alias isMatch) (const dstring src)
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


size_t goUntilIncluding (alias isMatch) (const dstring src)
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

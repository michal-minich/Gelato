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

    size_t endColumn () @safe @property const
    {
        return start.column + text.length;
    }

    dstring toDebugString () const
    {
        return txt(type, "\t", start.line, ":", start.column, "-", endColumn,
               "(", text.length, ")", "\t\"", toVisibleCharsText(text), "\"");
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
    error,

    white,
    newLine,

    num,

    ident,
}


immutable struct ParseResult
{
    TokenType type;
    size_t length;
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
    {
        assert (src.length);

        auto pr = parseNext(src);
        auto t = Token(pr.type, Position(line, column), src[0 .. pr.length]);
        column += pr.length;
        pos += pr.length;
        return t;
    }


    ParseResult parseNext (const dstring src) const @safe
    {
        assert (src.length);

        auto mySrc = src[0 .. $];

        tryAgain:

        foreach (f; [&parseIdent, &parseWhite, &parseNewLine, &parseNum])
        {
            auto pr = f(mySrc);
            if (pr.length)
                return mySrc.length == src.length
                    ? pr
                    : ParseResult(TokenType.error, src.length - mySrc.length);
        }

        mySrc = mySrc[1 .. $];
        goto tryAgain;
    }
}


@safe:


ParseResult parseWhite (const dstring src)
{
    auto l = goWhileCanFind (src, &isWhite);
    return ParseResult(TokenType.white, l);
}


ParseResult parseNewLine (const dstring src)
{
    auto l = goWhileCanFind (src, &isNewLine);
    return ParseResult(TokenType.newLine, l);
}


ParseResult parseIdent (const dstring src)
{
    auto l = goWhileCanFind (src, &isUnderscore);
    auto il = goWhileCanFind (src[l .. $], &isIdent);
    if (!il)
        return ParseResult(TokenType.empty, 0);
    l = l + il;
    if (l)
        l = l + goWhileCanFind (src[l .. $],
            function (ch) { return isIdent(ch) || isUnderscore(ch) || isNum(ch); } );
    return ParseResult(TokenType.ident, l);
}


ParseResult parseNum (const dstring src)
{
    auto l = goWhileCanFind (src, &isUnderscore);
    auto nl = goWhileCanFind (src[l .. $], &isNum);
    if (!nl)
        return ParseResult(TokenType.empty, 0);
    l = l + nl;
    if (l)
        l = l + goWhileCanFind (src[l .. $],
            function (ch) { return isNum(ch) || isUnderscore(ch); } );
    return ParseResult(TokenType.num, l);
}



alias bool function (const dchar) MemberFn;


size_t goWhileCanFind (const dstring src, const MemberFn isMember)
{
    size_t i = 0;
    while (i < src.length)
    {
        if (!isMember(src[i]))
            return i;
        i++;
    }
    return src.length;
}


bool isOp (const dchar ch)
{
    return ch == '!' ||  ch == '\\' ||  ch == '^' ||  ch == '`' ||  ch == '|' ||  ch == '~'
        || (ch >= '#' && ch <= '\'')
        || (ch >= '*' && ch <= '-') ||  ch == '/'
        || (ch >= ':' && ch <= '@');
}


bool isIdent (const dchar ch)
{
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
}


bool isNum (const dchar ch)
{
    return ch >= '0' && ch <= '9';
}


bool isWhite (const dchar ch)
{
    return ch == ' ' || ch == '\t';
}


bool isUnderscore (const dchar ch)
{
    return ch == '_';
}


bool isNewLine (const dchar ch)
{
    return ch == '\r' || ch == '\n';
}


bool isStar (const dchar ch)
{
    return ch == '*';
}


bool isDot (const dchar ch)
{
    return ch == '.';
}


bool isBraceEnd (const dchar ch)
{
    return ch == ')' || ch == '}' || ch == ']';
}


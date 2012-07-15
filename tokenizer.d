module tokenizer;

import common, std.array, std.algorithm;



struct Position
{
    size_t line;
    size_t column;
}


struct Token
{
    TokenType type;
    Position start;
    dstring text;

    size_t endColumn () @property const
    {
        return start.column + text.length;
    }

    dstring toDebugString ()
    {
        return txt(type, "\t", start.line, ":", start.column, "-", endColumn,
               "(", text.length, ")", "\t\"", toVisibleCharsText(text), "\"");
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


enum TokenType
{
    empty,
    error,

    white,
    newLine,

    num,

    ident,
}


struct ParseResult
{
    TokenType type;
    size_t length;
}


class Tokenizer
{
    size_t pos;
    size_t line;
    size_t column;

    Token[] tokenize (const dstring src)
    {
        Token[] toks;

        next:

        auto t = parseNextToken (src[pos..$]);
        if (t.type == TokenType.empty)
        {
            return toks;
        }
        else
        {
            toks ~= t;
            goto next;
        }
    }


    Token parseNextToken (const dstring src)
    {
        auto pr = parseNext(src);
        if (pr.length)
        {
            auto t = Token(pr.type, Position(line, column), src[0 .. pr.length]);
            column += pr.length;
            pos += pr.length;
            return t;
        }
        else
        {
            return Token(TokenType.empty);
        }
    }


    ParseResult parseNext (const dstring src) const
    {
        foreach (f; [&parseIdent, &parseWhite, &parseNewLine, &parseNum])
        {
            auto pr = f(src);
            if (pr.length)
                return pr;
        }

        return ParseResult(TokenType.error, src.length);
    }
}


ParseResult parseWhite (const dstring src)
{
    auto l = goWhileCanFind (src, &isWhite);
    return ParseResult(TokenType.white, l);
}


ParseResult parseIdent (const dstring src)
{
    auto l = goWhileCanFind (src, &isIdent);
    return ParseResult(TokenType.ident, l);
}


ParseResult parseNewLine (const dstring src)
{
    auto l = goWhileCanFind (src, &isNewLine);
    return ParseResult(TokenType.newLine, l);
}


ParseResult parseNum (const dstring src)
{
    auto l = goWhileCanFind (src, &isNum);
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


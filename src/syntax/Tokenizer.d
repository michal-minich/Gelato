module syntax.Tokenizer;

import syntax.ast;


@safe nothrow:


immutable struct TokenResult
{
    TokenType type;
    size_t length;
    bool isError;
}


private enum TokenResult empty = TokenResult();


private pure TokenResult ok (immutable TokenType tokenType, immutable size_t length)
{
    return TokenResult(tokenType, length);
}


private pure TokenResult error (immutable size_t length)
{
    return TokenResult(TokenType.unknown, length, true);
}


final class Tokenizer
{
    nothrow:

    private dstring src;
    private Token front;
    private uint index;


    this (dstring src) { this.src = src; }


    Token[] tokenize()
    {
        Token[] res;
        while (src.length)
        {
            popFront ();
            res ~= front;
        }
        return res;
    }


    private void popFront ()
    {
        immutable tr = parseNext();

        front = Token(
            index++,
            tr.type,
            front.type == TokenType.newLine
                ? Position (front.start.line + 1, 0)
                : Position (front.start.line, front.start.column + front.text.length),
            src[0 .. tr.length],
            front.pos + front.text.length,
            tr.isError);

        src = src[tr.length .. $];
    }


    pure private TokenResult parseNext ()
    {
        auto errorLength = 0;
        enum parsers = [&parseWhite, &parseIdent, &parseNum, &parseNewLine,
                        &parseBraceStart, &parseBraceEnd,
                        &parseCommentLine, &parseCommentStart, &parseCommentEnd,
                        &parseTextStart, &parseCharStart, &parseTextEscape, 
                        &parseOp];
        auto src2 = src;
        tryAgain:
        foreach (p; parsers)
        {
            immutable tr = p(src2);
            if (tr.length)
                return errorLength == 0 ? tr : error(errorLength);
        }

        src2 = src2[1 .. $];
        ++errorLength;

        if (!src2.length)
            return error(errorLength);

        goto tryAgain;
    }
}


pure:


TokenResult parseCharStart (const dstring src) { return ok(TokenType.quote, src[0] == '\''); }

TokenResult parseTextStart (const dstring src) { return ok(TokenType.quote, src[0] == '"'); }


TokenResult parseTextEscape (const dstring src)
{
    if (src[0] == '\\')
        return src.length >= 2
            ? src[1].isEcapeChar ? ok(TokenType.textEscape, 2) : error(2)
            : error(1);
    return empty;
}


TokenResult parseOp (const dstring src)
{
    if      (src[0] == ',') return ok(TokenType.coma, 1);
    else if (src[0] == ';') return ok(TokenType.op, 1);

    immutable l = src.lengthWhile!isOp;

    if (l == 1)
        switch (src[0])
        {
            case '=': return ok(TokenType.assign, 1);
            case '.': return ok(TokenType.dot, 1);
            case ':': return ok(TokenType.asType, 1);
            case '#': return ok(TokenType.unknown, 1);
            default: break;
        }

    return ok(TokenType.op, l);
}


TokenResult parseNum (const dstring src)
{
    if (src[0] == '#')
    {
        immutable tr = src[1 .. $].parseIdentOrNum!(isHexNum, ch => ch.isHexNum || ch == '_')(TokenType.num);
        return tr.length ? TokenResult(tr.type, tr.length + 1) : empty;
    }

    return src.parseIdentOrNum!(isNum, ch => ch.isNum || ch == '_')(TokenType.num);
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
        case "public": return ok(TokenType.keyPublic, tr.length);
        case "package":return ok(TokenType.keyPackage,tr.length);
        case "module": return ok(TokenType.keyModule, tr.length);

        case "Type":   return ok(TokenType.typeType,  tr.length);
        case "Void":   return ok(TokenType.typeVoid,  tr.length);
        case "Any":    return ok(TokenType.typeAny,   tr.length);
        case "AnyOf":  return ok(TokenType.typeAnyOf, tr.length);
        case "Fn":     return ok(TokenType.typeFn,    tr.length);
        case "Int":    return ok(TokenType.typeInt,   tr.length);
        case "Float":  return ok(TokenType.typeFloat, tr.length);
        case "Text":   return ok(TokenType.typeText,  tr.length);
        case "Char":   return ok(TokenType.typeChar,  tr.length);

        default:       return tr;
    }
}


TokenResult parseIdentOrNum (alias start, alias rest) (const dstring src, TokenType tokType)
{
    auto l = src.lengthWhile!(ch => ch == '_');
    immutable nl = src[l .. $].lengthWhile!start;
    if (!nl)
        return empty;
    l = l + nl;
    if (l)
        l = l + src[l .. $].lengthWhile!rest;
    return ok(tokType, l);
}


TokenResult parseBraceStart (const dstring src) { return ok(TokenType.braceStart, src[0].isBraceStart); }

TokenResult parseBraceEnd (const dstring src) { return ok(TokenType.braceEnd, src[0].isBraceEnd); }

TokenResult parseNewLine (const dstring src) { return ok(TokenType.newLine, src.lengthWhile!isNewLine); }

TokenResult parseWhite (const dstring src) { return ok(TokenType.white, src.lengthWhile!isWhite); }


TokenResult parseCommentLine (const dstring src)
{
    return ok(TokenType.commentLine, src.matchTwo ('-', '-'));
}


TokenResult parseCommentStart (const dstring src)
{
    return ok(TokenType.commentMultiStart, src.matchTwo ('/', '-'));
}


TokenResult parseCommentEnd (const dstring src)
{
    return ok(TokenType.commentMultiEnd, src.matchTwo ('-', '/'));
}


size_t matchTwo (const dstring src, dchar ch1, dchar ch2)
{
    return src.length >= 2 && src[0] == ch1 && src[1] == ch2 ? 2 : 0;
}


@property:


size_t lengthWhile (alias isMatch) (immutable dstring src)
{
    size_t i = 0;
    while (i < src.length && isMatch(src[i])) { i++; }
    return i;
}


bool isWhite (dchar ch) { return ch == ' ' || ch == '\t'; }

bool isNewLine (dchar ch) { return ch == '\r' || ch == '\n'; }

bool isEcapeChar (dchar ch) { return ch == 'r' || ch == 'n' || ch == '\'' || ch == '"'
    || ch == '\\' || ch == '#' || ch == '#' || ch == '&'; }

bool isIdent (dchar ch) { return ch >= 'a' && ch <= 'z' || (ch >= 'A' && ch <= 'Z'); }

bool isBraceStart (dchar ch) { return ch == '(' || ch == '{' || ch == '['; }

bool isBraceEnd (dchar ch) { return ch == ')' || ch == '}' || ch == ']'; }

bool isNum (dchar ch) { return ch >= '0' && ch <= '9'; }

bool isHexNum (dchar ch) { return ch.isNum || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F'); }

bool isOp (dchar ch)
{
    return ch == '!' ||  ch == '\\' ||  ch == '^' ||  ch == '`' ||  ch == '|' ||  ch == '~'
        || (ch >= '#' && ch <= '\'')
        || (ch >= '*' && ch <= '/')
        || (ch >= ':' && ch <= '@');
}
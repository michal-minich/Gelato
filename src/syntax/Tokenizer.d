module syntax.Tokenizer;

import syntax.ast;


@safe nothrow:


immutable struct TokenResult
{
    TokenType type;
    size_t length;
}


private enum TokenResult empty = TokenResult();


private pure TokenResult newTr (immutable TokenType tokenType, immutable size_t length)
{
    return TokenResult(tokenType, length);
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
            front.pos + front.text.length);

        src = src[tr.length .. $];
    }


    pure private TokenResult parseNext ()
    {
        auto unknownLength = 0;
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
                return unknownLength == 0 ? tr : newTr(TokenType.unknown, unknownLength);
        }

        src2 = src2[1 .. $];
        ++unknownLength;

        if (!src2.length)
            return newTr(TokenType.unknown, unknownLength);

        goto tryAgain;
    }
}


pure:


TokenResult parseCharStart (const dstring src) { return newTr(TokenType.quote, src[0] == '\''); }

TokenResult parseTextStart (const dstring src) { return newTr(TokenType.quote, src[0] == '"'); }


TokenResult parseTextEscape (const dstring src)
{
    return src[0] == '\\'
        ? newTr((src[1].isEcapeChar && src.length >= 2) ? TokenType.textEscape : TokenType.error, 1)
        : empty;
}


TokenResult parseOp (const dstring src)
{
    if      (src[0] == ',') return newTr(TokenType.coma, 1);
    else if (src[0] == ';') return newTr(TokenType.op, 1);

    immutable l = src.lengthWhile!isOp;

    if (l == 1)
        switch (src[0])
        {
            case '=': return newTr(TokenType.assign, 1);
            case '.': return newTr(TokenType.dot, 1);
            case ':': return newTr(TokenType.asType, 1);
            case '#': return newTr(TokenType.error, 1);
            default: break;
        }

    return newTr(TokenType.op, l);
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
        case "if":     return newTr(TokenType.keyIf,     tr.length);
        case "then":   return newTr(TokenType.keyThen,   tr.length);
        case "else":   return newTr(TokenType.keyElse,   tr.length);
        case "end":    return newTr(TokenType.keyEnd,    tr.length);
        case "fn":     return newTr(TokenType.keyFn,     tr.length);
        case "return": return newTr(TokenType.keyReturn, tr.length);
        case "goto":   return newTr(TokenType.keyGoto,   tr.length);
        case "label":  return newTr(TokenType.keyLabel,  tr.length);
        case "struct": return newTr(TokenType.keyStruct, tr.length);
        case "throw":  return newTr(TokenType.keyThrow,  tr.length);
        case "var":    return newTr(TokenType.keyVar,    tr.length);
        case "import": return newTr(TokenType.keyImport, tr.length);
        case "public": return newTr(TokenType.keyPublic, tr.length);
        case "package":return newTr(TokenType.keyPackage,tr.length);
        case "module": return newTr(TokenType.keyModule, tr.length);

        case "Type":   return newTr(TokenType.typeType,  tr.length);
        case "Void":   return newTr(TokenType.typeVoid,  tr.length);
        case "Any":    return newTr(TokenType.typeAny,   tr.length);
        case "AnyOf":  return newTr(TokenType.typeAnyOf, tr.length);
        case "Fn":     return newTr(TokenType.typeFn,    tr.length);
        case "Int":    return newTr(TokenType.typeInt,   tr.length);
        case "Float":  return newTr(TokenType.typeFloat, tr.length);
        case "Text":   return newTr(TokenType.typeText,  tr.length);
        case "Char":   return newTr(TokenType.typeChar,  tr.length);

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
    return newTr(tokType, l);
}


TokenResult parseBraceStart (const dstring src) { return newTr(TokenType.braceStart, src[0].isBraceStart); }

TokenResult parseBraceEnd (const dstring src) { return newTr(TokenType.braceEnd, src[0].isBraceEnd); }

TokenResult parseNewLine (const dstring src) { return newTr(TokenType.newLine, src.lengthWhile!isNewLine); }

TokenResult parseWhite (const dstring src) { return newTr(TokenType.white, src.lengthWhile!isWhite); }


TokenResult parseCommentLine (const dstring src)
{
    return newTr(TokenType.commentLine, src.matchTwo ('-', '-'));
}


TokenResult parseCommentStart (const dstring src)
{
    return newTr(TokenType.commentMultiStart, src.matchTwo ('/', '-'));
}


TokenResult parseCommentEnd (const dstring src)
{
    return newTr(TokenType.commentMultiEnd, src.matchTwo ('-', '/'));
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

bool isIdent (dchar ch) { return ch >= 'a' && ch <= 'z' || (ch >= 'A' && ch <= 'Z'); }

bool isBraceStart (dchar ch) { return ch == '(' || ch == '{' || ch == '['; }

bool isBraceEnd (dchar ch) { return ch == ')' || ch == '}' || ch == ']'; }

bool isNum (dchar ch) { return ch >= '0' && ch <= '9'; }

bool isHexNum (dchar ch) { return ch.isNum || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F'); }

bool isEcapeChar (dchar ch)
{ 
    return ch == 'r' || ch == 'n' || ch == '\'' || ch == '"'
        || ch == '\\' || ch == '#' || ch == '&' || ch == 'u' || ch == 'U';
}

bool isOp (dchar ch)
{
    return ch == '!' ||  ch == '\\' ||  ch == '^' ||  ch == '`' ||  ch == '|' ||  ch == '~'
        || (ch >= '#' && ch <= '\'')
        || (ch >= '*' && ch <= '/')
        || (ch >= ':' && ch <= '@');
}
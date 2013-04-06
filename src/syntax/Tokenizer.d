module syntax.Tokenizer;

import syntax.ast;


@safe nothrow:


immutable struct TokenResult { TokenType type; size_t length; }


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
        return res ~ Token(index, TokenType.empty);
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
                return unknownLength == 0 ? tr : TokenResult(TokenType.unknown, unknownLength);
        }

        src2 = src2[1 .. $];
        ++unknownLength;

        if (!src2.length)
            return TokenResult(TokenType.unknown, unknownLength);

        goto tryAgain;
    }
}


private pure:


TokenResult parseOp (const dstring src)
{
    if      (src[0] == ',') return TokenResult(TokenType.coma, 1);
    else if (src[0] == ';') return TokenResult(TokenType.op, 1);

    auto l = src.lengthWhile!(ch => 
        ch == '!' ||  ch == '\\' ||  ch == '^' ||  ch == '`' ||  ch == '|' ||  ch == '~'
        || (ch >= '#' && ch <= '\'')
        || (ch >= '*' && ch <= '/')
        || (ch >= ':' && ch <= '@'));

    if (l > 1)
    {
        for (auto i = 0; i < l - 1; i++)
            if (src[i] == '-' && src[i + 1] == '-')
                l = i;
    }

    if (l == 1)
        switch (src[0])
        {
            case '=': return TokenResult(TokenType.assign, 1);
            case '.': return TokenResult(TokenType.dot, 1);
            case ':': return TokenResult(TokenType.asType, 1);
            case '#': return TokenResult(TokenType.error, 1);
            default: break;
        }

    return TokenResult(TokenType.op, l);
}


TokenResult parseNum (const dstring src)
{
    if (src[0] == '#')
    {
        immutable tr = src[1 .. $].parseIdentOrNum!(
            isHexNum, ch => ch.isHexNum || ch == '_')(TokenType.num);
        return tr.length ? TokenResult(tr.type, tr.length + 1) : TokenResult();
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
        case "if":     return TokenResult(TokenType.keyIf,     tr.length);
        case "then":   return TokenResult(TokenType.keyThen,   tr.length);
        case "else":   return TokenResult(TokenType.keyElse,   tr.length);
        case "end":    return TokenResult(TokenType.keyEnd,    tr.length);
        case "fn":     return TokenResult(TokenType.keyFn,     tr.length);
        case "return": return TokenResult(TokenType.keyReturn, tr.length);
        case "goto":   return TokenResult(TokenType.keyGoto,   tr.length);
        case "label":  return TokenResult(TokenType.keyLabel,  tr.length);
        case "struct": return TokenResult(TokenType.keyStruct, tr.length);
        case "throw":  return TokenResult(TokenType.keyThrow,  tr.length);
        case "var":    return TokenResult(TokenType.keyVar,    tr.length);
        case "import": return TokenResult(TokenType.keyImport, tr.length);
        case "public": return TokenResult(TokenType.keyPublic, tr.length);
        case "package":return TokenResult(TokenType.keyPackage,tr.length);
        case "module": return TokenResult(TokenType.keyModule, tr.length);

        case "Type":   return TokenResult(TokenType.typeType,  tr.length);
        case "Void":   return TokenResult(TokenType.typeVoid,  tr.length);
        case "Any":    return TokenResult(TokenType.typeAny,   tr.length);
        case "AnyOf":  return TokenResult(TokenType.typeAnyOf, tr.length);
        case "Fn":     return TokenResult(TokenType.typeFn,    tr.length);
        case "Int":    return TokenResult(TokenType.typeInt,   tr.length);
        case "Float":  return TokenResult(TokenType.typeFloat, tr.length);
        case "Text":   return TokenResult(TokenType.typeText,  tr.length);
        case "Char":   return TokenResult(TokenType.typeChar,  tr.length);

        default:       return tr;
    }
}


TokenResult parseIdentOrNum (alias start, alias rest) (const dstring src, TokenType tokType)
{
    auto l = src.lengthWhile!(ch => ch == '_');
    immutable nl = src[l .. $].lengthWhile!start;
    if (!nl)
        return TokenResult();
    l = l + nl;
    if (l)
        l = l + src[l .. $].lengthWhile!rest;
    return TokenResult(tokType, l);
}


TokenResult parseTextEscape (const dstring src)
{
    if (src[0] == '\\')
    {
        immutable ch = src[1];
        immutable isEscape = ch == 'r' || ch == 'n' || ch == '\'' || ch == '"'
            || ch == '\\' || ch == '#' || ch == '&' || ch == 'u' || ch == 'U';
        return TokenResult((isEscape && src.length >= 2) ? TokenType.textEscape : TokenType.error, 1);
    }
    return TokenResult();
}


TokenResult parseCharStart (const dstring src) { return TokenResult(TokenType.quote, src[0] == '\''); }

TokenResult parseTextStart (const dstring src) { return TokenResult(TokenType.quote, src[0] == '"'); }


TokenResult parseBraceStart (const dstring src)
{
    return TokenResult(TokenType.braceStart, src[0] == '(' || src[0] == '{' || src[0] == '[');
}


TokenResult parseBraceEnd (const dstring src)
{
    return TokenResult(TokenType.braceEnd, src[0] == ')' || src[0] == '}' || src[0] == ']');
}


TokenResult parseNewLine (const dstring src)
{
    return TokenResult(TokenType.newLine, src.lengthWhile!(ch => ch == '\r' || ch == '\n'));
}


TokenResult parseWhite (const dstring src)
{ 
    return TokenResult(TokenType.white, src.lengthWhile!(ch => ch == ' ' || ch == '\t'));
}


TokenResult parseCommentLine (const dstring src)
{
    return TokenResult(TokenType.commentLine, src.matchTwo ('-', '-'));
}


TokenResult parseCommentStart (const dstring src)
{
    return TokenResult(TokenType.commentMultiStart, src.matchTwo ('/', '-'));
}


TokenResult parseCommentEnd (const dstring src)
{
    return TokenResult(TokenType.commentMultiEnd, src.matchTwo ('-', '/'));
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


bool isIdent (dchar ch) { return ch >= 'a' && ch <= 'z' || (ch >= 'A' && ch <= 'Z'); }

bool isNum (dchar ch) { return ch >= '0' && ch <= '9'; }

bool isHexNum (dchar ch) { return ch.isNum || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F'); }
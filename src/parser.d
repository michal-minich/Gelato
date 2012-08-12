module parser;


import std.stdio, std.algorithm, std.array, std.conv;
import common, tokenizer, ast;


final class Parser
{
    private Token[] toks2;
    private Token[] toks;
    Exp front;


    this (const dstring src)
    {
        toks = (new Tokenizer(src)).array();
        toks2 = toks;
        popFront();
    }


    @property Token current () { return toks.front; }


    @property bool empty () { return !front; }


    void popFront () { front = parse(); }


    Exp parse ()
    {
        if (toks.empty)
            return null;

        switch (current.type)
        {
            case TokenType.newLine: return parseAfterWhite();
            case TokenType.white: return parseAfterWhite();

            case TokenType.num: return parseNum();
            case TokenType.ident: return parseIdent();
            case TokenType.textStart: return parseText();

            case TokenType.braceStart: return parseBrace();
            case TokenType.braceEnd: assert(false, "redudant brace end");

            case TokenType.keyIf: return parserIf();
            case TokenType.keyThen: assert(false, "then without if");
            case TokenType.keyElse: assert(false, "else without if");
            case TokenType.keyEnd: assert(false, "end without if");

            case TokenType.keyFn: return parserFn();
            case TokenType.keyReturn: return parserReturn();

            case TokenType.keyGoto: return parserGoto();
            case TokenType.keyLabel: return parserLabel();

            //case TokenType.keyStruct: return parserStruct();
            //case TokenType.keyThrow: return parserThrow();
            //case TokenType.keyVar: return parserVar();

            case TokenType.unknown: return parseUnknown();
            case TokenType.empty: assert (false, "empty token");
            default: return null;
        }
    }


    void nextTok () { if (!toks.empty) toks.popFront();}


    void skipWhite ()
    {
        while (!toks.empty && (current.type == TokenType.white || current.type == TokenType.newLine))
            nextTok();
    }


    void skipWhiteIfWhite ()
    {
        if (!toks.empty && (current.type == TokenType.white || current.type == TokenType.newLine))
            skipWhite();
    }


    AstIf parserIf ()
    {
        Exp[] ts;
        uint startIndex = current.index;

        nextTok();
        auto w = parse ();

        skipWhite();
        if (current.type == TokenType.keyThen)
        {
            nextTok();
            skipWhite();

            while (current.type != TokenType.keyElse && current.type != TokenType.keyEnd)
            {
                ts ~= parse();
                skipWhite();
            }

            Exp[] es;
            if (current.type == TokenType.keyElse)
            {
                nextTok();
                skipWhite();
                while (current.type != TokenType.keyEnd)
                {
                    es ~= parse();
                    skipWhite();
                }
                nextTok();
            }

            if (current.type == TokenType.keyEnd)
                nextTok();

            const last = es is null ? ts : es;
            return new AstIf (toks2[startIndex ..  last[$ - 1].tokens[$ - 1].index + 1], w, ts, es);
        }
        else
        {
            assert (false, "no then");
        }
    }


    AstFn parserFn ()
    {
        uint startIndex = current.index;
        AstDeclr[] params;

        nextTok();
        skipWhiteIfWhite();
        if (current.type != TokenType.braceStart && current.text != "(")
            assert (false, "no brace after fn");

        nextTok();
        skipWhiteIfWhite();
        if (current.type == TokenType.braceEnd && current.text == ")")
            nextTok();
        else
            params = parseFnParameter();

        skipWhiteIfWhite();
        if (current.type == TokenType.braceStart && current.text == "{")
            nextTok();
        else
            assert (false, "no curly brace after fn");

        Exp[] items;
        skipWhiteIfWhite();
        if (current.type == TokenType.braceEnd && current.text == "}")
        {
        }
        else
        {
            while (current.type != TokenType.braceEnd && current.text != "}")
            {
                items ~= parse();
                skipWhiteIfWhite();
            }
        }

        auto f = new AstFn (toks2[startIndex .. current.index + 1], params, items);
        nextTok();
        return f;
    }


    AstDeclr[] parseFnParameter ()
    {
        AstDeclr[] params;
        while (true)
        {
            auto e = parse();
            auto ident = cast(AstIdent)e;
            if (!ident)
            {
                assert (false, "fn parameter is not identifier");
            }
            else
            {
                skipWhiteIfWhite();
                if (current.type == TokenType.braceEnd && current.text == ")")
                {
                    params ~= new AstDeclr(toks2[current.index .. current.index + 1], ident, null, null);
                    nextTok();
                    return params;
                }
                else if (current.type != TokenType.op && current.text != ",")
                {
                    assert (false, "no fn arg coma");
                }

                params ~= new AstDeclr(toks2[current.index .. current.index + 1], ident, null, null);
                nextTok();
            }
        }
    }


    AstReturn parserReturn ()
    {
        auto startIndex = current.index;
        nextTok();
        auto e = parse();
        if (!e)
            assert (false, "return without expression");
        return new AstReturn (toks2[startIndex .. e.tokens[$ - 1].index + 1], e);
    }


    AstGoto parserGoto ()
    {
        auto startIndex = current.index;
        nextTok();
        skipWhite();
        if (current.type != TokenType.ident)
            assert (false, "goto without identifier");
        auto g = new AstGoto (toks2[startIndex .. current.index + 1], current.text);
        nextTok();
        return g;
    }


    AstLabel parserLabel ()
    {
        auto startIndex = current.index;
        nextTok();
        skipWhite();
        if (current.type != TokenType.ident)
            assert (false, "label without identifier");
        auto l = new AstLabel (toks2[startIndex .. current.index + 1], current.text);
        nextTok();
        return l;
    }


    Exp parseBrace ()
    {
        auto b = current.text[0];

        if (b != '(')
            assert (false, "unsupported brace");

        nextTok();

        if (current.type == TokenType.braceEnd)
            assert (false, "empty braces");

        auto e = parse();

        if (current.type != TokenType.braceEnd || current.text[0] != oppositeBrace(b))
        {
            assert (false, "missing closing brace");
        }
        else if (e is null)
        {
            assert (false, "start brace without expression and unclosed");
        }
        else
        {
            nextTok();
            return e;
        }
    }


    dchar oppositeBrace (dchar brace)
    {
        switch (brace)
        {
            case '(': return ')';
            case '[': return ']';
            case '{': return '}';
            default: assert (false);
        }
    }


    AstText parseText ()
    {
        Token[] ts;
        dstring txt;

        nextTok();

        if (toks.empty)
        {
            assert (false, "unclosed empty text");
        }

        while (current.type != TokenType.textEnd)
        {
            if (toks.empty)
            {
                assert (false, "unclosed text");
                //return new AstText(ts, txt);
            }

            immutable t = current;
            ts ~= t;
            txt ~= t.type == TokenType.textEscape ? t.text.toInvisibleCharsText() : t.text;

            nextTok();
        }

        nextTok();

        return new AstText(ts, txt);
    }


    AstUnknown parseUnknown ()
    {
        auto u = new AstUnknown (toks[0 .. 1]);
        nextTok();
        return u;
    }


    AstNum parseNum ()
    {
        auto n = new AstNum (toks[0 .. 1], current.text);
        nextTok();
        return n;
    }


    Exp parseIdent ()
    {
        auto i = parseIdentOnly ();
        skipWhiteIfWhite();
        if (toks.empty)
            return i;
        else if (current.type == TokenType.braceStart && current.text == "(")
            return parseFnApply(i);
        else if (current.type == TokenType.op && current.text == "=")
            return parseDeclr(i);
        else
            return i;
    }


    AstDeclr parseDeclr (AstIdent i)
    {
        nextTok();
        auto e = parse();
        nextTok();
        return new AstDeclr(toks2[i.tokens[$ - 1].index .. e.tokens[$ - 1].index + 1], i, null, e);
    }


    AstFnApply parseFnApply (AstIdent i)
    {
        nextTok();
        skipWhiteIfWhite();
        if (current.type == TokenType.braceEnd && current.text == ")")
        {
            auto fa = new AstFnApply (toks2[i.tokens[$ - 1].index .. current.index + 1], i, null);
            nextTok();
            return fa;
        }
        else
        {
            Exp[] args;
            while (current.type != TokenType.braceEnd && current.text != ")")
            {
                args ~= parse();
                skipWhiteIfWhite();

                if (current.type == TokenType.op && current.text == ",")
                {
                    nextTok();
                    skipWhiteIfWhite();
                }
                else if (current.type == TokenType.braceEnd && current.text == ")")
                {
                    break;
                }
                else
                {
                    assert (false, "missing comma in fn apply");
                }
            }
            auto fa = new AstFnApply (toks2[i.tokens[$ - 1].index .. current.index + 1], i, args);
            nextTok();
            return fa;
        }
    }


    AstIdent parseIdentOnly ()
    {
        auto i = new AstIdent (toks[0 .. 1], current.text);
        nextTok();
        return i;
    }


    Exp parseAfterWhite ()
    {
        skipWhite();
        return parse();
    }
}
module parser;


import std.stdio, std.algorithm, std.array, std.conv;
import common, remarks, tokenizer, ast;


struct ParseResult
{
    Remark[] remarks;
    Exp value;
}


final class Parser
{
    private Token[] toks2;
    private Token[] toks;
    Exp front;


    this (const dstring src)
    {
        toks = (new Tokenizer(src)).array();
        toks2 = toks;
    }


    Exp[] parseAll ()
    {
        Exp[] res;
        Exp e;
        while ((e = parse()) !is null)
            res ~= e;
        return res;
    }


    Exp parse ()
    {
        if (toks.empty)
            return null;

        switch (toks.front.type)
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
        while (!toks.empty && (toks.front.type == TokenType.white || toks.front.type == TokenType.newLine))
            nextTok();
    }


    void skipWhiteIfWhite ()
    {
        if (!toks.empty && (toks.front.type == TokenType.white || toks.front.type == TokenType.newLine))
            skipWhite();
    }


    AstIf parserIf ()
    {
        Exp[] ts;
        uint startIndex = toks.front.index;

        nextTok();
        auto w = parse ();

        skipWhite();
        if (toks.front.type == TokenType.keyThen)
        {
            nextTok();
            skipWhite();

            while (toks.front.type != TokenType.keyElse && toks.front.type != TokenType.keyEnd)
            {
                ts ~= parse();
                skipWhite();
            }

            Exp[] es;
            if (toks.front.type == TokenType.keyElse)
            {
                nextTok();
                skipWhite();
                while (toks.front.type != TokenType.keyEnd)
                {
                    es ~= parse();
                    skipWhite();
                }
                nextTok();
            }

            if (toks.front.type == TokenType.keyEnd)
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
        uint startIndex = toks.front.index;
        AstDeclr[] params;

        nextTok();
        skipWhiteIfWhite();
        if (toks.front.type != TokenType.braceStart && toks.front.text != "(")
            assert (false, "no brace after fn");

        nextTok();
        skipWhiteIfWhite();
        if (toks.front.type == TokenType.braceEnd && toks.front.text == ")")
            nextTok();
        else
            params = parseFnParameter();

        skipWhiteIfWhite();
        if (toks.front.type == TokenType.braceStart && toks.front.text == "{")
            nextTok();
        else
            assert (false, "no curly brace after fn");

        Exp[] items;
        skipWhiteIfWhite();
        if (toks.front.type == TokenType.braceEnd && toks.front.text == "}")
        {
        }
        else
        {
            while (toks.front.type != TokenType.braceEnd && toks.front.text != "}")
            {
                items ~= parse();
                skipWhiteIfWhite();
            }
        }

        auto f = new AstFn (toks2[startIndex .. toks.front.index + 1], params, items);
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
                if (toks.front.type == TokenType.braceEnd && toks.front.text == ")")
                {
                    params ~= new AstDeclr(toks2[toks.front.index .. toks.front.index + 1], ident, null, null);
                    nextTok();
                    return params;
                }
                else if (toks.front.type != TokenType.op && toks.front.text != ",")
                {
                    assert (false, "no fn arg coma");
                }

                params ~= new AstDeclr(toks2[toks.front.index .. toks.front.index + 1], ident, null, null);
                nextTok();
            }
        }
    }


    AstReturn parserReturn ()
    {
        auto startIndex = toks.front.index;
        nextTok();
        auto e = parse();
        if (!e)
            assert (false, "return without expression");
        return new AstReturn (toks2[startIndex .. e.tokens[$ - 1].index + 1], e);
    }


    AstGoto parserGoto ()
    {
        auto startIndex = toks.front.index;
        nextTok();
        skipWhite();
        if (toks.front.type != TokenType.ident)
            assert (false, "goto without identifier");
        auto g = new AstGoto (toks2[startIndex .. toks.front.index + 1], toks.front.text);
        nextTok();
        return g;
    }


    AstLabel parserLabel ()
    {
        auto startIndex = toks.front.index;
        nextTok();
        skipWhite();
        if (toks.front.type != TokenType.ident)
            assert (false, "label without identifier");
        auto l = new AstLabel (toks2[startIndex .. toks.front.index + 1], toks.front.text);
        nextTok();
        return l;
    }


    Exp parseBrace ()
    {
        auto b = toks.front.text[0];

        if (b != '(')
            assert (false, "unsupported brace");

        nextTok();

        if (toks.front.type == TokenType.braceEnd)
            assert (false, "empty braces");

        auto e = parse();

        if (toks.front.type != TokenType.braceEnd || toks.front.text[0] != oppositeBrace(b))
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

        while (toks.front.type != TokenType.textEnd)
        {
            if (toks.empty)
            {
                assert (false, "unclosed text");
                //return new AstText(ts, txt);
            }

            immutable t = toks.front;
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
        auto n = new AstNum (toks[0 .. 1], toks.front.text);
        nextTok();
        return n;
    }


    Exp parseIdent ()
    {
        auto i = parseIdentOnly ();
        skipWhiteIfWhite();
        if (toks.empty)
            return i;
        else if (toks.front.type == TokenType.braceStart && toks.front.text == "(")
            return parseFnApply(i);
        else if (toks.front.type == TokenType.op && toks.front.text == "=")
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
        if (toks.front.type == TokenType.braceEnd && toks.front.text == ")")
        {
            auto fa = new AstFnApply (toks2[i.tokens[$ - 1].index .. toks.front.index + 1], i, null);
            nextTok();
            return fa;
        }
        else
        {
            Exp[] args;
            while (toks.front.type != TokenType.braceEnd && toks.front.text != ")")
            {
                args ~= parse();
                skipWhiteIfWhite();

                if (toks.front.type == TokenType.op && toks.front.text == ",")
                {
                    nextTok();
                    skipWhiteIfWhite();
                }
                else if (toks.front.type == TokenType.braceEnd && toks.front.text == ")")
                {
                    break;
                }
                else
                {
                    assert (false, "missing comma in fn apply");
                }
            }
            auto fa = new AstFnApply (toks2[i.tokens[$ - 1].index .. toks.front.index + 1], i, args);
            nextTok();
            return fa;
        }
    }


    AstIdent parseIdentOnly ()
    {
        auto i = new AstIdent (toks[0 .. 1], toks.front.text);
        nextTok();
        return i;
    }


    Exp parseAfterWhite ()
    {
        skipWhite();
        return parse();
    }
}
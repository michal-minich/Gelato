module parser;


import std.stdio, std.algorithm, std.array, std.conv;
import common, remarks, validation, tokenizer, ast;


struct ParseResult
{
    Remark[] remarks;
    Exp value;
}


final class Parser
{
    private
    {
        Token[] toks2;
        Token[] toks;
        IValidationContext vctx;
        Token current;
        int prevEndIndex;
    }


    this (IValidationContext valContext, const dstring src)
    {
        vctx = valContext;
        toks = (new Tokenizer(src)).array();
        toks2 = toks;
        current = toks.front;
    }


    Exp[] parseAll ()
    {
        Exp[] res;
        Exp e;
        while ((e = parse()) !is null)
            res ~= e;
        return res;
    }


    private:


    Exp prev;
    T newExp (T) (T exp) if (is (T : Exp))
    {
        if (prev)
            prev.next = exp;
        exp.prev = prev;
        prev = exp;
        return exp;
    }

    E newExp (E, A...) (A args)
    {
        auto ts = toks2[prevEndIndex .. current.index];
        prevEndIndex = current.index;

        auto exp = new E(ts, args);
        exp.prev = prev;
        if (prev)
            prev.next = exp;
        return exp;
    }


    void nextTok ()
    {
        if (!finished) {
            toks.popFront();
            if (!finished)
            current = toks.front;
        }
    }


    @property bool finished () { return toks.empty; }


    @property bool isWhite ()
    {
        return current.type == TokenType.newLine || current.type == TokenType.white;
    }


    void nextNonWhiteTok ()
    {
        nextTok();
        while (!finished && isWhite)
            nextTok();
    }


    void skipWhite ()
    {
        if (!finished && isWhite)
            nextNonWhiteTok();
    }


    Exp parse ()
    {
        if (finished)
            return null;

        if (isWhite)
            nextNonWhiteTok();

        switch (current.type)
        {
            case TokenType.num: return parseNum();
            case TokenType.ident: return parseIdent();
            case TokenType.textStart: return parseText();

            case TokenType.braceStart: return parseBrace();
            case TokenType.braceEnd: assert(false, "redudant brace end");

            case TokenType.keyIf: return parseIf();
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


    AstIf parseIf ()
    {
        Exp[] ts;
        uint startIndex = current.index;
        nextTok();
        auto w = parse ();
        skipWhite();

        if (current.type == TokenType.keyThen)
        {
            nextNonWhiteTok();

            while (current.type != TokenType.keyElse && current.type != TokenType.keyEnd)
            {
                ts ~= parse();
                skipWhite();
            }

            Exp[] es;
            if (current.type == TokenType.keyElse)
            {
                nextNonWhiteTok();

                while (current.type != TokenType.keyEnd)
                {
                    es ~= parse();
                    skipWhite();
                }
            }

            if (finished || current.type != TokenType.keyEnd)
                assert (false, "if without end");

            const last = es is null ? ts : es;
            auto e = newExp!AstIf(w, ts, es);
            nextTok();
            return e;

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

        nextNonWhiteTok();
        if (current.type != TokenType.braceStart && current.text != "(")
            assert (false, "no brace after fn");

        nextNonWhiteTok();
        if (current.type == TokenType.braceEnd && current.text == ")")
            nextTok();
        else
            params = parseFnParameter();

        skipWhite();
        if (current.type == TokenType.braceStart && current.text == "{")
            nextTok();
        else
            assert (false, "no curly brace after fn");

        Exp[] items;
        skipWhite();
        if (current.type == TokenType.braceEnd && current.text == "}")
        {
        }
        else
        {
            while (current.type != TokenType.braceEnd && current.text != "}")
            {
                items ~= parse();
                skipWhite();
            }
        }

        auto f = newExp!AstFn(params, items);
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
                skipWhite();
                if (current.type == TokenType.braceEnd && current.text == ")")
                {
                    params ~= newExp!AstDeclr(ident, null, null);
                    nextTok();
                    return params;
                }
                else if (current.type != TokenType.op && current.text != ",")
                {
                    assert (false, "no fn arg coma");
                }

                params ~= newExp!AstDeclr(ident, null, null);
                nextTok();
            }
        }
    }


    AstReturn parserReturn ()
    {
        nextNonWhiteTok();
        auto e = parse();
        if (!e)
            assert (false, "return without expression");
        return newExp!AstReturn(e);
    }


    AstGoto parserGoto ()
    {
        nextNonWhiteTok();
        if (current.type != TokenType.ident)
            assert (false, "goto without identifier");
        auto g = newExp!AstGoto(current.text);
        nextTok();
        return g;
    }


    AstLabel parserLabel ()
    {
        nextNonWhiteTok();
        if (current.type != TokenType.ident)
            assert (false, "label without identifier");
        auto l = newExp!AstLabel (current.text);
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

        skipWhite();

        if (current.type != TokenType.braceEnd)
        {
            assert (false, "missing closing brace");
        }
        else if (current.text[0] != oppositeBrace(b))
        {
            assert (false, "closing brace does not matches opening");
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


    Exp parseText ()
    {
        Token[] ts;
        dstring txt;

        nextTok();

        if (finished)
        {
            assert (false, "unclosed empty text");
        }

        while (current.type != TokenType.textEnd)
        {
            if (finished)
            {
                assert (false, "unclosed text");
                //return newExp(new AstText(ts, txt));
            }

            immutable t = current;
            ts ~= t;
            txt ~= t.type == TokenType.textEscape ? t.text.toInvisibleCharsText() : t.text;

            nextTok();
        }

        nextTok();

        return newExp(txt.length == 1 && ts[0].text == "'"
            ? new AstChar(ts, txt[0]) : new AstText(ts, txt));
    }


    AstUnknown parseUnknown ()
    {
        auto u = newExp!AstUnknown();
        nextTok();
        return u;
    }


    AstNum parseNum ()
    {
        auto n = newExp!AstNum(current.text);
        nextTok();
        return n;
    }


    Exp parseIdent ()
    {
        auto i = parseIdentOnly ();
        if (current.text == "(")
            return parseFnApply(i);
        else if (current.text == "=")
            return parseDeclr(i);
        else
            return i;
    }


    AstDeclr parseDeclr (AstIdent i)
    {
        nextTok();
        auto val = parse();
        return newExp!AstDeclr(i, null, val);
    }


    AstFnApply parseFnApply (AstIdent i)
    {
        nextNonWhiteTok();
        if (current.type == TokenType.braceEnd && current.text == ")")
        {
            nextTok();
            return newExp!AstFnApply(i, null);
        }
        else
        {
            Exp[] args;
            while (current.text != ")")
            {
                args ~= parse();
                skipWhite();

                if (current.text == ",")
                {
                    nextNonWhiteTok();
                }
                else if (current.text == ")")
                {
                    break;
                }
                else
                {
                    assert (false, "missing comma in fn apply");
                }
            }

            auto fa = newExp!AstFnApply(i, args);
            nextTok();
            return fa;
        }
    }


    AstIdent parseIdentOnly ()
    {
        dstring[] idents;

        while (true)
        {
            idents ~= current.text;
            nextNonWhiteTok();
            if (current.text == ".")
            {
                nextNonWhiteTok();
                if (current.type != TokenType.ident)
                {
                    assert (false, "ident expected after dot");
                }
            }
            else
            {
                break;
            }
        }

        return newExp!AstIdent(idents);
    }
}
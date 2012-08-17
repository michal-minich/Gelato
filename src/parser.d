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
        while ((e = parse(e ? e.parent : null)) !is null)
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


    E newExp (E, A...) (Exp parent, A args)
    {
        auto ts = toks2[prevEndIndex .. current.index];
        prevEndIndex = current.index;

        auto exp = new E(ts, parent, prev, args);
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


    Exp parseSkipWhiteAfter (Exp parent)
    {
        auto e = parse(parent);
        skipWhite();
        return e;
    }


    Exp parse (Exp parent)
    {
        if (finished)
            return null;

        if (isWhite)
            nextNonWhiteTok();

        switch (current.type)
        {
            case TokenType.num: return parseNum(parent);
            case TokenType.ident: return parseIdent(parent);
            case TokenType.textStart: return parseText(parent);

            case TokenType.braceStart: return parseBrace(parent);
            case TokenType.braceEnd: assert(false, "redudant brace end");

            case TokenType.keyIf: return parseIf(parent);
            case TokenType.keyThen: assert(false, "then without if");
            case TokenType.keyElse: assert(false, "else without if");
            case TokenType.keyEnd: assert(false, "end without if");

            case TokenType.keyFn: return parserFn(parent);
            case TokenType.keyReturn: return parserReturn(parent);

            case TokenType.keyGoto: return parserGoto(parent);
            case TokenType.keyLabel: return parserLabel(parent);

            //case TokenType.keyStruct: return parserStruct(parent);
            //case TokenType.keyThrow: return parserThrow(parent);
            //case TokenType.keyVar: return parserVar(parent);

            case TokenType.unknown: return parseUnknown(parent);
            case TokenType.empty: assert (false, "empty token");
            default: return null;
        }
    }


    AstIf parseIf (Exp parent)
    {
        uint startIndex = current.index;
        nextTok();

        auto i = newExp!AstIf(parent);
        i.when = parse(i);
        skipWhite();

        if (current.type == TokenType.keyThen)
        {
            nextNonWhiteTok();


            while (current.type != TokenType.keyElse && current.type != TokenType.keyEnd)
            {
                i.then ~= parse(i);
                skipWhite();
            }

            if (current.type == TokenType.keyElse)
            {
                nextNonWhiteTok();

                while (current.type != TokenType.keyEnd)
                {
                    i.otherwise ~= parse(i);
                    skipWhite();
                }
            }

            if (finished || current.type != TokenType.keyEnd)
                assert (false, "if without end");

            const last = i.otherwise is null ? i.then : i.otherwise;
            nextTok();
            return i;

        }
        else
        {
            assert (false, "no then");
        }
    }


    AstFn parserFn (Exp parent)
    {
        uint startIndex = current.index;

        nextNonWhiteTok();
        if (current.type != TokenType.braceStart && current.text != "(")
            assert (false, "no brace after fn");

        auto f = newExp!AstFn(parent);

        nextNonWhiteTok();
        if (current.type == TokenType.braceEnd && current.text == ")")
            nextTok();
        else
            f.params = parseFnParameter(f);

        skipWhite();
        if (current.type == TokenType.braceStart && current.text == "{")
            nextTok();
        else
            assert (false, "no curly brace after fn");

        skipWhite();
        if (current.type == TokenType.braceEnd && current.text == "}")
        {
        }
        else
        {
            while (current.type != TokenType.braceEnd && current.text != "}")
            {
                auto fni = parse(f);
                if (fni)
                    f.fnItems ~= fni;
                skipWhite();
            }
        }

        nextTok();
        return f;
    }


    AstDeclr[] parseFnParameter (Exp parent)
    {
        AstDeclr[] params;
        while (true)
        {
            auto e = parse(parent);
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
                    params ~= newExp!AstDeclr(parent, ident);
                    nextTok();
                    return params;
                }
                else if (current.type != TokenType.op && current.text != ",")
                {
                    assert (false, "no fn arg coma");
                }

                params ~= newExp!AstDeclr(parent, ident);
                nextTok();
            }
        }
    }


    AstReturn parserReturn (Exp parent)
    {
        nextNonWhiteTok();
        auto r = newExp!AstReturn(parent);
        r.exp = parse(r);
        if (!r.exp)
            assert (false, "return without expression");
        return r;
    }


    AstGoto parserGoto (Exp parent)
    {
        nextNonWhiteTok();
        if (current.type != TokenType.ident)
            assert (false, "goto without identifier");
        auto g = newExp!AstGoto(parent, current.text);
        nextTok();
        return g;
    }


    AstLabel parserLabel (Exp parent)
    {
        nextNonWhiteTok();
        if (current.type != TokenType.ident)
            assert (false, "label without identifier");
        auto l = newExp!AstLabel (parent, current.text);
        nextTok();
        return l;
    }


    Exp parseBrace (Exp parent)
    {
        auto b = current.text[0];

        if (b != '(')
            assert (false, "unsupported brace");

        nextTok();

        if (current.type == TokenType.braceEnd)
            assert (false, "empty braces");

        auto e = parse(parent);

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


    Exp parseText (Exp parent)
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
            ? new AstChar(ts, parent, null, txt[0]) : new AstText(ts, parent, null, txt));
    }


    AstUnknown parseUnknown (Exp parent)
    {
        auto u = newExp!AstUnknown(parent);
        nextTok();
        return u;
    }


    AstNum parseNum (Exp parent)
    {
        auto n = newExp!AstNum(parent, current.text);
        nextTok();
        return n;
    }


    Exp parseIdent (Exp parent)
    {
        auto i = parseIdentOnly (parent);
        if (current.text == "(")
            return parseFnApply(parent, i);
        else if (current.text == "=")
            return parseDeclr(parent, i);
        else
            return i;
    }


    AstDeclr parseDeclr (Exp parent, AstIdent i)
    {
        nextTok();
        auto d = newExp!AstDeclr(parent, i);
        d.value = parse(d);
        return d;
    }


    AstFnApply parseFnApply (Exp parent, AstIdent i)
    {
        nextNonWhiteTok();
        if (current.type == TokenType.braceEnd && current.text == ")")
        {
            nextTok();
            return newExp!AstFnApply(parent, i);
        }
        else
        {
            auto fa = newExp!AstFnApply(parent, i);

            while (current.text != ")")
            {
                fa.args ~= parse(fa);
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

            nextTok();
            return fa;
        }
    }


    AstIdent parseIdentOnly (Exp parent)
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

        return newExp!AstIdent(parent, idents);
    }
}
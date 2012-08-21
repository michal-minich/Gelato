module parse.parser;


import std.algorithm, std.array, std.conv;
import common, validate.remarks, parse.ast;


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
    }


    this (IValidationContext valContext, Token[] tokens)
    {
        vctx = valContext;
        toks = tokens;
        toks2 = tokens;
        current = toks.front;
    }


    AstFile parseAll ()
    {
        auto f = new AstFile;
        Exp e;
        while ((e = parse(f)) !is null)
            f.exps ~= e;
        return f;
    }


    private:


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


    void nextNonWhiteTokOnSameLine ()
    {
        nextTok();
        while (!finished && current.type == TokenType.white)
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
        auto startIndex = current.index;
        auto e = parse2(parent);
        if (e)
            e.tokens = toks2[startIndex .. current.index];
        return e;
    }


    Exp parse2 (Exp parent)
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

            case TokenType.keyStruct: return parserStruct(parent);
            //case TokenType.keyThrow: return parserThrow(parent);
            //case TokenType.keyVar: return parserVar(parent);

            case TokenType.unknown: return parseUnknown(parent);
            case TokenType.empty: assert (false, "empty token");

            case TokenType.typeType: return parseTypeType(parent);
            case TokenType.typeAny: return parseTypeAny(parent);
            case TokenType.typeVoid: return parseTypeVoid(parent);
            case TokenType.typeOr: return parseTypeOr(parent);
            case TokenType.typeFn: return parseTypeFn(parent);
            case TokenType.typeNum: return parseTypeNum(parent);
            case TokenType.typeText: return parseTypeText(parent);
            case TokenType.typeChar: return parseTypeChar(parent);

            default: return null;
        }
    }


    TypeType  parseTypeType (Exp parent)
    {
        auto tt = new TypeType(parent, null);

        nextNonWhiteTok();
        if (current.text != "(")
            assert (false, " type type (");

        tt.type = parse(tt);

        return tt;
    }


    TypeAny  parseTypeAny (Exp parent)
    {
        nextTok();
        return new TypeAny(parent);
    }


    TypeVoid parseTypeVoid (Exp parent)
    {
        nextTok();
        return new TypeVoid(parent);
    }


    TypeOr parseTypeOr (Exp parent)
    {
        nextNonWhiteTok();
        auto fna = parseFnApply(parent, null);
        return new TypeOr(parent, fna.args);
    }


    TypeFn parseTypeFn (Exp parent)
    {
        nextNonWhiteTok();
        auto fna = parseFnApply(parent, null);
        return new TypeFn(parent, fna.args[0.. $ - 1], fna.args[0]);
    }


    TypeNum parseTypeNum (Exp parent)
    {
        nextTok();
        return new TypeNum(parent);
    }


    TypeText parseTypeText (Exp parent)
    {
        nextTok();
        auto t = new TypeText(parent);
        nextTok();
        return t;
    }


    TypeChar parseTypeChar (Exp parent)
    {
        nextTok();
        return new TypeChar(parent);
    }


    AstIf parseIf (Exp parent)
    {
        uint startIndex = current.index;
        nextTok();

        auto i = new AstIf(parent);
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


    AstStruct parserStruct (Exp parent)
    {
        auto s = new AstStruct(parent);
        s.exps = parseCurlyBrace(s);
        return s;
    }


    AstFn parserFn (Exp parent)
    {
        uint startIndex = current.index;

        nextNonWhiteTok();
        if (current.text != "(")
            assert (false, "no brace after fn");

        auto f = new AstFn(parent);

        nextNonWhiteTok();
        if (current.text != ")")
            f.params = parseFnParameter(f);

        f.exps = parseCurlyBrace (f);
        return f;
    }


    Exp[] parseCurlyBrace (Exp parent)
    {
        nextNonWhiteTok();
        if (current.text == "{")
            nextNonWhiteTok();
        else
            assert (false, "expected curly brace");

        if (current.text == "}")
        {
            nextTok();
            return null;
        }
        else
        {
            Exp[] items;
            while (current.text != "}")
            {
                auto e = parse(parent);
                if (!e)
                    break;
                items ~= e;
                skipWhite();
            }
            nextTok();
            return items;
        }
    }


    AstDeclr[] parseFnParameter (Exp parent)
    {
        AstDeclr[] params;
        while (true)
        {
            auto e = parse(parent);
            auto i = cast(AstIdent)e;
            auto d = cast(AstDeclr)e;
            if (!i && !d)
            {
                assert (false, "fn parameter is not identifier or declaration");
            }
            else
            {
                skipWhite();
                if (current.type == TokenType.braceEnd && current.text == ")")
                {
                    params ~= d ? d : new AstDeclr(parent, i);
                    nextTok();
                    return params;
                }
                else if (current.type != TokenType.op && current.text != ",")
                {
                    assert (false, "no fn arg coma");
                }

                params ~= d ? d : new AstDeclr(parent, i);
                nextTok();
            }
        }
    }


    AstReturn parserReturn (Exp parent)
    {
        nextNonWhiteTokOnSameLine();
        auto r = new AstReturn(parent);
        r.exp = parse(r);
        if (!r.exp)
            assert (false, "return without expression");
        return r;
    }


    AstGoto parserGoto (Exp parent)
    {
        nextNonWhiteTokOnSameLine();
        if (current.type == TokenType.ident)
        {
            auto g = new AstGoto(parent, current.text);
            nextTok();
            return g;
        }
        else
        {
            auto gt = new AstGoto(parent, null);
            vctx.remark(GotoWithoutIdentifier(gt));
            return gt;
        }
    }


    AstLabel parserLabel (Exp parent)
    {
        nextNonWhiteTokOnSameLine();
        if (current.type == TokenType.ident)
        {
            auto l = new AstLabel (parent, current.text);
            nextTok();
            return l;
        }
        else
        {
            auto l = new AstLabel (parent, null);
            vctx.remark(LabelWithoutIdentifier(l));
            return l;
        }
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

        ts ~= current;

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
                //return new AstText(ts, txt);
            }

            alias current t;
            ts ~= current;
            txt ~= t.type == TokenType.textEscape ? t.text.toInvisibleCharsText() : t.text;

            nextTok();
        }

        nextTok();

        auto t = txt.length == 1 && ts[0].text == "'"
            ? new AstChar(parent, txt[0]) : new AstText(parent, txt);
        t.tokens = ts;
        return t;
    }


    AstUnknown parseUnknown (Exp parent)
    {
        auto u = new AstUnknown(parent);
        nextTok();
        return u;
    }


    AstNum parseNum (Exp parent)
    {
        auto n = new AstNum(parent, current.text);
        nextTok();
        return n;
    }


    Exp parseIdent (Exp parent)
    {
        auto i = parseIdentOnly (parent);
        AstDeclr d;

        if (current.text == "(")
        {
            return parseFnApply(parent, i);
        }
        else if (current.text == ":")
        {
            d = new AstDeclr(parent, i);
            i.parent = d;
            nextTok();
            d.type = parse(d);
        }

        skipWhite();
        if (current.text == "=")
        {
            if (!d)
                d = new AstDeclr(parent, i);
            i.parent = d;
            nextTok();
            d.value = parse(d);
            return d;
        }

        return d ? d: i;
    }


    AstFnApply parseFnApply (Exp parent, AstIdent i)
    {
        nextNonWhiteTok();
        if (current.type == TokenType.braceEnd && current.text == ")")
        {
            nextTok();
            return new AstFnApply(parent, i);
        }
        else
        {
            auto fa = new AstFnApply(parent, i);

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

        return new AstIdent(parent, idents);
    }
}
module parse.parser;


import std.algorithm, std.array, std.conv;
import common, validate.remarks, parse.ast;


nothrow:


final class Parser
{
    private
    {
        Token[] toks2;
        Token[] toks;
        IValidationContext vctx;
        Token current;
        bool sepPassed;
    }


    this (IValidationContext valContext, Token[] tokens)
    {
        vctx = valContext;
        toks = tokens;
        toks2 = tokens;
        current = toks.front;
    }


    ValueFile parseAll ()
    {
        auto f = new ValueFile;
        Exp e;
        skipWhite();
        while ((e = parse(f)) !is null)
            f.exps ~= e;
        return f;
    }


    private:


    void nextTok ()
    {
        if (!finished)
        {
            toks.popFront();
            if (!finished)
            current = toks.front;
        }
    }


    @property const bool finished () { return !toks.length; }


    @property const bool isWhite ()
    {
        return current.type == TokenType.newLine || current.type == TokenType.white;
    }


    void nextNonWhiteTok ()
    {
        nextTok();
        skipWhite();
    }


    void skipWhite ()
    {
        sepPassed = false;
        while(!finished)
        {
            switch (current.type)
            {
                case TokenType.white: nextTok(); continue;
                case TokenType.newLine: sepPassed = true; nextTok(); continue;
                case TokenType.coma: sepPassed = true; nextTok(); continue;
                default: return;
            }
        }
    }


    void nextNonWhiteTokOnSameLine ()
    {
        nextTok();
        while (!finished && current.type == TokenType.white)
            nextTok();
    }


    bool skipSep ()
    {
        while(!finished)
        {
            switch (current.type)
            {
                case TokenType.newLine: goto end;
                case TokenType.coma: goto end;
                case TokenType.white: nextTok(); break;
                default: return false;
            }
        }

        end:
        nextNonWhiteTok();
        return true;
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

        skipSep();

        Exp exp;
        switch (current.type)
        {
            case TokenType.num: exp = parseNum(parent); break;
            case TokenType.ident: exp = parseIdentOrDeclr(parent); break;
            case TokenType.textStart: exp = parseText(parent); break;

            case TokenType.braceEnd: assert(false, "redudant brace end");

            case TokenType.keyIf: exp = parseIf(parent); break;
            case TokenType.keyThen: assert(false, "then without if");
            case TokenType.keyElse: assert(false, "else without if");
            case TokenType.keyEnd: assert(false, "end without if");

            case TokenType.keyFn: exp = parserFn(parent); break;
            case TokenType.keyReturn: exp = parserReturn(parent); break;

            case TokenType.keyGoto: exp = parserGoto(parent); break;
            case TokenType.keyLabel: exp = parserLabel(parent); break;

            case TokenType.keyStruct: exp = parserStruct(parent); break;
            //case TokenType.keyThrow: exp = parserThrow(parent); break;
            //case TokenType.keyVar: exp = parserVar(parent); break;

            case TokenType.unknown: exp = parseUnknown(parent); break;
            case TokenType.empty: assert (false, "empty token");

            case TokenType.typeType: exp = parseTypeType(parent); break;
            case TokenType.typeAny: exp = parseTypeAny(parent); break;
            case TokenType.typeVoid: exp = parseTypeVoid(parent); break;
            case TokenType.typeOr: exp = parseTypeOr(parent); break;
            case TokenType.typeFn: exp = parseTypeFn(parent); break;
            case TokenType.typeNum: exp = parseTypeNum(parent); break;
            case TokenType.typeText: exp = parseTypeText(parent); break;
            case TokenType.typeChar: exp = parseTypeChar(parent); break;

            default: break;
        }

        sepPassed = skipSep() || sepPassed;

        while (current.type == TokenType.braceStart)
            exp = new ExpFnApply(parent, exp, parseBracedExpList(parent));

        return exp;
    }


    Exp[] parseBracedExpList (Exp parent)
    {
        Exp[] list;
        immutable opposite = oppositeBrace(current.text);
        nextNonWhiteTok();
        while (current.text != opposite)
        {
            auto e = parse(parent);
            if (!e)
            {
                vctx.remark(textRemark("reached end of file and close brace not found"));
                return list;
            }

            list ~= e;

            if (current.type == TokenType.braceEnd)
            {
                if (current.text != opposite)
                    vctx.remark(textRemark("end brace does not match start brace"));

                break;
            }
            else if (!sepPassed)
            {
                vctx.remark(textRemark("missing comma or new line to separeate expressions"));
            }
        }

        nextNonWhiteTok();
        return list;
    }


    dstring oppositeBrace (dstring brace)
    {
        switch (brace)
        {
            case "(": return ")";
            case "[": return "]";
            case "{": return "}";
            default: assert (false, "bad brace '" ~ brace.to!string() ~ "'");
        }
    }


    TypeAny parseTypeAny (Exp parent)
    {
        nextTok();
        return new TypeAny(parent);
    }


    TypeVoid parseTypeVoid (Exp parent)
    {
        nextTok();
        return new TypeVoid(parent);
    }


    TypeNum parseTypeNum (Exp parent)
    {
        nextTok();
        return new TypeNum(parent);
    }


    TypeChar parseTypeChar (Exp parent)
    {
        nextTok();
        return new TypeChar(parent);
    }


    TypeType parseTypeType (Exp parent)
    {
        nextNonWhiteTok();
        auto types = parseBracedExpList(parent);
        if (types.length != 1)
            vctx.remark(textRemark("Type takes one argument"));
        return new TypeType(parent, types[0]);
    }


    TypeOr parseTypeOr (Exp parent)
    {
        nextNonWhiteTok();
        auto types = parseBracedExpList(parent);
        return new TypeOr(parent, types);
    }


    TypeFn parseTypeFn (Exp parent)
    {
        nextNonWhiteTok();
        auto types = parseBracedExpList(parent);
        return new TypeFn(parent, types[0.. $ - 1], types[0]);
    }

    TypeText parseTypeText (Exp parent)
    {
        nextTok();
        auto t = new TypeText(parent);
        nextTok();
        return t;
    }


    ExpIf parseIf (Exp parent)
    {
        uint startIndex = current.index;
        nextTok();

        auto i = new ExpIf(parent);
        i.when = parse(i);

        if (current.type == TokenType.keyThen)
        {
            nextNonWhiteTok();


            while (current.type != TokenType.keyElse && current.type != TokenType.keyEnd)
            {
                i.then ~= parse(i);
            }

            if (current.type == TokenType.keyElse)
            {
                nextNonWhiteTok();

                while (current.type != TokenType.keyEnd)
                {
                    i.otherwise ~= parse(i);
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


    ValueStruct parserStruct (Exp parent)
    {
        auto s = new ValueStruct(parent);
        s.exps = parseBracedExpList(s);
        return s;
    }


    Exp parserFn (Exp parent)
    {
        auto f = new ValueFn(parent);
        nextNonWhiteTok();

        foreach (p; parseBracedExpList(f))
        {
            auto d = cast(StmDeclr)p;
            if (d)
            {
                f.params ~= d;
                continue;
            }

            auto i = cast(ExpIdent)p;
            if (i)
            {
                f.params ~= new StmDeclr(f, i);
                continue;
            }

            vctx.remark(textRemark("fn parameter is not identifer or declration"));
        }

        f.exps = parseBracedExpList (f);

        return f;
    }


    StmReturn parserReturn (Exp parent)
    {
        nextNonWhiteTokOnSameLine();
        auto r = new StmReturn(parent);
        r.exp = parse(r);
        if (!r.exp)
            vctx.remark(textRemark("return without expression"));
        return r;
    }


    StmGoto parserGoto (Exp parent)
    {
        nextNonWhiteTokOnSameLine();
        if (current.type == TokenType.ident)
        {
            auto g = new StmGoto(parent, current.text);
            nextTok();
            return g;
        }
        else
        {
            auto gt = new StmGoto(parent, null);
            vctx.remark(GotoWithoutIdentifier(gt));
            return gt;
        }
    }


    StmLabel parserLabel (Exp parent)
    {
        nextNonWhiteTokOnSameLine();
        if (current.type == TokenType.ident)
        {
            auto l = new StmLabel (parent, current.text);
            nextTok();
            return l;
        }
        else
        {
            auto l = new StmLabel (parent, null);
            vctx.remark(LabelWithoutIdentifier(l));
            return l;
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
                //return new ValueText(ts, txt);
            }

            alias current t;
            ts ~= current;
            txt ~= t.type == TokenType.textEscape ? t.text.toInvisibleCharsText() : t.text;

            nextTok();
        }

        nextTok();

        auto t = txt.length == 1 && ts[0].text == "'"
            ? new ValueChar(parent, txt[0]) : new ValueText(parent, txt);
        t.tokens = ts;
        return t;
    }


    AstUnknown parseUnknown (Exp parent)
    {
        auto u = new AstUnknown(parent);
        nextTok();
        return u;
    }


    ValueNum parseNum (Exp parent)
    {
        auto n = new ValueNum(parent, current.text.to!long());
        nextTok();
        return n;
    }


    Exp parseIdentOrDeclr (Exp parent)
    {
        auto exp = parseIdentOrOpDot (parent);
        auto i = cast(ExpIdent)exp;
        StmDeclr d;

        if (i && current.text == ":")
        {
            d = new StmDeclr(parent, i);
            i.parent = d;
            nextTok();
            d.type = parse(d);
        }
        if (i && current.text == "=") // on assigment i is not required
        {
            if (!d)
                d = new StmDeclr(parent, i); // it could be also assignment
            i.parent = d;
            nextTok();
            d.value = parse(d);
            return d;
        }

        return d ? d: i;
    }


    Exp parseIdentOrOpDot (Exp parent)
    {
        Exp res = new ExpIdent(parent, current.text);

        while (true)
        {
            nextNonWhiteTok();
            if (current.type != TokenType.dot)
                break;

            auto d = new ExpDot(parent, res, null);
            res = d;
            nextNonWhiteTok();
            if (current.type != TokenType.ident)
                assert (false, "ident expected after dot");
            d.member = current.text;
        }

        return res;
    }
}
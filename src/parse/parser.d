module parse.parser;


import std.array, std.conv;
import common, validate.remarks, ast;


@safe nothrow:


final class Parser
{
    private
    {
        Token[] toks2;
        Token[] toks;
        IValidationContext vctx;
        Token current;
        bool sepPassed;
        Comment comment;
        Stack!dchar braceStack;
    }


    this (IValidationContext valContext, Token[] tokens)
    {
        vctx = valContext;
        toks = tokens;
        toks2 = tokens;
        braceStack = new Stack!dchar;
        if (toks.length)
            current = toks.front;
    }


    ValueStruct parseAll ()
    {
        auto s = new ValueStruct(null);
        s.tokens = toks2;
        Exp e;
        skipWhite();
        while ((e = parse(s)) !is null)
            s.exps ~= e;
        return s;
    }


    private:


    @property const bool isWhite ()
    {
        return current.type == TokenType.newLine || current.type == TokenType.white;
    }


    void nextTok ()
    {
        if (toks.length)
        {
            toks.popFront();
            if (toks.length)
                current = toks.front;
        }
    }


    void nextNonWhiteTok ()
    {
        nextTok();
        skipWhite();
    }


    void skipWhite ()
    {
        sepPassed = false;
        while(toks.length)
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
        while (toks.length && current.type == TokenType.white)
            nextTok();
    }


    bool skipSep ()
    {
        while(toks.length)
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


    @trusted Exp parse (ValueScope parent)
    {
        next:
        skipComment:

        auto startIndex = current.index;
        if (!toks.length)
            return null;

        skipSep();

        Exp exp;
        switch (current.type)
        {
            case TokenType.num: exp = parseNum(parent); break;
            case TokenType.ident: exp = parseIdentOrAssign(parent); break;
            case TokenType.quote: exp = parseText(parent); break;

            case TokenType.braceEnd: handleBraceEnd(); goto next;

            case TokenType.keyIf: exp = parseIf(parent); break;
            case TokenType.keyThen: assert(false, "then without if");
            case TokenType.keyElse: assert(false, "else without if");
            case TokenType.keyEnd: assert(false, "end without if");

            case TokenType.keyFn: exp = parserFn(parent); break;
            case TokenType.keyReturn: exp = parserReturn(parent); break;

            case TokenType.keyGoto: exp = parserGoto(parent); break;
            case TokenType.keyLabel: exp = parserLabel(parent); break;

            case TokenType.keyStruct: exp = parseStruct(parent); break;
            //case TokenType.keyThrow: exp = parserThrow(parent); break;
            case TokenType.keyVar: exp = parseVar(parent); break;

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

            case TokenType.braceStart: exp = parseBracedExp(parent); break;

            case TokenType.commentLine: comment = parseCommentLine(parent); break;
            case TokenType.commentMultiStart: comment = parseCommentMulti(parent); break;

            default: assert (false, "parsing of this token type not implemented yet - " ~ text(current.type));
        }

        if (comment)
        {
            comment = null;
            goto skipComment;
        }

        typeof(current.index) prevIndex;

        do
        {
            prevIndex = current.index;

            sepPassed = skipSep() || sepPassed;

            if (exp)
                exp.tokens = toks2[startIndex .. current.index + 1];

            while (current.type == TokenType.braceStart)
                exp = new ExpFnApply(parent, exp, parseBracedExpList(parent));

            if (current.type == TokenType.op)
                exp = parseOp(parent, exp);

            if (current.type == TokenType.dot)
                exp = parseOpDot(parent, exp);

        } while (prevIndex != current.index);

        if (exp)
            exp.tokens = toks2[startIndex .. current.index + 1];

        return exp;
    }


    void handleBraceEnd ()
    {
        nextTok();
        vctx.remark(textRemark("redundant close brace"));
    }


    Exp parseVar (ValueScope parent)
    {
        nextTok();
        auto e = parse (parent);
        auto a = cast(ExpAssign)e;
        if (a)
        {
            return a;
        }
        else
        {
            vctx.remark(textRemark("var can be only used before declaration"));
            return e;
        }
    }


    Comment parseCommentLine (ValueScope parent)
    {
        auto c = new Comment;
        while (!(current.type == TokenType.newLine || current.type == TokenType.empty))
        {
            nextTok();
        }
        nextTok();
        return c;
    }


    Comment parseCommentMulti (ValueScope parent)
    {
        auto c = new Comment;
        while (current.type != TokenType.commentMultiEnd)
        {
            if (current.type == TokenType.empty)
            {
                vctx.remark(textRemark("unclosed multiline comment"));
                break;
            }

            nextTok();
        }
        nextTok();
        return c;
    }


    ExpDot parseOpDot (ValueScope parent, Exp operand1)
    {
        nextNonWhiteTok();

        if (current.type != TokenType.ident)
        {
            vctx.remark(textRemark("second operand must be identifier"));
            return new ExpDot(parent, operand1, new ExpIdent(parent, "<missing identifier>"));
        }

        auto dot = new ExpDot(parent, operand1, new ExpIdent(parent, current.text));
        // parent of exp ident should be value scope of operand 1, but oprerand1 is of arbitrary expression ...
        nextNonWhiteTok();
        return dot;
    }


    ExpFnApply parseOp (ValueScope parent, Exp operand1)
    {
        auto op = new ExpIdent(parent, current.text);
        op.tokens = [current];
        nextNonWhiteTok();
        auto operand2 = parse(parent);

        if (!operand2)
        {
            vctx.remark(textRemark("second operand is missing"));
            operand2 = new ValueUnknown(parent);
        }

        auto fna = new ExpFnApply(parent, op, [operand1, operand2]);
        return fna;
    }


    Exp parseBracedExp (ValueScope parent)
    {
        braceStack.push(current.text[0]);

        if (current.text[0] == '(')
        {
            auto exps = parseBracedExpList (parent);
            if (exps.length > 1)
                vctx.remark(textRemark("only one exp can be braced ()"));
            return exps[0];
        }
        else if (current.text[0] == '[')
        {
            auto op = new ExpIdent(parent, current.text);
            op.tokens = [current];
            auto exps = parseBracedExpList (parent);
            auto fna = new ExpFnApply(parent, op, exps);
            return fna;
        }
        else
        {
            vctx.remark(textRemark("unsupported brace op apply"));
            return new ValueUnknown(parent);
        }
    }


    Exp[] parseBracedExpList (ValueScope parent)
    {
        braceStack.push(current.text[0]);

        Exp[] list;
        immutable opposite = oppositeBrace(current.text);
        nextNonWhiteTok();
        while (current.text != opposite)
        {   
            if (!toks.length)
            {
                vctx.remark(textRemark("reached end of file and close brace not found"));
                return list;
            }

            auto e = parse(parent);
            list ~= e;

            if (current.type == TokenType.braceEnd)
            {
                if (current.text != opposite)
                    vctx.remark(textRemark("end brace does not match start brace"));
            }
            else if (!sepPassed)
            {
                vctx.remark(textRemark("missing comma or new line to separate expressions"));
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
            default: assert (false, "bad brace '" ~ brace.toString() ~ "'");
        }
    }


    ExpIf parseIf (ValueScope parent)
    {
        auto i = new ExpIf(parent);
        nextNonWhiteTok();
        i.when = parse(parent);

        if (current.type != TokenType.keyThen)
             vctx.remark(textRemark("missing 'then' after if"));
        
        nextNonWhiteTok();

        while (toks.length && current.type != TokenType.keyElse && current.type != TokenType.keyEnd)
            i.then ~= parse(parent);

        if (!i.then.length)
            i.then ~= new ValueUnknown(parent);

        if (current.type == TokenType.keyElse)
        {
            nextNonWhiteTok();

            while (toks.length && current.type != TokenType.keyEnd)
                i.otherwise ~= parse(parent);

            if (!i.otherwise.length)
                i.otherwise ~= new ValueUnknown(parent);
        }

        if (!toks.length)
            vctx.remark(textRemark("if without 'end'"));

        nextNonWhiteTok();
        return i;
    }


    ValueStruct parseStruct (ValueScope parent)
    {
        auto s = new ValueStruct(parent);
        nextNonWhiteTok();
        s.exps = parseBracedExpList(s);
        return s;
    }


    Exp parserFn (ValueScope parent)
    {
        auto f = new ValueFn(parent);
        nextNonWhiteTok();

        foreach (ix, p; parseBracedExpList(f))
        {
            auto d = cast(ExpAssign)p;
            if (!d)
            {
                auto i = cast(ExpIdent)p;
                if (i)
                    d = new ExpAssign(f, i, null);
            }

            if (d)
            {
                d.paramIndex = ix;
                f.params ~= d;
            }
            else
            {
                vctx.remark(textRemark("fn parameter is not identifier or declaration"));
            }
        }

        f.exps = parseBracedExpList (f);

        return f;
    }


    StmReturn parserReturn (ValueScope parent)
    {
        nextNonWhiteTokOnSameLine();
        return new StmReturn(parent, (toks.length && current.type != TokenType.newLine) ? parse(parent) : null);
    }


    StmGoto parserGoto (ValueScope parent)
    {
        nextNonWhiteTokOnSameLine();
        if (current.type != TokenType.ident)
            return new StmGoto(parent, null);
        
        auto g = new StmGoto(parent, current.text);
        nextTok();
        return g;
    }


    StmLabel parserLabel (ValueScope parent)
    {
        nextNonWhiteTokOnSameLine();
        if (current.type != TokenType.ident)
            return new StmLabel (parent, null);

        auto l = new StmLabel (parent, current.text);
        nextTok();
        return l;
    }


    Exp parseText (ValueScope parent)
    {
        Token[] ts;
        dstring txt;
        dchar startQoute = current.text[0];

        while (true)
        {
            ts ~= current;
            nextTok();

            if (!toks.length)
                break;

            if (current.type == TokenType.quote && current.text[0] == startQoute)
            {
                ts ~= current;
                nextNonWhiteTok();
                break;
            }

            txt ~= current.type == TokenType.textEscape 
                ? current.text.toInvisibleCharsText() 
                : current.text;
        }

        Exp t;

        if (ts[0].text == "'" && (ts.length == 1 || ((ts.length == 2 || (ts.length == 3 && ts[2].text == "'")) && txt.length == 1)))
            t = new ValueChar(parent, txt.length ? txt[0] : 255 /* TODO - should be invalid utf32 char*/);
        else
            t = new ValueText(parent, txt);

        t.tokens = ts;

        return t;
    }


    ValueUnknown parseUnknown (ValueScope parent)
    {
        nextTok();
        return new ValueUnknown(parent);
    }


    @trusted ValueNum parseNum (ValueScope parent)
    {
        immutable s = current.text.replace("_", "");
        auto n = new ValueNum(parent, s[0] == '#' ? s[1 .. $].to!long(16) : s.to!long());
        nextNonWhiteTok();
        return n;
    }


    Exp parseIdentOrAssign (ValueScope parent)
    {
        auto e = new ExpIdent(parent, current.text);
        nextNonWhiteTok();
        ExpAssign d;

        if (current.type == TokenType.asType)
        {
            d = new ExpAssign(parent, e, null);
            nextNonWhiteTok();
            d.type = parse(parent);
        }

        if (current.type == TokenType.assign)
        {
            if (!d)
                d = new ExpAssign(parent, e, null);
            nextTok();
            d.expValue = parse(parent);
            d.value = d.expValue;
        }

        return d ? d : e;
    }


    TypeAny parseTypeAny (ValueScope parent)
    {
        nextTok();
        return new TypeAny(parent);
    }


    TypeVoid parseTypeVoid (ValueScope parent)
    {
        nextTok();
        return new TypeVoid(parent);
    }


    TypeNum parseTypeNum (ValueScope parent)
    {
        nextTok();
        return new TypeNum(parent);
    }


    TypeChar parseTypeChar (ValueScope parent)
    {
        nextTok();
        return new TypeChar(parent);
    }


    TypeText parseTypeText (ValueScope parent)
    {
        nextTok();
        return new TypeText(parent);
    }


    TypeType parseTypeType (ValueScope parent)
    {
        nextNonWhiteTok();
        auto types = parseBracedExpList(parent);
        if (types.length != 1)
            vctx.remark(textRemark("Type takes one argument"));
        return new TypeType(parent, types[0]);
    }


    TypeOr parseTypeOr (ValueScope parent)
    {
        nextNonWhiteTok();
        auto types = parseBracedExpList(parent);
        return new TypeOr(parent, types);
    }


    TypeFn parseTypeFn (ValueScope parent)
    {
        nextNonWhiteTok();
        auto types = parseBracedExpList(parent);
        return new TypeFn(parent, types[0.. $ - 1], types[0]);
    }
}
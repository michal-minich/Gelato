module syntax.Parser;


import std.array, std.conv, std.format;
import common, validate.remarks, syntax.ast;


@safe:


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
        size_t prevStartIndex;
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
        auto s = newExp!ValueStruct(0, null);
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
            else if (current.type != TokenType.empty)
                current = Token(current.index + 1, TokenType.empty);
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
        auto sepLine = 0;
        auto sepComa = 0;
        while(toks.length)
        {
            switch (current.type)
            {
                case TokenType.white: nextTok(); continue;
                case TokenType.newLine: ++sepLine; nextTok(); continue;
                case TokenType.coma: ++sepComa; nextTok(); continue;
                default: goto end;
            }
        }
        
        end:

        sepPassed = sepLine > 0 || sepComa > 0;

        if (sepComa > 1)
            vctx.remark(textRemark("repeated coma"));

        else if (sepComa == 1 && sepLine > 0)
            vctx.remark(textRemark("coma is optional when newExp!line is used"));
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


    T newExp (T : Exp, A...) (size_t tokenStartIndex, A args)
    {
        auto e = new T(args);
        e.tokens = toks2[tokenStartIndex .. current.index];
        return e;
    }


    T newExp1 (T : Exp, A...) (A args)
    {
        auto e = new T(args);
        e.tokens = toks2[current.index .. current.index + 1];
        return e;
    }


    T newExp2 (T : Exp, A...) (size_t tokenStartIndex, size_t tokenEndIndex, A args)
    {
        auto e = new T(args);
        e.tokens = toks2[tokenStartIndex .. tokenEndIndex];
        return e;
    }


    Exp parse (ValueScope parent)
    {
        auto tokenStartIndex = current.index;

        next:
        skipComment:

        if (!toks.length)
            return null;

        sepPassed = false;

        skipSep();

        Exp exp;
        switch (current.type)
        {
            case TokenType.num: exp = parseNum(tokenStartIndex, parent); break;
            case TokenType.ident: exp = parseIdentOrAssign(parent); break;
            case TokenType.quote: exp = parseText(tokenStartIndex, parent); break;

            case TokenType.braceEnd: handleBraceEnd(); goto next;

            case TokenType.keyIf: exp = parseIf(tokenStartIndex, parent); break;
            case TokenType.keyThen: handleThen(); return newExp!ValueUnknown(tokenStartIndex, parent);
            case TokenType.keyElse: handleElse(); return newExp!ValueUnknown(tokenStartIndex, parent);
            case TokenType.keyEnd: handleEnd(); return newExp!ValueUnknown(tokenStartIndex, parent);

            case TokenType.keyFn: exp = parserFn(tokenStartIndex, parent); break;
            case TokenType.keyReturn: exp = parserReturn(tokenStartIndex, parent); break;

            case TokenType.keyGoto: exp = parserGoto(tokenStartIndex, parent); break;
            case TokenType.keyLabel: exp = parserLabel(tokenStartIndex, parent); break;

            case TokenType.keyStruct: exp = parseStruct(tokenStartIndex, parent); break;
            //case TokenType.keyThrow: exp = parserThrow(tokenStartIndex, parent); break;
            case TokenType.keyVar: exp = parseVar(tokenStartIndex, parent); break;

            case TokenType.unknown: exp = parseUnknown(parent); break;

            case TokenType.typeType: exp = parseTypeType(tokenStartIndex, parent); break;
            case TokenType.typeAny: exp = parseTypeAny(parent); break;
            case TokenType.typeVoid: exp = parseTypeVoid(parent); break;
            case TokenType.typeOr: exp = parseTypeOr(parent); break;
            case TokenType.typeFn: exp = parseTypeFn(parent); break;
            case TokenType.typeInt: exp = parseTypeInt(parent); break;
            case TokenType.typeText: exp = parseTypeText(parent); break;
            case TokenType.typeChar: exp = parseTypeChar(parent); break;

            case TokenType.braceStart: exp = parseBracedExp(tokenStartIndex, parent); break;

            case TokenType.commentLine: comment = parseCommentLine(tokenStartIndex, parent); break;
            case TokenType.commentMultiStart: comment = parseCommentMulti(tokenStartIndex, parent); break;

            case TokenType.empty: return null;
            default: assert (false);
        }

        if (comment)
        {
            comment = null;
            goto skipComment;
        }

        typeof(current.index) prevIndex;
        tokenStartIndex = current.index;

        do
        {
            prevIndex = current.index;

            sepPassed = skipSep() || sepPassed;

            if (sepPassed)
                break;

            while (current.type == TokenType.braceStart)
                exp = newExp!ExpFnApply(tokenStartIndex, parent, exp, parseBracedExpList(tokenStartIndex, parent));

            if (current.type == TokenType.op)
                exp = parseOp(current.index, parent, exp);

            if (current.type == TokenType.dot)
            {
                exp = parseOpDot(parent, exp);
                if (cast(ValueFloat)exp)
                    break;
            }

        } while (prevIndex != current.index);

        return exp;
    }


    void handleBraceEnd ()
    {
        nextTok();
        vctx.remark(textRemark("redundant close brace"));
    }


    Exp parseBracedExp (size_t tokenStartIndex, ValueScope parent)
    {
        braceStack.push(current.text[0]);

        if (current.text[0] == '(')
        {
            auto exps = parseBracedExpList (tokenStartIndex, parent);
            if (exps.length > 1)
                vctx.remark(textRemark("only one exp can be braced ()"));
            return exps[0];
        }
        else if (current.text[0] == '[')
        {
            auto op = newExp!ExpIdent(tokenStartIndex, parent, current.text);
            auto exps = parseBracedExpList (tokenStartIndex, parent);
            auto fna = newExp!ExpFnApply(tokenStartIndex, parent, op, exps);
            return fna;
        }
        else
        {
            vctx.remark(textRemark("unsupported brace op apply"));
            return newExp!ValueUnknown(tokenStartIndex, parent);
        }
    }


    Exp[] parseBracedExpList (size_t tokenStartIndex, ValueScope parent)
    {
        braceStack.push(current.text[0]);

        Exp[] list;
        immutable opposite = oppositeBrace(current.text);
        nextNonWhiteTok();
        while (true)
        {
            if (current.type == TokenType.braceEnd)
            {
                if (current.text == opposite)
                    break;

                vctx.remark(textRemark("closing brace has no matching beginning brace"));
                nextTok();
                continue;
            }

            if (!toks.length)
            {
                vctx.remark(textRemark("reached end of file and close brace not found"));
                return list;
            }

            if (list.length && !sepPassed)
                vctx.remark(textRemark("missing comma or newExp!line to separate expressions"));

            auto e = parse(parent);
            list ~= e;
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


    @trusted Exp parseOpDot (ValueScope parent, Exp operand1)
    {
        nextNonWhiteTok();

        auto nInt = cast(ValueInt)operand1;
        auto isBase16 = nInt && nInt.tokens[0].text[0] == '#';
        
        if (current.text == "(")
        {
            // TODO: parse op dot in form a.(+)   a.(..)
        }

        if ((current.type == TokenType.ident || current.type == TokenType.op) && !isBase16)
        {
            auto txt = current.text;
            nextTok();
            auto dot = newExp!ExpDot(operand1.tokens[0].index, parent, operand1, newExp!ExpIdent(current.index - 1, parent, txt));
            // parent of exp ident should be value scope of operand 1, but oprerand1 is of arbitrary expression ...
            return dot;
        }

        if (nInt && (current.type == TokenType.num || (isBase16 && (current.type == TokenType.ident || current.text == "#"))))
        {
            auto txt = current.text;
            nextTok();
            auto f = newExp!ValueFloat(operand1.tokens[0].index, parent, 0);
            immutable s = txt.replace("_", "");
            auto nDecimal = (s[0] == '#' || isBase16) ? s[(s[0] == '#' ? 1 : 0) .. $].to!long(16) : s.to!long();
            if (s[0] == '#')
                vctx.remark(textRemark("# in decimal part is unnecessary"));
            auto nTxt = nInt.value.to!string() ~ '.' ~ nDecimal.to!string();
            real n = nTxt.to!real();
            f.value = n; 
            return f;
        }

        vctx.remark(textRemark("second operand must be identifier"));
        return newExp!ExpDot(operand1.tokens[0].index, parent, operand1, 
                             newExp!ExpIdent(operand1.tokens[0].index, parent, "<missing identifier>"d));
    }


    @trusted ValueInt parseNum (size_t tokenStartIndex, ValueScope parent)
    {
        immutable s = current.text.replace("_", "");
        nextTok();
        return newExp!ValueInt(current.index - 1, parent, s[0] == '#' ? s[1 .. $].to!long(16) : s.to!long());
    }


    ExpFnApply parseOp (size_t tokenStartIndex, ValueScope parent, Exp operand1)
    {
        auto op = newExp!ExpIdent(tokenStartIndex, parent, current.text);
        nextNonWhiteTok();
        auto operand2 = parse(parent);

        if (!operand2)
        {
            vctx.remark(textRemark("second operand is missing"));
            operand2 = newExp!ValueUnknown(tokenStartIndex, parent);
        }

        auto fna = newExp!ExpFnApply(tokenStartIndex, parent, op, [operand1, operand2]);
        return fna;
    }


    Exp parseVar (size_t tokenStartIndex, ValueScope parent)
    {
        nextTok();
        auto e = parse (parent);
        auto a = cast(ExpAssign)e;
        if (a)
            return a;

        vctx.remark(textRemark("var can be only used before declaration"));
        return e;
    }


    ExpIf parseIf (size_t tokenStartIndex, ValueScope parent)
    {
        auto i = newExp!ExpIf(tokenStartIndex, parent);
        nextNonWhiteTok();
        i.when = parse(parent);

        if (!i.when)
        {
            i.when = newExp!ValueUnknown(tokenStartIndex, parent);
            vctx.remark(textRemark("missing test expression after if"));
        }

        if (current.type != TokenType.keyThen)
        {
            i.then ~= newExp!ValueUnknown(tokenStartIndex, parent);
            vctx.remark(textRemark("missing 'then' after if"));
        }
        else
        {
            nextNonWhiteTok();

            while (toks.length && current.type != TokenType.keyElse && current.type != TokenType.keyEnd)
                i.then ~= parse(parent);

            if (!i.then.length)
            {
                i.then ~= newExp!ValueUnknown(tokenStartIndex, parent);
                vctx.remark(textRemark("missing expression after then"));
            }
        }

        if (current.type == TokenType.keyElse)
        {
            nextNonWhiteTok();

            while (toks.length && current.type != TokenType.keyEnd)
                i.otherwise ~= parse(parent);

            if (!i.otherwise.length)
            {
                i.otherwise ~= newExp!ValueUnknown(tokenStartIndex, parent);
                vctx.remark(textRemark("missing expression after else"));
            }
        }
        
        if (!toks.length)
            vctx.remark(textRemark("if without 'end'"));

        nextNonWhiteTok();
        return i;
    }


    void handleThen ()
    {
        nextTok();
        vctx.remark(textRemark("'then' after 'if'"));
    }


    void handleElse ()
    {
        nextTok();
        vctx.remark(textRemark("'else' after 'if'"));
    }


    void handleEnd ()
    {
        vctx.remark(textRemark("'end' after 'if'"));
    }


    ValueStruct parseStruct (size_t tokenStartIndex, ValueScope parent)
    {
        auto s = newExp!ValueStruct(tokenStartIndex, parent);
        nextNonWhiteTok();
        s.exps = parseBracedExpList(tokenStartIndex, s);
        return s;
    }


    Exp parserFn (size_t tokenStartIndex, ValueScope parent)
    {
        auto f = newExp!ValueFn(tokenStartIndex, parent);
        nextNonWhiteTok();

        foreach (ix, p; parseBracedExpList(tokenStartIndex, f))
        {
            auto d = cast(ExpAssign)p;
            if (!d)
            {
                auto i = cast(ExpIdent)p;
                if (i)
                    d = newExp!ExpAssign(tokenStartIndex, f, i, null);
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

        f.exps = parseBracedExpList (tokenStartIndex, f);

        return f;
    }


    StmReturn parserReturn (size_t tokenStartIndex, ValueScope parent)
    {
        nextNonWhiteTokOnSameLine();
        return newExp!StmReturn(tokenStartIndex, parent, (toks.length && current.type != TokenType.newLine) ? parse(parent) : null);
    }


    StmGoto parserGoto (size_t tokenStartIndex, ValueScope parent)
    {
        nextNonWhiteTokOnSameLine();
        if (current.type != TokenType.ident)
            return newExp!StmGoto(tokenStartIndex, parent, null);
        
        auto g = newExp!StmGoto(tokenStartIndex, parent, current.text);
        nextTok();
        return g;
    }


    StmLabel parserLabel (size_t tokenStartIndex, ValueScope parent)
    {
        nextNonWhiteTokOnSameLine();
        if (current.type != TokenType.ident)
            return newExp!StmLabel (tokenStartIndex, parent, null);

        auto l = newExp!StmLabel (tokenStartIndex, parent, current.text);
        nextTok();
        return l;
    }


    Exp parseText (size_t tokenStartIndex, ValueScope parent)
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
            t = newExp!ValueChar(tokenStartIndex, parent, txt.length ? txt[0] : 255 /* TODO - should be invalid utf32 char*/);
        else
            t = newExp!ValueText(tokenStartIndex, parent, txt);

        return t;
    }


    Exp parseIdentOrAssign (ValueScope parent)
    {
        auto i = newExp1!ExpIdent(parent, current.text);

        Exp type;
        nextNonWhiteTok();
        if (current.type == TokenType.asType)
        {
            nextTok();
            type = parse(parent);
        }

        Exp value;
        if (current.type == TokenType.assign)
        {
            nextTok();
            auto v = parse(parent);
            value = v ? v : new ValueUnknown(parent);
        }

        if (type || value)
        {
            auto d = newExp2!ExpAssign(i.tokens[0].index, current.index, parent, i, value);
            d.type = type;
            return d;
        }
            
        return i;
    }


    Comment parseCommentLine (size_t tokenStartIndex, ValueScope parent)
    {
        auto c = newExp!Comment(tokenStartIndex);
        while (toks.length && current.type != TokenType.newLine)
            nextTok();
        nextNonWhiteTok();
        return c;
    }


    Comment parseCommentMulti (size_t tokenStartIndex, ValueScope parent)
    {
        auto c = newExp!Comment(tokenStartIndex);
        while (current.type != TokenType.commentMultiEnd)
        {
            if (!toks.length)
            {
                vctx.remark(textRemark("unclosed multiline comment"));
                return c;
            }

            nextTok();
        }
        nextNonWhiteTok();
        return c;
    }


    ValueUnknown parseUnknown (ValueScope parent)
    {
        nextTok();
        return newExp!ValueUnknown(current.index - 1, parent);
    }


    TypeAny parseTypeAny (ValueScope parent)
    {
        nextTok();
        return newExp!TypeAny(current.index - 1, parent);
    }


    TypeVoid parseTypeVoid (ValueScope parent)
    {
        nextTok();
        return newExp!TypeVoid(current.index - 1, parent);
    }


    TypeInt parseTypeInt (ValueScope parent)
    {
        nextTok();
        return newExp!TypeInt(current.index - 1, parent);
    }


    TypeChar parseTypeChar (ValueScope parent)
    {
        nextTok();
        return newExp!TypeChar(current.index - 1, parent);
    }


    TypeText parseTypeText (ValueScope parent)
    {
        nextTok();
        return newExp!TypeText(current.index - 1, parent);
    }


    TypeType parseTypeType (size_t tokenStartIndex, ValueScope parent)
    {
        nextNonWhiteTok();
        auto types = parseBracedExpList(tokenStartIndex, parent);
        if (types.length != 1)
            vctx.remark(textRemark("Type takes one argument"));
        return newExp!TypeType(tokenStartIndex, parent, types[0]);
    }


    TypeOr parseTypeOr (ValueScope parent)
    {
        immutable startIndex = current.index;
        nextNonWhiteTok();
        auto types = parseBracedExpList(startIndex, parent);
        return newExp!TypeOr(startIndex, parent, types);
    }


    TypeFn parseTypeFn (ValueScope parent)
    {
        immutable startIndex = current.index;
        nextNonWhiteTok();
        auto types = parseBracedExpList(startIndex, parent);
        return newExp!TypeFn(startIndex, parent, types[0.. $ - 1], types[0]);
    }
}
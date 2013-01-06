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
        dchar[] braceStack;
        size_t prevStartIndex;
    }


    this (IValidationContext valContext, Token[] tokens)
    {
        vctx = valContext;
        toks = tokens;
        toks2 = tokens;
        if (toks.length)
            current = toks.front;
    }


    ValueStruct parseAll ()
    {
        auto s = new ValueStruct(null);
        s.setTokens = toks2;
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
            vctx.remark(textRemark(null, "repeated coma"));

        else if (sepComa == 1 && sepLine > 0)
            vctx.remark(textRemark(null, "coma is optional when new line is used"));
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


    T newExp (T : Exp, A...) (size_t start, A args)
    {
        auto e = new T(args);
        e.setTokens = toks2[start .. current.index];
        return e;
    }


    T newExp1 (T : Exp, A...) (A args)
    {
        auto e = new T(args);
        e.setTokens = toks2[current.index .. current.index + 1];
        return e;
    }


    T newExp2 (T : Exp, A...) (size_t start, size_t end, A args)
    {
        auto e = new T(args);
        e.setTokens = toks2[start .. end];
        return e;
    }


    Exp parse (ValueScope parent)
    {
        next:
        skipComment:

        if (!toks.length)
            return null;

        sepPassed = false;

        skipSep();

        Exp exp;
        switch (current.type)
        {
            case TokenType.num: exp = parseNum(parent); break;
            case TokenType.ident: exp = parseIdentOrAssign(parent); break;
            case TokenType.quote: exp = parseText(parent); break;

            case TokenType.braceEnd: handleBraceEnd(); goto next;

            case TokenType.keyIf: exp = parseIf(parent); break;
            case TokenType.keyThen: return parseThen(parent);
            case TokenType.keyElse: return parseElse(parent);
            case TokenType.keyEnd: return parseEnd(parent);

            case TokenType.keyFn: exp = parseFn(parent); break;
            case TokenType.keyReturn: exp = parseReturn(parent); break;

            case TokenType.keyGoto: exp = parseGoto(parent); break;
            case TokenType.keyLabel: exp = parseLabel(parent); break;

            case TokenType.keyThrow: exp = parseThrow(parent); break;
            case TokenType.keyStruct: exp = parseStruct(parent); break;
            case TokenType.keyImport: exp = parseImport(parent); break;
            case TokenType.keyVar: exp = parseVar(parent); break;
            case TokenType.keyPublic: exp = parseVar(parent); break;
            case TokenType.keyPackage: exp = parseVar(parent); break;
            case TokenType.keyModule: exp = parseVar(parent); break;

            case TokenType.unknown: exp = parseUnknown(parent); break;

            case TokenType.typeType: exp = parseTypeType(parent); break;
            case TokenType.typeAny: exp = parseTypeAny(parent); break;
            case TokenType.typeVoid: exp = parseTypeVoid(parent); break;
            case TokenType.typeOr: exp = parseTypeOr(parent); break;
            case TokenType.typeFn: exp = parseTypeFn(parent); break;
            case TokenType.typeInt: exp = parseTypeInt(parent); break;
            case TokenType.typeText: exp = parseTypeText(parent); break;
            case TokenType.typeChar: exp = parseTypeChar(parent); break;

            case TokenType.braceStart: exp = parseBracedExp(parent); break;

            case TokenType.commentLine: comment = parseCommentLine(parent); break;
            case TokenType.commentMultiStart: comment = parseCommentMulti(parent); break;

            case TokenType.empty: return null;
            default: assert (false);
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

            if (sepPassed)
                break;

            while (current.type == TokenType.braceStart)
                exp = newExp!ExpFnApply(exp.tokens[0].index, parent, exp, parseBracedExpList(parent));

            if (current.type == TokenType.op)
                exp = parseOp(parent, exp);

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
        vctx.remark(textRemark(current, "redundant close brace"));
        nextTok();
    }


    Exp parseBracedExp (ValueScope parent)
    {
        immutable start = current.index;
        braceStack ~= current.text[0];

        if (current.text[0] == '(')
        {
            auto exps = parseBracedExpList(parent);
            if (exps.length > 1)
                vctx.remark(textRemark(exps[1], "only one exp can be braced ()"));
            return exps[0];
        }
        else if (current.text[0] == '[')
        {
            auto op = newExp1!ExpIdent(parent, current.text);
            auto exps = parseBracedExpList(parent);
            auto fna = newExp!ExpFnApply(start, parent, op, exps);
            return fna;
        }
        else
        {
            vctx.remark(textRemark(current, "unsupported brace op apply"));
            return new ValueUnknown(parent);
        }
    }


    Exp[] parseBracedExpList (ValueScope parent)
    {
        immutable start = current;
        braceStack ~= current.text[0];

        Exp[] list;
        immutable opposite = oppositeBrace(current.text);
        nextNonWhiteTok();
        while (true)
        {
            if (current.type == TokenType.braceEnd)
            {
                if (current.text == opposite)
                    break;

                vctx.remark(textRemark(current, "closing brace has no matching beginning brace"));
                nextTok();
                continue;
            }

            if (!toks.length)
            {
                vctx.remark(textRemark(start, "reached end of file and close brace not found"));
                return list;
            }

            if (list.length && !sepPassed)
                vctx.remark(textRemark(current, "missing comma or new line to separate expressions"));

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
                vctx.remark(textRemark(f, "# in decimal part is unnecessary"));
            auto nTxt = nInt.value.to!string() ~ '.' ~ nDecimal.to!string();
            real n = nTxt.to!real();
            f.value = n; 
            return f;
        }

        vctx.remark(textRemark(current, "second operand must be identifier"));
        return newExp!ExpDot(operand1.tokens[0].index, parent, operand1, 
                             newExp!ExpIdent(operand1.tokens[0].index, parent, "<missing identifier>"d));
    }


    @trusted ValueInt parseNum (ValueScope parent)
    {
        immutable s = current.text.replace("_", "");
        nextTok();
        return newExp!ValueInt(current.index - 1, parent, s[0] == '#' ? s[1 .. $].to!long(16) : s.to!long());
    }


    ExpFnApply parseOp (ValueScope parent, Exp operand1)
    {
        auto op = newExp1!ExpIdent(parent, current.text);
        nextNonWhiteTok();
        auto operand2 = parse(parent);

        if (!operand2)
        {
            vctx.remark(textRemark(null, "second operand is missing"));
            operand2 = new ValueUnknown(parent);
        }

        auto fna = newExp2!ExpFnApply(operand1.tokens[0].index, current.index, parent, op, [operand1, operand2]);
        return fna;
    }


    Exp parseVar (ValueScope parent)
    {
        auto first = current;
        nextNonWhiteTok();
        auto second = current;
        
        if (isScope(second.type) || second.type == TokenType.keyVar)
            nextTok();

        auto e = parse(parent);

        auto a = cast(ExpAssign)e;
        if (a)
        {
            a.isVar = first.type == TokenType.keyVar || second.type == TokenType.keyVar;
            if (isScope(first.type))
                a.accessScope = cast(AccessScope)first.type;
            else if (isScope(second.type))
                a.accessScope = cast(AccessScope)second.type;
            return a;
        }

        vctx.remark(textRemark(e, "'" ~ first.text ~ "' can be only used before declaration"));
        return e;
    }


    const bool isScope (const TokenType tt)
    {
        return tt == TokenType.keyPublic || tt == TokenType.keyPackage || tt == TokenType.keyModule;
    }


    ExpIf parseIf (ValueScope parent)
    {
        immutable start = current.index;

        nextNonWhiteTok();
        Exp when;
        while (true)
        {
            if (current.type == TokenType.keyThen || current.type == TokenType.keyElse ||
                current.type == TokenType.keyEnd)
            {
                if (!when)
                {
                    when = new ValueUnknown(parent);
                    vctx.remark(textRemark("missing test expression after if"));
                }
                break;
            }

            auto w = parse(parent);
            if (!when)
                when = w;
        }


        auto then = new ValueStruct(parent); // should be only ValueScope
        if (current.type != TokenType.keyThen)
        {
            then.exps ~= new ValueUnknown(then);
            vctx.remark(textRemark("missing 'then' after if"));
        }
        else
        {
            nextNonWhiteTok();

            while (toks.length && current.type != TokenType.keyElse && current.type != TokenType.keyEnd)
                then.exps ~= parse(then);

            if (!then.exps.length)
            {
                then.exps ~= new ValueUnknown(then);
                vctx.remark(textRemark("missing expression after then"));
            }
        }

        auto otherwise = new ValueStruct(parent); // should be only ValueScope
        if (current.type == TokenType.keyElse)
        {
            nextNonWhiteTok();

            while (toks.length && current.type != TokenType.keyEnd)
                otherwise.exps ~= parse(otherwise); 
            if (!otherwise.exps.length)
            {
                otherwise.exps ~= new ValueUnknown(otherwise);
                vctx.remark(textRemark("missing expression after else"));
            }
        }

        if (!toks.length)
            vctx.remark(textRemark("if without 'end'"));
        else
            nextTok();

        auto i = newExp2!ExpIf(start, current.index, parent);
        i.when = when;
        i.then = then;
        i.otherwise = otherwise;
        return i;
    }


    ValueUnknown parseThen (ValueScope parent)
    {
        auto t = new ValueUnknown(parent);
        nextTok();
        vctx.remark(textRemark("'then' after 'if'"));
        return t;
    }


    ValueUnknown parseElse (ValueScope parent)
    {
        auto e = new ValueUnknown(parent);
        nextTok();
        vctx.remark(textRemark("'else' after 'if'"));
        return e;
    }


    ValueUnknown parseEnd (ValueScope parent)
    {
        auto e = new ValueUnknown(parent);
        nextTok();
        vctx.remark(textRemark("'end' after 'if'"));
        return e;
    }


    ValueStruct parseStruct (ValueScope parent)
    {
        immutable start = current.index;
        auto s = new ValueStruct(parent);
        nextNonWhiteTok();
        s.exps = parseBracedExpList(s);
        s.setTokens = toks2[start .. current.index];
        return s;
    }


    Exp parseFn (ValueScope parent)
    {
        immutable start = current.index;
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

        f.exps = parseBracedExpList(f);
        f.setTokens = toks2[start .. current.index];
        return f;
    }


    StmThrow parseThrow (ValueScope parent)
    {
        immutable start = current.index;
        nextNonWhiteTokOnSameLine();
        return newExp!StmThrow(start, parent, (toks.length && current.type != TokenType.newLine) ? parse(parent) : null);
    }


    StmReturn parseReturn (ValueScope parent)
    {
        immutable start = current.index;
        nextNonWhiteTokOnSameLine();
        return newExp!StmReturn(start, parent, (toks.length && current.type != TokenType.newLine) ? parse(parent) : null);
    }


    StmImport parseImport (ValueScope parent)
    {
        immutable start = current.index;
        nextNonWhiteTokOnSameLine();
        return newExp!StmImport(start, parent, (toks.length && current.type != TokenType.newLine) ? parse(parent) : null);
    }


    StmGoto parseGoto (ValueScope parent)
    {
        return parseLabelGoto!StmGoto(parent);
    }


    StmLabel parseLabel (ValueScope parent)
    {
        return parseLabelGoto!StmLabel(parent);
    }


    LabelGoto parseLabelGoto (alias LabelGoto) (ValueScope parent)
    {
        immutable start = current.index;
        nextNonWhiteTokOnSameLine();
        if (current.type != TokenType.ident)
            return newExp2!LabelGoto (start, start, parent, ""d);

        auto l = newExp2!LabelGoto (start, current.index, parent, current.text);
        nextTok();
        return l;
    }


    Exp parseText (ValueScope parent)
    {
        immutable start = current.index;
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
            t = newExp!ValueChar(start, parent, txt.length ? txt[0] : 255 /* TODO - should be invalid utf32 char*/);
        else
            t = newExp!ValueText(start, parent, txt);

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
            if (!value)
                value = new ValueUnknown(parent);

            auto d = newExp2!ExpAssign(i.tokens[0].index, current.index, parent, i, value);
            d.type = type;
            return d;
        }
            
        return i;
    }


    Comment parseCommentLine (ValueScope parent)
    {
        immutable stasrt = current.index;
        while (toks.length && current.type != TokenType.newLine)
            nextTok();
        auto c = newExp!Comment(stasrt);
        nextTok();
        return c;
    }


    Comment parseCommentMulti (ValueScope parent)
    {
        immutable start = current.index;
        while (current.type != TokenType.commentMultiEnd)
        {
            if (!toks.length)
            {
                vctx.remark(textRemark("unclosed multiline comment"));
                return newExp!Comment(start);
            }

            nextTok();
        }
        auto c = newExp!Comment(start);
        nextTok();
        return c;
    }


    ValueUnknown parseUnknown (ValueScope parent)
    {
        nextTok();
        return newExp1!ValueUnknown(parent);
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


    TypeType parseTypeType (ValueScope parent)
    {
        immutable start = current.index;
        nextNonWhiteTok();
        auto types = parseBracedExpList(parent);
        if (types.length != 1)
            vctx.remark(textRemark("Type takes one argument"));
        return newExp!TypeType(start, parent, types[0]);
    }


    TypeOr parseTypeOr (ValueScope parent)
    {
        immutable start = current.index;
        nextNonWhiteTok();
        auto types = parseBracedExpList(parent);
        return newExp!TypeOr(start, parent, types);
    }


    TypeFn parseTypeFn (ValueScope parent)
    {
        immutable start = current.index;
        nextNonWhiteTok();
        auto types = parseBracedExpList(parent);
        return newExp!TypeFn(start, parent, types[0.. $ - 1], types[0]);
    }
}
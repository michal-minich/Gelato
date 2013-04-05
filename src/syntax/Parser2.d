module syntax.Parser2;


import std.conv;
import common, validate.remarks, syntax.ast, syntax.NamedCharRefs;


@safe final class Parser2
{
    ValueStruct root;

    ValueStruct parseAll (IValidationContext context, Token[] tokens)
    {
        vctx = context;
        toks = tokens;
        current = toks[0];
        prevExp = ValueUnknown.single;
        root = new ValueStruct(null);
        root.exps ~= prevExp;
        Exp e;
        while ((e = parse(root)) !is null)
            root.exps ~= e;
        return root;
    }


    private:


    Token[] toks;
    IValidationContext vctx;
    Token current;
    bool sepPassed;
    Wadding[] waddings;
    dchar[] braceStack;
    Exp prevExp;


    nothrow T newWad (T, A...) (size_t start, A args)
    {
        auto w = new T(args);
        w.setTokens = toks[start .. current.index];
        return w;
    }


    nothrow T newWad1 (T, A...) (A args)
    {
        auto w = new T(args);
        w.setTokens = toks[current.index .. current.index + 1];
        return w;
    }


    nothrow T newExp (T, A...) (size_t start, A args)
    {
        return newExpWithTokens!T(args, toks[start .. end]);
    }


    nothrow T newExp1 (T, A...) (A args)
    {
        return newExpWithTokens!T(args, toks[current.index .. current.index + 1]);
    }


    nothrow T newExp2 (T, A...) (size_t start, size_t end, A args)
    {
        return newExpWithTokens!T(args, toks[start .. end]);
    }


    nothrow T newExpWithTokens (T, A...) (A args, Token[] toks)
    {
        associateWadding(prevExp);
        auto e = new T(args);
        prevExp = e;
        e.setTokens = toks;
        return e;
    }


    nothrow void associateWadding (Exp e)
    {
        e.waddings ~= waddings;
        waddings = null;
    }


    @property nothrow const bool isWhite ()
    {
        return current.type == TokenType.newLine || current.type == TokenType.white;
    }


    @property nothrow const bool empty () { return current.type == TokenType.empty; }

    @property nothrow const bool notEmpty () { return current.type != TokenType.empty; }


    nothrow void nextTok ()
    {
        debug assert (notEmpty, "past last token");
        current = toks[current.index + 1];
    }


    void nextNonWhiteTok ()
    {
        nextTok();
        parseWaddings();
    }


    void parseWaddings ()
    {
        again:
        switch (current.type)
        {
            case TokenType.white: 
            case TokenType.newLine:           waddings ~= parseWadWhite();        goto again;
            case TokenType.commentLine:       waddings ~= parseWadCommentLine();  goto again;
            case TokenType.commentMultiStart: waddings ~= parseWadCommentMulti(); goto again;
            default: return;
        }
    }


    Exp parse (ValueScope parent, bool parsingFromExpAssign = false)
    {
        parseWaddings();

        Exp e;

        switch (current.type)
        {
            case TokenType.ident:  e = parseExpIdent(parent); break;
            case TokenType.num:    e = parseValueNum(parent); break;
            case TokenType.empty:  associateWadding(prevExp); return null;
            default:
                dbg("Attempt to parse token ", current.type);
                assert (false);
        }

        if (notEmpty)
            nextNonWhiteTok();

        if (!parsingFromExpAssign)
        {
            if (current.type == TokenType.asType || current.type == TokenType.assign)
            {
                innerAssign:
                e = parseExpAssign(e, parent);

                parseWaddings();

                if (current.type == TokenType.assign)
                    goto innerAssign;
            }
        }

        return e;
    }


    nothrow Wadding parseWadWhite ()
    {
        immutable start = current.index;
        while (notEmpty && (current.type == TokenType.white || current.type == TokenType.newLine))
            nextTok();
        return newWad!WhiteSpace(start);
    }


    nothrow Wadding parseWadCommentLine ()
    {
        immutable start = current.index;
        while (notEmpty && current.type != TokenType.newLine)
            nextTok();
        return newWad!Comment(start);
    }


    Wadding parseWadCommentMulti ()
    {
        immutable start = current.index;
        while (current.type != TokenType.commentMultiEnd)
        {
            if (empty)
            {
                vctx.remark(textRemark("unclosed multiline comment"));
                return newWad!Comment(start);
            }
            nextTok();
        }
        nextTok();
        return newWad!Comment(start);
    }


    Exp parseExpIdent (ValueScope parent) { return newExp1!ExpIdent(parent, current.text); }


    @trusted ValueInt parseValueNum (ValueScope parent)
    {
        immutable s = current.text.filterChar('_');
        return newExp1!ValueInt(parent, s[0] == '#' ? s[1 .. $].to!long(16) : s.to!long());
    }


    Exp parseExpAssign (Exp slot, ValueScope parent)
    {
        Exp type;
        if (current.type == TokenType.asType)
        {
            waddings ~= newWad1!Punctuation();
            nextTok();
            type = parse(parent, true);
        }

        Exp value;
        if (current.type == TokenType.assign)
        {
            waddings ~= newWad1!Punctuation();
            nextTok();
            value = parse(parent, true);
        }
        
        if (!value)
            value = new ValueUnknown(parent);

        auto d = newExp2!ExpAssign(slot.tokens[0].index, current.index, parent, slot, value);
        d.type = type;
        return d;
    }
}
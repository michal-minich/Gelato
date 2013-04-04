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
        root = new ValueStruct(null);
        while (notEmpty)
            root.exps ~= parse(root);
        return root;
    }


private:


    Token[] toks;
    IValidationContext vctx;
    Token current;
    bool sepPassed;
    Wadding[] waddings;
    dchar[] braceStack;


    nothrow T newExp (T, A...) (size_t start, A args)
    {
        auto e = new T(args);
        e.setTokens = toks[start .. current.index];
        return e;
    }


    nothrow T newExp1 (T, A...) (A args)
    {
        auto e = new T(args);
        e.setTokens = toks[current.index .. current.index + 1];
        return e;
    }


    nothrow T newExp2 (T, A...) (size_t start, size_t end, A args)
    {
        auto e = new T(args);
        e.setTokens = toks[start .. end];
        return e;
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


    nothrow void prevTok ()
    {
        current = toks[current.index - 1];
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


    Exp parse (ValueScope parent)
    {
        parseWaddings();

        Exp e;

        switch (current.type)
        {
            case TokenType.ident: e = parseIdentOrAssign  (parent); break;
            case TokenType.num:   e = parseNum            (parent); break;
            case TokenType.empty: return withWadding(ValueUnknown.single);
            default:
                dbg("Attempt to parse token ", current.type);
                assert (false);
        }

        nextTok();

        return withWadding(e);
    }


    nothrow Exp withWadding (Exp e)
    {
        addWadding(e);
        return e;
    }


    nothrow void addWadding (Exp e)
    {
        e.waddings ~= waddings;
        waddings = null;
    }


    nothrow Wadding parseWadWhite ()
    {
        immutable start = current.index;
        do nextTok();
        while (notEmpty && (current.type == TokenType.white || current.type == TokenType.white));
        return newExp!WhiteSpace(start);
    }


    nothrow Wadding parseWadCommentLine ()
    {
        immutable start = current.index;
        do nextTok();
        while (notEmpty && current.type != TokenType.newLine);
        return newExp!Comment(start);
    }


    Wadding parseWadCommentMulti ()
    {
        immutable start = current.index;
        while (current.type != TokenType.commentMultiEnd)
        {
            if (empty)
            {
                vctx.remark(textRemark("unclosed multiline comment"));
                return newExp!Comment(start);
            }
            nextTok();
        }
        nextTok();
        return newExp!Comment(start);
    }


    @trusted ValueInt parseNum (ValueScope parent)
    {
        immutable s = current.text.filterChar('_');
        return newExp1!ValueInt(parent, s[0] == '#' ? s[1 .. $].to!long(16) : s.to!long());
    }


    Exp parseIdentOrAssign (ValueScope parent)
    {
        auto i = newExp1!ExpIdent(parent, current.text);
        addWadding(i);
        nextNonWhiteTok();

        Exp type;
        if (current.type == TokenType.asType)
        {
            waddings ~= newExp1!Punctuation();
            nextTok();
            type = parse(parent);
        }

        Exp value;
        if (current.type == TokenType.assign)
        {
            waddings ~= newExp1!Punctuation();
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
            prevTok();
            return d;
        }

        prevTok();
        return i;
    }
}
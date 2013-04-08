module syntax.Parser2;


import std.conv;
import common, validate.remarks, syntax.ast, syntax.NamedCharRefs;


@safe final class Parser2
{
    nothrow this (IValidationContext context, Token[] tokens)
    {
        vctx = context;
        toks = tokens;
        current = toks[0];
        prevExp = ValueUnknown.single;
        root = new ValueStruct(null);
        root.exps ~= prevExp;
    }


    ValueStruct parseAll ()
    {
        Exp e;
        while ((e = parse(root)) !is null)
            root.exps ~= e;

        auto u = root.exps[0];
        if (u.waddings.length)
            u.setTokens = toks[u.waddings[0].tokens[0].index .. u.waddings[$ - 1].tokens[$ - 1].index + 1];

        return root;
    }


    private:


    IValidationContext vctx;
    Token[] toks;
    ValueStruct root;
    Token current;
    bool sepPassed;
    Wadding[] waddings;
    dchar[] braceStack;
    Exp prevExp;
    bool reverseParseOp = true;
    int inParsingOp;
    bool inParsingAsType;


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
        debug assert (notEmpty, "Parsing past last token");
        current = toks[current.index + 1];
    }

/*
    @property nothrow Token next ()
    {
        debug assert (toks.length > current.index + 1, "Peeking past last token");
        return toks[current.index + 1];
    }
*/

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


    Exp parse (ValueScope parent)
    {
        next:

        parseWaddings();

        Exp e;

        switch (current.type)
        {
            case TokenType.ident:  e = parseExpIdent(parent); break;
            case TokenType.num:    e = parseValueNum(parent); break;
            case TokenType.braceStart: e = parseBrace(parent); if (!e) goto next; else break;
            
            case TokenType.empty:  associateWadding(prevExp); return null;
            
            case TokenType.op:     e = parseOp(new ValueUnknown(parent)); goto nextOp;

            case TokenType.asType:
            case TokenType.assign: vctx.remark(textRemark(
                "Unexpected token " ~ current.type.toDString() ~ " '" ~ current.text ~ "'")); return null;
            
            default:
                dbg("Attempt to parse token ", current.type);
                assert (false);
        }

        parseWaddings();

        nextOp:
        if (reverseParseOp && current.type == TokenType.op)
        {
            e = parseOp(e);
            parseWaddings();
            goto nextOp;
        }

        if (!inParsingOp && current.type == TokenType.asType)
        {
            if (inParsingAsType)
            {
                // TODO: implement here more handlings of incorrect colon
                vctx.remark(textRemark("Repeated double colon"));
                nextTok();
            }
            e = parseExpAssign(e);
            parseWaddings();
        }

        nextAssign:
        if (!inParsingAsType && !inParsingOp && current.type == TokenType.assign)
        {
            e = parseExpAssign(e);
            parseWaddings();
            goto nextAssign;
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
                vctx.remark(textRemark("Unclosed multiline comment"));
                return newWad!Comment(start);
            }
            nextTok();
        }
        nextTok();
        return newWad!Comment(start);
    }


    ExpIdent parseExpIdent (ValueScope parent)
    {
        auto e = newExp1!ExpIdent(parent, current.text);
        nextTok();
        return e;
    }


    @trusted ValueInt parseValueNum (ValueScope parent)
    {
        immutable s = current.text.filterChar('_');
        auto e = newExp1!ValueInt(parent, s[0] == '#' ? s[1 .. $].to!long(16) : s.to!long());
        nextTok();
        return e;
    }


    ExpAssign parseExpAssign (Exp slot)
    {
        Exp type;
        if (current.type == TokenType.asType)
        {
            waddings ~= newWad1!Punctuation();
            nextNonWhiteTok();
            inParsingAsType = true;
            type = parse(slot.parent);
            inParsingAsType = false;
        }

        parseAssign:
        Exp value;
        if (current.type == TokenType.assign)
        {
            waddings ~= newWad1!Punctuation();
            nextTok();
            value = parse(slot.parent);
        }
        
        if (!value)
            value = new ValueUnknown(slot.parent);

        auto d = newExp2!ExpAssign(slot.tokens[0].index, current.index, slot.parent, slot, value);
        d.type = type;
        return d;
    }


    ExpFnApply parseOp (Exp op1, bool reverse = false)
    {
        auto op = newExp1!ExpIdent(op1.parent, current.text);
        nextTok();
        ++inParsingOp;
        reverseParseOp = reverse;
        auto op2 = parse(op1.parent);
        reverseParseOp = true;
        --inParsingOp;

        if (!op2)
        {
            vctx.remark(textRemark(null, "Second operand for '" ~ op.tokens[0].text ~ "' is missing"));
            op2 = new ValueUnknown(op1.parent);
        }

        immutable start = (op1.tokens ? op1.tokens : op.tokens)[0].index;
        auto fna = newExp2!ExpFnApply(start, current.index, op1.parent, op, [op1, op2]);
        return fna;
    }


    Exp parseBrace (ValueScope parent)
    {
        auto opposite = oppositeBrace(current.text[0]);
        waddings ~= newWad1!Punctuation();
        nextNonWhiteTok();

        if (opposite == current.text[0])
        {
            waddings ~= newWad1!Punctuation();
            nextTok();
            return null;
        }

        auto old = reverseParseOp;
        reverseParseOp = true;
        auto e = parse(parent);
        reverseParseOp = old;

        if (empty)
        {
            vctx.remark(textRemark(null, "Missing closing brace"));
            return e;
        }
        else if (opposite != current.text[0])
        {
            vctx.remark(textRemark(null, "Expected closing brace'"d ~ opposite ~ "', found '" ~ current.text ~ "'" ));
            nextTok();
            return e;
        }
        waddings ~= newWad1!Punctuation();
        nextTok();
        return e;
    }


    static dchar oppositeBrace (dchar brace)
    {
        switch (brace)
        {
            case '(': return ')';
            case '[': return ']';
            case '{': return '}';
            default: assert (false, "bad brace '" ~ brace.toString() ~ "'");
        }
    }
}
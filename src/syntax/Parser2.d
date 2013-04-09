module syntax.Parser2;


import std.conv;
import common, validate.remarks, syntax.ast, syntax.NamedCharRefs;


@safe final class Parser2
{
    this (IValidationContext context, Token[] tokens)
    {
        vctx = context;
        toks = tokens;
        current = toks[0];
        parseWaddings();
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
    bool parseOpLeftToRight;
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
        return newExpWithTokens!T(args, toks[start .. current.index]);
    }


    nothrow T newExp1 (T, A...) (A args)
    {
        return newExpWithTokens!T(args, toks[current.index .. current.index + 1]);
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


    void nextTok ()
    {
        nextOneTok();
        parseWaddings();
    }


    void nextOneTok ()
    {
        debug assert (notEmpty, "Parsing past last token");
        current = toks[current.index + 1];
    }


    void parseWaddings ()
    {
        sepPassed = false;
        auto sepLine = 0;
        auto sepComa = 0;

        again:
        switch (current.type)
        {
            case TokenType.white: 
            case TokenType.newLine: ++sepLine; waddings ~= parseWadWhite();        goto again;
            case TokenType.coma:    ++sepComa; waddings ~= newWad1!Punctuation(); nextOneTok();  goto again;
            case TokenType.commentLine:        waddings ~= parseWadCommentLine();  goto again;
            case TokenType.commentMultiStart:  waddings ~= parseWadCommentMulti(); goto again;

            case TokenType.braceStart:
            case TokenType.braceEnd:
            case TokenType.asType:
            case TokenType.assign:
                waddings ~= newWad1!Punctuation();
                break;
            default: break;
        }

        sepPassed = sepLine > 0 || sepComa > 0;

        if (sepComa > 1)
            vctx.remark(textRemark(null, "repeated coma"));

        else if (sepComa == 1 && sepLine > 0)
            vctx.remark(textRemark(null, "coma is optional when new line is used"));
    }


    Wadding parseWadWhite ()
    {
        immutable start = current.index;
        while (notEmpty && (current.type == TokenType.white || current.type == TokenType.newLine))
            nextOneTok();
        return newWad!WhiteSpace(start);
    }


    Wadding parseWadCommentLine ()
    {
        immutable start = current.index;
        while (notEmpty && current.type != TokenType.newLine)
            nextOneTok();
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
        nextOneTok();
        return newWad!Comment(start);
    }


    Exp parse (ValueScope parent)
    {
        next:

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
                "Unexpected token " ~ current.type.toDString() ~ " '" ~ current.text ~ "'")); 
                return null;
            
            default:
                dbg("Attempt to parse token ", current.type);
                assert (false);
        }

        nextOp:
        if (!parseOpLeftToRight && current.type == TokenType.op)
        {
            e = parseOp(e);
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
        }

        nextAssign:
        if (!inParsingAsType && !inParsingOp && current.type == TokenType.assign)
        {
            e = parseExpAssign(e);
            goto nextAssign;
        }


        while (!sepPassed && current.type == TokenType.braceStart)
        {
            e = newExp!ExpFnApply(e.tokens[0].index, parent, e, parseBracedExpList(parent));
        }

        return e;
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
            nextTok();
            inParsingAsType = true;
            type = parse(slot.parent);
            inParsingAsType = false;
        }

        parseAssign:
        Exp value;
        if (current.type == TokenType.assign)
        {
            nextTok();
            value = parse(slot.parent);
        }
        
        if (!value)
            value = new ValueUnknown(slot.parent);

        auto d = newExp!ExpAssign(slot.tokens[0].index, slot.parent, slot, value);
        d.type = type;
        return d;
    }


    ExpFnApply parseOp (Exp op1, ExpIdent op = null)
    {
        op = op ? op : newExp1!ExpIdent(op1.parent, current.text);
        
        nextTok();

        ++inParsingOp;
        parseOpLeftToRight = true;
        
        auto op2 = parse(op1.parent);
        
        parseOpLeftToRight = false;
        --inParsingOp;

        if (!op2)
        {
            vctx.remark(textRemark(op, "Second operand for '" 
                                   ~ op.tokens[0].text ~ "' is missing"));
            op2 = new ValueUnknown(op1.parent);
        }

        immutable start = (op1.tokens ? op1.tokens : op.tokens)[0].index;
        auto fna = newExp!ExpFnApply(start, op1.parent, op, [op1, op2]);
        return fna;
    }



    Exp parseBrace (ValueScope parent)
    {        
        immutable start = current.index;
        braceStack ~= current.text[0];

        if (current.text[0] == '(')
        {
            auto exps = parseBracedExpList(parent);
            if (exps.length > 1)
                vctx.remark(textRemark(exps[0], "Only one exp can be braced ()"));
            else if (exps.length == 1)
                vctx.remark(textRemark(exps[0], "Braces around expressions are not needed"));
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
            vctx.remark(textRemark(current, "Unsupported brace op apply"));
            return new ValueUnknown(parent);
        }
    }


    Exp[] parseBracedExpList (ValueScope parent)
    {
        Exp[] list;
        auto opposite = oppositeBrace(current.text[0]);
        nextTok();

        if (empty)
        {
            vctx.remark(textRemark("Missing closing brace"));
            return null;
        }

        if (opposite == current.text[0])
        {
            vctx.remark(textRemark("Empty braces"));
            nextTok();
            return null;
        }

        if (current.type == TokenType.op)
        {
            auto op = newExp1!ExpIdent(parent, current.text);
            nextTok();
            if (opposite == current.text[0])
            {
                nextTok();
                return [op];
            }
            else
            {
                parseOp(new ValueUnknown(parent), op);
            }
        }
        
        while (true)
        {
            auto old = parseOpLeftToRight;
            parseOpLeftToRight = false;
            list ~= parse(parent);
            parseOpLeftToRight = old;

            if (empty)
            {
                vctx.remark(textRemark(list[$ - 1], "Missing closing brace"));
                return list;
            }
            else if (current.type == TokenType.braceEnd)
            {
                if (current.text[0] == opposite)
                    break;

                vctx.remark(textRemark(current, "Closing brace has no matching beginning brace"));
                nextTok();
                continue;
            }
           /* else if (opposite != current.text[0])
            {
                vctx.remark(textRemark(list[$ - 1], "Expected closing brace'"d ~ opposite 
                                       ~ "', found '" ~ current.text ~ "'" ));
                nextTok();
                return list;
            }*/

            if (list.length >=2  && !sepPassed)
                vctx.remark(textRemark(current, "missing comma or new line to separate expressions"));
        }

        nextTok();
        list[$ -1].setTokens = toks[list[$ -1].tokens[0].index .. current.index + 1];
        return list;
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
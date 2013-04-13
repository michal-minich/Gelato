module syntax.Parser2;


import common, validate.remarks, syntax.ast, syntax.NamedCharRefs;




@safe final class Parser2
{
    nothrow:

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
        while (continueParsing)
        {
            auto e = parse(root, ParsingState());
            if (e)
                root.exps ~= e;
        }

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
    bool sepPassedIsComa;
    Wadding[] waddings;
    dchar[] braceStack;
    Exp prevExp;
    bool continueParsing = true;
    bool missingClosingBrace;


    enum ParsingAction
    {
        none,
        parsingFnApply,
        parsingBracedExps,
        parsingOp,
        parsingAsType,
    }


    static struct ParsingState
    {
        ParsingAction[] actions;
        bool parseOpLeftToRight;

        const nothrow @property bool curr (ParsingAction act)
        {
            return actions.length ? actions[$ - 1] == act : false;
        }
    }


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
            case TokenType.white:              waddings ~= parseWadWhite();        goto again;
            case TokenType.newLine: ++sepLine; waddings ~= parseWadWhite();        goto again;
            case TokenType.coma:    ++sepComa; waddings ~= newWad1!Punctuation();  nextOneTok(); goto again;
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
            vctx.remark(textRemark("Coma is repeated, expected and expression between comas"));

        else if (sepComa == 1 && sepLine > 0)
            vctx.remark(textRemark("To separate expressions use coma or new line, "
                                   ~ "there is no need to use both"));

        sepPassedIsComa = sepComa != 0;
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
                vctx.remark(textRemark("Multiline comment is not closed "
                                       ~ "(use '-/' to end the comment)"));
                return newWad!Comment(start);
            }
            nextTok();
        }
        nextOneTok();
        return newWad!Comment(start);
    }


    Exp parse (ValueScope parent, ParsingState ps)
    {
        next:

        Exp e;

        switch (current.type)
        {
            case TokenType.ident:      e = parseExpIdent(parent); break;
            case TokenType.num:        e = parseValueNum(parent); break;
            case TokenType.braceStart: e = parseBrace(parent, ps);  break;
            case TokenType.op:         e = parseOp(parent, ps, null); goto nextOp;

            case TokenType.braceEnd:
                vctx.remark(textRemark(current, "Closing brace is redundant"));
                nextTok();
                break;

            case TokenType.asType:
            case TokenType.assign: 
                vctx.remark(textRemark(
                    "Token " ~ current.type.toDString() ~ " '" ~ current.text ~ "' is unexpected at this place"));
                nextTok();
                return null;

            case TokenType.empty:  associateWadding(prevExp); continueParsing = false; return null;
            
            default:
                dbg("Attempt to parse token " ~ current.type.toString());
                assert (false);
        }

        nextOp:
        
        if (sepPassed)
            return e;

        if (current.type == TokenType.op && !ps.parseOpLeftToRight)
        {
            e = parseOp(parent, ps, e);
            goto nextOp;
        }

        e = continueParsingAsType(parent, ps, e);

        nextAssign:

        if (sepPassed)
            return e;

        if (current.type == TokenType.assign && ps.curr(ParsingAction.parsingAsType) && !ps.curr(ParsingAction.parsingOp))
        {
            e = parseExpAssign(e, ps);
            goto nextAssign;
        }

        e = continueParsingFnApply(parent, ps, e);

        return e;
    }

 
    Exp continueParsingAsType(ValueScope parent, ParsingState ps, Exp e)
    {
        if (current.type == TokenType.asType && !ps.curr(ParsingAction.parsingOp))
        {
            if (ps.curr(ParsingAction.parsingAsType))
            {
                // TODO: implement here more handlings of incorrect colon
                vctx.remark(textRemark("Double colon is repeated"));
                nextTok();
            }
            return parseExpAssign(e, ps);
        }
        return e;
    }


    Exp continueParsingFnApply (ValueScope parent, ParsingState ps, Exp e)
    {
        while (current.type == TokenType.braceStart && !sepPassed)
            e = newExp!ExpFnApply(e.tokens[0].index, parent, e, parseBracedExpList(parent, ps, true));

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
        auto e = newExp1!ValueInt(parent, s[0] == '#' ? s[1 .. $].toLong(16) : s.toLong());
        nextTok();
        return e;
    }


    ExpAssign parseExpAssign (Exp slot, ParsingState ps)
    {
        Exp type;
        if (current.type == TokenType.asType)
        {
            nextTok();
            ps.actions ~= ParsingAction.parsingAsType;
            type = parse(slot.parent, ps);
        }

        parseAssign:
        Exp value;
        if (current.type == TokenType.assign)
        {
            nextTok();
            value = parse(slot.parent, ps);
        }
        
        if (!value)
            value = new ValueUnknown(slot.parent);

        auto d = newExp!ExpAssign(slot.tokens[0].index, slot.parent, slot, value);
        d.type = type;
        return d;
    }


    Exp parseOp (ValueScope parent, ParsingState ps, Exp op1, ExpIdent op = null)
    {
        if (!op)
            op = newExp1!ExpIdent(parent, current.text);
        
        nextTok();

        Exp op2;
        if (current.type == TokenType.braceEnd)
        {
            //nextTok();
        }
        else
        {
            ps.actions ~= ParsingAction.parsingOp;
            ps.parseOpLeftToRight = true;
        
            op2 = parse(parent, ps);
        
            ps.parseOpLeftToRight = false;
        }

        if (!op2 && !op1)
        {
            if (ps.curr(ParsingAction.parsingBracedExps))
                return op;

            op1 = new ValueUnknown(parent);
            op2 = new ValueUnknown(parent);
            vctx.remark(textRemark(op, "Both operands for '" 
                                   ~ op.tokens[0].text ~ "' are missing. "
                                   ~ "To use operator as identifier, enclosed it in braces"));
            // TODO: additional waddings need to be addte to op here
            return op;
        }
        else if (!op1)
        {
            op1 = new ValueUnknown(parent);
            vctx.remark(textRemark(op, "First operand for '" 
                                   ~ op.tokens[0].text ~ "' is missing"));
        }
        else if (!op2)
        {
            op2 = new ValueUnknown(parent);
            vctx.remark(textRemark(op, "Second operand for '" 
                                   ~ op.tokens[0].text ~ "' is missing"));
        }

        immutable start = (op1.tokens ? op1.tokens : op.tokens)[0].index;
        auto fna = newExp!ExpFnApply(start, parent, op, [op1, op2]);
        return fna;
    }



    Exp parseBrace (ValueScope parent, ParsingState ps)
    {        
        immutable start = current.index;
        braceStack ~= current.text[0];

        if (current.text[0] == '(')
        {
            ps.actions ~= ParsingAction.parsingBracedExps;
            auto exps = parseBracedExpList(parent, ps);
            
            if (exps.length > 1)
                vctx.remark(textRemark(exps[0], "Multiple expressions are enclosed in brace, "
                                       ~ " did you wanted to call some function?"));

            else if (exps.length == 1 && !missingClosingBrace)
            {
                auto i = cast(ExpIdent)exps[0];
                if (i && i.tokens[0].type != TokenType.op)
                    vctx.remark(textRemark(exps[0], "Braces around expression are not needed"));
            }

            return exps ? (cast(ValueUnknown)exps[0] ? null : exps[0]) : null;
        }
        else if (current.text[0] == '[')
        {
            auto op = newExp1!ExpIdent(parent, current.text);
            auto exps = parseBracedExpList(parent, ps);
            auto fna = newExp!ExpFnApply(start, parent, op, exps);
            return fna;
        }
        else
        {
            vctx.remark(textRemark(current, "Unsupported brace op apply"));
            return new ValueUnknown(parent);
        }
    }


    Exp[] parseBracedExpList (ValueScope parent, ParsingState ps, bool parsingFnApply = false)
    {
        missingClosingBrace = false;

        Exp[] list;
        auto opposite = oppositeBrace(current.text[0]);
        nextTok();

        if (empty)
        {
            vctx.remark(textRemark("Closing brace is missing"));
            missingClosingBrace = true;
            return null;
        }

        if (opposite == current.text[0])
        {
            if (parsingFnApply)
                vctx.remark(textRemark("Braces are empty, it has no meaning."));
            nextTok();
            return null;
        }

       /* if (!parsingFnApply && current.type == TokenType.op)
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
                parseOp(parent, null, op);
            }
        }*/
        
        while (true)
        {
            auto old = ps.parseOpLeftToRight;
            ps.parseOpLeftToRight = false;
            list ~= parse(parent, ps);
            ps.parseOpLeftToRight = old;

            if (empty)
            {
                vctx.remark(textRemark(list[$ - 1], "Closing brace is missing"));
                missingClosingBrace = true;
                if (sepPassedIsComa)
                    vctx.remark(textRemark(list[$ - 1], "Expected an expression after coma"));
                goto end;
            }
            else if (current.type == TokenType.braceEnd)
            {
                if (sepPassedIsComa)
                    vctx.remark(textRemark(list[$ - 1], "Expected an expression after coma"));

                if (current.text[0] == opposite)
                    break;

                vctx.remark(textRemark(current, "Closing brace has no matching opening brace"));

                nextTok();
                continue;
            }

            if (list  && !sepPassed)
                vctx.remark(textRemark(current, "To separate expressions use coma or new line"));
        }

        nextTok();

        end:
        Exp lastNotNull;
        foreach_reverse (i; list)
            if (i !is null)
            {
                lastNotNull = i;
                break;
            }

        foreach (ref e; list)
            if (e is null)
                e = new ValueUnknown(parent);

        if (lastNotNull)
            lastNotNull.setTokens = toks[lastNotNull.tokens[0].index .. current.index + 1];
        
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
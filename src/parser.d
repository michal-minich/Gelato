module parser;


import std.stdio, std.algorithm, std.array, std.conv;
import common, remarks, validation, tokenizer, ast;


struct ParseResult
{
    Remark[] remarks;
    Exp value;
}


final class Parser
{
    private Token[] toks2;
    private Token[] toks;
    private IValidationContext vctx;
    private Token current;


    this (IValidationContext valContext, const dstring src)
    {
        vctx = valContext;
        toks = (new Tokenizer(src)).array();
        toks2 = toks;
        current = toks.front;
    }


    Exp[] parseAll ()
    {
        Exp[] res;
        Exp e;
        while ((e = parse()) !is null)
            res ~= e;
        return res;
    }


    private Exp prev;
    private T newExp (T) (T exp) if (is (T : Exp))
    {
        if (prev)
            prev.next = exp;
        exp.prev = prev;
        prev = exp;
        return exp;
    }


    private Exp parse ()
    {
        if (toks.empty)
            return null;

        if (current.type == TokenType.newLine || current.type == TokenType.white)
            nextNonWhiteTok();

        switch (current.type)
        {
            case TokenType.num: return parseNum();
            case TokenType.ident: return parseIdent();
            case TokenType.textStart: return parseText();

            case TokenType.braceStart: return parseBrace();
            case TokenType.braceEnd: assert(false, "redudant brace end");

            case TokenType.keyIf: return parserIf();
            case TokenType.keyThen: assert(false, "then without if");
            case TokenType.keyElse: assert(false, "else without if");
            case TokenType.keyEnd: assert(false, "end without if");

            case TokenType.keyFn: return parserFn();
            case TokenType.keyReturn: return parserReturn();

            case TokenType.keyGoto: return parserGoto();
            case TokenType.keyLabel: return parserLabel();

            //case TokenType.keyStruct: return parserStruct();
            //case TokenType.keyThrow: return parserThrow();
            //case TokenType.keyVar: return parserVar();

            case TokenType.unknown: return parseUnknown();
            case TokenType.empty: assert (false, "empty token");
            default: return null;
        }
    }


    private void nextTok ()
    {
        if (!toks.empty) {
            toks.popFront();
            if (!toks.empty)
            current = toks.front;
        }
    }


    private void nextNonWhiteTok ()
    {
        nextTok();
        while (!toks.empty && (current.type == TokenType.white
                            || current.type == TokenType.newLine))
            nextTok();
    }


    private void skipWhiteIfWhite ()
    {
        if (!toks.empty && (current.type == TokenType.white
                         || current.type == TokenType.newLine))
            nextNonWhiteTok();
    }


    private AstIf parserIf ()
    {
        Exp[] ts;
        uint startIndex = current.index;
        nextTok();
        auto w = parse ();
        nextNonWhiteTok();

        if (current.type == TokenType.keyThen)
        {
            nextNonWhiteTok();

            while (current.type != TokenType.keyElse && current.type != TokenType.keyEnd)
            {
                ts ~= parse();
                nextNonWhiteTok();
            }

            Exp[] es;
            if (current.type == TokenType.keyElse)
            {
                while (current.type != TokenType.keyEnd)
                {
                    es ~= parse();
                    nextNonWhiteTok();
                }
            }

            nextTok();

            const last = es is null ? ts : es;
            return newExp(new AstIf (
                toks2[startIndex ..  last[$ - 1].tokens[$ - 1].index + 1], w, ts, es));
        }
        else
        {
            assert (false, "no then");
        }
    }


    private AstFn parserFn ()
    {
        uint startIndex = current.index;
        AstDeclr[] params;

        nextNonWhiteTok();
        if (current.type != TokenType.braceStart && current.text != "(")
            assert (false, "no brace after fn");

        nextNonWhiteTok();
        if (current.type == TokenType.braceEnd && current.text == ")")
            nextTok();
        else
            params = parseFnParameter();

        skipWhiteIfWhite();
        if (current.type == TokenType.braceStart && current.text == "{")
            nextTok();
        else
            assert (false, "no curly brace after fn");

        Exp[] items;
        skipWhiteIfWhite();
        if (current.type == TokenType.braceEnd && current.text == "}")
        {
        }
        else
        {
            while (current.type != TokenType.braceEnd && current.text != "}")
            {
                items ~= parse();
                skipWhiteIfWhite();
            }
        }

        auto f = newExp(new AstFn (toks2[startIndex .. current.index + 1], params, items));
        nextTok();
        return f;
    }


    private AstDeclr[] parseFnParameter ()
    {
        AstDeclr[] params;
        while (true)
        {
            auto e = parse();
            auto ident = cast(AstIdent)e;
            if (!ident)
            {
                assert (false, "fn parameter is not identifier");
            }
            else
            {
                skipWhiteIfWhite();
                if (current.type == TokenType.braceEnd && current.text == ")")
                {
                    params ~= newExp(new AstDeclr(
                        toks2[current.index .. current.index + 1], ident, null, null));
                    nextTok();
                    return params;
                }
                else if (current.type != TokenType.op && current.text != ",")
                {
                    assert (false, "no fn arg coma");
                }

                params ~= newExp(new AstDeclr(
                    toks2[current.index .. current.index + 1], ident, null, null));
                nextTok();
            }
        }
    }


    private AstReturn parserReturn ()
    {
        auto startIndex = current.index;
        nextNonWhiteTok();
        auto e = parse();
        if (!e)
            assert (false, "return without expression");
        return newExp(new AstReturn (toks2[startIndex .. e.tokens[$ - 1].index + 1], e));
    }


    private AstGoto parserGoto ()
    {
        auto startIndex = current.index;
        nextNonWhiteTok();
        if (current.type != TokenType.ident)
            assert (false, "goto without identifier");
        auto g = newExp(new AstGoto (toks2[startIndex .. current.index + 1], current.text));
        nextTok();
        return g;
    }


    private AstLabel parserLabel ()
    {
        auto startIndex = current.index;
        nextNonWhiteTok();
        if (current.type != TokenType.ident)
            assert (false, "label without identifier");
        auto l = newExp(new AstLabel (toks2[startIndex .. current.index + 1], current.text));
        nextTok();
        return l;
    }


    private Exp parseBrace ()
    {
        auto b = current.text[0];

        if (b != '(')
            assert (false, "unsupported brace");

        nextTok();

        if (current.type == TokenType.braceEnd)
            assert (false, "empty braces");

        auto e = parse();

        if (current.type != TokenType.braceEnd || current.text[0] != oppositeBrace(b))
        {
            assert (false, "missing closing brace");
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


    Exp parseText ()
    {
        Token[] ts;
        dstring txt;

        nextTok();

        if (toks.empty)
        {
            assert (false, "unclosed empty text");
        }

        while (current.type != TokenType.textEnd)
        {
            if (toks.empty)
            {
                assert (false, "unclosed text");
                //return newExp(new AstText(ts, txt));
            }

            immutable t = current;
            ts ~= t;
            txt ~= t.type == TokenType.textEscape ? t.text.toInvisibleCharsText() : t.text;

            nextTok();
        }

        nextTok();

        return newExp(txt.length == 1 && ts[0].text == "'"
            ? new AstChar(ts, txt[0]) : new AstText(ts, txt));
    }


    private AstUnknown parseUnknown ()
    {
        auto u = newExp(new AstUnknown (toks[0 .. 1]));
        nextTok();
        return u;
    }


    private AstNum parseNum ()
    {
        auto n = newExp(new AstNum (toks[0 .. 1], current.text));
        nextTok();
        return n;
    }


    private Exp parseIdent ()
    {
        auto i = parseIdentOnly ();
        skipWhiteIfWhite();
        if (toks.empty)
            return i;
        else if (current.type == TokenType.braceStart && current.text == "(")
            return parseFnApply(i);
        else if (current.type == TokenType.op && current.text == "=")
            return parseDeclr(i);
        else
            return i;
    }


    private AstDeclr parseDeclr (AstIdent i)
    {
        nextTok();
        auto e = parse();
        return newExp(new AstDeclr(
            toks2[i.tokens[$ - 1].index .. e.tokens[$ - 1].index + 1], i, null, e));
    }


    private AstFnApply parseFnApply (AstIdent i)
    {
        nextNonWhiteTok();
        if (current.type == TokenType.braceEnd && current.text == ")")
        {
            auto fa = newExp(new AstFnApply (
                toks2[i.tokens[$ - 1].index .. current.index + 1], i, null));
            nextTok();
            return fa;
        }
        else
        {
            Exp[] args;
            while (current.type != TokenType.braceEnd && current.text != ")")
            {
                args ~= parse();
                skipWhiteIfWhite();

                if (current.type == TokenType.op && current.text == ",")
                {
                    nextTok();
                    skipWhiteIfWhite();
                }
                else if (current.type == TokenType.braceEnd && current.text == ")")
                {
                    break;
                }
                else
                {
                    assert (false, "missing comma in fn apply");
                }
            }
            auto fa = newExp(new AstFnApply (
                toks2[i.tokens[$ - 1].index .. current.index + 1], i, args));
            nextTok();
            return fa;
        }
    }


    private AstIdent parseIdentOnly ()
    {
        auto i = newExp(new AstIdent (toks[0 .. 1], current.text));
        nextTok();
        return i;
    }
}
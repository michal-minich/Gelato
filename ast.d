module ast;

import std.stdio, std.algorithm, std.array, std.conv;
import common, tokenizer;


interface IExp
{
    @property dstring str ();
}


abstract class Exp : IExp
{
    Token[] tokens;
    //Position start;
    //Position end;

    this (Token[] toks) { tokens = toks; }
}


final class AstUnknown : Exp
{
    this (Token[] toks) { super(toks); }

    @property dstring str ()
    {
        return tokens.map!(t => t.text)().join();
    }
}


final class AstFile : Exp
{
    AstDeclr[] declarations;

    this (Token[] toks, AstDeclr[] declrs)
    {
        super(toks);
        declarations = declrs;
    }

    @property dstring str ()
    {
        return declarations.map!(d => d.str)().join(newLine);
    }
}


final class AstDeclr : Exp
{
    AstIdent ident;
    Exp type;
    Exp value;

    this (Token[] toks, AstIdent identifier, Exp t, Exp val)
    {
        super(toks);
        ident = identifier;
        type = t;
        value = val;
    }

    @property dstring str ()
    {
        if (type is null)
            type = new AstIdent(tokens, "T");

        if (type is null)       return dtext (ident.str, " = ", value.str);
        else if (value is null) return dtext (ident.str, " : ", type.str);
        else                    return dtext (ident.str, " : ", type.str, " = ", value.str);
    }
}


final class AstStruct : Exp
{
    AstDeclr[] declarations;

    this (Token[] toks, AstDeclr[] declrs)
    {
        super(toks);
        declarations = declrs;
    }

    @property dstring str()
    {
        return dtext("struct", newLine, "{", newLine, "\t",
            declarations.map!(d => d.str)().join(newLine ~ "\t"), newLine ~ "}");
    }
}


final class AstIdent : Exp
{
    dstring ident;

    this (Token[] toks, dstring identfier)
    {
        super(toks);
        ident = identfier;
    }

    @property dstring str ()
    {
        return ident;
    }
}


final class AstNum : Exp
{
    dstring value;

    this (Token[] toks, dstring val)
    {
        super(toks);
        value = val;
    }

    @property dstring str () { return value; }
}


final class AstText : Exp
{
    dstring value;

    this (Token[] toks, dstring val)
    {
        super(toks);
        value = val;
    }

    @property dstring str ()
    {
        return dtext("\"", value.toVisibleCharsText(), "\"");
    }
}


final class AstChar : Exp
{
    dchar value;

    this (Token[] toks, dchar val)
    {
        super(toks);
        value = val;
    }

    @property dstring str ()
    {
        return dtext("'", to!dstring(value).toVisibleCharsChar(), "'");
    }
}


final class AstFn : Exp
{
    AstDeclr[] params;
    Exp[] fnItems;

    this (Token[] toks, AstDeclr[] parameters, Exp[] funcItems)
    {
        super(toks);
        params = parameters;
        fnItems = funcItems;
    }

    @property dstring str ()
    {
        return dtext("fn (", params.map!(p => p.str)().join(", "),
                    ")", newLine, "{", newLine, "\t",
                    fnItems.map!(e => e.str)().join(newLine ~ "\t"),  newLine, "}");
    }
}


final class AstFnApply : Exp
{
    AstIdent ident;
    Exp[] args;

    this (Token[] toks, AstIdent identifier, Exp[] arguments)
    {
        super(toks);
        ident = identifier;
        args = arguments;
    }

    @property dstring str ()
    {
        return dtext(ident.ident, "(", args.map!(a => a.str)().join(", "), ")");
    }
}


final class AstIf : Exp
{
    Exp when;
    Exp[] then;
    Exp[] otherwise;

    this (Token[] toks, Exp w, Exp[] t, Exp[] o)
    {
        super(toks);
        when = w;
        then = t;
        otherwise = o;
    }

    @property dstring str ()
    {
        auto t = then.map!(th => th.str)().join(newLine ~ "\t");
        return otherwise.length == 0
            ? dtext("if ", when.str, " then ", t, " end")
            : dtext("if ", when.str, " then ", t, " else ",
                otherwise.map!(o => o.str)().join(newLine ~ "\t"), " end");
    }
}


final class AstLabel : Exp
{
    dstring label;

    this (Token[] toks, dstring lbl)
    {
        super(toks);
        label = lbl;
    }

    @property dstring str ()
    {
        return "label " ~ label;
    }
}


final class AstGoto : Exp
{
    dstring label;

    this (Token[] toks, dstring lbl)
    {
        super(toks);
        label = lbl;
    }

    @property dstring str ()
    {
        return "goto " ~ label;
    }
}


final class AstReturn : Exp
{
    Exp exp;

    this (Token[] toks, Exp e)
    {
        super(toks);
        exp = e;
    }

    @property dstring str ()
    {
        return "return " ~ exp.str;
    }
}

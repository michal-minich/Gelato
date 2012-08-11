module ast;

import std.stdio, std.algorithm, std.array, std.conv;
import common;


interface IExp
{
    @property dstring str ();
}


abstract class Exp : IExp
{
    Position start;
    Position end;
}


final class AstFile : Exp
{
    AstDeclr[] declarations;

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

    @property dstring str ()
    {
        if (type is null)       return dtext (ident.str, " = ", value.str);
        else if (value is null) return dtext (ident.str, " : ", type.str);
        else                    return dtext (ident.str, " : ", type.str, " = ", value.str);
    }
}


final class AstStruct : Exp
{
    AstDeclr[] declarations;

    @property dstring str()
    {
        return dtext("struct", newLine, "{", newLine, "\t",
            declarations.map!(d => d.str)().join(newLine ~ "\t"), newLine ~ "}");
    }
}


final class AstIdent : Exp
{
    dstring ident;

    @property dstring str ()
    {
        return ident;
    }
}


final class AstNum : Exp
{
    dstring value;

    @property dstring str ()
    {
        return value;
    }
}


final class Astdtext : Exp
{
    dstring value;

    @property dstring str ()
    {
        return dtext("\"", value.toVisibleCharsText(), "\"");
    }
}


final class AstChar : Exp
{
    dchar value;

    @property dstring str ()
    {
        return dtext("'", to!dstring(value).toVisibleCharsChar(), "'");
    }
}


final class AstFn : Exp
{
    AstDeclr[] params;
    Exp[] fnItems;

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

    @property dstring str ()
    {
        return dtext(ident, "(", args.map!(a => a.str)().join(", "), ")");
    }
}


final class AstIf : Exp
{
    Exp when;
    Exp[] then;
    Exp[] otherwise;

    @property dstring str ()
    {
        auto t = then.map!(th => th.str)().join(newLine ~ "\t");
        return otherwise.length == 0
            ? dtext("if ", when.str, " then ", t, " end")
            : dtext("if ", when.str, " then ", t, " else ",
                otherwise.map!(o => o.str)().join(newLine ~ "t"), " end");
    }
}


final class AstLabel : Exp
{
    dstring label;

    @property dstring str ()
    {
        return "label " ~ label;
    }
}


final class AstGoto : Exp
{
    dstring label;

    @property dstring str ()
    {
        return "goto " ~ label;
    }
}


final class AstReturn : Exp
{
    Exp exp;

    @property dstring str ()
    {
        return "return " ~ exp.str;
    }
}

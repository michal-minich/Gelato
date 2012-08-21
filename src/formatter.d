module formatter;

import std.algorithm, std.array, std.conv;
import common, parse.ast;


@trusted pure final class FormatVisitor : IAstVisitor!(dstring)
{
    bool useInferredTypes;

    private enum tab = "    ";


    nothrow dstring visit (AstNum e)
    {
        return e.value;
    }


    dstring visit (AstUnknown e)
    {
        return e.tokens ? e.tokens.map!(t => t.text)().join() : "<unknown>";
    }


    dstring visit (AstFile e)
    {
        return e.exps.map!(d => d.str(this))().join(newLine);
    }


    dstring visit (AstDeclr e)
    {
        auto t = useInferredTypes ? e.infType : e.type;

        if (!t && !e.value) return e.ident.str(this);
        else if (!t)        return dtext (e.ident.str(this), " = ", e.value.str(this));
        else if (!e.value)  return dtext (e.ident.str(this), " : ", t.str(this));
        else                return dtext (e.ident.str(this), " : ", t.str(this),
                                    " = ", e.value.str(this));
    }


    dstring visit (AstStruct e)
    {
        return dtext("struct", newLine, "{", newLine, tab,
            e.exps.map!(d => d.str(this))().join(newLine ~ tab), newLine ~ "}");
    }


    dstring visit (AstFn e)
    {
        return dtext("fn (", e.params.map!(p => p.str(this))().join(", "),
                    ")", newLine, "{", newLine, tab,
                    e.exps.map!(e => e.str(this))().join(newLine ~ tab), newLine, "}");
    }


    dstring visit (AstFnApply e)
    {
        return dtext(e.ident.str(this),
            "(", e.args ? e.args.map!(a => a.str(this))().join(", ") : "", ")");
    }


    dstring visit (AstIdent e)
    {
        return e.idents.join(".").array();
    }


    nothrow dstring visit (AstLabel e)
    {
        return "label " ~ e.label;
    }


    dstring visit (AstReturn e)
    {
        return e.exp ? "return " ~ e.exp.str(this) : "return";
    }


    dstring visit (AstText e)
    {
        return dtext("\"", e.value.toVisibleCharsText(), "\"");
    }


    dstring visit (AstChar e)
    {
        return dtext("'", e.value.to!dstring().toVisibleCharsChar(), "'");
    }


    dstring visit (AstIf e)
    {
        auto t = e.then.map!(th => th.str(this))().join(newLine ~ tab);
        return e.otherwise.length == 0
            ? dtext("if ", e.when.str(this), " then ", t, " end")
            : dtext("if ", e.when.str(this), " then ", t, " else ",
                e.otherwise.map!(o => o.str(this))().join(newLine ~ tab), " end");
    }


    nothrow dstring visit (AstGoto e)
    {
        return "goto " ~ e.label;
    }


    dstring visit (AstLambda e)
    {
        return e.fn.str(this);
    }


    dstring visit (TypeType tt) { return dtext("Type(", tt.type.str(this) ,")"); }

    dstring visit (TypeAny) { return "Any"; }

    dstring visit (TypeVoid) { return "Void"; }

    dstring visit (TypeNum) { return "Num"; }

    dstring visit (TypeText) { return "Text"; }

    dstring visit (TypeChar) { return "Char"; }

    dstring visit (BuiltinFn) { assert (false, "built in fn has no textual representation"); }


    dstring visit (TypeOr or)
    {
        return dtext("AnyOf(", or.types.map!(o => o.str(this))().join(", "), ")");
    }


    dstring visit (TypeFn tfn)
    {
        return dtext("Fn(", (tfn.types ~ tfn.retType).map!(t => t.str(this))().join(", "), ")");
    }
}



final class Formatter
{
    static Formatter load (
        IValidationContext vctx, const string rootPath, const string name)
    {
        auto exps = parseFile(vctx, rootPath ~ "/format/" ~ name ~ ".gel");
        auto f = new Formatter;

        /*foreach (e; exps)
        {
            auto decldstring = cast(AstDeclr)e;
            if (declr.ident.ident == "name")
                rl.name = declr.value.str(this);
            else
                rl.values[declr.ident.ident] = declr.value.str(this).to!RemarkSeverity();
        }*/

        return f;
    }
}
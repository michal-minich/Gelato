module formatter;

import std.stdio, std.algorithm, std.array, std.conv, std.string, std.file, std.utf;
import common, ast, remarks, parser, validation, interpreter;


@trusted final class FormatVisitor : AstVisitor!(dstring)
{
    dstring visit (Exp e)
    {
        return "";
    }

    dstring visit (AstNum e)
    {
        return e.value;
    }

    dstring visit (AstUnknown e)
    {
        return e.tokens.map!(t => t.text)().join();
    }

    dstring visit (AstFile e)
    {
        return e.declarations.map!(d => d.accept(fv))().join(newLine);
    }

    dstring visit (AstDeclr e)
    {
        if (!e.type && !e.value) return e.ident.accept(fv);
        else if (!e.type)        return dtext (e.ident.accept(fv), " = ", e.value.accept(fv));
        else if (!e.value)       return dtext (e.ident.accept(fv), " : ", e.type.accept(fv));
        else                     return dtext (e.ident.accept(fv), " : ", e.type.accept(fv), " = ", e.value.accept(fv));
    }

    dstring visit (AstStruct e)
    {
        return dtext("struct", newLine, "{", newLine, "\t",
            e.declarations.map!(d => d.accept(fv))().join(newLine ~ "\t"), newLine ~ "}");
    }

    dstring visit (AstFn e)
    {
        return dtext("fn (", e.params.map!(p => p.accept(fv))().join(", "),
                    ")", newLine, "{", newLine, "\t",
                    e.fnItems.map!(e => e.accept(fv))().join(newLine ~ "\t"),  newLine, "}");
    }

    dstring visit (AstFnApply e)
    {
        return dtext(e.ident.ident, "(", e.args.map!(a => a.accept(fv))().join(", "), ")");
    }

    dstring visit (AstIdent e)
    {
        return e.ident;
    }

    dstring visit (AstLabel e)
    {
        return "label " ~ e.label;
    }

    dstring visit (AstReturn e)
    {
        return "return " ~ e.exp.accept(fv);
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
        auto t = e.then.map!(th => th.accept(fv))().join(newLine ~ "\t");
        return e.otherwise.length == 0
            ? dtext("if ", e.when.accept(fv), " then ", t, " end")
            : dtext("if ", e.when.accept(fv), " then ", t, " else ",
                e.otherwise.map!(o => o.accept(fv))().join(newLine ~ "\t"), " end");
    }

    dstring visit (AstGoto e)
    {
        return "goto " ~ e.label;
    }

    dstring visit (AstLambda e)
    {
        return e.fn.accept(fv);
    }
}



final class Formatter
{
    static Formatter load (
        IValidationContext vctx, const string rootPath, const string name)
    {
        immutable src = toUTF32(readText!string(rootPath ~ "/format/" ~ name ~ ".gel"));

        auto exps = (new Parser(vctx, src)).parseAll();

        auto f = new Formatter;

        /*foreach (e; exps)
        {
            auto decldstring = cast(AstDeclr)e;
            if (declr.ident.ident == "name")
                rl.name = declr.value.accept(fv);
            else
                rl.values[declr.ident.ident] = declr.value.accept(fv).to!RemarkSeverity();
        }*/

        return f;
    }
}
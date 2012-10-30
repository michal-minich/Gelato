module formatter;

import std.algorithm, std.array, std.conv;
import common, parse.ast;


@trusted pure final class FormatVisitor : IFormatVisitor
{
    bool useInferredTypes;
    bool printOriginalParse;

    private uint level;
    enum dstring tabs = "    "d.replicate(16);


    const private @property tab() { return tabs[0 .. 4 * level]; }

    const private @property tab1() { return tabs[0 .. 4 * (level - 1)]; }


    const dstring visit (ValueNum e) { return e.value.to!dstring(); }


    dstring visit (AstUnknown e)
    {
        return e.tokens ? e.tokens.map!(t => t.text)().join() : "<unknown>";
    }


    dstring visit (StmDeclr e)
    {
        if (printOriginalParse && !e.parent)
            return e.value.str(this);

        auto t = useInferredTypes ? e.infType : e.type;

        if (!t && !e.value) return e.slot.str(this);
        else if (!t)        return dtext (e.slot.str(this), " = ", e.value.str(this));
        else if (!e.value)  return dtext (e.slot.str(this), " : ", t.str(this));
        else                return dtext (e.slot.str(this), " : ", t.str(this),
                                    " = ", e.value.str(this));
    }


    dstring visit (ValueStruct e)
    {
        if (!e.parent)
            return e.exps.map!(d => d.str(this))().join(newLine);

        auto exps = e.exps.map!(d => d.str(this))().join(newLine ~ tab);

        if (printOriginalParse && !e.parent)
            return exps;

        ++level;
        immutable txt = dtext("struct", newLine, tab1, "{", newLine, tab, exps, newLine, tab1, "}");
        --level;
        return txt;
    }


    dstring visit (ValueFn e)
    {
        ++level;
        immutable bdy = e.exps.length == 0
            ? " { "
            : e.exps.length == 1
                ? " { " ~ e.exps[0].str(this) ~ " "
                : dtext(newLine, tab1, "{", newLine, tab,
                    e.exps.map!(e => e.str(this))().join(newLine ~ tab), newLine, tab1);

        immutable txt = dtext("fn (", e.params.map!(p => p.str(this))().join(", "), ")", bdy, "}");
        --level;
        return txt;
    }


    dstring visit (ExpFnApply e)
    {
        if (printOriginalParse && !e.parent)
            return e.applicable.str(this);

        return dtext(e.applicable.str(this),
            "(", e.args ? e.args.map!(a => a.str(this))().join(", ") : "", ")");
    }


    const dstring visit (ExpIdent i)
    {
        return i.text;
    }


    nothrow dstring visit (StmLabel e)
    {
        return "label " ~ e.label;
    }


    dstring visit (StmReturn e)
    {
        return e.exp ? "return " ~ e.exp.str(this) : "return";
    }


    dstring visit (ValueText e)
    {
        return dtext("\"", e.value.toVisibleCharsText(), "\"");
    }


    dstring visit (ValueChar e)
    {
        return dtext("'", e.value.to!dstring().toVisibleCharsChar(), "'");
    }


    dstring visit (ExpIf e)
    {
        ++level;
        immutable expandBoth = e.then.length > 1 || e.otherwise.length > 1;
        immutable txt = e.otherwise.length == 1 && cast(AstUnknown)e.otherwise[0]
            ? dtext("if ", e.when.str(this), " then", dtextExps(e.then, expandBoth), "end")
            : dtext("if ", e.when.str(this), " then", dtextExps(e.then, expandBoth), "else",
                dtextExps(e.otherwise, expandBoth), "end");
        --level;
        return txt;
    }


    private dstring dtextExps(Exp[] exps, bool forceExpand)
    {
        if (!forceExpand && exps.length == 1)
        {
            return " " ~ exps[0].str(this) ~ " ";
        }
        else
        {
            dstring res;
            foreach (e; exps)
                res ~= newLine ~ tab ~ e.str(this);
            return res ~ newLine ~ tab1;
        }
    }


    const nothrow dstring visit (StmGoto e)
    {
        return "goto " ~ e.label;
    }


    dstring visit (ExpLambda e)
    {
        return e.fn.str(this);
    }


    dstring visit (ExpScope sc) 
    {
        dstring bdy;
        foreach (ix, d; sc.declarations)
            bdy ~= newLine ~ tab ~ d.slot.str(this) ~ " = " ~ sc.values[ix].str(this);

        return "{ "~ bdy ~ " }"; 
    }


    dstring visit (ExpDot dot) { return dot.record.str(this) ~ "." ~ dot.member; }

    dstring visit (TypeType tt) { return dtext("Type(", tt.type.str(this) ,")"); }

    const dstring visit (TypeAny) { return "Any"; }

    const dstring visit (TypeVoid) { return "Void"; }

    const dstring visit (TypeNum) { return "Num"; }

    const dstring visit (TypeText) { return "Text"; }

    const dstring visit (TypeChar) { return "Char"; }

    const dstring visit (TypeStruct) { return "struct { TODO }"; }

    const dstring visit (BuiltinFn) { assert (false, "built in fn has no textual representation"); }

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
            auto decldstring = cast(StmDeclr)e;
            if (declr.ident.text == "name")
                rl.name = declr.value.str(this);
            else
                rl.values[declr.ident.text] = declr.value.str(this).to!RemarkSeverity();
        }*/

        return f;
    }
}
module syntax.Formatter;

import std.algorithm, std.array, std.conv;
import common, syntax.ast;


@trusted pure final class Formatter : IFormatVisitor
{
    bool useInferredTypes;
    bool printOriginalParse;

    private uint level;
    enum dstring tabs = "    "d.replicate(16);


    const private @property dstring tab() { return tabs[0 .. 4 * level]; }

    const private @property dstring tab1() { return tabs[0 .. 4 * (level - 1)]; }


    const dstring visit (ValueInt i) { return i.value.to!dstring(); }

    const dstring visit (ValueFloat f) { return f.value.to!dstring(); }


    dstring visit (ValueUnknown e)
    {
        return e.tokens ? e.tokens.map!(t => t.text)().join() : "<unknown" ~ (e.ident ? ": " ~ e.ident.text : "") ~ ">";
    }


    dstring visit (ExpAssign e)
    {
        auto t = useInferredTypes ? e.infType : e.type;
        auto v = e.isVar ? "var " : "";
        auto hasValue = e.value && !cast(ValueUnknown)e.value;

        dstring access;
        final switch (e.accessScope)
        {
            case AccessScope.scopePrivate: access = ""; break;
            case AccessScope.scopePublic: access = "public "; break;
            case AccessScope.scopePackage: access = "package "; break;
            case AccessScope.scopeModule: access = "module "; break;
        }

        if (!t && !hasValue) return e.slot.str(this);
        else if (!t)         return dtext (access, v, e.slot.str(this), " = ", e.value.str(this));
        else if (!hasValue)  return dtext (access, v, e.slot.str(this), " : ", t.str(this));
        else                 return dtext (access, v, e.slot.str(this), " : ", t.str(this),
                                    " = ", e.value.str(this));
    }


    dstring visit (ValueStruct e)
    {
        if (!e.parent)
            return e.exps.map!(d => d.str(this))().join(newLine);

        ++level;
        auto exps = e.exps.map!(d => d.str(this))().join(newLine ~ tab);
        --level;

        if (printOriginalParse && !e.parent)
            return exps;

        if (e.exps.length == 0)
        {
            immutable txt = dtext("struct { }");
            return txt;
        }
       /* else if (e.exps.length == 1)
        {
            ++level;
            immutable txt = dtext("struct { ", exps, " }");
            --level;
            return txt;
        }*/
        else
        {
            ++level;
            immutable txt = dtext("struct", newLine, tab1, "{", newLine, tab, exps, newLine, tab1, "}");
            --level;
            return txt;
        }
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
        if (e.applicable.tokens)
        {
            if (e.applicable.tokens[0].type == TokenType.braceStart)
                return formatBraceOpApply(e.applicable.tokens[0].text, e.args);

            else if (e.applicable.tokens[0].type == TokenType.op)
                return dtext(e.args[0].str(this), " ", e.applicable.tokens[0].text, " ", e.args[1].str(this));
        }

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


    dstring visit (StmReturn r)
    {
        return r.exp ? "return " ~ r.exp.str(this) : "return";
    }


    dstring visit (StmImport im)
    {
        return "import" ~ (im.exp ?  " " ~ im.exp.str(this) : "");
    }


    dstring visit (StmThrow th)
    {
        return "throw" ~ (th.exp ?  " " ~ th.exp.str(this) : "");
    }


    dstring visit (ValueText e)
    {
        return dtext("\"", e.value.toVisibleCharsText(), "\"");
    }


    dstring visit (ValueChar e)
    {
        return dtext("'", e.value.to!dstring().toVisibleCharsChar(), "'");
    }


    dstring visit (ValueArray arr) { return formatBraceOpApply("[", arr.items); }


    dstring visit (ExpIf e)
    {
        ++level;
        immutable forceExpand = e.then.exps.length > 1 || e.otherwise.exps.length > 1;
        auto txt = dtext("if ", e.when.str(this), " then", dtextExps(e.then.exps, forceExpand));

        if (e.otherwise.exps.length)
            txt ~= dtext("else", dtextExps(e.otherwise.exps, forceExpand));

        --level;
        return txt ~ "end";
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


    dstring visit (Closure sc) 
    {
        dstring bdy;
        foreach (ix, d; sc.declarations)
            bdy ~= newLine ~ tab ~ d.slot.str(this) ~ " = " ~ sc.values[ix].str(this);

        return "{ "~ bdy ~ " }"; 
    }


    dstring visit (ExpDot dot) { return dot.record.str(this) ~ "." ~ dot.member.text; }

    dstring visit (TypeType tt) { return dtext("Type(", tt.type.str(this) ,")"); }

    const dstring visit (TypeAny) { return "Any"; }

    const dstring visit (TypeVoid) { return "Void"; }

    const dstring visit (TypeInt) { return "Int"; }

    const dstring visit (TypeFloat) { return "Float"; }

    const dstring visit (TypeText) { return "Text"; }

    const dstring visit (TypeChar) { return "Char"; }

    dstring visit (TypeStruct s) { return s.typeAlias.slot.str(fv); }
       // return "Struct(" ~ s.value.exps.map!(vs => vs.infType.str(this))().join(", ").array() ~ ")"; }

    dstring visit (TypeArray arr) { return "Array(" ~ (arr.elementType ? arr.elementType.str(this) : "?") ~ ")"; }

    const dstring visit (ValueBuiltinFn) { assert (false, "built in fn has no textual representation"); }

    dstring visit (TypeAnyOf or)
    {
        return dtext("AnyOf(", or.types.map!(o => o.str(this))().join(", "), ")");
    }


    dstring visit (TypeFn tfn)
    {
        return dtext("Fn(", (tfn.types ~ tfn.retType).map!(t => t.str(this))().join(", "), ")");
    }


    private dstring formatBraceOpApply (dstring braceStart, Exp[] items)
    {
        return dtext(braceStart, items.map!(i => i.str(this))().join(", "), braceStart.map!reverseBrace().array().getReversed());
    }


    static Formatter load (IValidationContext vctx, const string rootPath, const string name)
    {
        auto exps = parseFile(vctx, rootPath ~ "/format/" ~ name ~ ".gel");
        auto f = new Formatter;

        /*foreach (e; exps)
        {
        auto decldstring = cast(ExpAssign)e;
        if (declr.ident.text == "name")
        rl.name = declr.value.str(this);
        else
        rl.values[declr.ident.text] = declr.value.str(this).to!RemarkSeverity();
        }*/

        return f;
    }
}


@safe pure nothrow dchar reverseBrace (dchar brace)
{
    switch (brace)
    {
        case '[': return ']';
        case '{': return '}';
        case '(': return ')';
        default: assert(false);         
    }
}